# Development Log

## MatrixRain Screensaver

A chronological record of the development process for the MatrixRain macOS screensaver.

---

### February 1, 2026

#### Initial Project Setup
- Created Xcode project for macOS ScreenSaver bundle
- Set up basic project structure with Swift
- Configured Info.plist with bundle identifier `com.matrixy.rain`

#### Core Animation Implementation
- Implemented falling column animation with katakana characters
- Initial rendering using basic NSString drawing
- Fixed animation direction (glyphs fall from top to bottom)
- Head of column is brightest, fading trail above

#### Performance Optimization
- Upgraded to 60fps animation (animationTimeInterval = 1.0/60.0)
- Implemented time-delta based movement for consistent speed
- Switched to Core Text (CTFont/CTFontDrawGlyphs) for efficient rendering
- Pre-computed alpha color cache for faster fade calculations

#### Font Rendering
- Fixed character rendering issues (boxes instead of glyphs)
- Switched to "Hiragino Kaku Gothic ProN" for proper katakana support
- Fixed upside-down text using CGContext transform (translateBy/scaleBy)

#### Settings Persistence
- Initial attempt with ScreenSaverDefaults (failed cross-process)
- Attempted CFPreferences (synchronization issues)
- Final solution: Plist file in `~/Library/Application Support/MatrixRain/`
- Settings now persist reliably between screensaver and System Settings

#### Options Panel
- Created MatrixConfigSheetController with NSPanel
- Added sliders for glyph size and speed
- Added color wells for primary, secondary, and background colors
- Fixed panel not opening (code signature issues)
- Added OK/Cancel/Defaults buttons
- Fixed repeated opening issues by creating fresh controller each time

#### Project Rename
- Renamed from "MatrixSaver" to "MatrixRain" to avoid naming conflict
- Updated all references in code, Info.plist, and Xcode project

#### Visual Refinements

**Head Brightness Control**
- Added slider (50% - 200%) for lead character brightness
- Brightness only affects the head glyph, not the tail

**Fade Length Control**
- Added slider (0.5x - 2.0x) for tail fade persistence
- Uses power curve for natural-looking falloff
- Independent of head brightness

**Column Density Control**
- Added slider (20% - 200%) for column count
- <100%: Sparse columns spread across screen
- >100%: Overlapping columns at same position
- Overlap offset by 50% of tail length for natural layering

**Head Glow Effect**
- Added radial gradient halo around head character
- Intensity scales with head brightness
- Added separate Head Glow slider (0% - 100%)
- Glow blends primary color toward white
- Default set to 50% for visible effect

---

## Architecture

```
MatrixRain/
├── MatrixRainView.swift      # Main ScreenSaverView subclass
│   ├── Column struct         # Tracks position, speed, glyphs
│   ├── animateOneFrame()     # 60fps animation loop
│   ├── drawColumn()          # Core Text glyph rendering
│   └── drawHalo()            # Radial gradient glow effect
│
├── MatrixSettings.swift      # Settings persistence
│   ├── Plist file storage    # ~/Library/Application Support/MatrixRain/
│   ├── Getters/Setters       # Type-safe access to all settings
│   └── Default values        # Classic Matrix defaults
│
├── MatrixConfigSheetController.swift  # Options panel UI
│   ├── NSPanel with sliders  # All visual settings
│   ├── NSColorWell           # Color pickers
│   └── Defaults button       # Reset to classic Matrix look
│
└── Info.plist               # Bundle configuration
    ├── NSPrincipalClass     # MatrixRainView
    └── CFBundleIdentifier   # com.matrixy.rain
```

## Key Technical Decisions

1. **Core Text over NSString**: 10x faster glyph rendering
2. **File-based settings**: Cross-process persistence (screensaver ↔ System Settings)
3. **Time-delta animation**: Consistent speed regardless of frame drops
4. **Fresh controller per sheet**: Avoids stale state in options panel
5. **Ad-hoc code signing**: Allows local development without Apple Developer account

## Settings Summary

| Setting | Key | Default | Range |
|---------|-----|---------|-------|
| Glyph Size | glyphSize | 18 | 8-36 |
| Fall Speed | fallSpeed | 1.6 | 0.4-4.0 |
| Head Brightness | headBrightness | 1.0 | 0.5-2.0 |
| Head Glow | headGlow | 0.5 | 0.0-1.0 |
| Fade Length | fadeLength | 1.0 | 0.5-2.0 |
| Column Density | columnDensity | 1.0 | 0.2-2.0 |
| Primary Color | palettePrimary | Bright Green | - |
| Secondary Color | paletteSecondary | Light Green | - |
| Background | backgroundColor | Black | - |
