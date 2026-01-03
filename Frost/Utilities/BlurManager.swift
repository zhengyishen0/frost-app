//
//  BlurManager.swift
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//
//  Redesigned for Frost: unified blur layer with elegant hole animation.
//

import Foundation
import Cocoa
import Combine

// MARK: - Enums

enum BlurMode: Int {
    case glass // Uniform frosted blur with grain texture (like frosted glass)
    case frost // Gradient blur: strong at bottom, subtle at top

    var targetAlpha: CGFloat {
        switch self {
        case .glass: return 0.75
        case .frost: return 1.0
        }
    }

    var label: String {
        switch self {
        case .glass: return "Glass"
        case .frost: return "Frost"
        }
    }
}

enum TransitionDuration: Double, CaseIterable {
    case fast = 1.0
    case medium = 1.5
    case slow = 2.0

    var label: String {
        switch self {
        case .fast: return "1s"
        case .medium: return "1.5s"
        case .slow: return "2s"
        }
    }
}

enum ShakeRestoreDelay: Double, CaseIterable {
    case three = 3.0
    case four = 4.0
    case five = 5.0

    var label: String {
        switch self {
        case .three: return "3s"
        case .four: return "4s"
        case .five: return "5s"
        }
    }
}

// MARK: - BlurManager

class BlurManager {

    // MARK: - Singleton
    static let sharedInstance = BlurManager()

    // MARK: - Properties
    let setting = SettingObservable()

    private var blurWindows: [NSScreen: NSWindow] = [:]
    private var cancellableSet: Set<AnyCancellable> = []

    // Track current focused window for animation
    private var currentFocusedWindowNumber: Int = 0
    private var currentFocusedWindowFrame: CGRect = .zero
    private var isAnimating = false
    private var isRecoveringFromSpaceChange = false
    private var updateRetryCount = 0
    private let maxUpdateRetries = 3

    // Track hole layers for cleanup
    private var activeHoleLayers: [CALayer] = []

    // MARK: - Init
    private init() {
        observeActiveWindowChanged()
        observeSettingChanged()
        observeScreenChanges()
    }

    // MARK: - Public Methods

    func blur(runningApplication: NSRunningApplication?, withDelay: Bool = true) {
        print("👆 [Click] blur() called, app: \(runningApplication?.localizedName ?? "nil")")

        guard setting.isEnabled else {
            print("👆 [Click] Blur disabled, hiding")
            hideBlur(animated: true)
            return
        }

        // Skip if recovering from space change - let the scheduled recovery complete
        if isRecoveringFromSpaceChange {
            print("👆 [Click] BLOCKED - recovering from space change")
            return
        }

        // Hide blur if clicking to empty desktop
        if let bundle = runningApplication?.bundleIdentifier, bundle == "com.apple.finder" {
            let finderWindows = getWindowInfos().filter { $0.ownerName == "Finder" }
            if finderWindows.isEmpty {
                print("👆 [Click] Empty desktop, hiding blur")
                hideBlur(animated: true)
                return
            }
        }

        let delay = withDelay ? 0.05 : 0
        print("👆 [Click] Scheduling updateBlur in \(delay)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.updateBlur()
        }
    }

    func toggleBlur(isEnabled: Bool) {
        // Cancel any ongoing animations and cleanup
        cancelAnimations()

        if isEnabled {
            // Reset state so show animation triggers
            currentFocusedWindowNumber = 0
            currentFocusedWindowFrame = .zero
            updateBlur()
        } else {
            hideBlur(animated: true)
        }
    }

    /// Defrost (shake) uses fixed 1s transition, independent of user setting
    func defrost() {
        cancelAnimations()
        hideBlur(animated: true, duration: 1.0)
    }

    /// Refrost after shake delay uses fixed 1s transition
    func refrost() {
        cancelAnimations()
        currentFocusedWindowNumber = 0
        currentFocusedWindowFrame = .zero
        showBlurForDefrost()
    }

