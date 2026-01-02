# Frost Implementation Plan

## Overview

Transform the original Blurred app from a **dark dimming utility** into a **frosted glass blur focus tool** (Frost).

---

## Original Architecture (Blurred)

```
┌─────────────────────────────────────────────────────────────┐
│ AppDelegate                                                 │
│  - HotKey listener                                          │
│  - EventMonitor (mouse clicks)                              │
│  - StatusBarController                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ DimManager (Singleton)                                      │
│  - Creates NSWindow overlays with black.withAlphaComponent  │
│  - Positions overlay .below active window                   │
│  - Modes: Single (frontmost) / Parallel (per-screen)        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ SettingObservable (@Published properties)                   │
│  - alpha, isEnabled, dimMode, globalHotkey                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Frost Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ AppDelegate                                                 │
│  - HotKey listener                                          │
│  - EventMonitor (mouse clicks)                              │
│  - CursorShakeDetector (NEW - monitors mouse movement)      │
│  - StatusBarController                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ BlurManager (renamed from DimManager)                       │
│  - Creates NSWindow with NSVisualEffectView (blur)          │
│  - Positions overlay .below active window(s)                │
│  - Focus Modes: Window / App-wide                           │
│  - Blur Modes: Full / Ambient (gradient)                    │
│  - Crossfade animation support                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ SettingObservable (@Published properties)                   │
│  - isEnabled                                                │
│  - focusMode: .window / .app                                │
│  - blurMode: .full / .ambient                               │
│  - transitionDuration: 0 / 0.5 / 1.0 / 1.5                  │
│  - cursorShakeEnabled: Bool                                 │
│  - globalHotkey                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Feature Implementation Details

### 1. Frosted Glass Blur Effect (Instead of Dark Dim)

**Current:** `NSColor.black.withAlphaComponent(alpha/100.0)` on `NSWindow.backgroundColor`

**New:** Use `NSVisualEffectView` with blur material

```swift
// BlurManager.swift
private func createBlurWindow(for screen: NSScreen) -> NSWindow {
    let frame = NSRect(origin: .zero, size: screen.frame.size)
    let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)

    // Create visual effect view with frosted glass appearance
    let visualEffectView = NSVisualEffectView(frame: frame)
    visualEffectView.material = .fullScreenUI  // or .hudWindow, .sheet
    visualEffectView.blendingMode = .behindWindow
    visualEffectView.state = .active
    visualEffectView.wantsLayer = true
    visualEffectView.alphaValue = 0  // Start transparent for animation

    window.contentView = visualEffectView
    window.isOpaque = false
    window.backgroundColor = .clear
    window.ignoresMouseEvents = true
    window.collectionBehavior = [.transient, .fullScreenNone]
    window.level = .normal

    return window
}
```

**Material Options:**
- `.fullScreenUI` - Light/medium blur (good for focus)
- `.hudWindow` - Darker vibrancy
- `.sheet` - Subtle light blur
- `.underWindowBackground` - Very subtle

For a "rough glass" effect without customization, `.fullScreenUI` or a custom implementation using:
- White/light gray tint overlay on the visual effect view
- Fixed blur radius

---

### 2. Ambient Mode (Half-Screen Blur)

**Concept:** Instead of blurring everything except the focused window, create a gradient blur that's strongest at the edges and fades toward the center/active window.

**Implementation Approach:**

```swift
enum BlurMode: Int {
    case full      // Blur entire background (current behavior, but with blur)
    case ambient   // Gradient blur - stronger at edges, softer near focus
}

