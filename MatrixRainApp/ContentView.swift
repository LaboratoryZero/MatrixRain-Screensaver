import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PreviewViewModel()
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        ZStack {
            MatrixPreviewView(renderer: viewModel.renderer)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Button("Settings") {
                            openSettings()
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(",", modifiers: .command)
                        
                        Button("Export Video") {
                            viewModel.showExportSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                }
            }
        }
        .sheet(isPresented: $viewModel.showExportSheet) {
            ExportSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .matrixSettingsChanged)) { _ in
            viewModel.reloadSettings()
        }
    }
}

struct MatrixPreviewView: NSViewRepresentable {
    let renderer: MatrixRainRenderer
    
    func makeNSView(context: Context) -> MatrixPreviewNSView {
        let view = MatrixPreviewNSView(renderer: renderer)
        return view
    }
    
    func updateNSView(_ nsView: MatrixPreviewNSView, context: Context) {
        nsView.renderer = renderer
    }
}

class MatrixPreviewNSView: NSView {
    var renderer: MatrixRainRenderer
    private var displayLink: CVDisplayLink?
    
    init(renderer: MatrixRainRenderer) {
        self.renderer = renderer
        super.init(frame: .zero)
        wantsLayer = true
        startDisplayLink()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopDisplayLink()
    }
    
    override var isFlipped: Bool { true }
    
    override func layout() {
        super.layout()
        renderer.resize(to: bounds.size)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        renderer.draw(in: context)
    }
    
    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }
        
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo in
            let view = Unmanaged<MatrixPreviewNSView>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                view.renderer.update()
                view.needsDisplay = true
            }
            return kCVReturnSuccess
        }
        
        CVDisplayLinkSetOutputCallback(link, callback, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(link)
    }
    
    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
    }
}

class PreviewViewModel: ObservableObject {
    let renderer: MatrixRainRenderer
    @Published var showExportSheet = false
    @Published var exportProgress: Double = 0
    @Published var isExporting = false
    
    init() {
        let settings = MatrixRainRenderer.Settings.fromMatrixSettings()
        renderer = MatrixRainRenderer(settings: settings)
    }
    
    func reloadSettings() {
        renderer.settings = .fromMatrixSettings()
        renderer.reset()
    }
}