    private func showBlurForDefrost() {
        guard setting.isEnabled else { return }

        ensureBlurWindowsExist()

        let windowInfos = getWindowInfos()
        guard let frontWindow = windowInfos.first else { return }

        currentFocusedWindowNumber = frontWindow.number
        currentFocusedWindowFrame = frontWindow.bounds ?? .zero
        orderBlurWindows(below: frontWindow.number)

        // Use fixed 1s duration for defrost
        let targetAlpha = setting.blurMode.targetAlpha
        for (_, window) in blurWindows {
            guard let layer = window.contentView?.layer else { continue }

            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = layer.opacity
            animation.toValue = Float(targetAlpha)
            animation.duration = 1.0  // Fixed 1s for defrost
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false

            layer.add(animation, forKey: "showBlur")
            window.contentView?.alphaValue = targetAlpha
        }
    }

    private func cancelAnimations() {
        isAnimating = false

        // Remove any active hole layers
        for holeLayer in activeHoleLayers {
            // Capture current visual opacity before removing animation
            let currentOpacity = holeLayer.presentation()?.opacity ?? holeLayer.opacity
            holeLayer.removeAllAnimations()
            holeLayer.opacity = currentOpacity
            holeLayer.removeFromSuperlayer()
        }
        activeHoleLayers.removeAll()

        // Capture presentation values and restore proper masks
        for (_, window) in blurWindows {
            guard let layer = window.contentView?.layer else { continue }

            // Capture current visual opacity BEFORE removing animation
            // This prevents the snap-to-model-value problem
            let currentOpacity = layer.presentation()?.opacity ?? layer.opacity

            layer.removeAllAnimations()

            // Set model value to where animation was visually
            layer.opacity = currentOpacity
            window.contentView?.alphaValue = CGFloat(currentOpacity)

            // Restore proper mask based on mode
            if setting.blurMode == .frost {
                applyGradientMask(to: layer)
            } else {
                layer.mask = nil
            }
        }
    }
}

// MARK: - Blur Window Management

extension BlurManager {

    private func updateBlur() {
        print("🔍 [Update] updateBlur() called")

        guard setting.isEnabled else {
            print("🔍 [Update] Blur disabled, exiting")
            return
        }

        // Cancel any ongoing animation and proceed (don't block)
        if isAnimating {
            print("🔍 [Update] Canceling ongoing animation")
            cancelAnimations()
        }

        ensureBlurWindowsExist()

        let windowInfos = getWindowInfos()
        guard let frontWindow = windowInfos.first else {
            print("🔍 [Update] No front window found")
            // Retry if we're in a transition state (Mission Control exit, etc.)
            if updateRetryCount < maxUpdateRetries {
                updateRetryCount += 1
                print("🔍 [Update] Scheduling retry \(updateRetryCount)/\(maxUpdateRetries)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.updateBlur()
                }
            } else {
                updateRetryCount = 0
            }
            return
        }

        // Reset retry count on success
        updateRetryCount = 0

        let newFocusedWindowNumber = frontWindow.number
        let newFocusedWindowFrame = frontWindow.bounds ?? .zero

        print("🔍 [Update] Front window: \(frontWindow.ownerName ?? "?"), number: \(newFocusedWindowNumber)")
        print("🔍 [Update] Current tracked: \(currentFocusedWindowNumber)")

        // Check if focused window changed
        if currentFocusedWindowNumber != newFocusedWindowNumber && currentFocusedWindowNumber != 0 {
            // Window changed - animate with snow burial effect
            print("🔍 [Update] Window CHANGED - animating switch")
            let oldWindowFrame = currentFocusedWindowFrame
            currentFocusedWindowNumber = newFocusedWindowNumber
            currentFocusedWindowFrame = newFocusedWindowFrame
            animateWindowSwitch(to: newFocusedWindowNumber, oldWindowFrame: oldWindowFrame)
        } else {
            // First time or same window - just show
            let shouldAnimate = currentFocusedWindowNumber == 0
            print("🔍 [Update] \(shouldAnimate ? "FIRST TIME" : "SAME WINDOW") - showing blur (animated: \(shouldAnimate))")
            currentFocusedWindowNumber = newFocusedWindowNumber
            currentFocusedWindowFrame = newFocusedWindowFrame
            orderBlurWindows(below: newFocusedWindowNumber)
            showBlur(animated: shouldAnimate)
        }
    }