// For ambient mode, create multiple layered windows or use gradient mask
private func createAmbientBlurWindow(for screen: NSScreen, focusRect: CGRect) -> NSWindow {
    let window = createBlurWindow(for: screen)

    // Create gradient mask that's transparent in center, opaque at edges
    let gradientLayer = CAGradientLayer()
    gradientLayer.type = .radial
    gradientLayer.colors = [
        NSColor.clear.cgColor,      // Center (focused area)
        NSColor.white.cgColor       // Edges (blurred)
    ]
    gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)  // Center of focus
    gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)    // Edges

    // Apply as mask to visual effect view
    window.contentView?.layer?.mask = gradientLayer

    return window
}
```

---

### 3. Cursor Shake Detection

**Concept:** Detect rapid back-and-forth mouse movement (shake-to-defrost).

```swift
// CursorShakeDetector.swift
class CursorShakeDetector {
    private var positions: [(point: CGPoint, time: Date)] = []
    private var monitor: Any?
    private let shakeThreshold: CGFloat = 400  // pixels per second
    private let shakeCount = 3                  // back-and-forth count
    private let timeWindow: TimeInterval = 0.5  // detection window

    var onShakeDetected: (() -> Void)?

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.trackMovement(event.locationInWindow)
        }
    }

    private func trackMovement(_ point: CGPoint) {
        let now = Date()
        positions.append((point, now))

        // Remove old positions outside time window
        positions = positions.filter { now.timeIntervalSince($0.time) < timeWindow }

        // Detect shake pattern (rapid direction changes)
        if detectShakePattern() {
            positions.removeAll()
            onShakeDetected?()
        }
    }

    private func detectShakePattern() -> Bool {
        guard positions.count >= 4 else { return false }

        var directionChanges = 0
        var lastDirection: CGFloat = 0

        for i in 1..<positions.count {
            let dx = positions[i].point.x - positions[i-1].point.x
            let direction = dx > 0 ? 1.0 : -1.0

            if lastDirection != 0 && direction != lastDirection {
                directionChanges += 1
            }
            lastDirection = direction
        }

        // Check if velocity is high enough and direction changed enough times
        let totalDistance = calculateTotalDistance()
        let velocity = totalDistance / timeWindow

        return directionChanges >= shakeCount && velocity > shakeThreshold
    }
}
```

---

### 4. App-Wide Focus Mode

**Concept:** Focus on ALL windows of the active application, not just the frontmost window.

```swift
enum FocusMode: Int {
    case window  // Focus on single frontmost window (current behavior)
    case app     // Focus on all windows of the active application
}

// In BlurManager
private func getWindowsToFocus() -> [WindowInfo] {
    let windowInfos = getWindowInfos()

    switch setting.focusMode {
    case .window:
        // Return only the frontmost window
        return windowInfos.prefix(1).map { $0 }

    case .app:
        // Return all windows belonging to the frontmost app
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return []
        }

        // Filter windows by ownerPID matching the frontmost app
        return windowInfos.filter { $0.ownerPID == Int(frontApp.processIdentifier) }
    }
}

// Position blur window below ALL focused windows
private func positionBlurWindow(_ blurWindow: NSWindow, below focusedWindows: [WindowInfo]) {
    if let lowestWindow = focusedWindows.max(by: { $0.layer < $1.layer }) {
        blurWindow.order(.below, relativeTo: lowestWindow.number)
    }
}
```

---

### 5. Crossfade Animation

**Concept:** Smooth fade-in/fade-out transitions with configurable duration.

```swift
enum TransitionDuration: Double, CaseIterable {
    case instant = 0
    case fast = 0.5
    case medium = 1.0
    case slow = 1.5
}

// In BlurManager
func applyBlur(animated: Bool = true) {
    let duration = animated ? setting.transitionDuration.rawValue : 0

    NSAnimationContext.runAnimationGroup({ context in
        context.duration = duration
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        for window in blurWindows {
            window.contentView?.animator().alphaValue = 1.0
        }
    })
}

func removeBlur(animated: Bool = true) {
    let duration = animated ? setting.transitionDuration.rawValue : 0

    NSAnimationContext.runAnimationGroup({ context in
        context.duration = duration
        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        for window in blurWindows {
            window.contentView?.animator().alphaValue = 0.0
        }
    }) {
        // Cleanup after animation completes
        self.closeAllBlurWindows()
    }
}
```

---

## New Settings Model

```swift
// SettingObservable.swift
final class SettingObservable: ObservableObject {
    // Existing
    @Published var isStartWhenLogin: Bool
    @Published var isOpenPrefWhenOpenApp: Bool
    @Published var isEnabled: Bool
    @Published var globalHotkey: GlobalKeybindPreferences?

