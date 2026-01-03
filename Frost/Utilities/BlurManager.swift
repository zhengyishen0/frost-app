//
//  BlurManager.swift
//
//  Copyright © 2026 Zhengyi Shen. All rights reserved.
//
//  Multi-layer frost system: layers crossfade to create smooth transitions.
//

import Foundation
import Cocoa
import Combine

// MARK: - Enums

enum BlurMode: Int {
    case frost // Uniform frosted blur (like ice crystals covering entire window)
    case fog   // Gradient blur: strong at bottom, subtle at top (like condensation)

    var targetAlpha: CGFloat {
        switch self {
        case .frost: return 0.75
        case .fog: return 1.0
        }
    }

    var label: String {
        switch self {
        case .frost: return "Frost"
        case .fog: return "Fog"
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

// MARK: - FrostLayer

/// A single frost layer that covers the screen and is ordered below a specific window
class FrostLayer {
    let id: UUID = UUID()
    let window: NSWindow
    let targetWindowNumber: Int
    var currentOpacity: CGFloat = 0.0

    init(window: NSWindow, targetWindowNumber: Int) {
        self.window = window
        self.targetWindowNumber = targetWindowNumber
    }
}

// MARK: - BlurManager

class BlurManager {

    // MARK: - Singleton
    static let sharedInstance = BlurManager()

    // MARK: - Properties
    let setting = SettingObservable()

    // Multi-layer system: stack of frost layers per screen
    private var frostLayers: [NSScreen: [FrostLayer]] = [:]
    private var cancellableSet: Set<AnyCancellable> = []

    // Track current focused window
    private var currentFocusedWindowNumber: Int = 0
    private var isRecoveringFromSpaceChange = false
    private var updateRetryCount = 0
    private let maxUpdateRetries = 3
    private var pendingBlurWorkItem: DispatchWorkItem?

    // Defrost multiplier: 1.0 = normal, 0.0 = fully defrosted (invisible)
    private var defrostMultiplier: CGFloat = 1.0

    // MARK: - Init
    private init() {
        observeActiveWindowChanged()
        observeSettingChanged()
        observeScreenChanges()
    }

    // MARK: - Public Methods

    func blur(runningApplication: NSRunningApplication?, withDelay: Bool = true) {
        guard setting.isEnabled else {
            hideAllLayers(animated: true)
            return
        }

        // Skip if recovering from space change
        if isRecoveringFromSpaceChange {
            return
        }

        // Hide blur if clicking to empty desktop
        if let bundle = runningApplication?.bundleIdentifier, bundle == "com.apple.finder" {
            let finderWindows = getWindowInfos().filter { $0.ownerName == "Finder" }
            if finderWindows.isEmpty {
                hideAllLayers(animated: true)
                return
            }
        }

        // Debounce
        pendingBlurWorkItem?.cancel()
        let delay = withDelay ? 0.25 : 0.05

        let workItem = DispatchWorkItem { [weak self] in
            self?.updateBlur()
        }
        pendingBlurWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func toggleBlur(isEnabled: Bool) {
        defrostMultiplier = 1.0

        if isEnabled {
            currentFocusedWindowNumber = 0
            updateBlur()
        } else {
            hideAllLayers(animated: true)
        }
    }

    var isDefrosted: Bool {
        return defrostMultiplier < 1.0
    }

    func resetDefrost() {
        defrostMultiplier = 1.0
    }

    func defrost() {
        animateDefrostMultiplier(to: 0.0, duration: 0.5)
    }

    func refrost() {
        let duration = setting.transitionDuration.rawValue
        animateDefrostMultiplier(to: 1.0, duration: duration)
    }

    // MARK: - Core Multi-Layer Logic

    private func updateBlur() {
        guard setting.isEnabled else { return }

        let windowInfos = getWindowInfos()
        guard let frontWindow = windowInfos.first else {
            // Retry if in transition state
            if updateRetryCount < maxUpdateRetries {
                updateRetryCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.updateBlur()
                }
            } else {
                updateRetryCount = 0
            }
            return
        }

        updateRetryCount = 0
        let newFocusedWindowNumber = frontWindow.number

        if currentFocusedWindowNumber != newFocusedWindowNumber {
            // Window changed - crossfade layers
            transitionToWindow(newFocusedWindowNumber)
            currentFocusedWindowNumber = newFocusedWindowNumber
        } else if currentFocusedWindowNumber == 0 {
            // First time - just show
            currentFocusedWindowNumber = newFocusedWindowNumber
            showInitialLayer(below: newFocusedWindowNumber)
        }
        // Same window - do nothing
    }

    /// Create initial layer when frost first appears
    private func showInitialLayer(below windowNumber: Int) {
        let targetAlpha = effectiveAlpha(for: setting.blurMode.targetAlpha)
        let duration = setting.transitionDuration.rawValue

        for screen in NSScreen.screens {
            // Create new layer
            let layer = createFrostLayer(for: screen, below: windowNumber)

            if frostLayers[screen] == nil {
                frostLayers[screen] = []
            }
            frostLayers[screen]?.append(layer)

            // Animate in
            animateLayerOpacity(layer, to: targetAlpha, duration: duration)
        }
    }

    /// Crossfade: new layer fades in, all existing layers fade out
    private func transitionToWindow(_ newWindowNumber: Int) {
        let targetAlpha = effectiveAlpha(for: setting.blurMode.targetAlpha)
        let duration = setting.transitionDuration.rawValue

        for screen in NSScreen.screens {
            // Fade out ALL existing layers
            if let existingLayers = frostLayers[screen] {
                for layer in existingLayers {
                    animateLayerOpacity(layer, to: 0.0, duration: duration) { [weak self] in
                        self?.removeLayer(layer, from: screen)
                    }
                }
            }

            // Create and fade in new layer
            let newLayer = createFrostLayer(for: screen, below: newWindowNumber)

            if frostLayers[screen] == nil {
                frostLayers[screen] = []
            }
            frostLayers[screen]?.append(newLayer)

            animateLayerOpacity(newLayer, to: targetAlpha, duration: duration)
        }
    }

    /// Create a frost layer for a screen, ordered below a specific window
    private func createFrostLayer(for screen: NSScreen, below windowNumber: Int) -> FrostLayer {
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

        let contentView = createBlurView(frame: NSRect(origin: .zero, size: frame.size))
        window.contentView = contentView
        contentView.alphaValue = 0.0

        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
        window.displayIfNeeded()

        // Order below target window
        orderWindow(window, below: windowNumber)

        let layer = FrostLayer(window: window, targetWindowNumber: windowNumber)
        return layer
    }

    private func orderWindow(_ window: NSWindow, below windowNumber: Int) {
        let allWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], CGWindowID(0)) as? [[String: Any]] ?? []
        let targetExists = allWindows.contains { dict in
            (dict[kCGWindowNumber as String] as? Int) == windowNumber
        }

        if targetExists {
            window.order(.below, relativeTo: windowNumber)
        } else {
            window.orderBack(nil)
        }
    }

    private func animateLayerOpacity(_ layer: FrostLayer, to targetOpacity: CGFloat, duration: Double, completion: (() -> Void)? = nil) {
        layer.currentOpacity = targetOpacity

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            layer.window.contentView?.animator().alphaValue = targetOpacity
        }, completionHandler: {
            completion?()
        })
    }

    private func removeLayer(_ layer: FrostLayer, from screen: NSScreen) {
        layer.window.contentView?.alphaValue = 0.0
        layer.window.orderOut(nil)
        layer.window.close()

        if var layers = frostLayers[screen] {
            layers.removeAll { $0.id == layer.id }
            frostLayers[screen] = layers.isEmpty ? nil : layers
        }
    }

    private func hideAllLayers(animated: Bool) {
        let duration = animated ? setting.transitionDuration.rawValue : 0

        for (screen, layers) in frostLayers {
            for layer in layers {
                if animated {
                    animateLayerOpacity(layer, to: 0.0, duration: duration) { [weak self] in
                        self?.removeLayer(layer, from: screen)
                    }
                } else {
                    removeLayer(layer, from: screen)
                }
            }
        }

        if !animated {
            frostLayers.removeAll()
        }
        currentFocusedWindowNumber = 0
    }

    // MARK: - Defrost

    private func effectiveAlpha(for baseAlpha: CGFloat) -> CGFloat {
        return baseAlpha * defrostMultiplier
    }

    private func animateDefrostMultiplier(to targetMultiplier: CGFloat, duration: Double) {
        let baseAlpha = setting.blurMode.targetAlpha
        let targetAlpha = baseAlpha * targetMultiplier

        for (_, layers) in frostLayers {
            for layer in layers {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = duration
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    context.allowsImplicitAnimation = true
                    layer.window.contentView?.animator().alphaValue = targetAlpha * (layer.currentOpacity / baseAlpha)
                })
            }
        }

        defrostMultiplier = targetMultiplier
    }

    // MARK: - Blur View Creation

    private func createBlurView(frame: NSRect) -> NSVisualEffectView {
        let blurView = NSVisualEffectView(frame: frame)
        blurView.wantsLayer = true
        blurView.material = .fullScreenUI
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.alphaValue = 0.0

        if setting.blurMode == .fog {
            if let layer = blurView.layer {
                layer.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
            }
            applyGradientMask(to: blurView)
        } else if setting.blurMode == .frost {
            if let layer = blurView.layer {
                addGrainLayer(to: layer, frame: frame)
            }
        }

        return blurView
    }

    private func addGrainLayer(to layer: CALayer, frame: NSRect) {
        let grainLayer = CALayer()
        grainLayer.frame = CGRect(origin: .zero, size: frame.size)

        if let noiseImage = createNoiseImage(size: CGSize(width: 200, height: 200)) {
            grainLayer.backgroundColor = NSColor(patternImage: noiseImage).cgColor
        }

        grainLayer.opacity = 0.20
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

    // MARK: - Window Info

    private func getWindowInfos() -> [WindowInfo] {
        let options = CGWindowListOption([.excludeDesktopElements, .optionOnScreenOnly])
        guard let windowsListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as? [[String: Any]] else {
            return []
        }

        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)

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
                guard info.layer == 0 else { return false }
                guard info.ownerPID != ownPID else { return false }
                if let ownerName = info.ownerName, systemProcessNames.contains(ownerName) {
                    return false
                }
                return true
            }
    }

    // MARK: - Observers

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
                self?.recreateAllLayers()
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
        // Reset state after space change
        currentFocusedWindowNumber = 0
        isRecoveringFromSpaceChange = true

        // Hide all layers immediately
        for (_, layers) in frostLayers {
            for layer in layers {
                layer.window.contentView?.alphaValue = 0.0
            }
        }

        // Recover after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.isRecoveringFromSpaceChange = false
            self?.updateBlur()
        }
    }

    @objc private func screensDidChange(notification: Notification) {
        recreateAllLayers()
    }

    private func recreateAllLayers() {
        hideAllLayers(animated: false)
        if setting.isEnabled {
            updateBlur()
        }
    }
}
