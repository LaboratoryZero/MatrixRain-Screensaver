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
        // Seek to start and play to ensure video is ready
        player?.seek(to: .zero) { [weak self] _ in
            self?.player?.play()
        }
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

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        // Optimize for smooth playback
        item.preferredForwardBufferDuration = 5.0 // Buffer 5 seconds ahead
        
        let queue = AVQueuePlayer(items: [])
        queue.actionAtItemEnd = .none
        queue.automaticallyWaitsToMinimizeStalling = true
        
        // Start playing immediately so first frame is ready
        queue.play()
        
        let looper = AVPlayerLooper(player: queue, templateItem: item)

        // Setup layer-backed view with player layer
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        
        let playerLyr = AVPlayerLayer(player: queue)
        playerLyr.frame = bounds
        playerLyr.videoGravity = .resizeAspectFill
        playerLyr.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(playerLyr)

        self.player = queue
        self.playerLayer = playerLyr
        self.playerLooper = looper
        
        os_log("Player setup complete, bounds: %{public}@", log: log, type: .info, String(describing: bounds))
    }
}
