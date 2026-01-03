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
        // Use SMAppService.mainApp for macOS 13+ (no helper app needed)
        if #available(macOS 13.0, *) {
            do {
                if isAutoStart {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(isAutoStart ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        }
        // Note: macOS 14.0 is minimum requirement, so no fallback needed
    }
}
