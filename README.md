<p align="center">
	<img width="128" height="128" src="misc/icon.png" alt="Frost Icon">
</p>

<h1 align="center">Frost</h1>

<p align="center">
	<strong>Focus on what matters.</strong>
</p>

<p align="center">
	<a href="https://github.com/zhengyishen0/blurred-monocle/releases/latest">
		<img src="https://img.shields.io/github/v/release/zhengyishen0/blurred-monocle?style=flat-square&color=blue" alt="Latest Release">
	</a>
	<a href="https://github.com/zhengyishen0/blurred-monocle/releases">
		<img src="https://img.shields.io/github/downloads/zhengyishen0/blurred-monocle/total?style=flat-square&color=brightgreen" alt="Downloads">
	</a>
	<a href="https://github.com/zhengyishen0/blurred-monocle/blob/main/LICENSE">
		<img src="https://img.shields.io/github/license/zhengyishen0/blurred-monocle?style=flat-square" alt="License">
	</a>
	<img src="https://img.shields.io/badge/macOS-14.0+-orange?style=flat-square" alt="macOS 14+">
</p>

---

## What is Frost?

Frost applies a beautiful frosted blur to everything except the window you're working on. Stay focused without distractions.

---

## Features

| Feature | Description |
|---------|-------------|
| **Glass Mode** | Uniform frosted blur with subtle grain texture |
| **Frost Mode** | Gradient blur: strong at bottom, subtle at top |
| **Smooth Transitions** | 1s, 1.5s, or 2s fade animations |
| **Shake to Defrost** | Shake your cursor to temporarily clear the blur |
| **Defrost Delay** | Auto-restore blur after 3s, 4s, or 5s |
| **Start at Login** | Launch Frost automatically when you log in |

### Glass Mode

A uniform frosted glass effect with subtle grain texture. Everything outside your focused window gets a consistent blur.

### Frost Mode

A gradient blur effect:
- **Bottom**: Full blur (maximum focus)
- **Top**: Subtle blur (peripheral awareness)

Perfect for keeping your dock and menu bar slightly visible while focusing on your work.

---

## Installation

1. [Download the latest release](https://github.com/zhengyishen0/blurred-monocle/releases/latest)
2. Unzip and drag `Frost.app` to Applications
3. Right-click → Open (first launch only, to bypass Gatekeeper)

---

## Usage

1. Click the ❄️ snowflake icon in your menu bar
2. Toggle between **Glass** and **Frost** modes
3. Adjust transition speed and defrost delay as needed
4. Shake your cursor to temporarily defrost

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel

---

## Known Issues

- **Mission Control**: After using Mission Control, the blur animation may behave unexpectedly. Clicking on a window will restore normal behavior.
- **Multi-window apps**: When switching between windows of the same app (e.g., multiple Chrome windows), the first click may not trigger the blur transition. A second click will work normally.

---

## Credits

Built on the shoulders of giants:

| Project | Contribution |
|---------|--------------|
| [**Blurred**](https://github.com/dwarvesf/blurred) by Dwarves Foundation | Original codebase and architecture |
| [**Monocle**](https://monocle.heyiam.dk/) by Dominik Kandravy | Inspiration for blur effect and ambient mode |

---

## License

MIT License © [Zhengyi Shen](https://github.com/zhengyishen0)