    private func animateWindowSwitch(to newWindowNumber: Int, oldWindowFrame: CGRect) {
        isAnimating = true
        let duration = setting.transitionDuration.rawValue

        // Reorder blur windows below the new focused window
        orderBlurWindows(below: newWindowNumber)

        // Animate snow burial effect on each screen
        for (screen, blurWindow) in blurWindows {
            guard let contentView = blurWindow.contentView,
                  let layer = contentView.layer else { continue }

            // Convert old window frame to view coordinates
            let holeRect = convertToViewCoordinates(windowFrame: oldWindowFrame, screen: screen)

            // Skip if hole rect doesn't intersect this screen
            guard holeRect.intersects(contentView.bounds) else { continue }

            // Show blur at target alpha
            contentView.alphaValue = setting.blurMode.targetAlpha

            // Animate the hole being filled (snow burial)
            animateHoleFilling(on: layer, holeRect: holeRect, duration: duration)
        }
    }

    /// Shared hole animation that works for both full and ambient modes
    private func animateHoleFilling(on layer: CALayer, holeRect: CGRect, duration: Double) {
        // Create a mask container
        let maskContainer = CALayer()
        maskContainer.frame = layer.bounds

        // Add base mask layer (solid for full, gradient for ambient)
        let baseLayer = createBaseMask(frame: layer.bounds)
        maskContainer.addSublayer(baseLayer)

        // Add hole layer with destOut filter (cuts through the base)
        let holeLayer = CALayer()
        holeLayer.frame = holeRect
        holeLayer.backgroundColor = NSColor.white.cgColor
        holeLayer.cornerRadius = 10.0  // macOS window corner radius
        holeLayer.compositingFilter = "destOut"
        holeLayer.opacity = 1.0
        maskContainer.addSublayer(holeLayer)

        // Track for cleanup
        activeHoleLayers.append(holeLayer)

        // Apply the mask
        layer.mask = maskContainer

        // Animate hole layer opacity from 1 → 0 (hole fades, blur fills in)
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.0
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false

        CATransaction.setCompletionBlock { [weak self, weak layer] in
            // Restore original mask (gradient for ambient, nil for full)
            if self?.setting.blurMode == .frost {
                self?.applyGradientMask(to: layer)
            } else {
                layer?.mask = nil
            }

            // Cleanup
            if let index = self?.activeHoleLayers.firstIndex(where: { $0 === holeLayer }) {
                self?.activeHoleLayers.remove(at: index)
            }
            self?.isAnimating = false

            // Re-order blur windows below current focused window to ensure proper layering
            if let windowNumber = self?.currentFocusedWindowNumber, windowNumber != 0 {
                self?.orderBlurWindows(below: windowNumber)
            }
        }

        holeLayer.add(animation, forKey: "holeFade")
        CATransaction.commit()
    }

    /// Creates base mask layer based on current mode
    private func createBaseMask(frame: CGRect) -> CALayer {
        if setting.blurMode == .frost {
            // Gradient mask for ambient mode
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = frame
            gradientLayer.colors = [
                NSColor.white.cgColor,                              // Bottom: full blur
                NSColor.white.cgColor,
                NSColor.white.withAlphaComponent(0.8).cgColor,
                NSColor.white.withAlphaComponent(0.4).cgColor,
                NSColor.white.withAlphaComponent(0.1).cgColor,
                NSColor.clear.cgColor                               // Top: clear
            ]
            gradientLayer.locations = [0.0, 0.40, 0.55, 0.67, 0.80, 1.0]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
            return gradientLayer
        } else {
            // Solid white mask for full mode
            let solidLayer = CALayer()
            solidLayer.frame = frame
            solidLayer.backgroundColor = NSColor.white.cgColor
            return solidLayer
        }
    }

    private func convertToViewCoordinates(windowFrame: CGRect, screen: NSScreen) -> CGRect {
        let screenFrame = screen.frame
        let flippedY = screenFrame.maxY - windowFrame.maxY
        return CGRect(
            x: windowFrame.origin.x - screenFrame.origin.x,
            y: flippedY,
            width: windowFrame.width,
            height: windowFrame.height
        )
    }

    private func ensureBlurWindowsExist() {
        let screens = NSScreen.screens

        for screen in screens {
            if blurWindows[screen] == nil {
                blurWindows[screen] = createBlurWindow(for: screen)
            }
        }

        // Remove windows for disconnected screens
        let currentScreens = Set(screens)
        for (screen, window) in blurWindows where !currentScreens.contains(screen) {
            window.close()
            blurWindows.removeValue(forKey: screen)
        }
    }

