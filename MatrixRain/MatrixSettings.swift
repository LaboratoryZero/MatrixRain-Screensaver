import Cocoa
import ScreenSaver

enum MatrixSettings {
    // Use a plist file in Application Support for cross-process settings
    private static let settingsURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("MatrixRain", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("Settings.plist")
    }()
    
    private static var cachedSettings: [String: Any] = {
        loadFromDisk()
    }()

    static let glyphSizeKey = "glyphSize"
    static let fallSpeedKey = "fallSpeed"
    static let palettePrimaryKey = "palettePrimary"
    static let paletteSecondaryKey = "paletteSecondary"
    static let backgroundColorKey = "backgroundColor"
    static let headBrightnessKey = "headBrightness"
    static let headGlowKey = "headGlow"
    static let fadeLengthKey = "fadeLength"
    static let colorTransitionKey = "colorTransition"
    static let columnDensityKey = "columnDensity"

    static let defaultGlyphSize: CGFloat = 18
    static let defaultFallSpeed: CGFloat = 1.6
    static let defaultPrimaryColor = NSColor(calibratedRed: 0.0, green: 0.95, blue: 0.35, alpha: 1.0)
    static let defaultSecondaryColor = NSColor(calibratedRed: 0.55, green: 1.0, blue: 0.55, alpha: 0.85)
    static let defaultBackgroundColor = NSColor.black
    static let defaultHeadBrightness: CGFloat = 1.0  // 0.5 to 2.0 (100% default, up to 200%)
    static let defaultHeadGlow: CGFloat = 0.5        // 0.0 to 1.0 (50% default, pushes toward white)
    static let defaultFadeLength: CGFloat = 1.0      // 0.5 to 2.0 (multiplier for tail fade)
    static let defaultColorTransition: CGFloat = 0.3 // 0.0 to 1.0 (how far into tail before full tail color)
    static let defaultColumnDensity: CGFloat = 1.0  // 0.2 to 2.0 (100% default, >100% allows overlap)
    
    // MARK: - File I/O
    
    private static func loadFromDisk() -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return [:]
        }
        return dict
    }
    
    private static func saveToDisk() {
        if let data = try? PropertyListSerialization.data(fromPropertyList: cachedSettings, format: .binary, options: 0) {
            try? data.write(to: settingsURL, options: .atomic)
        }
    }
    
    static func refreshFromDisk() {
        cachedSettings = loadFromDisk()
    }

    // MARK: - Getters

    static func glyphSize() -> CGFloat {
        refreshFromDisk()
        if let value = cachedSettings[glyphSizeKey] as? Double {
            return CGFloat(value)
        }
        return defaultGlyphSize
    }

    static func fallSpeed() -> CGFloat {
        refreshFromDisk()
        if let value = cachedSettings[fallSpeedKey] as? Double {
            return CGFloat(value)
        }
        return defaultFallSpeed
    }

    static func primaryColor() -> NSColor {
        refreshFromDisk()
        if let data = cachedSettings[palettePrimaryKey] as? Data,
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            return color
        }
        return defaultPrimaryColor
    }

    static func secondaryColor() -> NSColor {
        refreshFromDisk()
        if let data = cachedSettings[paletteSecondaryKey] as? Data,
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            return color
        }
        return defaultSecondaryColor
    }

    static func backgroundColor() -> NSColor {
        refreshFromDisk()
        if let data = cachedSettings[backgroundColorKey] as? Data,
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            return color
        }
        return defaultBackgroundColor
    }

    // MARK: - Setters

    static func setGlyphSize(_ value: CGFloat) {
        cachedSettings[glyphSizeKey] = Double(value)
        saveToDisk()
    }

    static func setFallSpeed(_ value: CGFloat) {
        cachedSettings[fallSpeedKey] = Double(value)
        saveToDisk()
    }

    static func setPrimaryColor(_ color: NSColor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            cachedSettings[palettePrimaryKey] = data
            saveToDisk()
        }
    }

    static func setSecondaryColor(_ color: NSColor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            cachedSettings[paletteSecondaryKey] = data
            saveToDisk()
        }
    }

    static func setBackgroundColor(_ color: NSColor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
            cachedSettings[backgroundColorKey] = data
            saveToDisk()
        }
    }

    // MARK: - Head Brightness

    static func headBrightness() -> CGFloat {
        refreshFromDisk()
        if let value = cachedSettings[headBrightnessKey] as? Double {
            return CGFloat(value)
        }
        return defaultHeadBrightness
    }

    static func setHeadBrightness(_ value: CGFloat) {
        cachedSettings[headBrightnessKey] = Double(value)
        saveToDisk()
    }

    // MARK: - Head Glow

    static func headGlow() -> CGFloat {
        refreshFromDisk()
        if let value = cachedSettings[headGlowKey] as? Double {
            return CGFloat(value)
        }
        return defaultHeadGlow
    }

    static func setHeadGlow(_ value: CGFloat) {
        cachedSettings[headGlowKey] = Double(value)
        saveToDisk()
    }

    // MARK: - Fade Length

    static func fadeLength() -> CGFloat {
        refreshFromDisk()
        if let value = cachedSettings[fadeLengthKey] as? Double {
            return CGFloat(value)
        }
        return defaultFadeLength
    }

    static func setFadeLength(_ value: CGFloat) {
        cachedSettings[fadeLengthKey] = Double(value)
        saveToDisk()
    }

    // MARK: - Color Transition

    static func colorTransition() -> CGFloat {
        refreshFromDisk()
        if let value = cachedSettings[colorTransitionKey] as? Double {
            return CGFloat(value)
        }
        return defaultColorTransition
    }

    static func setColorTransition(_ value: CGFloat) {
        cachedSettings[colorTransitionKey] = Double(value)
        saveToDisk()
    }

    // MARK: - Column Density

    static func columnDensity() -> CGFloat {
        refreshFromDisk()
        if let value = cachedSettings[columnDensityKey] as? Double {
            return CGFloat(value)
        }
        return defaultColumnDensity
    }

    static func setColumnDensity(_ value: CGFloat) {
        cachedSettings[columnDensityKey] = Double(value)
        saveToDisk()
    }
}
