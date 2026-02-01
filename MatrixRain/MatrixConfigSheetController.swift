import Cocoa

final class MatrixConfigSheetController: NSWindowController {
    private let glyphSlider = NSSlider(value: 18, minValue: 8, maxValue: 36, target: nil, action: nil)
    private let speedSlider = NSSlider(value: 1.6, minValue: 0.4, maxValue: 4.0, target: nil, action: nil)
    private let brightnessSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 2.0, target: nil, action: nil)
    private let glowSlider = NSSlider(value: 0.0, minValue: 0.0, maxValue: 1.0, target: nil, action: nil)
    private let fadeLengthSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 2.0, target: nil, action: nil)
    private let densitySlider = NSSlider(value: 1.0, minValue: 0.2, maxValue: 2.0, target: nil, action: nil)
    private let glyphValueLabel = NSTextField(labelWithString: "18")
    private let speedValueLabel = NSTextField(labelWithString: "1.6")
    private let brightnessValueLabel = NSTextField(labelWithString: "100%")
    private let glowValueLabel = NSTextField(labelWithString: "0%")
    private let fadeLengthValueLabel = NSTextField(labelWithString: "1.0x")
    private let densityValueLabel = NSTextField(labelWithString: "100%")
    private let primaryColorWell = NSColorWell()
    private let secondaryColorWell = NSColorWell()
    private let backgroundColorWell = NSColorWell()

    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 420, height: 440)
        let styleMask: NSWindow.StyleMask = [.titled, .closable]
        let panel = NSPanel(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
        panel.title = "Matrix Settings"
        panel.isFloatingPanel = false
        panel.becomesKeyOnlyIfNeeded = false

        super.init(window: panel)
        panel.contentView = buildContentView()
        syncDefaults()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildContentView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 440))

        var yPos: CGFloat = 390

        let glyphLabel = makeLabel(text: "Glyph Size")
        glyphLabel.frame.origin = CGPoint(x: 20, y: yPos)
        view.addSubview(glyphLabel)

        glyphSlider.frame = NSRect(x: 140, y: yPos - 5, width: 200, height: 20)
        glyphSlider.isContinuous = true
        glyphSlider.target = self
        glyphSlider.action = #selector(sliderChanged)
        view.addSubview(glyphSlider)
        
        glyphValueLabel.frame = NSRect(x: 350, y: yPos - 5, width: 50, height: 20)
        view.addSubview(glyphValueLabel)

        yPos -= 40

        let speedLabel = makeLabel(text: "Falling Speed")
        speedLabel.frame.origin = CGPoint(x: 20, y: yPos)
        view.addSubview(speedLabel)

        speedSlider.frame = NSRect(x: 140, y: yPos - 5, width: 200, height: 20)
        speedSlider.isContinuous = true
        speedSlider.target = self
        speedSlider.action = #selector(sliderChanged)
        view.addSubview(speedSlider)
        
        speedValueLabel.frame = NSRect(x: 350, y: yPos - 5, width: 50, height: 20)
        view.addSubview(speedValueLabel)

        yPos -= 40

        let brightnessLabel = makeLabel(text: "Head Brightness")
        brightnessLabel.frame.origin = CGPoint(x: 20, y: yPos)
        view.addSubview(brightnessLabel)

        brightnessSlider.frame = NSRect(x: 140, y: yPos - 5, width: 200, height: 20)
        brightnessSlider.isContinuous = true
        brightnessSlider.target = self
        brightnessSlider.action = #selector(sliderChanged)
        view.addSubview(brightnessSlider)
        
        brightnessValueLabel.frame = NSRect(x: 350, y: yPos - 5, width: 50, height: 20)
        view.addSubview(brightnessValueLabel)

        yPos -= 40

        let glowLabel = makeLabel(text: "Head Glow")
        glowLabel.frame.origin = CGPoint(x: 20, y: yPos)
        view.addSubview(glowLabel)

        glowSlider.frame = NSRect(x: 140, y: yPos - 5, width: 200, height: 20)
        glowSlider.isContinuous = true
        glowSlider.target = self
        glowSlider.action = #selector(sliderChanged)
        view.addSubview(glowSlider)
        
        glowValueLabel.frame = NSRect(x: 350, y: yPos - 5, width: 50, height: 20)
        view.addSubview(glowValueLabel)

        yPos -= 40

        let fadeLengthLabel = makeLabel(text: "Fade Length")
        fadeLengthLabel.frame.origin = CGPoint(x: 20, y: yPos)
        view.addSubview(fadeLengthLabel)

        fadeLengthSlider.frame = NSRect(x: 140, y: yPos - 5, width: 200, height: 20)
        fadeLengthSlider.isContinuous = true
        fadeLengthSlider.target = self
        fadeLengthSlider.action = #selector(sliderChanged)
        view.addSubview(fadeLengthSlider)
        
        fadeLengthValueLabel.frame = NSRect(x: 350, y: yPos - 5, width: 50, height: 20)
        view.addSubview(fadeLengthValueLabel)

        yPos -= 40

        let densityLabel = makeLabel(text: "Column Density")
        densityLabel.frame.origin = CGPoint(x: 20, y: yPos)
        view.addSubview(densityLabel)

        densitySlider.frame = NSRect(x: 140, y: yPos - 5, width: 200, height: 20)
        densitySlider.isContinuous = true
        densitySlider.target = self
        densitySlider.action = #selector(sliderChanged)
        view.addSubview(densitySlider)
        
        densityValueLabel.frame = NSRect(x: 350, y: yPos - 5, width: 50, height: 20)
        view.addSubview(densityValueLabel)

        yPos -= 50

        let primaryLabel = makeLabel(text: "Primary Color")
        primaryLabel.frame.origin = CGPoint(x: 20, y: yPos + 10)
        view.addSubview(primaryLabel)

        primaryColorWell.frame = NSRect(x: 140, y: yPos, width: 80, height: 30)
        primaryColorWell.target = self
        primaryColorWell.action = #selector(colorChanged)
        view.addSubview(primaryColorWell)

        let backgroundLabel = makeLabel(text: "Background")
        backgroundLabel.frame.origin = CGPoint(x: 240, y: yPos + 10)
        view.addSubview(backgroundLabel)

        backgroundColorWell.frame = NSRect(x: 340, y: yPos, width: 60, height: 30)
        backgroundColorWell.target = self
        backgroundColorWell.action = #selector(colorChanged)
        view.addSubview(backgroundColorWell)

        yPos -= 40

        let secondaryLabel = makeLabel(text: "Secondary Color")
        secondaryLabel.frame.origin = CGPoint(x: 20, y: yPos + 10)
        view.addSubview(secondaryLabel)

        secondaryColorWell.frame = NSRect(x: 140, y: yPos, width: 80, height: 30)
        secondaryColorWell.target = self
        secondaryColorWell.action = #selector(colorChanged)
        view.addSubview(secondaryColorWell)

        let closeButton = makeButton(title: "OK", action: #selector(closeSheet))
        closeButton.frame = NSRect(x: 310, y: 20, width: 80, height: 30)
        view.addSubview(closeButton)

        let cancelButton = makeButton(title: "Cancel", action: #selector(cancelSheet))
        cancelButton.frame = NSRect(x: 220, y: 20, width: 80, height: 30)
        view.addSubview(cancelButton)

        let defaultButton = makeButton(title: "Defaults", action: #selector(resetToDefaults))
        defaultButton.frame = NSRect(x: 20, y: 20, width: 90, height: 30)
        view.addSubview(defaultButton)

        return view
    }

    private func makeLabel(text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        return label
    }

    private func makeButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    private func syncDefaults() {
        let size = MatrixSettings.glyphSize()
        let speed = MatrixSettings.fallSpeed()
        let brightness = MatrixSettings.headBrightness()
        let glow = MatrixSettings.headGlow()
        let fadeLength = MatrixSettings.fadeLength()
        let density = MatrixSettings.columnDensity()
        
        glyphSlider.doubleValue = Double(size)
        speedSlider.doubleValue = Double(speed)
        brightnessSlider.doubleValue = Double(brightness)
        glowSlider.doubleValue = Double(glow)
        fadeLengthSlider.doubleValue = Double(fadeLength)
        densitySlider.doubleValue = Double(density)
        
        glyphValueLabel.stringValue = String(format: "%.0f", size)
        speedValueLabel.stringValue = String(format: "%.1f", speed)
        brightnessValueLabel.stringValue = String(format: "%.0f%%", brightness * 100)
        glowValueLabel.stringValue = String(format: "%.0f%%", glow * 100)
        fadeLengthValueLabel.stringValue = String(format: "%.1fx", fadeLength)
        densityValueLabel.stringValue = String(format: "%.0f%%", density * 100)
        
        primaryColorWell.color = MatrixSettings.primaryColor()
        secondaryColorWell.color = MatrixSettings.secondaryColor()
        backgroundColorWell.color = MatrixSettings.backgroundColor()
    }

    @objc private func sliderChanged() {
        let size = CGFloat(glyphSlider.doubleValue)
        let speed = CGFloat(speedSlider.doubleValue)
        let brightness = CGFloat(brightnessSlider.doubleValue)
        let glow = CGFloat(glowSlider.doubleValue)
        let fadeLength = CGFloat(fadeLengthSlider.doubleValue)
        let density = CGFloat(densitySlider.doubleValue)
        
        glyphValueLabel.stringValue = String(format: "%.0f", size)
        speedValueLabel.stringValue = String(format: "%.1f", speed)
        brightnessValueLabel.stringValue = String(format: "%.0f%%", brightness * 100)
        glowValueLabel.stringValue = String(format: "%.0f%%", glow * 100)
        fadeLengthValueLabel.stringValue = String(format: "%.1fx", fadeLength)
        densityValueLabel.stringValue = String(format: "%.0f%%", density * 100)
        
        MatrixSettings.setGlyphSize(size)
        MatrixSettings.setFallSpeed(speed)
        MatrixSettings.setHeadBrightness(brightness)
        MatrixSettings.setHeadGlow(glow)
        MatrixSettings.setFadeLength(fadeLength)
        MatrixSettings.setColumnDensity(density)
    }

    @objc private func colorChanged() {
        MatrixSettings.setPrimaryColor(primaryColorWell.color)
        MatrixSettings.setSecondaryColor(secondaryColorWell.color)
        MatrixSettings.setBackgroundColor(backgroundColorWell.color)
    }

    @objc private func resetToDefaults() {
        // Reset all settings to classic Matrix defaults
        MatrixSettings.setGlyphSize(MatrixSettings.defaultGlyphSize)
        MatrixSettings.setFallSpeed(MatrixSettings.defaultFallSpeed)
        MatrixSettings.setHeadBrightness(MatrixSettings.defaultHeadBrightness)
        MatrixSettings.setHeadGlow(MatrixSettings.defaultHeadGlow)
        MatrixSettings.setFadeLength(MatrixSettings.defaultFadeLength)
        MatrixSettings.setColumnDensity(MatrixSettings.defaultColumnDensity)
        MatrixSettings.setPrimaryColor(MatrixSettings.defaultPrimaryColor)
        MatrixSettings.setSecondaryColor(MatrixSettings.defaultSecondaryColor)
        MatrixSettings.setBackgroundColor(MatrixSettings.defaultBackgroundColor)
        
        // Update UI to reflect defaults
        syncDefaults()
    }

    @objc private func closeSheet() {
        guard let window = self.window else { return }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.close()
        }
    }

    @objc private func cancelSheet() {
        syncDefaults()
        guard let window = self.window else { return }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.close()
        }
    }
}
