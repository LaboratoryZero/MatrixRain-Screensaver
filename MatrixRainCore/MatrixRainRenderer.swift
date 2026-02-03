import Foundation
import CoreText
import CoreGraphics

#if canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
#endif

/// Shared Matrix Rain renderer usable by both app and saver targets.
/// Draws to a CGContext without any view/window dependency.
public final class MatrixRainRenderer {
    
    // MARK: - Glitch Effect
    
    public enum GlitchPhase {
        case none
        case corruption(progress: Double)   // 0.0 - 1.0
        case error(progress: Double)        // 0.0 - 1.0
        case reset(progress: Double)        // 0.0 - 1.0
        case completion(progress: Double)   // 0.0 - 1.0 - Code finishes falling, fades to black
    }
    
    public var glitchPhase: GlitchPhase = .none
    
    private let errorMessages = [
        "SYSTEM FAILURE",
        "ERR_0xC0DE_OVERFLOW",
        "MATRIX CORE DUMP",
        "REINITIALIZING..."
    ]
    
    // MARK: - Column State
    
    private struct Column {
        var x: CGFloat
        var headRow: Int
        var speed: Double
        var length: Int
        var glyphs: [UniChar]
        var accumulator: Double
    }
    
    // MARK: - Settings
    
    public struct Settings {
        public var glyphSize: CGFloat
        public var fallSpeed: CGFloat
        public var primaryColor: PlatformColor
        public var secondaryColor: PlatformColor
        public var backgroundColor: PlatformColor
        public var headBrightness: CGFloat
        public var headGlow: CGFloat
        public var fadeLength: CGFloat
        public var colorTransition: CGFloat
        public var columnDensity: CGFloat
        
        public init(
            glyphSize: CGFloat = 18,
            fallSpeed: CGFloat = 1.6,
            primaryColor: PlatformColor = PlatformColor(calibratedRed: 0.0, green: 0.95, blue: 0.35, alpha: 1.0),
            secondaryColor: PlatformColor = PlatformColor(calibratedRed: 0.55, green: 1.0, blue: 0.55, alpha: 0.85),
            backgroundColor: PlatformColor = .black,
            headBrightness: CGFloat = 1.0,
            headGlow: CGFloat = 0.5,
            fadeLength: CGFloat = 1.0,
            colorTransition: CGFloat = 0.3,
            columnDensity: CGFloat = 1.0
        ) {
            self.glyphSize = glyphSize
            self.fallSpeed = fallSpeed
            self.primaryColor = primaryColor
            self.secondaryColor = secondaryColor
            self.backgroundColor = backgroundColor
            self.headBrightness = headBrightness
            self.headGlow = headGlow
            self.fadeLength = fadeLength
            self.colorTransition = colorTransition
            self.columnDensity = columnDensity
        }
        
        /// Load from MatrixSettings (for saver compatibility)
        public static func fromMatrixSettings() -> Settings {
            Settings(
                glyphSize: MatrixSettings.glyphSize(),
                fallSpeed: MatrixSettings.fallSpeed(),
                primaryColor: MatrixSettings.primaryColor(),
                secondaryColor: MatrixSettings.secondaryColor(),
                backgroundColor: MatrixSettings.backgroundColor(),
                headBrightness: MatrixSettings.headBrightness(),
                headGlow: MatrixSettings.headGlow(),
                fadeLength: MatrixSettings.fadeLength(),
                colorTransition: MatrixSettings.colorTransition(),
                columnDensity: MatrixSettings.columnDensity()
            )
        }
    }
    
    // MARK: - Properties
    
    public var settings: Settings {
        didSet { rebuildCaches() }
    }
    
    public private(set) var size: CGSize = .zero
    
    private var columns: [Column] = []
    private var glyphChars: [UniChar] = []
    private var rowCount: Int = 0
    private var lastFrameTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    
    // Cached rendering resources
    private var ctFont: CTFont!
    private var cachedGlyphs: [UniChar: CGGlyph] = [:]
    private var cachedAlphaColors: [CGColor] = []
    private var primaryCGColor: CGColor!
    private var backgroundCGColor: CGColor!
    private var cachedHaloGradient: CGGradient?
    private var cachedHaloRadius: CGFloat = 0
    
    // MARK: - Init
    
