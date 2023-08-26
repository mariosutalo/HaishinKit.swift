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
    var delegate: (any ChoreographerDelegate)? { get set }
    func clear()
    func setPlaybackSpeed(speed playbackSpeed: Double)
}

final class DisplayLinkChoreographer: NSObject, Choreographer {
    private static let duration = 0.0
    private static let preferredFramesPerSecond = 0
    let dequeuBufferQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.dequeueBufferQueue", qos: .userInteractive)
    var dequeBufferThread: Thread!
    var playbackTimer: DispatchSourceTimer!
    // 24 frames per second
    let fps: Double = 24
    var addInitialDelay: Bool = true
    var initialDequeuDelaySeconds: Double = 0.5
    
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
    
    /*@objc
     private func update(displayLink: DisplayLink) {
     delegate?.choreographer(self, didFrame: duration)
     duration += displayLink.duration
     }*/
    
    private func update() {
        delegate?.choreographer(self, didFrame: duration)
    }
}

extension DisplayLinkChoreographer: Running {
    
    
    /*func startRunning() {
        if isRunning.value == true {
            return
        }
        isRunning.mutate { $0 = true }
        dequeBufferThread = Thread() { [weak self] in

            while(self?.isRunning.value == true) {
                guard let self = self else {
                    return
                }
                if self.addInitialDelay == true {
                    Thread.sleep(forTimeInterval: self.initialDequeuDelaySeconds)
                    self.addInitialDelay = false
                }
                self.update()
                Thread.sleep(forTimeInterval: self.poolingInterval)
            }
        }
        dequeBufferThread.qualityOfService = .userInteractive
        dequeBufferThread.start()
     //isRunning.mutate { $0 = true }
     //displayLink = DisplayLink(target: self, selector: #selector(self.update(displayLink:)))
    }*/
    
    func startRunning() {
        if isRunning.value == true {
            return
        }
        isRunning.mutate { $0 = true }
        initializeAndStartPlaybackTimer(speed: 1.0)
    }
    
    func stopRunning() {
        //displayLink = nil
        //duration = DisplayLinkChoreographer.duration
        isRunning.mutate { $0 = false }
        guard let timer = playbackTimer else {
            return
        }
        if !timer.isCancelled {
            timer.cancel()
        }
    }
    
    func setPlaybackSpeed(speed playbackSpeed: Double) {
        guard let timer = playbackTimer else {
            return
        }
        if !timer.isCancelled {
            timer.cancel()
        }
        initializeAndStartPlaybackTimer(speed: playbackSpeed)
    }
}

extension DisplayLinkChoreographer {

    func initializeAndStartPlaybackTimer(speed playbackSpeed: Double){
        let poolingInterval = 1 / (fps * playbackSpeed)
        playbackTimer = DispatchSource.makeTimerSource(flags: .strict, queue: dequeuBufferQueue)
        playbackTimer.schedule(deadline: .now(), repeating: poolingInterval, leeway: .nanoseconds(0))
        playbackTimer.setEventHandler() { [weak self] in
            guard let self = self else {
                return
            }
            DispatchQueue.main.async {
                self.update()
            }
        }
        playbackTimer.resume()
    }
}
