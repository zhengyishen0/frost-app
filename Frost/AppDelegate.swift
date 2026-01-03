//
//  AppDelegate.swift
//  Frost
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
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
                let setting = BlurManager.sharedInstance.setting
                if !setting.isEnabled {
                    // Trying to enable - check license
                    if !LicenseManager.shared.canUseApp {
                        LicenseWindowController.shared.showLicenseWindow()
                        return
                    }
                }
                setting.isEnabled.toggle()
            }
        }
    }

    var eventMonitor: EventMonitor!

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        hideDockIcon()
        setupAutoStartAtLogin()
        checkLicenseStatus()
        openPrefWindowIfNeeded()
        setupHotKey()
        setupCursorShakeDetector()
        setupEventMonitor()
    }

    /// Check license/trial status and disable app if expired
    private func checkLicenseStatus() {
        if !LicenseManager.shared.canUseApp {
            // Trial expired and not licensed - force disable
            BlurManager.sharedInstance.setting.isEnabled = false
            // Show license window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                LicenseWindowController.shared.showLicenseWindow()
            }
        }
    }

    func setupEventMonitor() {
        // Track mouseDown, mouseUp, and mouseDragged to handle all interactions
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .leftMouseUp, .leftMouseDragged]) { [weak self] event in
            // Reset defrost timer on any mouse activity if currently defrosted
            if BlurManager.sharedInstance.isDefrosted {
                self?.resetDefrostTimerOnActivity()
            }

            // Only trigger blur update on mouse down (start of interaction)
            if event?.type == .leftMouseDown {
                BlurManager.sharedInstance.blur(
                    runningApplication: NSWorkspace.shared.frontmostApplication,
                    withDelay: false
                )
            }
        }
        eventMonitor.start()
    }

    /// Reset the defrost timer when user interacts with windows while defrosted
    private func resetDefrostTimerOnActivity() {
        guard wasEnabledBeforeShake else { return }

        // Cancel existing timer and start a new one
        shakeRestoreTimer?.invalidate()
        startShakeRestoreTimer()
        print("🔄 [Defrost] Timer reset due to window activity")
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

        // Reset shake state when blur is manually toggled
        BlurManager.sharedInstance.setting.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resetShakeState()
            }
            .store(in: &cancellableSet)
    }

    private func resetShakeState() {
        shakeRestoreTimer?.invalidate()
        shakeRestoreTimer = nil
        wasEnabledBeforeShake = false
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
        // Hardcoded 2 second inactivity delay before refrost
        let delay: TimeInterval = 2.0

        shakeRestoreTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, self.wasEnabledBeforeShake else { return }

            // Restore blur (refrost) with full transition animation
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