    public init(settings: Settings = Settings()) {
        self.settings = settings
        setupGlyphs()
        rebuildCaches()
    }
    
    // MARK: - Public API
    
    /// Resize the renderer to a new frame size; rebuilds columns.
    public func resize(to newSize: CGSize) {
        guard newSize != size else { return }
        size = newSize
        rebuildColumns()
    }
    
    /// Advance simulation by one frame (call at desired fps).
    /// Use fixedDelta for consistent timing during video export.
    public func update(fixedDelta: Double? = nil) {
        updateColumns(fixedDelta: fixedDelta)
    }
    
    /// Draw the current state into the given context.
    public func draw(in context: CGContext) {
        context.setFillColor(backgroundCGColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        switch glitchPhase {
        case .none:
            for column in columns {
                drawColumn(column, in: context)
            }
            
        case .corruption(let progress):
            drawCorruptedColumns(in: context, progress: progress)
            
        case .error(let progress):
            drawCorruptedColumns(in: context, progress: 1.0)
            drawErrorOverlay(in: context, progress: progress)
            
        case .reset(let progress):
            drawResetEffect(in: context, progress: progress)
            
        case .completion(let progress):
            drawCompletionEffect(in: context, progress: progress)
        }
    }
    
    /// Render a single frame to a CGImage (for offscreen/export).
    public func renderFrame() -> CGImage? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        // Flip for top-left origin
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        
        draw(in: context)
        return context.makeImage()
    }
    
    /// Reset columns and timing (useful when starting fresh).
    public func reset() {
        lastFrameTime = CFAbsoluteTimeGetCurrent()
        rebuildColumns()
    }
    
    // MARK: - Private: Setup
    
    private func setupGlyphs() {
        let katakana = "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
        let digits = "0123456789"
        glyphChars = Array((katakana + digits).utf16)
    }
    
    private func rebuildCaches() {
        let s = settings
        
        ctFont = CTFontCreateWithName("Hiragino Kaku Gothic ProN" as CFString, s.glyphSize, nil)
        
        cachedGlyphs.removeAll()
        for char in glyphChars {
            var uniChar = char
            var cgGlyph: CGGlyph = 0
            CTFontGetGlyphsForCharacters(ctFont, &uniChar, &cgGlyph, 1)
            cachedGlyphs[char] = cgGlyph
        }
        
        primaryCGColor = s.primaryColor.withAlphaComponent(s.headBrightness).cgColor
        backgroundCGColor = s.backgroundColor.cgColor
        
        rebuildHaloCache()
        rebuildAlphaColors()
    }
    
    private func rebuildHaloCache() {
        let s = settings
        let brightnessIntensity = (s.headBrightness - 0.5) / 1.5
        let glowIntensity = s.headGlow
        
        cachedHaloRadius = s.glyphSize * (1.0 + brightnessIntensity * 0.5 + glowIntensity * 0.5)
        
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        s.primaryColor.usingColorSpace(.deviceRGB)?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let glowRed = red + (1.0 - red) * glowIntensity
        let glowGreen = green + (1.0 - green) * glowIntensity
        let glowBlue = blue + (1.0 - blue) * glowIntensity
        
        let baseAlpha = min(0.6, brightnessIntensity * 0.6)
        let glowAlpha = min(0.8, baseAlpha + glowIntensity * 0.4)
        
        let colors: [CGFloat] = [
            glowRed, glowGreen, glowBlue, glowAlpha,
            glowRed, glowGreen, glowBlue, glowAlpha * 0.3,
            glowRed, glowGreen, glowBlue, 0.0
        ]
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        
        cachedHaloGradient = CGGradient(
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            colorComponents: colors,
            locations: locations,
            count: 3
        )
    }
    
    private func rebuildAlphaColors() {
        let s = settings
        cachedAlphaColors.removeAll()
        let steps = 20
        
        var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
        var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0, sa: CGFloat = 0
        s.primaryColor.usingColorSpace(.deviceRGB)?.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
        s.secondaryColor.usingColorSpace(.deviceRGB)?.getRed(&sr, green: &sg, blue: &sb, alpha: &sa)
        
        for i in 0...steps {
            let fadeProgress = CGFloat(i) / CGFloat(steps)
            let adjustedProgress = pow(fadeProgress, 2.0 / s.fadeLength)
            let alpha = max(0.05, 1.0 - adjustedProgress)
            
            let transitionRange = max(0.01, s.colorTransition)
            let colorBlend = min(1.0, fadeProgress / transitionRange)
            let r = pr + (sr - pr) * colorBlend
            let g = pg + (sg - pg) * colorBlend
            let b = pb + (sb - pb) * colorBlend
            
            let color = PlatformColor(calibratedRed: r, green: g, blue: b, alpha: alpha).cgColor
            cachedAlphaColors.append(color)
        }
    }
    