    private func createBlurWindow(for screen: NSScreen) -> NSWindow {
        let frame = screen.frame

        let window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.transient, .fullScreenNone, .canJoinAllSpaces]
        window.level = .normal
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false

        // Create blur content
        let contentView = createBlurView(frame: NSRect(origin: .zero, size: frame.size))
        window.contentView = contentView

        // Start fully transparent
        contentView.alphaValue = 0.0

        window.setFrame(frame, display: true)

        // CRITICAL: Make window visible immediately (required for animations to render)
        // Use orderFrontRegardless() instead of makeKeyAndOrderFront() to avoid key window warnings
        window.orderFrontRegardless()

        return window
    }

    private func createBlurView(frame: NSRect) -> NSVisualEffectView {
        let blurView = NSVisualEffectView(frame: frame)
        blurView.wantsLayer = true
        blurView.material = .fullScreenUI
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.alphaValue = 0.0

        // Apply mode-specific configuration
        if setting.blurMode == .frost {
            if let layer = blurView.layer {
                layer.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
            }
            applyGradientMask(to: blurView)
        } else if setting.blurMode == .glass {
            // Add grain texture for glass effect
            if let layer = blurView.layer {
                addGrainLayer(to: layer, frame: frame)
            }
        }

        return blurView
    }

    private func addGrainLayer(to layer: CALayer, frame: NSRect) {
        let grainLayer = CALayer()
        grainLayer.frame = CGRect(origin: .zero, size: frame.size)

        // Create noise image for grain effect
        if let noiseImage = createNoiseImage(size: CGSize(width: 200, height: 200)) {
            grainLayer.backgroundColor = NSColor(patternImage: noiseImage).cgColor
        }

        grainLayer.opacity = 0.20  // Fixed 20% grain for glass effect
        grainLayer.compositingFilter = "overlayBlendMode"

        layer.addSublayer(grainLayer)
    }

    private func createNoiseImage(size: CGSize) -> NSImage? {
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        let width = Int(size.width)
        let height = Int(size.height)

        for y in 0..<height {
            for x in 0..<width {
                let gray = CGFloat.random(in: 0...1)
                context.setFillColor(NSColor(white: gray, alpha: 1.0).cgColor)
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }

        image.unlockFocus()
        return image
    }

    private func applyGradientMask(to view: NSView) {
        guard let layer = view.layer else { return }
        applyGradientMask(to: layer)
    }

    private func applyGradientMask(to layer: CALayer?) {
        guard let layer = layer else { return }

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = layer.bounds

        gradientLayer.colors = [
            NSColor.black.withAlphaComponent(1.0).cgColor,
            NSColor.black.withAlphaComponent(1.0).cgColor,
            NSColor.black.withAlphaComponent(0.8).cgColor,
            NSColor.black.withAlphaComponent(0.4).cgColor,
            NSColor.black.withAlphaComponent(0.1).cgColor,
            NSColor.black.withAlphaComponent(0.0).cgColor
        ]
        gradientLayer.locations = [0.0, 0.40, 0.55, 0.67, 0.80, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)

        layer.mask = gradientLayer
    }

    private func orderBlurWindows(below windowNumber: Int) {
        print("📐 [Order] Ordering blur windows below window #\(windowNumber)")

        // Verify the target window exists
        let allWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], CGWindowID(0)) as? [[String: Any]] ?? []
        let targetExists = allWindows.contains { dict in
            (dict[kCGWindowNumber as String] as? Int) == windowNumber
        }
        print("📐 [Order] Target window exists: \(targetExists)")

        for (screen, blurWindow) in blurWindows {
            blurWindow.setFrame(screen.frame, display: false)

            // Step 1: Ensure window is in the window server by bringing it front
            blurWindow.orderFrontRegardless()

            // Step 2: Force display to ensure it's rendered
            blurWindow.displayIfNeeded()

            // Step 3: Order below the target window (only if it exists)
            if targetExists {
                blurWindow.order(.below, relativeTo: windowNumber)
            } else {
                // Fallback: just keep it at back
                blurWindow.orderBack(nil)
            }

            print("📐 [Order] Screen \(screen.localizedName): level \(blurWindow.level.rawValue), alpha \(blurWindow.contentView?.alphaValue ?? -1), visible: \(blurWindow.isVisible), onScreen: \(blurWindow.isOnActiveSpace)")
        }
    }

    private func showBlur(animated: Bool) {
        let targetAlpha = setting.blurMode.targetAlpha

        print("✨ [Show] showBlur(animated: \(animated)), target alpha: \(targetAlpha)")

        if animated {
            let duration = setting.transitionDuration.rawValue
            print("✨ [Show] Animating over \(duration)s")

            // Use NSAnimationContext instead of CABasicAnimation for better window server integration
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true

                for (_, window) in self.blurWindows {
                    let currentAlpha = window.contentView?.alphaValue ?? 0
                    print("✨ [Show] Animating from \(currentAlpha) to \(targetAlpha)")
                    window.contentView?.animator().alphaValue = targetAlpha
                }
            })
        } else {
            print("✨ [Show] Setting alpha immediately to \(targetAlpha)")
            for (_, window) in blurWindows {
                window.contentView?.alphaValue = targetAlpha
            }
        }
    }

    private func hideBlur(animated: Bool, duration: Double? = nil) {
        if animated {
            let animDuration = duration ?? setting.transitionDuration.rawValue

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = animDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                context.allowsImplicitAnimation = true

                for (_, window) in self.blurWindows {
                    window.contentView?.animator().alphaValue = 0.0
                }
            })
        } else {
            for (_, window) in blurWindows {
                window.contentView?.alphaValue = 0.0
            }
        }
    }
}

