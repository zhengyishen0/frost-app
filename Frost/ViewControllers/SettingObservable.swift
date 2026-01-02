//
//  SettingObservable.swift
//  Frost
//
//  Original by Trung Phan on 1/7/20.
//  Copyright © 2020 Dwarves Foundation. All rights reserved.
//
//  Simplified for Frost.
//

import Foundation
import Combine

final class SettingObservable: ObservableObject {

    // MARK: - Startup Settings

    @Published var isStartWhenLogin: Bool = UserDefaults.isStartWhenLogin {
        didSet {
            UserDefaults.isStartWhenLogin = isStartWhenLogin
        }
    }

    @Published var isOpenPrefWhenOpenApp: Bool = UserDefaults.isOpenPrefWhenOpenApp {
        didSet {
            UserDefaults.isOpenPrefWhenOpenApp = isOpenPrefWhenOpenApp
        }
    }

    // MARK: - Blur Settings

    @Published var isEnabled: Bool = UserDefaults.isEnabled {
        didSet {
            UserDefaults.isEnabled = isEnabled
        }
    }

    @Published var blurMode: BlurMode = BlurMode(rawValue: UserDefaults.blurMode) ?? .glass {
        didSet {
            UserDefaults.blurMode = blurMode.rawValue
        }
    }

    @Published var transitionDuration: TransitionDuration = TransitionDuration(rawValue: UserDefaults.transitionDuration) ?? .slow {
        didSet {
            UserDefaults.transitionDuration = transitionDuration.rawValue
        }
    }

    // MARK: - Interaction Settings

    @Published var cursorShakeEnabled: Bool = UserDefaults.cursorShakeEnabled {
        didSet {
            UserDefaults.cursorShakeEnabled = cursorShakeEnabled
        }
    }

    @Published var shakeRestoreDelay: ShakeRestoreDelay = ShakeRestoreDelay(rawValue: UserDefaults.shakeRestoreDelay) ?? .four {
        didSet {
            UserDefaults.shakeRestoreDelay = shakeRestoreDelay.rawValue
        }
    }

    // MARK: - Hotkey Settings

    @Published var globalHotkey: GlobalKeybindPreferences? = UserDefaults.globalKey {
        didSet {
            UserDefaults.globalKey = globalHotkey
        }
    }

    @Published var currentHotkeyLabel: String = UserDefaults.globalKey?.description ?? "Set Hotkey"

    @Published var isListeningForHotkey: Bool = false
}