    // MARK: - Private: Columns
    
    private func rebuildColumns() {
        columns.removeAll()
        guard settings.glyphSize > 0, size.width > 0, size.height > 0 else { return }
        
        lastFrameTime = CFAbsoluteTimeGetCurrent()
        rowCount = Int(ceil(size.height / settings.glyphSize))
        let maxColumnCount = Int(ceil(size.width / settings.glyphSize))
        
        if settings.columnDensity <= 1.0 {
            let actualColumnCount = max(1, Int(CGFloat(maxColumnCount) * settings.columnDensity))
            let spacing = CGFloat(maxColumnCount) / CGFloat(actualColumnCount)
            
            for index in 0..<actualColumnCount {
                let x = CGFloat(Int(CGFloat(index) * spacing)) * settings.glyphSize
                let length = Int.random(in: max(6, rowCount / 4)...max(8, rowCount))
                let speed = Double.random(in: 4...14) * Double(settings.fallSpeed)
                let headRow = -Int.random(in: 0...length)
                let glyphs = (0..<length).map { _ in glyphChars.randomElement() ?? 0x30 }
                columns.append(Column(x: x, headRow: headRow, speed: speed, length: length, glyphs: glyphs, accumulator: 0))
            }
        } else {
            let columnsPerPosition = settings.columnDensity
            
            for posIndex in 0..<maxColumnCount {
                let x = CGFloat(posIndex) * settings.glyphSize
                let baseLength = Int.random(in: max(6, rowCount / 4)...max(8, rowCount))
                
                let speed1 = Double.random(in: 4...14) * Double(settings.fallSpeed)
                let headRow1 = -Int.random(in: 0...baseLength)
                let glyphs1 = (0..<baseLength).map { _ in glyphChars.randomElement() ?? 0x30 }
                columns.append(Column(x: x, headRow: headRow1, speed: speed1, length: baseLength, glyphs: glyphs1, accumulator: 0))
                
                let extraColumns = Int(columnsPerPosition - 1.0)
                let fractionalChance = columnsPerPosition - 1.0 - CGFloat(extraColumns)
                
                for _ in 0..<extraColumns {
                    addOverlappingColumn(at: x, baseLength: baseLength)
                }
                
                if CGFloat.random(in: 0...1) < fractionalChance {
                    addOverlappingColumn(at: x, baseLength: baseLength)
                }
            }
        }
    }
    
    private func addOverlappingColumn(at x: CGFloat, baseLength: Int) {
        let length = Int.random(in: max(6, rowCount / 4)...max(8, rowCount))
        let minOffset = length / 2
        let maxOffset = length + rowCount / 2
        let startOffset = Int.random(in: minOffset...maxOffset)
        
        let speed = Double.random(in: 4...14) * Double(settings.fallSpeed)
        let headRow = -startOffset
        let glyphs = (0..<length).map { _ in glyphChars.randomElement() ?? 0x30 }
        columns.append(Column(x: x, headRow: headRow, speed: speed, length: length, glyphs: glyphs, accumulator: 0))
    }
    
