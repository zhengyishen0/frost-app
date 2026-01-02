# Rebranding Report: Blurred → Frost

This document lists all traces of the original "Blurred" app by Dwarves Foundation that need to be updated for the Frost rebrand.

## Source File Headers (Copyright/Author)

| File | Issue |
|------|-------|
| `Blurred/AppDelegate.swift` | © 2019 Dwarves Foundation |
| `Blurred/Utilities/BlurManager.swift` | Trung Phan, © 2019 Dwarves Foundation |
| `Blurred/Utilities/UserDefaults+Extension.swift` | Trung Phan, © 2020 Dwarves Foundation |
| `Blurred/Utilities/Util.swift` | © 2020 Dwarves Foundation |
| `Blurred/Utilities/EventMonitor.swift` | © 2020 Dwarves Foundation |
| `Blurred/Utilities/Collection+Extension.swift` | © 2020 Dwarves Foundation |
| `Blurred/Utilities/Bundle+Extension.swift` | © 2020 Dwarves Foundation |
| `Blurred/Utilities/String+Extension.swift` | © 2020 Dwarves Foundation |
| `Blurred/ViewControllers/StatusBarController.swift` | Trung Phan, © 2020 Dwarves Foundation |
| `Blurred/ViewControllers/SettingObservable.swift` | Trung Phan, © 2020 Dwarves Foundation |
| `Blurred/Views/StatusBarSwipeToSetAlphaView.swift` | Trung Phan, © 2020 Dwarves Foundation |
| `Blurred/Views/LinkView.swift` | © 2020 Dwarves Foundation, links to dwarves.foundation |
| `Blurred/Models/GlobalKeyBindPreferences.swift` | © 2020 Dwarves Foundation |
| `Blurred/Models/WindowInfo.swift` | © 2020 Dwarves Foundation |
| `BlurredLauncher/AppDelegate.swift` | © 2020 Dwarves Foundation |

## Bundle Identifiers & App Names

| File | Line | Issue |
|------|------|-------|
| `Blurred/Utilities/Util.swift` | 15 | `foundation.dwarves.blurredlauncher` |
| `BlurredLauncher/AppDelegate.swift` | 20 | `foundation.dwarves.blurred` |
| `BlurredLauncher/AppDelegate.swift` | 34 | `appName = "Blurred"` |
| `Blurred.xcodeproj/project.pbxproj` | Multiple | `foundation.dwarves.blurred`, `foundation.dwarves.blurredlauncher`, `ORGANIZATIONNAME = "Dwarves Foundation"` |

## Info.plist Files

| File | Issue |
|------|-------|
| `Blurred/Info.plist` | Copyright © 2019 Dwarves Foundation |
| `BlurredLauncher/Info.plist` | Copyright © 2020 Dwarves Foundation |

## Localization Files

| File | Issue |
|------|-------|
| `Blurred/en.lproj/Main.strings` | "Blurred" title |
| `Blurred/zh-Hans.lproj/Main.strings` | "Blurred" title |
| `Blurred/en.lproj/Localizable.strings` | Blurred, Dwarves |
| `Blurred/zh-Hans.lproj/Localizable.strings` | Blurred references |

## Project Structure (Folder/File Renaming Required)

- `Blurred/` → `Frost/`
- `BlurredLauncher/` → `FrostLauncher/`
- `Blurred.xcodeproj/` → `Frost.xcodeproj/`
- `Blurred.entitlements` → `Frost.entitlements`
- `BlurredLauncher.entitlements` → `FrostLauncher.entitlements`

## Other Files

| File | Issue |
|------|-------|
| `LICENSE` | Copyright Dwarves Foundation |
| `PRIVACY_POLICY.md` | Dwarves Foundation, Blurred |
| `README.md` | References to Dwarves, blurred-monocle |
| `IMPLEMENTATION_PLAN.md` | References to Blurred |
| `.github/workflows/objective-c-xcode.yml` | Blurred.app references |
| `Blurred/Views/LinkView.swift:40` | Link to dwarves.foundation/apps |
| `Blurred/Assets.xcassets/ico_menu.imageset/Contents.json` | "Blurred icon.png" |

## Recommended New Values

| Item | Old Value | New Value |
|------|-----------|-----------|
| App Name | Blurred | Frost |
| Bundle ID (Main) | foundation.dwarves.blurred | com.zhengyishen.frost |
| Bundle ID (Launcher) | foundation.dwarves.blurredlauncher | com.zhengyishen.frostlauncher |
| Organization | Dwarves Foundation | Zhengyi Shen |
| Copyright | © 2019/2020 Dwarves Foundation | © 2024 Zhengyi Shen |
