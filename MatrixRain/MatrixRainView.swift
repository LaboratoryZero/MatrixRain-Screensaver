import ScreenSaver
import CoreText

@objc(MatrixRainView)
final class MatrixRainView: ScreenSaverView {
    // Each column tracks the row position of its head (brightest glyph)
    private struct Column {
        var x: CGFloat
        var headRow: Int
        var speed: Double
        var length: Int
        var glyphs: [UniChar]  // Store as UniChar for faster Core Text rendering
        var accumulator: Double
    }

    private var columns: [Column] = []
    private var glyphSize: CGFloat = MatrixSettings.defaultGlyphSize
    private var fallSpeed: CGFloat = MatrixSettings.defaultFallSpeed
    private var primaryColor: NSColor = MatrixSettings.defaultPrimaryColor
    private var secondaryColor: NSColor = MatrixSettings.defaultSecondaryColor
    private var backgroundColor: NSColor = MatrixSettings.defaultBackgroundColor
    private var headBrightness: CGFloat = MatrixSettings.defaultHeadBrightness
    private var headGlow: CGFloat = MatrixSettings.defaultHeadGlow
    private var fadeLength: CGFloat = MatrixSettings.defaultFadeLength
    private var colorTransition: CGFloat = MatrixSettings.defaultColorTransition
    private var columnDensity: CGFloat = MatrixSettings.defaultColumnDensity
    private var glyphChars: [UniChar] = []
    private var configController: MatrixConfigSheetController?
    private var lastFrameTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var rowCount: Int = 0
    
    // Cached for performance
    private var ctFont: CTFont!
    private var cachedAlphaColors: [CGColor] = []  // Pre-computed alpha variants
    private var primaryCGColor: CGColor!
    private var backgroundCGColor: CGColor!
    private var cachedHaloGradient: CGGradient?    // Cached halo gradient
    private var cachedHaloRadius: CGFloat = 0      // Cached halo radius
    private var cachedGlyphs: [UniChar: CGGlyph] = [:]  // Cached glyph lookups

    override var isFlipped: Bool { true }