    // NEW: Focus Mode
    @Published var focusMode: FocusMode = .window

    // NEW: Blur Mode
    @Published var blurMode: BlurMode = .full

    // NEW: Transition Duration
    @Published var transitionDuration: TransitionDuration = .slow  // 1.5s default

    // NEW: Cursor Shake Toggle
    @Published var cursorShakeEnabled: Bool = true
}
```

---

## Updated UI (GeneralView)

```swift
struct GeneralView: View {
    @ObservedObject var setting: SettingObservable

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Preview section (show blur effect preview)
            BlurPreviewView(setting: setting)

            // Focus Mode
            Picker("Focus Mode", selection: $setting.focusMode) {
                Text("Window").tag(FocusMode.window)
                Text("App").tag(FocusMode.app)
            }
            .pickerStyle(SegmentedPickerStyle())

            // Blur Mode
            Picker("Blur Mode", selection: $setting.blurMode) {
                Text("Full").tag(BlurMode.full)
                Text("Ambient").tag(BlurMode.ambient)
            }
            .pickerStyle(SegmentedPickerStyle())

            // Transition Duration
            Picker("Transition", selection: $setting.transitionDuration) {
                Text("Instant").tag(TransitionDuration.instant)
                Text("0.5s").tag(TransitionDuration.fast)
                Text("1.0s").tag(TransitionDuration.medium)
                Text("1.5s").tag(TransitionDuration.slow)
            }

            // Toggles
            Toggle("Enable Blur", isOn: $setting.isEnabled)
            Toggle("Cursor Shake to Toggle", isOn: $setting.cursorShakeEnabled)
            Toggle("Start at Login", isOn: $setting.isStartWhenLogin)

            // Hotkey section
            HotkeySettingView(setting: setting)
        }
        .padding()
    }
}
```

---

## File Changes Summary

| File | Action | Changes |
|------|--------|---------|
| `DimManager.swift` | Rename → `BlurManager.swift` | Complete rewrite with blur effect, focus modes, animations |
| `SettingObservable.swift` | Modify | Add focusMode, blurMode, transitionDuration, cursorShakeEnabled |
| `UserDefaults+Extension.swift` | Modify | Add new setting keys |
| `AppDelegate.swift` | Modify | Add CursorShakeDetector |
| `CursorShakeDetector.swift` | **NEW** | Cursor shake detection logic |
| `GeneralView.swift` | Modify | New UI layout for settings |
| `StatusBarController.swift` | Modify | Update menu items |

---

## Implementation Order

1. **Phase 1: Core Blur Engine**
   - Rename DimManager → BlurManager
   - Replace dim overlay with NSVisualEffectView blur
   - Add crossfade animation support

2. **Phase 2: New Settings**
   - Add new properties to SettingObservable
   - Update UserDefaults extension
   - Wire up Combine publishers

3. **Phase 3: Focus Modes**
   - Implement window vs app-wide focus
   - Update window detection logic

4. **Phase 4: Blur Modes**
   - Implement full blur mode
   - Implement ambient (gradient) blur mode

5. **Phase 5: Cursor Shake**
   - Create CursorShakeDetector
   - Integrate with AppDelegate
   - Add setting toggle

6. **Phase 6: UI Updates**
   - Update GeneralView with new controls
   - Update StatusBarController menu
   - Update preview image

---

## Technical Considerations

### macOS Version Compatibility
- NSVisualEffectView: macOS 10.10+
- Current target: macOS 10.15+ (fine)

### Performance
- NSVisualEffectView is GPU-accelerated
- Cursor shake detection uses minimal CPU (global event monitor)
- Animations use Core Animation (hardware accelerated)

### Edge Cases
- Multiple displays: Handle per-screen blur windows
- Full-screen apps: May need special handling
- Spaces: Blur should follow active space
