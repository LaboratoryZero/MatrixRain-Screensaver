# MatrixRain Screensaver

A macOS screensaver that displays the iconic Matrix-style falling code rain animation. Features a companion app for customizing colors and effects, with high-quality video export up to 5K resolution.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-green)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/License-MIT-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-Required-red)

## Features

- **Video-Based Screensaver**: Zero CPU/GPU load during playback - just plays a pre-rendered video
- **High Resolution Export**: Render at 1080p, 4K, or 5K
- **Live Preview**: Preview at 1080p, 4K, or 5K before rendering
- **Authentic Matrix Effect**: Falling columns of Japanese katakana and numeric characters
- **Customizable Colors**: Head, tail, and background color selection
- **Head Glow Effect**: Adjustable brightness and white-hot glow for lead characters
- **Fade Control**: Configure how quickly the tail fades behind each column
- **Color Transition**: Control the blend gradient from head to tail color
- **Column Density**: Sparse to overlapping column configurations (20% - 200%)
- **Catppuccin Themes**: Built-in presets for all four Catppuccin flavors
- **One-Click Install**: Export and install screensaver in a single step

## Requirements

- **macOS 14.0 (Sonoma)** or later
- **Apple Silicon Mac** (M1/M2/M3/M4)

## Installation

### From Release

