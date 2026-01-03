//
//  Util.swift
//  Frost
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//

import SwiftUI
import Foundation
import ServiceManagement

enum Util {
    static func setUpAutoStart(isAutoStart: Bool) {
        let launcherAppId = "com.zhengyishen.frostlauncher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty

        if #available(macOS 13.0, *) {
            // Use modern SMAppService API
            let service = SMAppService.loginItem(identifier: launcherAppId)

            do {
                if isAutoStart {
                    if service.status == .notRegistered {
                        try service.register()
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                    }
                }
            } catch {
                print("Failed to \(isAutoStart ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        } else {
            // Fallback for macOS 12 and earlier
            SMLoginItemSetEnabled(launcherAppId as CFString, isAutoStart)
        }

        if isRunning {
            DistributedNotificationCenter.default().post(
                name: Notification.Name("killLauncher"),
                object: Bundle.main.bundleIdentifier!
            )
        }
    }
}
