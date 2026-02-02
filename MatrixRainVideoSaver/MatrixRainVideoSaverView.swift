import ScreenSaver
import AVFoundation
import OSLog

@objc(MatrixRainVideoSaverView)
final class MatrixRainVideoSaverView: ScreenSaverView {
    private let log = OSLog(subsystem: "com.matrixy.videosaver", category: "player")
    private var player: AVQueuePlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerLooper: AVPlayerLooper?

    override var isFlipped: Bool { true }

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 30.0
        setupPlayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1.0 / 30.0
        setupPlayer()
    }

    override func startAnimation() {
        super.startAnimation()
        player?.play()
        os_log("startAnimation", log: log, type: .info)
    }

    override func stopAnimation() {
        player?.pause()
        os_log("stopAnimation", log: log, type: .info)
        super.stopAnimation()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        playerLayer?.frame = bounds
    }

    private func setupPlayer() {
        guard let url = Bundle(for: MatrixRainVideoSaverView.self).url(forResource: "Loop", withExtension: "mp4") else {
            os_log("Loop.mp4 not found", log: log, type: .error)
            return
        }

        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(items: [])
        queue.actionAtItemEnd = .none
        let looper = AVPlayerLooper(player: queue, templateItem: item)

        let layer = AVPlayerLayer(player: queue)
        layer.frame = bounds
        layer.videoGravity = .resizeAspectFill
        wantsLayer = true
        self.layer?.addSublayer(layer)

        self.player = queue
        self.playerLayer = layer
        self.playerLooper = looper
    }
}
