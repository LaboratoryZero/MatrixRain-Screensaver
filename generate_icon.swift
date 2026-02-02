#!/usr/bin/env swift

import Cocoa

// Matrix rain icon generator - creates exact pixel dimensions
func generateMatrixIcon(size: Int) -> NSBitmapImageRep {
    // Create bitmap with exact pixel dimensions (not points)
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    
    bitmap.size = NSSize(width: size, height: size)
    
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    
    // Background - dark black/green
    NSColor(red: 0.02, green: 0.05, blue: 0.02, alpha: 1.0).setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    
    // Draw rounded rect mask
    let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), 
                            xRadius: CGFloat(size) * 0.22, 
                            yRadius: CGFloat(size) * 0.22)
    path.addClip()
    
    // Refill with background after clip
    NSColor(red: 0.0, green: 0.02, blue: 0.0, alpha: 1.0).setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    
    // Matrix characters
    let katakana = "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
    let chars = Array(katakana)
    
    let fontSize = CGFloat(size) / 8.0
    let font = NSFont(name: "Hiragino Kaku Gothic ProN", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    
    let columns = 6
    let rows = 8
    let cellWidth = CGFloat(size) / CGFloat(columns)
    let cellHeight = CGFloat(size) / CGFloat(rows)
    
    srand48(42) // Fixed seed for reproducibility
    
    for col in 0..<columns {
        // Each column has a "head" position
        let headRow = Int(drand48() * Double(rows + 2)) - 1
        
        for row in 0..<rows {
            let char = chars[Int(drand48() * Double(chars.count))]
            let x = CGFloat(col) * cellWidth + cellWidth * 0.2
            let y = CGFloat(size) - CGFloat(row + 1) * cellHeight
            
            // Calculate brightness based on distance from head
            let distFromHead = row - headRow
            var alpha: CGFloat = 0.0
            var green: CGFloat = 0.0
            var isHead = false
            
            if distFromHead == 0 {
                // Head - bright white/green
                alpha = 1.0
                green = 1.0
                isHead = true
            } else if distFromHead > 0 && distFromHead < 6 {
                // Tail - fading green
                alpha = 1.0 - CGFloat(distFromHead) * 0.18
                green = 0.9 - CGFloat(distFromHead) * 0.1
            } else if distFromHead < 0 && distFromHead > -3 {
                // Just passed - very dim
                alpha = 0.2
                green = 0.3
            }
            
            if alpha > 0 {
                let color: NSColor
                if isHead {
                    color = NSColor(red: 0.9, green: 1.0, blue: 0.9, alpha: alpha)
                } else {
                    color = NSColor(red: 0.0, green: green, blue: 0.1, alpha: alpha)
                }
                
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color
                ]
                
                let str = String(char)
                str.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            }
        }
    }
    
    // Add subtle glow overlay
    let gradient = NSGradient(colors: [
        NSColor(red: 0, green: 0.3, blue: 0, alpha: 0.1),
        NSColor.clear,
        NSColor(red: 0, green: 0.2, blue: 0, alpha: 0.05)
    ])
    gradient?.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)
    
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func savePNG(_ bitmap: NSBitmapImageRep, to path: String) {
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created: \(path) (\(bitmap.pixelsWide)x\(bitmap.pixelsHigh))")
    } catch {
        print("Error writing \(path): \(error)")
    }
}

// Generate all required sizes for macOS app icon
let basePath = "/Users/zero/Documents/GitHub/Matrix-y/MatrixRainApp/Assets.xcassets/AppIcon.appiconset"

// macOS app icon sizes: base@1x and base@2x
let iconSizes: [(base: Int, scale: Int, suffix: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),      // 32px
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),      // 64px
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),   // 256px
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),   // 512px
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),   // 1024px
]

for iconSize in iconSizes {
    let actualSize = iconSize.base * iconSize.scale
    let bitmap = generateMatrixIcon(size: actualSize)
    savePNG(bitmap, to: "\(basePath)/\(iconSize.suffix)")
}

print("Done! Icon generation complete.")
