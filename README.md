# MatrixRain Screensaver

A macOS screensaver that renders the iconic Matrix-style falling code rain animation with Japanese katakana characters. Features smooth 60fps animation, customizable colors, and adjustable visual effects.

![macOS](https://img.shields.io/badge/macOS-11.0%2B-green)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![License](https://img.shields.io/badge/License-MIT-blue)

## Features

- **Authentic Matrix Effect**: Falling columns of Japanese katakana and numeric characters
- **Smooth 60fps Animation**: Time-based rendering for consistent performance
- **Customizable Colors**: Head, tail, and background color selection
- **Head Glow Effect**: Adjustable brightness and white-hot glow for lead characters
- **Fade Control**: Configure how quickly the tail fades behind each column
- **Color Transition**: Control the blend gradient from head to tail color
- **Column Density**: Sparse to overlapping column configurations (20% - 200%)
- **Catppuccin Themes**: Built-in presets for all four Catppuccin flavors (Latte, Frappé, Macchiato, Mocha)
- **Persistent Settings**: Preferences saved between sessions

## Installation

### Pre-built Release

1. Download the latest `MatrixRain.saver` from the [Releases](https://github.com/LaboratoryZero/MatrixRain-Screensaver/releases) page
2. Double-click the `.saver` file to install, or copy it to:
   - `~/Library/Screen Savers/` (current user only)
   - `/Library/Screen Savers/` (all users, requires admin)
3. Open **System Settings → Screen Saver** and select **MatrixRain**
4. Click **Options** to customize the effect

### Build from Source

#### Requirements
- macOS 11.0 or later
- Xcode 13.0 or later

#### Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/LaboratoryZero/MatrixRain-Screensaver.git
   cd MatrixRain-Screensaver
   ```

2. Open the project in Xcode:
   ```bash
   open MatrixRain.xcodeproj
   ```

3. Build the project:
   - Select the **MatrixRain** scheme
   - Choose **Product → Build** (⌘B)

4. Install the screensaver:
   ```bash
   cp -R ~/Library/Developer/Xcode/DerivedData/MatrixRain-*/Build/Products/Release/MatrixRain.saver ~/Library/Screen\ Savers/
   ```

5. Sign for local use (if needed):
   ```bash
   xattr -cr ~/Library/Screen\ Savers/MatrixRain.saver
   codesign --force --deep --sign - ~/Library/Screen\ Savers/MatrixRain.saver
   ```

## Configuration Options

| Setting | Range | Description |
|---------|-------|-------------|
| **Glyph Size** | 8 - 36 | Size of the falling characters in pixels |
| **Falling Speed** | 0.4x - 4.0x | Speed multiplier for the falling animation |
| **Head Brightness** | 50% - 200% | Brightness of the lead character in each column |
| **Head Glow** | 0% - 100% | Intensity of the white-hot halo effect around the head |
| **Fade Length** | 0.5x - 2.0x | How far the brightness persists into the tail |
| **Color Transition** | 0% - 100% | How quickly colors blend from head to tail |
| **Column Density** | 20% - 200% | Number of falling columns (>100% creates overlapping streams) |
| **Head Color** | Color picker | Color of the head/lead character |
| **Tail Color** | Color picker | Color of the trailing characters |
| **Background** | Color picker | Background color (default: black) |

### Catppuccin Theme Presets

One-click theme presets using the beautiful [Catppuccin](https://github.com/catppuccin/catppuccin) color palette:

| Button | Flavor | Description |
|--------|--------|-------------|
| 🌻 | **Latte** | Light, warm flavor with cream background |
| 🪴 | **Frappé** | Medium, cool flavor with blue-gray background |
| 🌺 | **Macchiato** | Dark, rich flavor with deep purple background |
| 🌿 | **Mocha** | Darkest flavor with signature purple head glow |

## Troubleshooting

### Options menu doesn't open
Kill the legacy screensaver process and try again:
```bash
pkill -f legacyScreenSaver
```

### Screensaver shows code signature error
Re-sign the bundle:
```bash
xattr -cr ~/Library/Screen\ Savers/MatrixRain.saver
codesign --force --deep --sign - ~/Library/Screen\ Savers/MatrixRain.saver
```

### Settings not persisting
Settings are stored in `~/Library/Application Support/MatrixRain/Settings.plist`. Ensure the directory is writable.

## Technical Details

- **Framework**: ScreenSaver.framework (macOS native)
- **Rendering**: Core Text (CTFont) for efficient glyph drawing
- **Font**: Hiragino Kaku Gothic ProN for Japanese katakana support
- **Animation**: 60fps with time-delta based movement for smooth, consistent speed
- **Settings Storage**: Plist file in Application Support (cross-process compatible)

## License

MIT License - See [LICENSE](LICENSE) for details.

## Credits

Developed by Laboratory Zero, 2026.

Inspired by the iconic "digital rain" effect from The Matrix (1999).

Color themes use the [Catppuccin](https://github.com/catppuccin/catppuccin) palette, a community-driven pastel theme created by [Catppuccin](https://github.com/catppuccin). Catppuccin is released under the MIT License.
