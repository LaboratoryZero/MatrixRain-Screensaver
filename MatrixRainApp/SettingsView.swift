import SwiftUI

extension Notification.Name {
    static let matrixSettingsChanged = Notification.Name("matrixSettingsChanged")
}

private func notifySettingsChanged() {
    NotificationCenter.default.post(name: .matrixSettingsChanged, object: nil)
}

struct SettingsView: View {
    @State private var glyphSize: Double = Double(MatrixSettings.glyphSize())
    @State private var fallSpeed: Double = Double(MatrixSettings.fallSpeed())
    @State private var headBrightness: Double = Double(MatrixSettings.headBrightness())
    @State private var headGlow: Double = Double(MatrixSettings.headGlow())
    @State private var fadeLength: Double = Double(MatrixSettings.fadeLength())
    @State private var colorTransition: Double = Double(MatrixSettings.colorTransition())
    @State private var columnDensity: Double = Double(MatrixSettings.columnDensity())
    
    @State private var primaryColor: Color = Color(MatrixSettings.primaryColor())
    @State private var secondaryColor: Color = Color(MatrixSettings.secondaryColor())
    @State private var backgroundColor: Color = Color(MatrixSettings.backgroundColor())
    
    var body: some View {
        Form {
            Section("Size & Speed") {
                LabeledContent("Glyph Size") {
                    Slider(value: $glyphSize, in: 8...36, step: 1)
                        .onChange(of: glyphSize) { _, newValue in
                            MatrixSettings.setGlyphSize(CGFloat(newValue))
                            notifySettingsChanged()
                        }
                    Text("\(Int(glyphSize))px")
                        .frame(width: 50, alignment: .trailing)
                }
                
                LabeledContent("Fall Speed") {
                    Slider(value: $fallSpeed, in: 0.4...4.0, step: 0.1)
                        .onChange(of: fallSpeed) { _, newValue in
                            MatrixSettings.setFallSpeed(CGFloat(newValue))
                            notifySettingsChanged()
                        }
                    Text(String(format: "%.1fx", fallSpeed))
                        .frame(width: 50, alignment: .trailing)
                }
                
                LabeledContent("Column Density") {
                    Slider(value: $columnDensity, in: 0.2...2.0, step: 0.1)
                        .onChange(of: columnDensity) { _, newValue in
                            MatrixSettings.setColumnDensity(CGFloat(newValue))
                            notifySettingsChanged()
                        }
                    Text("\(Int(columnDensity * 100))%")
                        .frame(width: 50, alignment: .trailing)
                }
            }
            
            Section("Head Effects") {
                LabeledContent("Brightness") {
                    Slider(value: $headBrightness, in: 0.5...2.0, step: 0.1)
                        .onChange(of: headBrightness) { _, newValue in
                            MatrixSettings.setHeadBrightness(CGFloat(newValue))
                            notifySettingsChanged()
                        }
                    Text("\(Int(headBrightness * 100))%")
                        .frame(width: 50, alignment: .trailing)
                }
                
                LabeledContent("Glow") {
                    Slider(value: $headGlow, in: 0...1.0, step: 0.1)
                        .onChange(of: headGlow) { _, newValue in
                            MatrixSettings.setHeadGlow(CGFloat(newValue))
                            notifySettingsChanged()
                        }
                    Text("\(Int(headGlow * 100))%")
                        .frame(width: 50, alignment: .trailing)
                }
            }
            
            Section("Tail Effects") {
                LabeledContent("Fade Length") {
                    Slider(value: $fadeLength, in: 0.5...2.0, step: 0.1)
                        .onChange(of: fadeLength) { _, newValue in
                            MatrixSettings.setFadeLength(CGFloat(newValue))
                            notifySettingsChanged()
                        }
                    Text(String(format: "%.1fx", fadeLength))
                        .frame(width: 50, alignment: .trailing)
                }
                
                LabeledContent("Color Transition") {
                    Slider(value: $colorTransition, in: 0...1.0, step: 0.1)
                        .onChange(of: colorTransition) { _, newValue in
                            MatrixSettings.setColorTransition(CGFloat(newValue))
                            notifySettingsChanged()
                        }
                    Text("\(Int(colorTransition * 100))%")
                        .frame(width: 50, alignment: .trailing)
                }
            }
            
            Section("Colors") {
                ColorPicker("Head Color", selection: $primaryColor)
                    .onChange(of: primaryColor) { _, newValue in
                        MatrixSettings.setPrimaryColor(NSColor(newValue))
                        notifySettingsChanged()
                    }
                
                ColorPicker("Tail Color", selection: $secondaryColor)
                    .onChange(of: secondaryColor) { _, newValue in
                        MatrixSettings.setSecondaryColor(NSColor(newValue))
                        notifySettingsChanged()
                    }
                
                ColorPicker("Background", selection: $backgroundColor)
                    .onChange(of: backgroundColor) { _, newValue in
                        MatrixSettings.setBackgroundColor(NSColor(newValue))
                        notifySettingsChanged()
                    }
            }
            
            Section("Presets") {
                HStack {
                    Button("🌻 Latte") { applyPreset(.latte) }
                    Button("🪴 Frappé") { applyPreset(.frappe) }
                    Button("🌺 Macchiato") { applyPreset(.macchiato) }
                    Button("🌿 Mocha") { applyPreset(.mocha) }
                }
                
                Button("Reset to Defaults") {
                    applyPreset(.defaults)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 500)
        .padding()
    }
    
    enum Preset {
        case latte, frappe, macchiato, mocha, defaults
    }
    
    private func applyPreset(_ preset: Preset) {
        switch preset {
        case .latte:
            primaryColor = Color(red: 0.25, green: 0.62, blue: 0.43)
            secondaryColor = Color(red: 0.53, green: 0.73, blue: 0.58)
            backgroundColor = Color(red: 0.94, green: 0.93, blue: 0.89)
        case .frappe:
            primaryColor = Color(red: 0.65, green: 0.89, blue: 0.63)
            secondaryColor = Color(red: 0.51, green: 0.70, blue: 0.68)
            backgroundColor = Color(red: 0.19, green: 0.21, blue: 0.29)
        case .macchiato:
            primaryColor = Color(red: 0.65, green: 0.89, blue: 0.63)
            secondaryColor = Color(red: 0.49, green: 0.71, blue: 0.68)
            backgroundColor = Color(red: 0.14, green: 0.16, blue: 0.21)
        case .mocha:
            primaryColor = Color(red: 0.65, green: 0.89, blue: 0.63)
            secondaryColor = Color(red: 0.49, green: 0.71, blue: 0.68)
            backgroundColor = Color(red: 0.12, green: 0.12, blue: 0.18)
        case .defaults:
            glyphSize = Double(MatrixSettings.defaultGlyphSize)
            fallSpeed = Double(MatrixSettings.defaultFallSpeed)
            headBrightness = Double(MatrixSettings.defaultHeadBrightness)
            headGlow = Double(MatrixSettings.defaultHeadGlow)
            fadeLength = Double(MatrixSettings.defaultFadeLength)
            colorTransition = Double(MatrixSettings.defaultColorTransition)
            columnDensity = Double(MatrixSettings.defaultColumnDensity)
            primaryColor = Color(MatrixSettings.defaultPrimaryColor)
            secondaryColor = Color(MatrixSettings.defaultSecondaryColor)
            backgroundColor = Color(MatrixSettings.defaultBackgroundColor)
        }
        
        MatrixSettings.setPrimaryColor(NSColor(primaryColor))
        MatrixSettings.setSecondaryColor(NSColor(secondaryColor))
        MatrixSettings.setBackgroundColor(NSColor(backgroundColor))
        MatrixSettings.setGlyphSize(CGFloat(glyphSize))
        MatrixSettings.setFallSpeed(CGFloat(fallSpeed))
        MatrixSettings.setHeadBrightness(CGFloat(headBrightness))
        MatrixSettings.setHeadGlow(CGFloat(headGlow))
        MatrixSettings.setFadeLength(CGFloat(fadeLength))
        MatrixSettings.setColorTransition(CGFloat(colorTransition))
        MatrixSettings.setColumnDensity(CGFloat(columnDensity))
        notifySettingsChanged()
    }
}
