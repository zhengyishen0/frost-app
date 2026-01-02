//
//  AppDelegate.swift
//  Frost
//
//  Original by phucld on 12/17/19.
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//
//  Updated for Frost.
//

import Cocoa
import SwiftUI
import HotKey
import Combine

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    let statusBarController = StatusBarController()
    let cursorShakeDetector = CursorShakeDetector()
    private var cancellableSet: Set<AnyCancellable> = []

    // Shake restore timer
    private var shakeRestoreTimer: Timer?
    private var wasEnabledBeforeShake = false

    var hotKey: HotKey? {
        didSet {
            guard let hotKey = hotKey else { return }

            hotKey.keyDownHandler = {
                BlurManager.sharedInstance.setting.isEnabled.toggle()
            }
        }
    }

    let eventMonitor = EventMonitor(mask: .leftMouseDown) { _ in
        // Trigger blur immediately on mouse down (not up)
        BlurManager.sharedInstance.blur(
            runningApplication: NSWorkspace.shared.frontmostApplication,
            withDelay: false
        )
    }

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        hideDockIcon()
        setupAutoStartAtLogin()
        openPrefWindowIfNeeded()
        setupHotKey()
        setupCursorShakeDetector()
        eventMonitor.start()
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        BlurManager.sharedInstance.blur(runningApplication: NSWorkspace.shared.frontmostApplication)
    }

    // MARK: - Setup Methods

    func setupHotKey() {
        guard let globalKey = UserDefaults.globalKey else { return }
        hotKey = HotKey(keyCombo: KeyCombo(carbonKeyCode: globalKey.keyCode, carbonModifiers: globalKey.carbonFlags))
    }

    func setupCursorShakeDetector() {
        // Configure shake detector - shake temporarily clears blur
        cursorShakeDetector.onShakeDetected = { [weak self] in
            self?.handleShakeDetected()
        }

        // Start monitoring
        cursorShakeDetector.start()

        // Update enabled state based on setting
        cursorShakeDetector.setEnabled(BlurManager.sharedInstance.setting.cursorShakeEnabled)

        // Observe setting changes
        BlurManager.sharedInstance.setting.$cursorShakeEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.cursorShakeDetector.setEnabled(enabled)
            }
            .store(in: &cancellableSet)
    }

    // MARK: - Shake Handling

    private func handleShakeDetected() {
        let setting = BlurManager.sharedInstance.setting

        // Cancel any existing timer
        shakeRestoreTimer?.invalidate()

        if setting.isEnabled && !wasEnabledBeforeShake {
            // Blur is on - shake to temporarily hide it (defrost)
            wasEnabledBeforeShake = true
            BlurManager.sharedInstance.defrost()

            // Start timer to restore blur
            startShakeRestoreTimer()
        } else if wasEnabledBeforeShake {
            // Already defrosted - extend the timer
            startShakeRestoreTimer()
        }
        // If blur was manually disabled (not by shake), do nothing
    }

    private func startShakeRestoreTimer() {
        let delay = BlurManager.sharedInstance.setting.shakeRestoreDelay.rawValue

        shakeRestoreTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, self.wasEnabledBeforeShake else { return }

            // Restore blur (refrost)
            BlurManager.sharedInstance.refrost()
            self.wasEnabledBeforeShake = false
        }
    }

    func openPrefWindowIfNeeded() {
        // Settings screen removed - all settings now in menu bar dropdown
    }

    func setupAutoStartAtLogin() {
        let isAutoStart = UserDefaults.isStartWhenLogin
        Util.setUpAutoStart(isAutoStart: isAutoStart)
    }

    func hideDockIcon() {
        NSApp.setActivationPolicy(.accessory)
    }
}
