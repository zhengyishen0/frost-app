//
//  UserDefaults+Extension.swift
//  Frost
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//
//  Updated for Frost with new settings keys.
//

import Foundation
import Cocoa

// MARK: - Default Values

let defaultTransitionDuration = 1.5

// MARK: - UserDefaults Extension

extension UserDefaults {

    private struct Key {
        static let isStartWhenLogin = "IS_START_WHEN_LOGIN"
        static let isEnabled = "IS_ENABLED"
        static let isOpenPrefWhenOpenApp = "IS_OPEN_PREF_WHEN_OPEN_APP"
        static let globalKey = "GLOBAL_KEY"

        // New settings for Frost
        static let focusMode = "FOCUS_MODE"
        static let blurMode = "BLUR_MODE"
        static let transitionDuration = "TRANSITION_DURATION"
        static let cursorShakeEnabled = "CURSOR_SHAKE_ENABLED"
        static let shakeRestoreDelay = "SHAKE_RESTORE_DELAY"
    }

    // MARK: - Startup Settings

    static var isStartWhenLogin: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Key.isStartWhenLogin)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.isStartWhenLogin)
            Util.setUpAutoStart(isAutoStart: newValue)
        }
    }

    static var isOpenPrefWhenOpenApp: Bool {
        get {
            UserDefaults.standard.register(defaults: [Key.isOpenPrefWhenOpenApp: true])
            return UserDefaults.standard.bool(forKey: Key.isOpenPrefWhenOpenApp)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.isOpenPrefWhenOpenApp)
        }
    }

    // MARK: - Blur Settings

    static var isEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: Key.isEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.isEnabled)
        }
    }

    static var focusMode: Int {
        get {
            return UserDefaults.standard.integer(forKey: Key.focusMode)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.focusMode)
        }
    }

    static var blurMode: Int {
        get {
            return UserDefaults.standard.integer(forKey: Key.blurMode)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.blurMode)
        }
    }

    static var transitionDuration: Double {
        get {
            // Register default value
            UserDefaults.standard.register(defaults: [Key.transitionDuration: defaultTransitionDuration])
            let value = UserDefaults.standard.double(forKey: Key.transitionDuration)
            // Return default if not set (0.0 means not set for double)
            return value == 0.0 && !UserDefaults.standard.dictionaryRepresentation().keys.contains(Key.transitionDuration)
                ? defaultTransitionDuration
                : value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.transitionDuration)
        }
    }

    // MARK: - Interaction Settings

    static var cursorShakeEnabled: Bool {
        get {
            // Default to true
            UserDefaults.standard.register(defaults: [Key.cursorShakeEnabled: true])
            return UserDefaults.standard.bool(forKey: Key.cursorShakeEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.cursorShakeEnabled)
        }
    }

    static var shakeRestoreDelay: Double {
        get {
            // Default to 4 seconds
            UserDefaults.standard.register(defaults: [Key.shakeRestoreDelay: 4.0])
            return UserDefaults.standard.double(forKey: Key.shakeRestoreDelay)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.shakeRestoreDelay)
        }
    }

    // MARK: - Hotkey Settings

    static var globalKey: GlobalKeybindPreferences? {
        get {
            guard let data = UserDefaults.standard.value(forKey: Key.globalKey) as? Data else {
                return nil
            }
            return try? JSONDecoder().decode(GlobalKeybindPreferences.self, from: data)
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: Key.globalKey)
        }
    }
}