    private func updateColumns(fixedDelta: Double? = nil) {
        let delta: Double
        if let fixed = fixedDelta {
            // Use fixed delta for consistent timing (video export)
            delta = fixed
        } else {
            // Use real-time delta for interactive preview
            let now = CFAbsoluteTimeGetCurrent()
            delta = min(0.1, max(0.0, now - lastFrameTime))
            lastFrameTime = now
        }
        
        // Get completion progress for straggler acceleration
        let completionProgress = completionAccelerationFactor
        
        for index in columns.indices {
            var effectiveSpeed = columns[index].speed
            
            // During code completion, accelerate slow columns so they finish in time
            if completionProgress > 0 {
                // Calculate how far the TAIL of this column needs to travel to be off-screen
                let tailRow = columns[index].headRow - columns[index].length + 1
                let remainingDistance = Double(rowCount - tailRow)
                
                // Only accelerate if column tail is still visible and column is moving
                if remainingDistance > 0 && columns[index].speed > 0 {
                    // More aggressive acceleration curve
                    // At progress 0.3, slow columns get 2x speed
                    // At progress 0.6, slow columns get 4x speed  
                    // At progress 0.9, slow columns get 8x speed
                    let baseAccel = 1.0 + (completionProgress * completionProgress * 8.0)
                    
                    // Slow columns (speed < 8) get more acceleration than fast ones
                    let speedFactor = max(0.5, (12.0 - columns[index].speed) / 8.0)
                    let acceleration = 1.0 + (baseAccel - 1.0) * speedFactor
                    
                    effectiveSpeed = columns[index].speed * acceleration
                }
            }
            
            columns[index].accumulator += effectiveSpeed * delta
            
            let rowsToMove = Int(columns[index].accumulator)
            if rowsToMove > 0 {
                columns[index].headRow += rowsToMove
                columns[index].accumulator -= Double(rowsToMove)
                
                let newGlyphs = (0..<rowsToMove).map { _ in glyphChars.randomElement() ?? 0x30 }
                columns[index].glyphs.insert(contentsOf: newGlyphs, at: 0)
                let overflow = columns[index].glyphs.count - columns[index].length
                if overflow > 0 {
                    columns[index].glyphs.removeLast(overflow)
                }
            }
            
            if columns[index].headRow - columns[index].length > rowCount {
                // Don't respawn columns during code completion transition
                if shouldPreventRespawn {
                    // Mark column as completely off-screen by pushing it far away
                    columns[index].headRow = rowCount + columns[index].length + 1000
                    columns[index].speed = 0
                    continue
                }
                
                let length = Int.random(in: max(6, rowCount / 4)...max(8, rowCount))
                let minOffset = settings.columnDensity > 1.0 ? length / 2 : 0
                let maxOffset = settings.columnDensity > 1.0 ? length + rowCount / 2 : length
                columns[index].headRow = -Int.random(in: minOffset...maxOffset)
                columns[index].speed = Double.random(in: 4...14) * Double(settings.fallSpeed)
                columns[index].length = length
                columns[index].glyphs = (0..<length).map { _ in glyphChars.randomElement() ?? 0x30 }
                columns[index].accumulator = 0
            }
        }
    }
    
    // MARK: - Private: Drawing
    
