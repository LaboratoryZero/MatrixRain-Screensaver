import AVFoundation
import OSLog

struct MatrixRainExportSettings {
    var width: Int
    var height: Int
    var fps: Int
    var durationSeconds: Int
    var outputURL: URL
}

final class MatrixRainExporter {
    private let log = OSLog(subsystem: "com.matrixy.renderer", category: "export")

    func renderAndExport(settings: MatrixRainExportSettings, renderFrame: (Int) -> CGImage?) throws {
        let frameCount = settings.fps * settings.durationSeconds
        os_log("export start (%{public}@x%{public}@ fps=%{public}@ duration=%{public}@)", log: log, type: .info,
               String(settings.width), String(settings.height), String(settings.fps), String(settings.durationSeconds))

        let writer = try AVAssetWriter(outputURL: settings.outputURL, fileType: .mp4)
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: settings.width,
            AVVideoHeightKey: settings.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: settings.width,
            kCVPixelBufferHeightKey as String: settings.height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)

        guard writer.canAdd(input) else {
            throw NSError(domain: "MatrixRainExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot add writer input"])
        }
        writer.add(input)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(settings.fps))
        var frameTime = CMTime.zero
        var frameIndex = 0

        while frameIndex < frameCount {
            autoreleasepool {
                guard input.isReadyForMoreMediaData else { return }
                guard let image = renderFrame(frameIndex),
                      let pixelBuffer = Self.makePixelBuffer(from: image, width: settings.width, height: settings.height) else {
                    return
                }

                adaptor.append(pixelBuffer, withPresentationTime: frameTime)
                frameTime = frameTime + frameDuration
                frameIndex += 1
            }
        }

        input.markAsFinished()
        writer.finishWriting {
            os_log("export finished status=%{public}@", log: self.log, type: .info, String(describing: writer.status))
        }
    }

    private static func makePixelBuffer(from image: CGImage, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                         kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
