//
//  StatusBarController.swift
//  Frost
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//

import Foundation
import Cocoa
import Combine
import SwiftUI

class StatusBarController {

    // MARK: - Properties

    private let menuStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var cancellableSet: Set<AnyCancellable> = []

    // MARK: - Init

    init() {
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        if let button = menuStatusItem.button {
            // Use SF Symbol snowflake icon (black, simple)
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            if let snowflakeImage = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Frost")?.withSymbolConfiguration(config) {
                snowflakeImage.isTemplate = true  // Makes it adapt to menu bar (black in light mode)
                button.image = snowflakeImage
            } else {
                // Fallback: simple asterisk-like snowflake character
                button.title = "✳"
                button.font = NSFont.systemFont(ofSize: 14)
            }

            let swipeView = StatusBarSwipeToSetAlphaView(
                frame: CGRect(origin: .zero, size: button.frame.size)
            )
            button.addSubview(swipeView)

            // Set initial opacity based on enabled state
            let setting = BlurManager.sharedInstance.setting
            button.alphaValue = setting.isEnabled ? 1.0 : 0.4

            // Update opacity when enabled state changes
            setting.$isEnabled
                .receive(on: DispatchQueue.main)
                .sink { [weak button] isEnabled in
                    button?.alphaValue = isEnabled ? 1.0 : 0.4
                }
                .store(in: &cancellableSet)
        }
        menuStatusItem.menu = createContextMenu()
    }

    // MARK: - Menu

    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        let setting = BlurManager.sharedInstance.setting

        // Power switch toggle (green macOS-style switch)
        let powerSwitchItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        powerSwitchItem.view = createPowerSwitchView(setting: setting)
        menu.addItem(powerSwitchItem)
        menu.addItem(NSMenuItem.separator())

        // Mode toggle - tab style: [ Frost | Fog ]
        let modeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        modeItem.view = createModeToggleView(setting: setting)
        menu.addItem(modeItem)

        // Transition Duration submenu
        let transitionMenu = NSMenu()
        var transitionItems: [TransitionDuration: NSMenuItem] = [:]

        for duration in TransitionDuration.allCases {
            let item = NSMenuItem(
                title: duration.label,
                action: #selector(setTransitionDuration(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = duration
            transitionMenu.addItem(item)
            transitionItems[duration] = item
        }

        let transitionMenuItem = NSMenuItem(title: "Transition".localized, action: nil, keyEquivalent: "")
        transitionMenuItem.submenu = transitionMenu

        // Update checkmarks for transition duration
        setting.$transitionDuration
            .receive(on: DispatchQueue.main)
            .sink { currentDuration in
                for (duration, item) in transitionItems {
                    item.state = duration == currentDuration ? .on : .off
                }
            }
            .store(in: &cancellableSet)

        menu.addItem(transitionMenuItem)
        menu.addItem(NSMenuItem.separator())

        // Shake to Defrost toggle (checkbox)
        let shakeItem = NSMenuItem(
            title: "Shake to Defrost".localized,
            action: #selector(toggleCursorShake),
            keyEquivalent: ""
        )
        shakeItem.target = self
        shakeItem.state = setting.cursorShakeEnabled ? .on : .off

        setting.$cursorShakeEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak shakeItem] enabled in
                shakeItem?.state = enabled ? .on : .off
            }
            .store(in: &cancellableSet)

        menu.addItem(shakeItem)

        // Start at Login toggle (checkbox)
        let startAtLoginItem = NSMenuItem(
            title: "Start at Login".localized,
            action: #selector(toggleStartAtLogin),
            keyEquivalent: ""
        )
        startAtLoginItem.target = self
        startAtLoginItem.state = setting.isStartWhenLogin ? .on : .off

        setting.$isStartWhenLogin
            .receive(on: DispatchQueue.main)
            .sink { [weak startAtLoginItem] enabled in
                startAtLoginItem?.state = enabled ? .on : .off
            }
            .store(in: &cancellableSet)

        menu.addItem(startAtLoginItem)

        // License status (above divider)
        let licenseStatus = LicenseManager.shared.statusText
        let licenseItem = NSMenuItem(
            title: licenseStatus,
            action: #selector(showLicense),
            keyEquivalent: ""
        )
        licenseItem.target = self

        // Add visual indicator for trial/licensed status
        if LicenseManager.shared.isLicensed {
            // Just show "Licensed" in normal color
            licenseItem.title = "Licensed"
        } else if !LicenseManager.shared.isTrialActive {
            // Trial expired - make it stand out
            licenseItem.attributedTitle = NSAttributedString(
                string: "Trial expired - Get License",
                attributes: [.foregroundColor: NSColor.systemRed]
            )
        }
        menu.addItem(licenseItem)
        menu.addItem(NSMenuItem.separator())

        // About
        let aboutItem = NSMenuItem(title: "About Frost".localized, action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Check for Updates
        let updateItem = NSMenuItem(title: "Check for Updates...".localized, action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        // DEBUG: Test Expiry button
        #if DEBUG
        menu.addItem(NSMenuItem.separator())
        let testExpiryItem = NSMenuItem(title: "⚠️ Test Expiry", action: #selector(testExpiry), keyEquivalent: "")
        testExpiryItem.target = self
        menu.addItem(testExpiryItem)
        #endif

        // Quit
        menu.addItem(NSMenuItem(title: "Quit".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    // MARK: - Power Switch View

    private func createPowerSwitchView(setting: SettingObservable) -> NSView {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 32))

        // Label
        let label = NSTextField(labelWithString: "Enabled".localized)
        label.frame = NSRect(x: 16, y: 6, width: 100, height: 20)
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = .labelColor
        containerView.addSubview(label)

        // Green toggle switch
        let toggle = NSSwitch(frame: NSRect(x: 150, y: 4, width: 40, height: 24))
        toggle.state = setting.isEnabled ? .on : .off
        toggle.target = self
        toggle.action = #selector(powerSwitchChanged(_:))
        containerView.addSubview(toggle)

        // Observe changes
        setting.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak toggle] isEnabled in
                toggle?.state = isEnabled ? .on : .off
            }
            .store(in: &cancellableSet)

        return containerView
    }

    @objc private func powerSwitchChanged(_ sender: NSSwitch) {
        if sender.state == .on {
            // Check if user can use the app
            if !LicenseManager.shared.canUseApp {
                // Trial expired and not licensed - show license window
                sender.state = .off
                LicenseWindowController.shared.showLicenseWindow()
                return
            }
        }
        BlurManager.sharedInstance.setting.isEnabled = (sender.state == .on)
    }

    // MARK: - Actions

    @objc private func toggleEnable() {
        BlurManager.sharedInstance.setting.isEnabled.toggle()
    }

    @objc private func setBlurModeFrost() {
        BlurManager.sharedInstance.setting.blurMode = .frost
    }

    @objc private func setBlurModeFog() {
        BlurManager.sharedInstance.setting.blurMode = .fog
    }

    @objc private func setTransitionDuration(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? TransitionDuration else { return }
        BlurManager.sharedInstance.setting.transitionDuration = duration
    }

    @objc private func toggleCursorShake() {
        BlurManager.sharedInstance.setting.cursorShakeEnabled.toggle()
    }

    @objc private func toggleStartAtLogin() {
        BlurManager.sharedInstance.setting.isStartWhenLogin.toggle()
    }

    @objc private func showLicense() {
        LicenseWindowController.shared.showLicenseWindow()
    }

    @objc private func showAbout() {
        AboutWindowController.shared.showAboutWindow()
    }

    #if DEBUG
    @objc private func testExpiry() {
        // Remove license
        UserDefaults.standard.removeObject(forKey: "FrostLicenseKey")

        // Set first launch to 8 days ago
        let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        UserDefaults.standard.set(eightDaysAgo, forKey: "FrostFirstLaunchDate")
        UserDefaults.standard.synchronize()

        // Disable blur
        BlurManager.sharedInstance.setting.isEnabled = false

        // Show alert and quit
        let alert = NSAlert()
        alert.messageText = "Test Expiry Set"
        alert.informativeText = "License removed and trial set to expired. The app will now quit. Please relaunch to test the expired behavior."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Quit")
        alert.runModal()

        NSApplication.shared.terminate(nil)
    }
    #endif

    @objc private func checkForUpdates() {
        let currentVersion = Bundle.main.releaseVersionNumber ?? "0.0.0"

        let url = URL(string: "https://api.github.com/repos/zhengyishen0/frost-app/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showUpdateAlert(title: "Update Check Failed", message: "Could not check for updates: \(error.localizedDescription)")
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.showUpdateAlert(title: "Update Check Failed", message: "Could not parse update information.")
                    return
                }

                // Remove 'v' prefix if present (e.g., "v1.0.5" -> "1.0.5")
                let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

                if self.isVersion(latestVersion, newerThan: currentVersion) {
                    let alert = NSAlert()
                    alert.messageText = "Update Available"
                    alert.informativeText = "A new version (\(latestVersion)) is available. You are currently running version \(currentVersion)."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Download")
                    alert.addButton(withTitle: "Later")

                    if alert.runModal() == .alertFirstButtonReturn {
                        if let downloadURL = URL(string: "https://github.com/zhengyishen0/frost-app/releases/latest") {
                            NSWorkspace.shared.open(downloadURL)
                        }
                    }
                } else {
                    self.showUpdateAlert(title: "You're Up to Date", message: "Frost \(currentVersion) is the latest version.")
                }
            }
        }.resume()
    }

    private func showUpdateAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func isVersion(_ version1: String, newerThan version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(v1Components.count, v2Components.count)

        for i in 0..<maxLength {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0

            if v1 > v2 { return true }
            if v1 < v2 { return false }
        }

        return false
    }

    // MARK: - Mode Toggle View

    private func createModeToggleView(setting: SettingObservable) -> NSView {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 32))

        let segmentedControl = NSSegmentedControl(frame: NSRect(x: 16, y: 4, width: 168, height: 24))
        segmentedControl.segmentCount = 2

        // Frost segment with snowflake icon
        if let snowflakeImage = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Frost") {
            segmentedControl.setImage(snowflakeImage, forSegment: 0)
        }
        segmentedControl.setLabel("Frost".localized, forSegment: 0)
        segmentedControl.setImageScaling(.scaleProportionallyDown, forSegment: 0)

        // Fog segment with cloud icon
        if let cloudImage = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "Fog") {
            segmentedControl.setImage(cloudImage, forSegment: 1)
        }
        segmentedControl.setLabel("Fog".localized, forSegment: 1)
        segmentedControl.setImageScaling(.scaleProportionallyDown, forSegment: 1)

        segmentedControl.segmentStyle = .rounded
        segmentedControl.trackingMode = .selectOne
        segmentedControl.target = self
        segmentedControl.action = #selector(modeSegmentChanged(_:))

        // Set initial selection
        segmentedControl.selectedSegment = setting.blurMode == .frost ? 0 : 1

        // Observe changes
        setting.$blurMode
            .receive(on: DispatchQueue.main)
            .sink { [weak segmentedControl] mode in
                segmentedControl?.selectedSegment = mode == .frost ? 0 : 1
            }
            .store(in: &cancellableSet)

        containerView.addSubview(segmentedControl)
        return containerView
    }

    @objc private func modeSegmentChanged(_ sender: NSSegmentedControl) {
        BlurManager.sharedInstance.setting.blurMode = sender.selectedSegment == 0 ? .frost : .fog
    }
}