    private func drawColumn(_ column: Column, in context: CGContext) {
        let visibleStart = max(0, column.headRow - column.length + 1)
        let visibleEnd = min(rowCount - 1, column.headRow)
        
        guard visibleStart <= visibleEnd else { return }
        
        let xOffset = (settings.glyphSize - settings.glyphSize * 0.6) / 2
        
        for row in visibleStart...visibleEnd {
            let step = column.headRow - row
            guard step >= 0 && step < column.glyphs.count else { continue }
            
            let cellY = CGFloat(row) * settings.glyphSize
            let centerX = column.x + settings.glyphSize / 2
            let centerY = cellY + settings.glyphSize / 2
            
            if step == 0 && (settings.headBrightness > 0.5 || settings.headGlow > 0) {
                drawHalo(at: CGPoint(x: centerX, y: centerY), in: context)
            }
            
            let color: CGColor
            if step == 0 {
                color = primaryCGColor
            } else {
                let colorIndex = min(cachedAlphaColors.count - 1, step * cachedAlphaColors.count / column.length)
                color = cachedAlphaColors[colorIndex]
            }
            
            let glyph = column.glyphs[step]
            let cgGlyph = cachedGlyphs[glyph] ?? 0
            
            context.saveGState()
            context.translateBy(x: centerX, y: centerY)
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: -settings.glyphSize / 2, y: -settings.glyphSize / 2)
            
            context.setFillColor(color)
            var glyphToDraw = cgGlyph
            var position = CGPoint(x: xOffset, y: settings.glyphSize * 0.2)
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
    
    // MARK: - Glitch Effects
    
    /// Resolution-specific glitch parameters for consistent visual effect
    private struct GlitchParams {
        let scanLineSpacing: CGFloat
        let glitchBarHeightMin: CGFloat
        let glitchBarHeightMax: CGFloat
        let glitchBarOffsetRange: CGFloat
        let shakeAmount: CGFloat
        let bootFontSize: CGFloat
        let bootLineHeight: CGFloat
        let bootMarginTop: CGFloat
        let bootMarginLeft: CGFloat
        
        // 1080p settings (1920x1080)
        static let p1080 = GlitchParams(
            scanLineSpacing: 4,
            glitchBarHeightMin: 2,
            glitchBarHeightMax: 20,
            glitchBarOffsetRange: 50,
            shakeAmount: 3,
            bootFontSize: 12,
            bootLineHeight: 16,
            bootMarginTop: 50,
            bootMarginLeft: 20
        )
        
        // 4K settings (3840x2160)
        static let p4K = GlitchParams(
            scanLineSpacing: 8,
            glitchBarHeightMin: 4,
            glitchBarHeightMax: 40,
            glitchBarOffsetRange: 100,
            shakeAmount: 6,
            bootFontSize: 24,
            bootLineHeight: 32,
            bootMarginTop: 100,
            bootMarginLeft: 40
        )
        
        // 5K settings (5120x2880)
        static let p5K = GlitchParams(
            scanLineSpacing: 10,
            glitchBarHeightMin: 5,
            glitchBarHeightMax: 50,
            glitchBarOffsetRange: 130,
            shakeAmount: 8,
            bootFontSize: 32,
            bootLineHeight: 42,
            bootMarginTop: 130,
            bootMarginLeft: 50
        )
    }
    
    private var glitchParams: GlitchParams {
        if size.height >= 2880 {
            return .p5K
        } else if size.height >= 2160 {
            return .p4K
        } else {
            return .p1080
        }
    }
    
    private func drawCorruptedColumns(in context: CGContext, progress: Double) {
        for (index, column) in columns.enumerated() {
            // Some columns flicker/freeze based on progress
            let corruptionThreshold = Double(index % 7) / 7.0
            
            if progress > corruptionThreshold {
                // This column is corrupted
                if Int.random(in: 0...10) > 3 {
                    // Draw with glitchy offset and color shift
                    drawGlitchedColumn(column, in: context, intensity: progress)
                }
                // else: column flickers out (not drawn)
            } else {
                // Normal draw
                drawColumn(column, in: context)
            }
        }
        
        // Add scan lines
        drawScanLines(in: context, intensity: progress)
        
        // Add random horizontal glitch bars
        if progress > 0.3 {
            drawGlitchBars(in: context, count: Int(progress * 8))
        }
    }
    
    private func drawGlitchedColumn(_ column: Column, in context: CGContext, intensity: Double) {
        let visibleStart = max(0, column.headRow - column.length + 1)
        let visibleEnd = min(rowCount - 1, column.headRow)
        
        guard visibleStart <= visibleEnd else { return }
        
        // Random horizontal offset for glitch effect
        let glitchOffset = CGFloat.random(in: -settings.glyphSize * CGFloat(intensity) * 2...settings.glyphSize * CGFloat(intensity) * 2)
        
        let xOffset = (settings.glyphSize - settings.glyphSize * 0.6) / 2
        
        for row in visibleStart...visibleEnd {
            let step = column.headRow - row
            guard step >= 0 && step < column.glyphs.count else { continue }
            
            // Random chance to skip (flicker)
            if Double.random(in: 0...1) < intensity * 0.3 { continue }
            
            let cellY = CGFloat(row) * settings.glyphSize
            let centerX = column.x + settings.glyphSize / 2 + glitchOffset
            let centerY = cellY + settings.glyphSize / 2
            
            // Shift color towards red/orange as corruption increases
            let corruptColor: CGColor
            if step == 0 {
                let red = min(1.0, 0.0 + CGFloat(intensity) * 1.5)
                let green = max(0.0, 0.95 - CGFloat(intensity) * 0.8)
                corruptColor = PlatformColor(calibratedRed: red, green: green, blue: 0.1, alpha: 1.0).cgColor
            } else {
                let colorIndex = min(cachedAlphaColors.count - 1, step * cachedAlphaColors.count / column.length)
                let baseColor = cachedAlphaColors[colorIndex]
                // Tint towards red
                if let components = baseColor.components, components.count >= 4 {
                    let red = min(1.0, components[0] + CGFloat(intensity) * 0.5)
                    let green = max(0.0, components[1] - CGFloat(intensity) * 0.3)
                    corruptColor = PlatformColor(calibratedRed: red, green: green, blue: components[2], alpha: components[3]).cgColor
                } else {
                    corruptColor = baseColor
                }
            }
            
            // Randomly substitute glyphs
            let glyph: UniChar
            if Double.random(in: 0...1) < intensity * 0.5 {
                glyph = glyphChars.randomElement() ?? column.glyphs[step]
            } else {
                glyph = column.glyphs[step]
            }
            let cgGlyph = cachedGlyphs[glyph] ?? 0
            
            context.saveGState()
            context.translateBy(x: centerX, y: centerY)
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: -settings.glyphSize / 2, y: -settings.glyphSize / 2)
            
            context.setFillColor(corruptColor)
            var glyphToDraw = cgGlyph
            var position = CGPoint(x: xOffset, y: settings.glyphSize * 0.2)
            CTFontDrawGlyphs(ctFont, &glyphToDraw, &position, 1, context)
            
            context.restoreGState()
        }
    }
    