1. Download `MatrixRain-2.1.2.pkg` from the [Releases](https://github.com/LaboratoryZero/MatrixRain-Screensaver/releases) page
2. Double-click the pkg to install **MatrixRain** to your Applications folder
3. Launch **MatrixRain** from Applications
4. Customize your colors and settings
5. Click **Export Video** → Ensure **Install after export** is checked → **Export**
6. Open **System Settings → Screen Saver** and select **Matrix Rain**

### Build from Source

```bash
# Clone the repository
git clone https://github.com/LaboratoryZero/MatrixRain-Screensaver.git
cd MatrixRain-Screensaver

# Build the app (Release)
xcodebuild -scheme MatrixRainApp -configuration Release build

# Build the screensaver (requires arm64e for legacyScreenSaver)
xcodebuild -scheme MatrixRainVideoSaver -configuration Release ARCHS=arm64e build

# Find built products
open ~/Library/Developer/Xcode/DerivedData/MatrixRain-*/Build/Products/Release/
```

## How It Works

### Two-Component Architecture

1. **MatrixRain** - A standalone macOS app for:
   - Live preview of the Matrix rain effect
   - Color and effect customization
   - Video export at various resolutions
   - Automatic screensaver installation

2. **MatrixRainVideoSaver** - A lightweight screensaver bundle that:
   - Simply plays the exported video in a loop
   - Uses zero CPU/GPU (hardware video decode only)
   - No real-time rendering = no battery drain or fan noise

### Why Video-Based?

The original v1.0 used real-time rendering which caused:
- High CPU/GPU usage
- Fan noise on laptops
- Battery drain
- Thermal throttling on some Macs

Version 2.0 pre-renders the animation once, then plays it back efficiently using hardware video decode.

## Configuration Options

| Setting | Range | Description |
|---------|-------|-------------|
| **Glyph Size** | 8 - 50 | Size of the falling characters in pixels |
| **Falling Speed** | 0.4x - 4.0x | Speed multiplier for the falling animation |
| **Head Brightness** | 50% - 200% | Brightness of the lead character in each column |
| **Head Glow** | 0% - 100% | Intensity of the white-hot halo effect around the head |
| **Fade Length** | 0.5x - 2.0x | How far the brightness persists into the tail |
| **Color Transition** | 0% - 100% | How quickly colors blend from head to tail |
| **Column Density** | 20% - 200% | Number of falling columns (>100% creates overlapping) |
| **Head Color** | Color picker | Color of the head/lead character |
| **Tail Color** | Color picker | Color of the trailing characters |
| **Background** | Color picker | Background color (default: black) |

### Export Settings

| Setting | Options | Description |
|---------|---------|-------------|
| **Resolution** | 1080p / 4K / 5K | Output video resolution |
| **Duration** | 30 - 300 sec | Length of the looping video |
| **Frame Rate** | 30 / 60 / 120 fps | Smoothness of animation |
| **Loop Transition** | None / Glitch / Code Completion | How the video loops seamlessly |

### Loop Transition Options

| Transition | Duration | Description |
|------------|----------|-------------|
| **None** | - | Video loops with a hard cut (default) |
| **Glitch** | 8 sec | Matrix-style system failure with error messages, then reboot sequence |
| **Code Completion** | 15 sec | All columns finish falling naturally, fading to black |

### Catppuccin Theme Presets

One-click theme presets using the beautiful [Catppuccin](https://github.com/catppuccin/catppuccin) color palette:

| Button | Flavor | Description |
|--------|--------|-------------|
| 🌻 | **Latte** | Light, warm flavor with cream background |
| 🪴 | **Frappé** | Medium, cool flavor with blue-gray background |
| 🌺 | **Macchiato** | Dark, rich flavor with deep purple background |
| 🌿 | **Mocha** | Darkest flavor with Mauve purple head glow |

## Troubleshooting

### Screensaver doesn't appear in System Settings

1. Ensure the export completed with "Install as Screen Saver" checked
2. Log out and back in, or restart your Mac
3. Check that `~/Library/Screen Savers/MatrixRain.saver` exists

### Video plays with wrong colors

This was fixed in v2.1.0. Make sure you're using the latest version. If upgrading, re-export your video.

### Export takes a long time

Higher resolutions (4K+) require more time to render. A 60-second 4K export typically takes 2-3 minutes on M1.

### App won't open (unsigned)

```bash
xattr -cr /path/to/MatrixRain.app
```

## Project Structure

```
Matrix-y/
├── MatrixRainApp/           # Main configuration app (MatrixRain.app)
│   ├── ContentView.swift    # Preview with resolution selector
│   ├── SettingsView.swift   # Color/effect settings
│   ├── ExportSheet.swift    # Video export & install
│   └── ...
├── MatrixRainCore/          # Shared rendering engine
│   ├── MatrixRainRenderer.swift  # Core animation renderer
│   └── MatrixSettings.swift      # Settings persistence
├── MatrixRainVideoSaver/    # Screensaver bundle
│   ├── MatrixRainVideoSaverView.swift  # Video playback
│   └── Info.plist
└── docs/
    └── VideoSaverTemplate.md
```

## Technical Details

- **Video Codec**: H.264 with hardware encoding
- **Color Space**: sRGB with Rec.709 color properties
- **Bitrate**: 40 Mbps for high quality
- **Rendering**: Core Text (CTFont) for efficient glyph drawing
- **Font**: Hiragino Kaku Gothic ProN for Japanese katakana
- **Animation**: Time-delta based for consistent speed
- **Settings**: Plist file in `~/Library/Application Support/MatrixRain/`

## Version History

### v2.1.0 (2026-02-03)
- Renamed app bundle to **MatrixRain.app**
- H.264 export with improved frame pacing and progress reporting
- Corrected app icon orientation
- Updated export size estimates and app quit behavior

### v2.0.0 (2025-02-02)
- Complete rewrite with video-based screensaver architecture
- Added MatrixRain app for configuration and export
- Live preview with resolution selector (1080p / 4K / 5K)
- Fixed color export issues (sRGB color space attachment)
- Removed legacy real-time rendering (caused CPU/GPU overload)
- Updated Mocha preset with Catppuccin Mauve head color
- Increased max glyph size to 50

### v1.0.0 (2025-01-xx)
- Initial release with real-time rendering (deprecated)

## License

MIT License - See [LICENSE](LICENSE) for details.

## Credits

Developed by Laboratory Zero, 2025.

Inspired by the iconic "digital rain" effect from The Matrix (1999).

Color themes use the [Catppuccin](https://github.com/catppuccin/catppuccin) palette, a community-driven pastel theme released under the MIT License.
