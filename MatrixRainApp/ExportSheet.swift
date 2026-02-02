import SwiftUI
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

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
        MatrixSettings.refreshFromDisk()
        let currentSettings = MatrixRainRenderer.Settings.fromMatrixSettings()
        let config = ExportConfig(
            resolution: selectedResolution.size,
            duration: duration,
            frameRate: frameRate,
            rendererSettings: currentSettings
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
                if let contents = try? fileManager.contentsOfDirectory(at: derivedDataPath, includingPropertiesForKeys: nil) {
                    for folder in contents where folder.lastPathComponent.hasPrefix("MatrixRain-") {
                        let potentialSaver = folder.appendingPathComponent("Build/Products/Debug/MatrixRainVideoSaver.saver")
                        if fileManager.fileExists(atPath: potentialSaver.path) {
                            sourceSaverURL = potentialSaver
                            break
                        }
                        let releaseSaver = folder.appendingPathComponent("Build/Products/Release/MatrixRainVideoSaver.saver")
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
                let contentsDir = saverBundlePath.appendingPathComponent("Contents")
                let macOSDir = contentsDir.appendingPathComponent("MacOS")
                let resourcesDir = contentsDir.appendingPathComponent("Resources")
                try fileManager.createDirectory(at: macOSDir, withIntermediateDirectories: true)
                try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
                // Copy the video
                let destVideoURL = resourcesDir.appendingPathComponent("Loop.mp4")
                try? fileManager.removeItem(at: destVideoURL)
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
                // Double-check video presence
                if !fileManager.fileExists(atPath: destVideoURL.path) {
                    exportManager.statusMessage = "Warning: Loop.mp4 missing from .saver!"
                } else if let attrs = try? fileManager.attributesOfItem(atPath: destVideoURL.path), let size = attrs[.size] as? NSNumber, size.intValue == 0 {
                    exportManager.statusMessage = "Warning: Loop.mp4 is zero bytes!"
                } else {
                    exportManager.statusMessage = "✓ Installed to Screen Savers"
                }
                return
            }

            // Copy the pre-built saver bundle
            try fileManager.copyItem(at: sourceSaverURL!, to: saverBundlePath)

            // Always overwrite the video in the bundle
            let resourcesDir = saverBundlePath.appendingPathComponent("Contents/Resources")
            if !fileManager.fileExists(atPath: resourcesDir.path) {
                try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
            }
            let destVideoURL = resourcesDir.appendingPathComponent("Loop.mp4")
            try? fileManager.removeItem(at: destVideoURL)
            try fileManager.copyItem(at: videoURL, to: destVideoURL)
            // Double-check video presence
            if !fileManager.fileExists(atPath: destVideoURL.path) {
                exportManager.statusMessage = "Warning: Loop.mp4 missing from .saver!"
            } else if let attrs = try? fileManager.attributesOfItem(atPath: destVideoURL.path), let size = attrs[.size] as? NSNumber, size.intValue == 0 {
                exportManager.statusMessage = "Warning: Loop.mp4 is zero bytes!"
            } else {
                exportManager.statusMessage = "✓ Installed to Screen Savers"
            }
        } catch {
            exportManager.errorMessage = "Install failed: \(error.localizedDescription)"
        }
    }
}

struct ExportConfig {
    let resolution: CGSize
    let duration: Double
    let frameRate: Int
    let rendererSettings: MatrixRainRenderer.Settings
    
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

        exportTask?.cancel()

        let updateStatus: @Sendable @MainActor (String) -> Void = { [weak self] message in
            self?.statusMessage = message
        }
        let updateProgress: @Sendable @MainActor (Double, String?) -> Void = { [weak self] progress, message in
            self?.progress = progress
            if let message {
                self?.statusMessage = message
            }
        }

        exportTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let videoURL = try await Task.detached(priority: .userInitiated) {
                    try await ExportManager.performExport(
                        config: config,
                        updateProgress: updateProgress,
                        updateStatus: updateStatus
                    )
                }.value
                await MainActor.run {
                    self.isComplete = true
                    self.statusMessage = "Export complete!"
                    self.isExporting = false
                    self.outputURL = videoURL
                    self.onComplete?(videoURL)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.statusMessage = "Cancelled"
                    self.isExporting = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isExporting = false
                }
            }
        }
    }
    
    func cancel() {
        exportTask?.cancel()
        isExporting = false
        statusMessage = "Cancelled"
    }
    
    nonisolated private static func performExport(
        config: ExportConfig,
        updateProgress: @Sendable @MainActor (Double, String?) -> Void,
        updateStatus: @Sendable @MainActor (String) -> Void
    ) async throws -> URL {
        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("MatrixLoop_\(UUID().uuidString).mp4")
        
        // Set up renderer with current settings
        let renderer = MatrixRainRenderer(settings: config.rendererSettings)
        renderer.resize(to: config.resolution)
        
        // Set up AVAssetWriter
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(config.resolution.width),
            AVVideoHeightKey: Int(config.resolution.height),
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 50_000_000, // 50 Mbps for high quality
            ] as [String: Any]
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(config.resolution.width),
                kCVPixelBufferHeightKey as String: Int(config.resolution.height),
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
        )
        
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // Wait for pixel buffer pool to be ready
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let frameDuration = CMTimeMake(value: 1, timescale: Int32(config.frameRate))
        let totalFrames = config.totalFrames
        
        await updateStatus("Rendering frames...")
        
        for frame in 0..<totalFrames {
            try Task.checkCancellation()
            
            // Update renderer simulation
            renderer.update()
            
            // Wait for writer to be ready
            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            // Create pixel buffer and draw directly into it
            guard let pixelBuffer = createPixelBuffer(
                renderer: renderer,
                size: config.resolution,
                adaptor: pixelBufferAdaptor
            ) else {
                throw ExportError.pixelBufferFailed
            }
            
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frame))
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            
            // Update progress on main thread periodically
            if frame % 10 == 0 {
                let currentProgress = Double(frame + 1) / Double(totalFrames)
                let currentFrame = frame + 1
                let message = currentFrame % config.frameRate == 0
                    ? "Rendering frame \(currentFrame)/\(totalFrames)..."
                    : nil
                await updateProgress(currentProgress, message)
            }
        }
        
        writerInput.markAsFinished()
        await writer.finishWriting()
        
        if writer.status == .failed {
            throw writer.error ?? ExportError.writerFailed
        }
        
        return videoURL
    }
    
    nonisolated private static func createPixelBuffer(
        renderer: MatrixRainRenderer,
        size: CGSize,
        adaptor: AVAssetWriterInputPixelBufferAdaptor
    ) -> CVPixelBuffer? {
        guard let pool = adaptor.pixelBufferPool else { return nil }
        
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        
        guard let buffer = pixelBuffer else { return nil }
        
        // Attach sRGB color space to the pixel buffer so HEVC encoder interprets colors correctly
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        CVBufferSetAttachment(buffer, kCVImageBufferCGColorSpaceKey, colorSpace, .shouldPropagate)
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        // Use premultipliedLast (RGBA) to match BGRA pixel buffer with little-endian byte order
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        // Match renderer's expected coordinate system (top-left origin)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        renderer.draw(in: context)
        
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