// MARK: - Window Info

extension BlurManager {

    private func getWindowInfos() -> [WindowInfo] {
        let options = CGWindowListOption([.excludeDesktopElements, .optionOnScreenOnly])
        guard let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
            return []
        }

        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)

        // System processes to ignore (these can appear as "frontmost" during Mission Control transitions)
        let systemProcessNames: Set<String> = [
            "Dock",
            "Control Center",
            "Notification Center",
            "WindowManager",
            "SystemUIServer",
            "Spotlight"
        ]

        return windowsListInfo
            .map { WindowInfo(dict: $0) }
            .filter { info in
                // Must be layer 0 (normal window level)
                guard info.layer == 0 else { return false }
                // Must not be our own app
                guard info.ownerPID != ownPID else { return false }
                // Must not be a system process that appears during transitions
                if let ownerName = info.ownerName, systemProcessNames.contains(ownerName) {
                    return false
                }
                return true
            }
    }
}

// MARK: - Observers

extension BlurManager {

    private func observeSettingChanged() {
        setting.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.toggleBlur(isEnabled: isEnabled)
            }
            .store(in: &cancellableSet)

        setting.$blurMode
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] (_: BlurMode) in
                self?.recreateBlurWindows()
            }
            .store(in: &cancellableSet)
    }

    private func observeActiveWindowChanged() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivateApplication),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        // Observe space changes (Mission Control, desktop switching)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func workspaceDidActivateApplication(notification: Notification) {
        guard let userInfo = notification.userInfo as? [AnyHashable: NSRunningApplication],
              let activeApplication = userInfo["NSWorkspaceApplicationKey"] else {
            return
        }
        blur(runningApplication: activeApplication)
    }

    @objc private func spaceDidChange(notification: Notification) {
        print("🔄 [Mission Control] Space changed detected")

        // Reset animation state after Mission Control/space switch
        cancelAnimations()
        currentFocusedWindowNumber = 0
        currentFocusedWindowFrame = .zero
        isRecoveringFromSpaceChange = true

        // Set blur to transparent so it can animate back in smoothly
        for (_, window) in blurWindows {
            window.contentView?.layer?.opacity = 0.0
            window.contentView?.alphaValue = 0.0
        }

        print("🔄 [Mission Control] Scheduled recovery in 0.2s")

        // Longer delay to let the system fully settle after Mission Control
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            print("🔄 [Mission Control] Recovery executing")
            self?.isRecoveringFromSpaceChange = false
            self?.updateBlur()
        }
    }

    @objc private func screensDidChange(notification: Notification) {
        recreateBlurWindows()
    }

    private func recreateBlurWindows() {
        cancelAnimations()

        for (_, window) in blurWindows {
            window.contentView?.alphaValue = 0.0
            window.close()
        }
        blurWindows.removeAll()
        currentFocusedWindowNumber = 0

        if setting.isEnabled {
            updateBlur()
        }
    }
}
