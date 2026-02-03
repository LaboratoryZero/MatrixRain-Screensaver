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
        
        for column in columns {
            drawColumn(column, in: context)
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
        
        for index in columns.indices {
            columns[index].accumulator += columns[index].speed * delta
            
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
}
