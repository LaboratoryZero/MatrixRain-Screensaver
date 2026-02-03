import SwiftUI
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

private enum ExportResolution: String, CaseIterable, Identifiable {
    case p1080 = "1080p"
    case p4k = "4K"
    case p5k = "5K"
    
    var id: String { rawValue }
    
    var size: CGSize {
        switch self {
        case .p1080: return CGSize(width: 1920, height: 1080)
        case .p4k: return CGSize(width: 3840, height: 2160)
        case .p5k: return CGSize(width: 5120, height: 2880)
        }
    }
}

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exportManager = ExportManager()
    
    // Export settings
    @State private var exportResolution: ExportResolution = .p1080
    @State private var duration: Double = 60
    @State private var frameRate: Int = 60
    @State private var installAfterExport: Bool = true
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Video Saver")
                .font(.title)
            
            Form {
                Section("Video Settings") {
                    Picker("Resolution", selection: $exportResolution) {
                        ForEach(ExportResolution.allCases) { option in
                            Text(option.rawValue).tag(option)
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
                    let bitrateMbps = 40.0
                    let estimatedSizeMB = (bitrateMbps * duration / 8.0) * 1.03 // bitrate + container overhead
                    HStack {
                        Text("Frames: \(totalFrames)")
                        Spacer()
                        Text("Est. size: \(Int(estimatedSizeMB)) MB")
                    }
                    HStack {
                        Text("Bitrate: \(Int(bitrateMbps)) Mbps")
                        Spacer()
                        Text("Duration: \(Int(duration))s")
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
                Button(exportManager.isComplete ? "OK" : "Cancel") {
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
            resolution: exportResolution.size,
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
            // Ensure Screen Savers directory exists
            if !fileManager.fileExists(atPath: screenSaversDir.path) {
                try fileManager.createDirectory(at: screenSaversDir, withIntermediateDirectories: true)
            }
            
            // Remove existing saver if present
            if fileManager.fileExists(atPath: saverBundlePath.path) {
                try fileManager.removeItem(at: saverBundlePath)
            }

            // Find the built video saver - check multiple locations
            var sourceSaverURL: URL?

            // Option 1: Look for embedded saver in app's Resources (distributed builds)
            if let embeddedSaver = Bundle.main.url(forResource: "MatrixRainVideoSaver", withExtension: "saver") {
                sourceSaverURL = embeddedSaver
            }

            // Option 2: Look in the same Products directory as the app (Xcode builds)
            if sourceSaverURL == nil, let appBundlePath = Bundle.main.bundlePath as String? {
                let productsDir = URL(fileURLWithPath: appBundlePath).deletingLastPathComponent()
                let potentialSaver = productsDir.appendingPathComponent("MatrixRainVideoSaver.saver")
                if fileManager.fileExists(atPath: potentialSaver.path) {
                    sourceSaverURL = potentialSaver
                }
            }

            // Option 3: Search DerivedData for the saver (fallback for dev builds)
            if sourceSaverURL == nil {
                let derivedDataPath = fileManager.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Developer/Xcode/DerivedData")
                if let contents = try? fileManager.contentsOfDirectory(at: derivedDataPath, includingPropertiesForKeys: nil) {
                    for folder in contents where folder.lastPathComponent.hasPrefix("MatrixRain-") {
                        let releaseSaver = folder.appendingPathComponent("Build/Products/Release/MatrixRainVideoSaver.saver")
                        if fileManager.fileExists(atPath: releaseSaver.path) {
                            sourceSaverURL = releaseSaver
                            break
                        }
                        let debugSaver = folder.appendingPathComponent("Build/Products/Debug/MatrixRainVideoSaver.saver")
                        if fileManager.fileExists(atPath: debugSaver.path) {
                            sourceSaverURL = debugSaver
                            break
                        }
                    }
                }
            }

            guard let sourceSaverURL else {
                exportManager.errorMessage = "Saver bundle not found. Please rebuild the project in Xcode."
                return
            }

            // Copy the saver bundle
            try fileManager.copyItem(at: sourceSaverURL, to: saverBundlePath)

            // Ensure Resources directory exists in the copied saver
            let resourcesDir = saverBundlePath.appendingPathComponent("Contents/Resources")
            if !fileManager.fileExists(atPath: resourcesDir.path) {
                try fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
            }
            
            // Copy the exported video into the saver bundle
            let destVideoURL = resourcesDir.appendingPathComponent("Loop.mp4")
            try? fileManager.removeItem(at: destVideoURL)
            try fileManager.copyItem(at: videoURL, to: destVideoURL)
            
            // Verify installation
            if !fileManager.fileExists(atPath: destVideoURL.path) {
                exportManager.statusMessage = "Warning: Loop.mp4 missing from .saver!"
            } else if let attrs = try? fileManager.attributesOfItem(atPath: destVideoURL.path), 
                      let size = attrs[.size] as? NSNumber, size.intValue == 0 {
                exportManager.statusMessage = "Warning: Loop.mp4 is zero bytes!"
            } else {
                exportManager.statusMessage = "✓ Installed to Screen Savers"
            }
            
            // Also update system saver if it exists (from pkg install)
            let systemSaverPath = URL(fileURLWithPath: "/Library/Screen Savers/MatrixRain.saver")
            if fileManager.fileExists(atPath: systemSaverPath.path) {
                let systemResourcesDir = systemSaverPath.appendingPathComponent("Contents/Resources")
                let systemVideoURL = systemResourcesDir.appendingPathComponent("Loop.mp4")
                do {
                    // Create Resources dir if needed (pkg install may not have created it)
                    if !fileManager.fileExists(atPath: systemResourcesDir.path) {
                        try fileManager.createDirectory(at: systemResourcesDir, withIntermediateDirectories: true)
                    }
                    try? fileManager.removeItem(at: systemVideoURL)
                    try fileManager.copyItem(at: videoURL, to: systemVideoURL)
                    exportManager.statusMessage = "✓ Installed to Screen Savers (user & system)"
                } catch {
                    // System location may require admin privileges - that's okay, user location works
                    exportManager.statusMessage = "✓ Installed (system location needs admin)"
                }
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
        updateProgress: @escaping @Sendable @MainActor (Double, String?) -> Void,
        updateStatus: @escaping @Sendable @MainActor (String) -> Void
    ) async throws -> URL {
        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let videoURL = tempDir.appendingPathComponent("MatrixLoop_\(UUID().uuidString).mp4")
        
        await updateStatus("Preparing export...")
        
        // Set up AVAssetWriter
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(config.resolution.width),
            AVVideoHeightKey: Int(config.resolution.height),
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 40_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: config.frameRate,
                AVVideoMaxKeyFrameIntervalDurationKey: 1.0,
                AVVideoExpectedSourceFrameRateKey: config.frameRate,
                AVVideoAllowFrameReorderingKey: false,
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
        
        let totalFrames = config.totalFrames
        let frameDuration = CMTimeMake(value: 1, timescale: Int32(config.frameRate))
        let fixedDelta = 1.0 / Double(config.frameRate)
        let resolution = config.resolution
        let rendererSettings = config.rendererSettings
        
        await updateStatus("Rendering and encoding...")
        let progressHandler: @Sendable (Double, String?) -> Void = { progress, message in
            Task { await updateProgress(progress, message) }
        }
        
        // Single-pass: render and encode on dedicated queue using requestMediaDataWhenReady
        // This avoids async/await context switching and memory pressure from caching
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // High-priority dedicated queue for encoding
            let encodingQueue = DispatchQueue(label: "com.matrixy.encoding", qos: .userInitiated)
            
            // State holder for the closure
            final class ExportState: @unchecked Sendable {
                let renderer: MatrixRainRenderer
                var frameIndex = 0
                var hasFinished = false
                var pendingBuffer: CVPixelBuffer?
                
                init(settings: MatrixRainRenderer.Settings, resolution: CGSize) {
                    renderer = MatrixRainRenderer(settings: settings)
                    renderer.resize(to: resolution)
                }
            }
            let state = ExportState(settings: rendererSettings, resolution: resolution)
            
            writerInput.requestMediaDataWhenReady(on: encodingQueue) { [pixelBufferAdaptor, writerInput] in
                // Process frames synchronously while writer is ready
                while writerInput.isReadyForMoreMediaData && state.frameIndex < totalFrames {
                    if state.pendingBuffer == nil {
                        // Update simulation with fixed time step
                        state.renderer.update(fixedDelta: fixedDelta)
                        
                        // Render directly to pixel buffer
                        guard let pixelBuffer = Self.createPixelBuffer(
                            renderer: state.renderer,
                            size: resolution,
                            adaptor: pixelBufferAdaptor
                        ) else {
                            if !state.hasFinished {
                                state.hasFinished = true
                                continuation.resume(throwing: ExportError.pixelBufferFailed)
                            }
                            return
                        }
                        state.pendingBuffer = pixelBuffer
                    }
                    
                    guard let pending = state.pendingBuffer else { return }
                    let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(state.frameIndex))
                    let appended = pixelBufferAdaptor.append(pending, withPresentationTime: presentationTime)
                    
                    if appended {
                        state.pendingBuffer = nil
                        state.frameIndex += 1
                        if state.frameIndex % 10 == 0 {
                            let progress = Double(state.frameIndex) / Double(totalFrames)
                            progressHandler(progress, "Rendering frame \(state.frameIndex)/\(totalFrames)...")
                        }
                    } else {
                        // Writer not ready; retry this same frame later without advancing simulation.
                        return
                    }
                }
                
                // Done
                if state.frameIndex >= totalFrames && !state.hasFinished {
                    state.hasFinished = true
                    writerInput.markAsFinished()
                    continuation.resume()
                }
            }
        }
        
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
        
        // Attach sRGB color space to the pixel buffer so encoder interprets colors correctly
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
