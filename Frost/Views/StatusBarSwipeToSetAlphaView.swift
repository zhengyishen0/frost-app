//
//  StatusBarSwipeToSetAlphaView.swift
//  Frost
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//
//  Updated for Frost - scroll to cycle through transition durations.
//

import Cocoa

class StatusBarSwipeToSetAlphaView: NSView {
    override func wantsScrollEventsForSwipeTracking(on axis: NSEvent.GestureAxis) -> Bool {
        if axis == .vertical {
            return true
        }
        return false
    }

    override func scrollWheel(with event: NSEvent) {
        let setting = BlurManager.sharedInstance.setting
        let allCases = TransitionDuration.allCases

        guard let currentIndex = allCases.firstIndex(of: setting.transitionDuration) else { return }

        // Scroll up: faster transition (lower duration)
        if event.deltaY > 0 {
            if currentIndex > 0 {
                setting.transitionDuration = allCases[currentIndex - 1]
            }
        }

        // Scroll down: slower transition (higher duration)
        if event.deltaY < 0 {
            if currentIndex < allCases.count - 1 {
                setting.transitionDuration = allCases[currentIndex + 1]
            }
        }
    }
}
