<p align="center">
  <img src=".github/assets/atoll-logo.png" alt="Atoll logo" width="120">
</p>
<h1 align="center">Atoll - DynamicIsland for macOS</h1>
<p align="center">
  <a href="https://github.com/nikitaSobolev2/Dynamic-Island/stargazers">
    <img src="https://img.shields.io/github/stars/nikitaSobolev2/Dynamic-Island?style=social" alt="GitHub stars"/>
  </a>
  <a href="https://github.com/nikitaSobolev2/Dynamic-Island/network/members">
    <img src="https://img.shields.io/github/forks/nikitaSobolev2/Dynamic-Island?style=social" alt="GitHub forks"/>
  </a>
  <a href="https://github.com/nikitaSobolev2/Dynamic-Island/releases">
    <img src="https://img.shields.io/github/downloads/nikitaSobolev2/Dynamic-Island/total?label=Downloads" alt="GitHub downloads"/>
  </a>
</p>

<p align="center">
  <a href="https://github.com/nikitaSobolev2/Dynamic-Island/releases/latest">
    <img src="https://img.shields.io/badge/Download-Dynamic%20Island%20for%20macOS-0A84FF?style=for-the-badge&logo=apple" alt="Download Dynamic Island for macOS"/>
  </a>
</p>

Atoll turns the MacBook notch into a focused command surface for media, system insight, and quick utilities. It stays out of the way until needed, then expands with responsive, native SwiftUI animations.

<p align="center">
  <img src="https://i.postimg.cc/t49mW5yN/Screenshot-2026-03-02-at-6-00-22-PM.png" alt="Atoll lock screen" width="920">
</p>





## Highlights
- Media controls for Apple Music, Spotify, and more with inline previews.
- Live Activities for media playback, Focus, screen recording, privacy indicators, downloads (beta), and battery/charging.
- Lock screen widgets for media, timers, charging, Bluetooth devices, and weather.
- Lightweight system insight for CPU, GPU, memory, network, and disk usage.
- Productivity tools including timers, clipboard history, color picker, and calendar previews.
- Customization for layouts, animations, hover behavior, and shortcut remapping.

## Other Features
- Gesture controls for opening/closing the notch and media navigation.
- Parallax hover interactions with smooth transitions.
- Lock screen appearance and positioning controls for panels and widgets.

<p align="center">
  <img src="https://i.postimg.cc/HkLGn6yH/846F86A4_A2F9_4CD6_BC84_1D720D377728_1_201_a.jpg" alt="Atoll preview" width="920">
</p>

## Requirements
- macOS 14.0 or later (optimised for macOS 15+).
- MacBook with a notch (14/16‑inch MBP across Apple silicon generations).
- Xcode 15+ to build from source.
- Permissions as needed: Accessibility, Camera, Calendar, Screen Recording, Music.

## Installation

Builds are not notarized. After installing, macOS may block the app until you remove the quarantine flag.

### Homebrew

```bash
brew tap nikitaSobolev2/dynamic-island https://github.com/nikitaSobolev2/Dynamic-Island
brew install --cask dynamic-island
```

### GitHub Release

1. Download the latest DMG from [Releases](https://github.com/nikitaSobolev2/Dynamic-Island/releases/latest).
2. Open the DMG and drag Atoll into Applications.
3. Clear Gatekeeper quarantine, then launch Atoll:

```bash
xattr -dr com.apple.quarantine /Applications/Atoll.app
```

### Build from source

```bash
git clone https://github.com/nikitaSobolev2/Dynamic-Island.git
cd Dynamic-Island
open DynamicIsland.xcodeproj
```

Select your Mac as the run destination and build (Cmd+R). Grant the requested permissions.

## Quick Start
- Hover near the notch to expand; click to enter controls.
- Use tabs for Media, Stats, Timers, Clipboard, and more.
- Adjust layout, appearance, and shortcuts from Settings.

## Settings
- Choose appearance, animation style, and per‑feature toggles.
- Remap global shortcuts and adjust hover behaviour.
- Enable lock screen widgets and select data sources.

## Gesture Controls
- Two-finger swipe down to open the notch when hover-to-open is disabled; swipe up to close.
- Enable horizontal media gestures in **Settings → General → Gesture control** to turn the music pane into a trackpad for previous/next or ±10 second seeks.
- Pick the gesture skip behaviour (track vs ±10s) independently from the skip button configuration so swipes can scrub while buttons change tracks—or vice versa.
- Horizontal swipes trigger the same haptics and button animations you see in the notch, keeping visual feedback consistent with tap interactions.

## Troubleshooting (Basics)
- After granting Accessibility or Screen Recording, quit and relaunch the app.
- If metrics are empty, enable categories in Settings → Stats.
- Media not responding: verify player is active and Music permission is granted.

## License
Atoll is released under the GPL v3 License. Refer to [LICENSE](LICENSE) for the full terms.

## Contributors

<a href="https://github.com/nikitaSobolev2/Dynamic-Island/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=nikitaSobolev2/Dynamic-Island" />
</a>

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=nikitaSobolev2/Dynamic-Island&type=timeline&legend=top-left)](https://www.star-history.com/#nikitaSobolev2/Dynamic-Island&type=timeline&legend=top-left)
