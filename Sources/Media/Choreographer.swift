import Foundation

#if os(macOS)
#else
import QuartzCore
typealias DisplayLink = CADisplayLink
#endif

protocol ChoreographerDelegate: AnyObject {
    func choreographer(_ choreographer: any Choreographer, didFrame duration: Double)
}

protocol Choreographer: Running {
    var isPaused: Bool { get set }
    var frameDurationSeconds: Double { get set }
    var delegate: (any ChoreographerDelegate)? { get set }
    func clear()
    func setPlaybackSpeed(speed playbackSpeed: Double)
}

final class DisplayLinkChoreographer: NSObject, Choreographer {
    
    private static let duration = 0.0
    private static let preferredFramesPerSecond = 0
    // added code
    let dequeuBufferQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.dequeueBufferQueue", qos: .default)
    var dequeBufferThread: Thread!
    var playbackTimer: DispatchSourceTimer!
    // 24 fps
    var frameDurationSeconds: Double = 0.041 // same as 24 fps - initial framerate
    var dequeueBufferRateSeconds: Double = 1 / 24
    let timerIntervalSeconds: Double = 1 / 1000
    var lastTriggered = Date()
    // end added code
    
    var isPaused: Bool {
        get {
            displayLink?.isPaused ?? true
        }
        set {
            displayLink?.isPaused = newValue
        }
    }
    weak var delegate: (any ChoreographerDelegate)?
    var isRunning: Atomic<Bool> = .init(false)
    private var duration: Double = DisplayLinkChoreographer.duration
    private var displayLink: DisplayLink? {
        didSet {
            oldValue?.invalidate()
            guard let displayLink = displayLink else {
                return
            }
            displayLink.isPaused = true
            displayLink.preferredFramesPerSecond = Self.preferredFramesPerSecond
            displayLink.add(to: .main, forMode: .common)
        }
    }
    
    func clear() {
        duration = Self.duration
    }
    
    private func update() {
        delegate?.choreographer(self, didFrame: duration)
    }
}

extension DisplayLinkChoreographer: Running {
    
    func startRunning() {
        if isRunning.value == true {
            return
        }
        isRunning.mutate { $0 = true }
        initializeAndStartPlaybackTimer(speed: 1.0)
        logger.info("Playback timer started")
    }
    
    func stopRunning() {
        isRunning.mutate { $0 = false }
        guard let timer = playbackTimer else {
            return
        }
        if !timer.isCancelled {
            timer.cancel()
            logger.info("Playback timer canceled")
        }
    }
    
    func setPlaybackSpeed(speed playbackSpeed: Double) {
        dequeueBufferRateSeconds = frameDurationSeconds / playbackSpeed
    }
}

extension DisplayLinkChoreographer {

    func initializeAndStartPlaybackTimer(speed playbackSpeed: Double){
        playbackTimer = DispatchSource.makeTimerSource(flags: .strict, queue: dequeuBufferQueue)
        playbackTimer.schedule(deadline: .now(), repeating: timerIntervalSeconds, leeway: .milliseconds(1))
        playbackTimer.setEventHandler() { [weak self] in
            guard let self = self else {
                return
            }
            let currentTime = Date()
            let differenceInTime = currentTime.timeIntervalSince(self.lastTriggered)
            if differenceInTime >= self.dequeueBufferRateSeconds {
                self.update()
                self.lastTriggered = currentTime
            }
        }
        playbackTimer.resume()
    }
}