    private func drawScanLines(in context: CGContext, intensity: Double) {
        let params = glitchParams
        let lineSpacing: CGFloat = params.scanLineSpacing
        let lineAlpha = CGFloat(intensity) * 0.15
        
        context.setFillColor(PlatformColor.black.withAlphaComponent(lineAlpha).cgColor)
        
        var y: CGFloat = 0
        while y < size.height {
            context.fill(CGRect(x: 0, y: y, width: size.width, height: 1))
            y += lineSpacing
        }
    }
    
    private func drawGlitchBars(in context: CGContext, count: Int) {
        let params = glitchParams
        for _ in 0..<count {
            let y = CGFloat.random(in: 0...size.height)
            let height = CGFloat.random(in: params.glitchBarHeightMin...params.glitchBarHeightMax)
            let offsetX = CGFloat.random(in: -params.glitchBarOffsetRange...params.glitchBarOffsetRange)
            
            // Draw a horizontal slice offset
            context.saveGState()
            context.clip(to: CGRect(x: 0, y: y, width: size.width, height: height))
            context.translateBy(x: offsetX, y: 0)
            
            // Redraw columns in this slice (shifted)
            for column in columns.prefix(columns.count / 3) {
                drawColumn(column, in: context)
            }
            context.restoreGState()
            
            // Random color bar
            let barColor = PlatformColor(
                calibratedRed: CGFloat.random(in: 0.5...1.0),
                green: CGFloat.random(in: 0...0.3),
                blue: CGFloat.random(in: 0...0.2),
                alpha: CGFloat.random(in: 0.1...0.4)
            ).cgColor
            context.setFillColor(barColor)
            context.fill(CGRect(x: 0, y: y, width: size.width, height: height * 0.3))
        }
    }
    
