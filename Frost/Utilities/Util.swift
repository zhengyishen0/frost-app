//
//  Util.swift
//  Frost
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//

import SwiftUI
import Foundation
import ServiceManagement

enum Util {
    static func setUpAutoStart(isAutoStart:Bool) {
        let launcherAppId = "com.zhengyishen.frostlauncher"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty
        
        SMLoginItemSetEnabled(launcherAppId as CFString, isAutoStart)
        
        if isRunning {
            DistributedNotificationCenter.default().post(name: Notification.Name("killLauncher"),
                                                         object: Bundle.main.bundleIdentifier!)
        }
    }
}
