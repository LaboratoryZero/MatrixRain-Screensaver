import SwiftUI
import AVFoundation

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exportManager = ExportManager()
    
    // Export settings
    @State private var selectedResolution: Resolution = .uhd4K
    @State private var duration: Double = 60
    @State private var frameRate: Int = 60
    @State private var installAfterExport: Bool = true
    
    enum Resolution: String, CaseIterable {
        case hd720p = "720p"
        case hd1080p = "1080p"
        case qhd1440p = "1440p"
        case uhd4K = "4K"
        case uhd5K = "5K"
        case uhd6K = "6K"
        
        var size: CGSize {
            switch self {
            case .hd720p:    return CGSize(width: 1280, height: 720)
            case .hd1080p:   return CGSize(width: 1920, height: 1080)
            case .qhd1440p:  return CGSize(width: 2560, height: 1440)
            case .uhd4K:     return CGSize(width: 3840, height: 2160)
            case .uhd5K:     return CGSize(width: 5120, height: 2880)
            case .uhd6K:     return CGSize(width: 6016, height: 3384)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Video Saver")
                .font(.title)
            
            Form {
                Section("Video Settings") {
                    Picker("Resolution", selection: $selectedResolution) {
                        ForEach(Resolution.allCases, id: \.self) { res in
                            Text("\(res.rawValue) (\(Int(res.size.width))×\(Int(res.size.height)))")
                                .tag(res)
                        }
                    }
                    
                    LabeledContent("Duration") {
                        Slider(value: $duration, in: 10...300, step: 10)
                        Text("\(Int(duration))s")
                            .frame(width: 50)
                    }
                    
                    Picker("Frame Rate", selection: $frameRate) {
                        Text("30 fps").tag(30)
                        Text("60 fps").tag(60)
                        Text("120 fps").tag(120)
                    }
                }
                
                Section("Installation") {
                    Toggle("Install after export", isOn: $installAfterExport)
                    Text("Saver will be installed to ~/Library/Screen Savers/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Estimated") {
                    let totalFrames = Int(duration) * frameRate
                    let estimatedSizeMB = Double(totalFrames) * 0.15 // rough estimate
                    HStack {
                        Text("Frames: \(totalFrames)")
                        Spacer()
                        Text("Est. size: \(Int(estimatedSizeMB)) MB")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(width: 400, height: 280)
            
            if exportManager.isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: exportManager.progress, total: 1.0)
                    Text(exportManager.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            
            if let error = exportManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    if exportManager.isExporting {
                        exportManager.cancel()
                    }
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(exportManager.isExporting ? "Exporting..." : "Export") {
                    startExport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(exportManager.isExporting)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 500, height: 480)
    }
    
    private func startExport() {
        let config = ExportConfig(
            resolution: selectedResolution.size,
            duration: duration,
            frameRate: frameRate
        )
        exportManager.startExport(config: config) { [self] videoURL in
            if installAfterExport {
                Task {
                    await installSaver(videoURL: videoURL)
                }
            }
        }
    }
    
    private func installSaver(videoURL: URL) async {
        
        let fileManager = FileManager.default
        let screenSaversDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers")
        let saverBundlePath = screenSaversDir.appendingPathComponent("MatrixRain.saver")
        
        do {
            // Remove existing saver if present
            if fileManager.fileExists(atPath: saverBundlePath.path) {
                try fileManager.removeItem(at: saverBundlePath)
            }
            
            // Find the built video saver from Xcode's DerivedData
            // First try to find it relative to the app bundle
            var sourceSaverURL: URL?
            
            // Option 1: Look in the same Products directory as the app
            if let appBundlePath = Bundle.main.bundlePath as String? {
                let productsDir = URL(fileURLWithPath: appBundlePath).deletingLastPathComponent()
                let potentialSaver = productsDir.appendingPathComponent("MatrixRainVideoSaver.saver")
                if fileManager.fileExists(atPath: potentialSaver.path) {
                    sourceSaverURL = potentialSaver
                }
            }
            
            // Option 2: Search DerivedData for the saver
            if sourceSaverURL == nil {
                let derivedDataPath = fileManager.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Developer/Xcode/DerivedData")
                
                // Look for MatrixRain-* folders first
                if let contents = try? fileManager.contentsOfDirectory(at: derivedDataPath, includingPropertiesForKeys: nil) {
                    for folder in contents where folder.lastPathComponent.hasPrefix("MatrixRain-") {
                        let potentialSaver = folder
                            .appendingPathComponent("Build/Products/Debug/MatrixRainVideoSaver.saver")
                        if fileManager.fileExists(atPath: potentialSaver.path) {
                            sourceSaverURL = potentialSaver
                            break
                        }
                        // Also check Release
                        let releaseSaver = folder
                            .appendingPathComponent("Build/Products/Release/MatrixRainVideoSaver.saver")
                        if fileManager.fileExists(atPath: releaseSaver.path) {
                            sourceSaverURL = releaseSaver
                            break
                        }
                    }
                }
            }
            
            // Option 3: Build the saver on-the-fly if not found
            if sourceSaverURL == nil {
                exportManager.statusMessage = "Building saver bundle..."
                
                // Create a minimal saver bundle structure manually
                let contentsDir = saverBundlePath.appendingPathComponent("Contents")
                let macOSDir = contentsDir.appendingPathComponent("MacOS")
                let resourcesDir = contentsDir.appendingPathComponent("Resources")
                
                try fileManager.createDirectory(at: macOSDir, withIntermediateDirectories: true)
                try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
                
                // Copy the video
                let destVideoURL = resourcesDir.appendingPathComponent("Loop.mp4")
                try fileManager.copyItem(at: videoURL, to: destVideoURL)
                
                // Create Info.plist
                let infoPlist: [String: Any] = [
                    "CFBundleIdentifier": "com.matrixy.videosaver",
                    "CFBundleName": "MatrixRain",
                    "CFBundleDisplayName": "Matrix Rain",
                    "CFBundleVersion": "1.0",
                    "CFBundleShortVersionString": "1.0",
                    "CFBundlePackageType": "BNDL",
                    "CFBundleExecutable": "MatrixRainVideoSaver",
                    "NSPrincipalClass": "MatrixRainVideoSaverView",
                    "CFBundleInfoDictionaryVersion": "6.0",
                    "LSMinimumSystemVersion": "11.0"
                ]
                let plistData = try PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0)
                try plistData.write(to: contentsDir.appendingPathComponent("Info.plist"))
                
                // Try to find and copy the compiled binary
                let derivedDataPath = fileManager.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Developer/Xcode/DerivedData")
                
                let enumerator = fileManager.enumerator(at: derivedDataPath, includingPropertiesForKeys: nil)
                while let fileURL = enumerator?.nextObject() as? URL {
                    if fileURL.lastPathComponent == "MatrixRainVideoSaver.saver" && 
                       fileURL.path.contains("Build/Products") {
                        let binaryURL = fileURL.appendingPathComponent("Contents/MacOS/MatrixRainVideoSaver")
                        if fileManager.fileExists(atPath: binaryURL.path) {
                            try fileManager.copyItem(at: binaryURL, to: macOSDir.appendingPathComponent("MatrixRainVideoSaver"))
                            break
                        }
                    }
                }
                
                exportManager.statusMessage = "✓ Installed to Screen Savers"
                return
            }
            
            // Copy the pre-built saver bundle
            try fileManager.copyItem(at: sourceSaverURL!, to: saverBundlePath)
            
            // Create Resources directory if it doesn't exist
            let resourcesDir = saverBundlePath.appendingPathComponent("Contents/Resources")
            if !fileManager.fileExists(atPath: resourcesDir.path) {
                try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
            }
            
            // Inject the video into the copied bundle
            let destVideoURL = resourcesDir.appendingPathComponent("Loop.mp4")
            if fileManager.fileExists(atPath: destVideoURL.path) {
                try fileManager.removeItem(at: destVideoURL)
            }
            try fileManager.copyItem(at: videoURL, to: destVideoURL)
            
            exportManager.statusMessage = "✓ Installed to Screen Savers"
        } catch {
            exportManager.errorMessage = "Install failed: \(error.localizedDescription)"
        }
    }
}

struct ExportConfig {
    let resolution: CGSize
    let duration: Double
    let frameRate: Int
    
    var totalFrames: Int {
        Int(duration) * frameRate
    }
}

@MainActor
class ExportManager: ObservableObject {
    @Published var isExporting = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    @Published var errorMessage: String?
    @Published var isComplete = false
    @Published var outputURL: URL?
    
    private var exportTask: Task<Void, Never>?
    private var onComplete: ((URL) -> Void)?
    
    func startExport(config: ExportConfig, onComplete: @escaping (URL) -> Void) {
        isExporting = true
        isComplete = false
        progress = 0
        statusMessage = "Preparing..."
        errorMessage = nil
        self.onComplete = onComplete
        
        exportTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let videoURL = try await self?.performExport(config: config)
                await MainActor.run {
                    self?.isComplete = true
                    self?.statusMessage = "Export complete!"
                    self?.isExporting = false
                    if let url = videoURL {
                        self?.outputURL = url
                        self?.onComplete?(url)
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.statusMessage = "Cancelled"
                    self?.isExporting = false
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                    self?.isExporting = false
                }
            }
        }
    }
    
    func cancel() {
        exportTask?.cancel()
        isExporting = false
        statusMessage = "Cancelled"
    }
    
    nonisolated private func performExport(config: ExportConfig) async throws -> URL {
        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("MatrixLoop_\(UUID().uuidString).mp4")
        
        // Set up renderer with current settings
        let settings = MatrixRainRenderer.Settings.fromMatrixSettings()
        let renderer = MatrixRainRenderer(settings: settings)
        renderer.resize(to: config.resolution)
        
        // Set up AVAssetWriter
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(config.resolution.width),
            AVVideoHeightKey: Int(config.resolution.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 50_000_000, // 50 Mbps for high quality
            ] as [String: Any]
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(config.resolution.width),
                kCVPixelBufferHeightKey as String: Int(config.resolution.height)
            ]
        )
        
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // Wait for pixel buffer pool to be ready
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let frameDuration = CMTimeMake(value: 1, timescale: Int32(config.frameRate))
        let totalFrames = config.totalFrames
        
        await MainActor.run {
            statusMessage = "Rendering frames..."
        }
        
        for frame in 0..<totalFrames {
            try Task.checkCancellation()
            
            // Update renderer simulation
            renderer.update()
            
            // Render frame to CGImage
            guard let cgImage = renderer.renderFrame() else {
                throw ExportError.renderFailed
            }
            
            // Wait for writer to be ready
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            // Create pixel buffer from CGImage
            guard let pixelBuffer = createPixelBuffer(from: cgImage, size: config.resolution, adaptor: pixelBufferAdaptor) else {
                throw ExportError.pixelBufferFailed
            }
            
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frame))
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            
            // Update progress on main thread periodically
            if frame % 10 == 0 {
                let currentProgress = Double(frame + 1) / Double(totalFrames)
                let currentFrame = frame + 1
                await MainActor.run { [weak self] in
                    self?.progress = currentProgress
                    if currentFrame % config.frameRate == 0 {
                        self?.statusMessage = "Rendering frame \(currentFrame)/\(totalFrames)..."
                    }
                }
            }
        }
        
        writerInput.markAsFinished()
        await writer.finishWriting()
        
        if writer.status == .failed {
            throw writer.error ?? ExportError.writerFailed
        }
        
        return videoURL
    }
    
    nonisolated private func createPixelBuffer(from image: CGImage, size: CGSize, adaptor: AVAssetWriterInputPixelBufferAdaptor) -> CVPixelBuffer? {
        guard let pool = adaptor.pixelBufferPool else { return nil }
        
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        
        guard let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        
        context.draw(image, in: CGRect(origin: .zero, size: size))
        
        return buffer
    }
    
    enum ExportError: LocalizedError {
        case renderFailed
        case pixelBufferFailed
        case writerFailed
        
        var errorDescription: String? {
            switch self {
            case .renderFailed: return "Failed to render frame"
            case .pixelBufferFailed: return "Failed to create pixel buffer"
            case .writerFailed: return "Video writer failed"
            }
        }
    }
}