    private func drawErrorOverlay(in context: CGContext, progress: Double) {
        // Darken background
        let overlayAlpha = min(0.7, progress * 0.8)
        context.setFillColor(PlatformColor.black.withAlphaComponent(overlayAlpha).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Screen shake effect (scaled for resolution)
        let shakeAmount = glitchParams.shakeAmount
        let shakeX = progress > 0.1 ? CGFloat.random(in: -shakeAmount...shakeAmount) : 0
        let shakeY = progress > 0.1 ? CGFloat.random(in: -shakeAmount...shakeAmount) : 0
        context.translateBy(x: shakeX, y: shakeY)
        
        // Calculate which messages to show based on progress
        let visibleCount = min(errorMessages.count, Int(progress * Double(errorMessages.count + 1)))
        
        // Draw error messages
        let fontSize: CGFloat = min(size.width / 15, 48)
        let font = CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
        let lineHeight = fontSize * 1.5
        let startY = size.height / 2 - (CGFloat(errorMessages.count) * lineHeight / 2)
        
        for (index, message) in errorMessages.prefix(visibleCount).enumerated() {
            let y = startY + CGFloat(index) * lineHeight
            
            // Glitchy red/green color
            let isGreen = index == errorMessages.count - 1 && progress > 0.9
            let textColor: CGColor
            if isGreen {
                textColor = PlatformColor(calibratedRed: 0.0, green: 1.0, blue: 0.3, alpha: 1.0).cgColor
            } else {
                textColor = PlatformColor(calibratedRed: 1.0, green: CGFloat.random(in: 0...0.3), blue: 0.1, alpha: 1.0).cgColor
            }
            
            // Create attributed string
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: PlatformColor(cgColor: textColor) ?? PlatformColor.red
            ]
            let attrString = NSAttributedString(string: message, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attrString)
            
            // Center the text
            let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
            let x = (size.width - textWidth) / 2
            
            // Draw text right-side up (flip context for this text only)
            context.saveGState()
            context.translateBy(x: x, y: y)
            context.scaleBy(x: 1, y: -1)
            context.textPosition = .zero
            CTLineDraw(line, context)
            context.restoreGState()
        }
        
        // Flicker effect
        if Int.random(in: 0...10) < 2 {
            context.setFillColor(PlatformColor.white.withAlphaComponent(0.05).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func drawResetEffect(in context: CGContext, progress: Double) {
        if progress < 0.2 {
            // Flash to white
            let flashIntensity = (0.2 - progress) / 0.2
            context.setFillColor(PlatformColor.white.withAlphaComponent(flashIntensity * 0.8).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        } else if progress < 0.85 {
            // Boot sequence with hex dump
            let bootProgress = (progress - 0.2) / 0.65
            
            // Fade out the boot sequence towards the end
            let fadeOut = progress > 0.7 ? 1.0 - ((progress - 0.7) / 0.15) : 1.0
            
            if fadeOut > 0 {
                context.saveGState()
                context.setAlpha(fadeOut)
                drawBootSequence(in: context, progress: min(bootProgress * 1.2, 1.0))
                context.restoreGState()
            }
        }
        // else: 0.85-1.0 stays black for seamless loop
    }
    
    private func drawBootSequence(in context: CGContext, progress: Double) {
        let params = glitchParams
        let fontSize: CGFloat = params.bootFontSize
        let font = CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
        
        // Generate pseudo-hex lines
        let lineCount = Int(progress * 15)
        let lineHeight: CGFloat = params.bootLineHeight
        
        let bootColor = PlatformColor(calibratedRed: 0.0, green: 0.8, blue: 0.3, alpha: 0.8).cgColor
        
        for i in 0..<lineCount {
            let y = CGFloat(i) * lineHeight + params.bootMarginTop
            
            // Generate hex string
            let hexString = String(format: "0x%08X: %@ %@ %@ %@",
                                   Int.random(in: 0x10000000...0xFFFFFFFF),
                                   String(format: "%08X", Int.random(in: 0...0xFFFFFFFF)),
                                   String(format: "%08X", Int.random(in: 0...0xFFFFFFFF)),
                                   String(format: "%08X", Int.random(in: 0...0xFFFFFFFF)),
                                   String(format: "%08X", Int.random(in: 0...0xFFFFFFFF)))
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: PlatformColor(cgColor: bootColor) ?? PlatformColor.green
            ]
            let attrString = NSAttributedString(string: hexString, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attrString)
            
            // Draw text right-side up (flip context for this text only)
            context.saveGState()
            context.translateBy(x: params.bootMarginLeft, y: y)
            context.scaleBy(x: 1, y: -1)
            context.textPosition = .zero
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }
    
    // MARK: - Code Completion Effect
    
    private func drawCompletionEffect(in context: CGContext, progress: Double) {
        // During completion, columns continue falling but no new ones spawn at top.
        // The updateColumns will naturally move them down, and we prevent respawning
        // via the shouldPreventRespawn check. Columns fall off naturally to black.
        
        for column in columns {
            // Only draw columns that are still on screen
            let bottomOfColumn = column.headRow - column.length + 1
            if bottomOfColumn < rowCount {
                drawColumn(column, in: context)
            }
        }
        // Screen naturally goes black as all columns fall off
    }
    
    /// Whether columns should stop respawning (used during code completion)
    private var shouldPreventRespawn: Bool {
        if case .completion = glitchPhase {
            return true
        }
        return false
    }
    
    /// Returns the completion progress (0.0-1.0) for straggler acceleration, or 0 if not in completion mode
    private var completionAccelerationFactor: Double {
        if case .completion(let progress) = glitchPhase {
            return progress
        }
        return 0
    }
}