    private var settingsCheckCounter: Int = 0

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 60.0
        setupGlyphs()
        reloadSettings()
        rebuildColumns()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1.0 / 60.0
        setupGlyphs()
        reloadSettings()
        rebuildColumns()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        rebuildColumns()
    }

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        // Always create a fresh controller to avoid stale state
        configController = MatrixConfigSheetController()
        return configController?.window
    }

    override func animateOneFrame() {
        // Check settings every 15 frames (~0.25 sec at 60fps)
        settingsCheckCounter += 1
        if settingsCheckCounter >= 15 {
            settingsCheckCounter = 0
            reloadSettingsIfNeeded()
        }
        updateColumns()
        setNeedsDisplay(bounds)
    }

    override func draw(_ rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Fill background
        context.setFillColor(backgroundCGColor)
        context.fill(bounds)
        
        // Draw all columns
        for column in columns {
            drawColumn(column, in: context)
        }
    }

    private func setupGlyphs() {
        // Half-width katakana and ASCII for Matrix effect
        let katakana = "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
        let digits = "0123456789"
        let chars = katakana + digits
        glyphChars = Array(chars.utf16)
    }

    private func reloadSettings() {
        glyphSize = MatrixSettings.glyphSize()
        fallSpeed = MatrixSettings.fallSpeed()
        primaryColor = MatrixSettings.primaryColor()
        secondaryColor = MatrixSettings.secondaryColor()
        backgroundColor = MatrixSettings.backgroundColor()
        headBrightness = MatrixSettings.headBrightness()
        headGlow = MatrixSettings.headGlow()
        fadeLength = MatrixSettings.fadeLength()
        colorTransition = MatrixSettings.colorTransition()
        columnDensity = MatrixSettings.columnDensity()
        
        // Use Hiragino Kaku Gothic for katakana support
        ctFont = CTFontCreateWithName("Hiragino Kaku Gothic ProN" as CFString, glyphSize, nil)
        
        // Pre-cache all glyph lookups
        cachedGlyphs.removeAll()
        for char in glyphChars {
            var uniChar = char
            var cgGlyph: CGGlyph = 0
            CTFontGetGlyphsForCharacters(ctFont, &uniChar, &cgGlyph, 1)
            cachedGlyphs[char] = cgGlyph
        }
        
        // Cache CGColors - head brightness only affects the lead character
        primaryCGColor = primaryColor.withAlphaComponent(headBrightness).cgColor
        backgroundCGColor = backgroundColor.cgColor
        
        // Cache halo gradient and radius
        rebuildHaloCache()
        
        // Pre-compute color variants for the tail with color transition
        // colorTransition controls how quickly we blend from primary to secondary color
        cachedAlphaColors.removeAll()
        let steps = 20
        
        // Get primary and secondary color components for blending
        var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
        var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0, sa: CGFloat = 0
        primaryColor.usingColorSpace(.deviceRGB)?.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
        secondaryColor.usingColorSpace(.deviceRGB)?.getRed(&sr, green: &sg, blue: &sb, alpha: &sa)
        
        for i in 0...steps {
            let fadeProgress = CGFloat(i) / CGFloat(steps)
            // Apply fadeLength as power curve - higher = longer fade (slower falloff)
            let adjustedProgress = pow(fadeProgress, 2.0 / fadeLength)
            // Tail starts at full brightness (1.0), fades based on position
            let alpha = max(0.05, 1.0 - adjustedProgress)
            
            // Color transition: blend from primary to secondary
            // colorTransition=0: instant switch to secondary
            // colorTransition=1: gradual blend over entire tail
            let transitionRange = max(0.01, colorTransition)  // Avoid division by zero
            let colorBlend = min(1.0, fadeProgress / transitionRange)
            let r = pr + (sr - pr) * colorBlend
            let g = pg + (sg - pg) * colorBlend
            let b = pb + (sb - pb) * colorBlend
            
            let color = NSColor(calibratedRed: r, green: g, blue: b, alpha: alpha).cgColor
            cachedAlphaColors.append(color)
        }
        
        // Cache halo gradient and radius
        rebuildHaloCache()
    }

    private func rebuildHaloCache() {
        // Halo intensity scales with headBrightness (baseline)
        let brightnessIntensity = (headBrightness - 0.5) / 1.5  // 0.0 at 0.5, 1.0 at 2.0
        let glowIntensity = headGlow
        
        // Cache the radius
        cachedHaloRadius = glyphSize * (1.0 + brightnessIntensity * 0.5 + glowIntensity * 0.5)
        
        // Get primary color components
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        primaryColor.usingColorSpace(.deviceRGB)?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Blend toward white based on headGlow
        let glowRed = red + (1.0 - red) * glowIntensity
        let glowGreen = green + (1.0 - green) * glowIntensity
        let glowBlue = blue + (1.0 - blue) * glowIntensity
        
        // Alpha increases with both brightness and glow
        let baseAlpha = min(0.6, brightnessIntensity * 0.6)
        let glowAlpha = min(0.8, baseAlpha + glowIntensity * 0.4)
        
        let colors: [CGFloat] = [
            glowRed, glowGreen, glowBlue, glowAlpha,
            glowRed, glowGreen, glowBlue, glowAlpha * 0.3,
            glowRed, glowGreen, glowBlue, 0.0
        ]
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        cachedHaloGradient = CGGradient(colorSpace: colorSpace, colorComponents: colors, locations: locations, count: 3)
    }

    private func reloadSettingsIfNeeded() {
        let newGlyphSize = MatrixSettings.glyphSize()
        let newSpeed = MatrixSettings.fallSpeed()
        let newPrimary = MatrixSettings.primaryColor()
        let newSecondary = MatrixSettings.secondaryColor()
        let newBackground = MatrixSettings.backgroundColor()
        let newHeadBrightness = MatrixSettings.headBrightness()
        let newHeadGlow = MatrixSettings.headGlow()
        let newFadeLength = MatrixSettings.fadeLength()
        let newColorTransition = MatrixSettings.colorTransition()
        let newDensity = MatrixSettings.columnDensity()

        let needsRebuild = newGlyphSize != glyphSize || newDensity != columnDensity
        let needsColorUpdate = newSpeed != fallSpeed ||
           newPrimary != primaryColor || newSecondary != secondaryColor ||
           newBackground != backgroundColor || newHeadBrightness != headBrightness ||
           newHeadGlow != headGlow || newFadeLength != fadeLength || newColorTransition != colorTransition

        if needsRebuild || needsColorUpdate {
            glyphSize = newGlyphSize
            fallSpeed = newSpeed
            primaryColor = newPrimary
            secondaryColor = newSecondary
            backgroundColor = newBackground
            headBrightness = newHeadBrightness
            headGlow = newHeadGlow
            fadeLength = newFadeLength
            colorTransition = newColorTransition
            columnDensity = newDensity
            
            ctFont = CTFontCreateWithName("Hiragino Kaku Gothic ProN" as CFString, glyphSize, nil)
            
            // Rebuild glyph cache when font changes
            cachedGlyphs.removeAll()
            for char in glyphChars {
                var uniChar = char
                var cgGlyph: CGGlyph = 0
                CTFontGetGlyphsForCharacters(ctFont, &uniChar, &cgGlyph, 1)
                cachedGlyphs[char] = cgGlyph
            }
            
            primaryCGColor = primaryColor.withAlphaComponent(headBrightness).cgColor
            backgroundCGColor = backgroundColor.cgColor
            
            // Rebuild halo cache
            rebuildHaloCache()
            
            // Pre-compute color variants for the tail with color transition
            cachedAlphaColors.removeAll()
            let steps = 20
            
            // Get primary and secondary color components for blending
            var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
            var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0, sa: CGFloat = 0
            primaryColor.usingColorSpace(.deviceRGB)?.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
            secondaryColor.usingColorSpace(.deviceRGB)?.getRed(&sr, green: &sg, blue: &sb, alpha: &sa)
            
            for i in 0...steps {
                let fadeProgress = CGFloat(i) / CGFloat(steps)
                let adjustedProgress = pow(fadeProgress, 2.0 / fadeLength)
                // Tail starts at full brightness, fades based on position
                let alpha = max(0.05, 1.0 - adjustedProgress)
                
                // Color transition: blend from primary to secondary
                let transitionRange = max(0.01, colorTransition)
                let colorBlend = min(1.0, fadeProgress / transitionRange)
                let r = pr + (sr - pr) * colorBlend
                let g = pg + (sg - pg) * colorBlend
                let b = pb + (sb - pb) * colorBlend
                
                let color = NSColor(calibratedRed: r, green: g, blue: b, alpha: alpha).cgColor
                cachedAlphaColors.append(color)
            }
            
            if needsRebuild {
                rebuildColumns()
            }
        }
    }

    private func rebuildColumns() {
        columns.removeAll()
        guard glyphSize > 0 else { return }

        lastFrameTime = CFAbsoluteTimeGetCurrent()
        rowCount = Int(ceil(bounds.height / glyphSize))
        let maxColumnCount = Int(ceil(bounds.width / glyphSize))
        
        // Density < 1.0: fewer columns spread out
        // Density = 1.0: one column per position
        // Density > 1.0: multiple overlapping columns per position
        
        if columnDensity <= 1.0 {
            // Sparse mode: reduce number of columns
            let actualColumnCount = max(1, Int(CGFloat(maxColumnCount) * columnDensity))
            let spacing = CGFloat(maxColumnCount) / CGFloat(actualColumnCount)
            
            for index in 0..<actualColumnCount {
                let x = CGFloat(Int(CGFloat(index) * spacing)) * glyphSize
                let length = Int.random(in: max(6, rowCount / 4)...max(8, rowCount))
                let speed = Double.random(in: 4...14) * Double(fallSpeed)
                let headRow = -Int.random(in: 0...length)
                let glyphsForColumn = (0..<length).map { _ in glyphChars.randomElement() ?? 0x30 }
                columns.append(Column(x: x, headRow: headRow, speed: speed, length: length, glyphs: glyphsForColumn, accumulator: 0))
            }
        } else {
            // Dense mode: add overlapping columns
            // density 2.0 = 2 columns per position
            let columnsPerPosition = columnDensity
            
            for posIndex in 0..<maxColumnCount {
                let x = CGFloat(posIndex) * glyphSize
                let baseLength = Int.random(in: max(6, rowCount / 4)...max(8, rowCount))
                
                // First column at this position (always add)
                let speed1 = Double.random(in: 4...14) * Double(fallSpeed)
                let headRow1 = -Int.random(in: 0...baseLength)
                let glyphs1 = (0..<baseLength).map { _ in glyphChars.randomElement() ?? 0x30 }
                columns.append(Column(x: x, headRow: headRow1, speed: speed1, length: baseLength, glyphs: glyphs1, accumulator: 0))
                
                // Additional overlapping columns based on density > 1.0
                // Probability of adding extra column based on fractional part
                let extraColumns = Int(columnsPerPosition - 1.0)
                let fractionalChance = columnsPerPosition - 1.0 - CGFloat(extraColumns)
                
                for _ in 0..<extraColumns {
                    addOverlappingColumn(at: x, baseLength: baseLength)
                }
                
                // Fractional chance for one more
                if CGFloat.random(in: 0...1) < fractionalChance {
                    addOverlappingColumn(at: x, baseLength: baseLength)
                }
            }
        }
    }
    
    private func addOverlappingColumn(at x: CGFloat, baseLength: Int) {
        // Offset the start position by at least 50% of the tail length
        // so columns don't start at the same place
        let length = Int.random(in: max(6, rowCount / 4)...max(8, rowCount))
        let minOffset = length / 2  // At least 50% of tail length offset
        let maxOffset = length + rowCount / 2
        let startOffset = Int.random(in: minOffset...maxOffset)
        
        let speed = Double.random(in: 4...14) * Double(fallSpeed)
        let headRow = -startOffset
        let glyphs = (0..<length).map { _ in glyphChars.randomElement() ?? 0x30 }
        columns.append(Column(x: x, headRow: headRow, speed: speed, length: length, glyphs: glyphs, accumulator: 0))
    }

    private func updateColumns() {
        let now = CFAbsoluteTimeGetCurrent()
        let delta = min(0.1, max(0.0, now - lastFrameTime))
        lastFrameTime = now

        for index in columns.indices {
            columns[index].accumulator += columns[index].speed * delta

            let rowsToMove = Int(columns[index].accumulator)
            if rowsToMove > 0 {
                columns[index].headRow += rowsToMove
                columns[index].accumulator -= Double(rowsToMove)

                // Batch insert new glyphs
                let newGlyphs = (0..<rowsToMove).map { _ in glyphChars.randomElement() ?? 0x30 }
                columns[index].glyphs.insert(contentsOf: newGlyphs, at: 0)
                let overflow = columns[index].glyphs.count - columns[index].length
                if overflow > 0 {
                    columns[index].glyphs.removeLast(overflow)
                }
            }

            if columns[index].headRow - columns[index].length > rowCount {
                let length = Int.random(in: max(6, rowCount / 4)...max(8, rowCount))
                // When density > 1.0, use offset to stagger overlapping columns
                let minOffset = columnDensity > 1.0 ? length / 2 : 0
                let maxOffset = columnDensity > 1.0 ? length + rowCount / 2 : length
                columns[index].headRow = -Int.random(in: minOffset...maxOffset)
                columns[index].speed = Double.random(in: 4...14) * Double(fallSpeed)
                columns[index].length = length
                columns[index].glyphs = (0..<length).map { _ in glyphChars.randomElement() ?? 0x30 }
                columns[index].accumulator = 0
            }
        }
    }

    private func drawColumn(_ column: Column, in context: CGContext) {
        let visibleStart = max(0, column.headRow - column.length + 1)
        let visibleEnd = min(rowCount - 1, column.headRow)
        
        guard visibleStart <= visibleEnd else { return }
        
        // Calculate offset for text centering
        let xOffset = (glyphSize - glyphSize * 0.6) / 2  // Approximate character width
        
        for row in visibleStart...visibleEnd {
            let step = column.headRow - row
            guard step >= 0 && step < column.glyphs.count else { continue }
            
            // Position for this glyph cell
            let cellY = CGFloat(row) * glyphSize
            let centerX = column.x + glyphSize / 2
            let centerY = cellY + glyphSize / 2
            
            // Draw halo effect for the head character when brightness > 0.5 OR glow > 0
            if step == 0 && (headBrightness > 0.5 || headGlow > 0) {
                drawHalo(at: CGPoint(x: centerX, y: centerY), in: context)
            }
            
            // Get color from cache
            let color: CGColor
            if step == 0 {
                color = primaryCGColor
            } else {
                let colorIndex = min(cachedAlphaColors.count - 1, step * cachedAlphaColors.count / column.length)
                color = cachedAlphaColors[colorIndex]
            }
            
            // Draw glyph using Core Text with transform to flip text right-side up
            let glyph = column.glyphs[step]
            let cgGlyph = cachedGlyphs[glyph] ?? 0
            
            context.saveGState()
            
            // Flip the text within the cell: translate to cell center, flip, translate back
            context.translateBy(x: centerX, y: centerY)
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: -glyphSize / 2, y: -glyphSize / 2)
            
            context.setFillColor(color)
            var glyphToDraw = cgGlyph
            var position = CGPoint(x: xOffset, y: glyphSize * 0.2)  // Baseline offset from bottom
            CTFontDrawGlyphs(ctFont, &glyphToDraw, &position, 1, context)
            
            context.restoreGState()
        }
    }
    
    private func drawHalo(at center: CGPoint, in context: CGContext) {
        guard let gradient = cachedHaloGradient else { return }
        
        context.saveGState()
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: cachedHaloRadius, options: [])
        context.restoreGState()
    }
}
