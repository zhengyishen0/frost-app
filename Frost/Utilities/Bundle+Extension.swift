//
//  Bundle+Extension.swift
//  Frost
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//

import Foundation

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}
