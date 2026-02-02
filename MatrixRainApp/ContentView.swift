import SwiftUI

// Fixed 1080p resolution for optimal quality/performance
private let previewSize = CGSize(width: 1920, height: 1080)

struct ContentView: View {
    @StateObject private var viewModel = PreviewViewModel()
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        ZStack {
            MatrixPreviewView(renderer: viewModel.renderer, renderSize: previewSize)
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
    let renderSize: CGSize
    
    func makeNSView(context: Context) -> MatrixPreviewNSView {
        let view = MatrixPreviewNSView(renderer: renderer, renderSize: renderSize)
        return view
    }
    
    func updateNSView(_ nsView: MatrixPreviewNSView, context: Context) {
        nsView.renderer = renderer
        nsView.renderSize = renderSize
    }
}

class MatrixPreviewNSView: NSView {
    var renderer: MatrixRainRenderer
    var renderSize: CGSize {
        didSet {
            renderer.resize(to: renderSize)
        }
    }
    private var displayLink: CVDisplayLink?
    
    init(renderer: MatrixRainRenderer, renderSize: CGSize) {
        self.renderer = renderer
        self.renderSize = renderSize
        super.init(frame: .zero)
        wantsLayer = true
        renderer.resize(to: renderSize)
        startDisplayLink()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopDisplayLink()
    }
    
    override var isFlipped: Bool { true }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Render at fixed resolution, then scale to fit view
        guard let image = renderer.renderFrame() else { return }
        
        // Calculate aspect-fit scaling
        let imageSize = CGSize(width: image.width, height: image.height)
        let viewSize = bounds.size
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (viewSize.width - scaledSize.width) / 2,
            y: (viewSize.height - scaledSize.height) / 2
        )
        
        // Draw black letterbox/pillarbox
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(bounds)
        
        // Flip context for correct image orientation (CGImage origin is bottom-left, view is flipped)
        context.saveGState()
        context.translateBy(x: 0, y: viewSize.height)
        context.scaleBy(x: 1, y: -1)
        
        // Adjust origin for flipped coordinates
        let flippedOrigin = CGPoint(x: origin.x, y: viewSize.height - origin.y - scaledSize.height)
        
        // Draw scaled image
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: flippedOrigin, size: scaledSize))
        context.restoreGState()
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
        renderer.resize(to: previewSize)
    }
    
    func reloadSettings() {
        renderer.settings = .fromMatrixSettings()
        renderer.reset()
    }
}
