# Video-Player Saver Template

## Pipeline Overview
1) App previews MatrixRain with adjustable settings.
2) Offscreen render frame sequence for N seconds at selected resolution/fps.
3) Encode frames to Loop.mp4 using AVAssetWriter.
4) Copy template .saver bundle, replace Loop.mp4 and Metadata.plist.
5) Install to ~/Library/Screen Savers and select in System Settings.

## Minimal Bundle Layout
MatrixRainVideo.saver
- Contents
  - Info.plist
  - MacOS
    - MatrixRainVideo
  - Resources
    - Loop.mp4
    - Metadata.plist (optional)

## Metadata.plist
Recommended keys:
- width (Int)
- height (Int)
- fps (Int)
- durationSeconds (Int)
- colorSpace (String, e.g. sRGB)
