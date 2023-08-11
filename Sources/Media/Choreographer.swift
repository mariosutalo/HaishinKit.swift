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
}

final class DisplayLinkChoreographer: NSObject, Choreographer {
    private static let duration = 0.0
    private static let preferredFramesPerSecond = 0
    let dequeuBufferQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.dequeueBufferQueue", qos: .userInteractive)
    var timer: DispatchSourceTimer!
    var poolingInterval: Double = 0.04166667
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
    
    
    func startRunning() {
        if isRunning.value == true {
            return
        }
        isRunning.mutate { $0 = true }
        dequeuBufferQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            while(self.isRunning.value == true) {
                if self.addInitialDelay {
                    Thread.sleep(forTimeInterval: self.initialDequeuDelaySeconds)
                    self.addInitialDelay = false
                }
                self.update()
                /*DispatchQueue.main.async(qos: .userInteractive) {
                    self.update()
                }*/
                Thread.sleep(forTimeInterval: self.poolingInterval)
            }
        }
        //isRunning.mutate { $0 = true }
        //displayLink = DisplayLink(target: self, selector: #selector(self.update(displayLink:)))
    }
    
    func startRunningv1() {
        if isRunning.value == true {
            return
        }
        isRunning.mutate { $0 = true }
        timer = DispatchSource.makeTimerSource(flags: .strict, queue: dequeuBufferQueue)
        timer.schedule(deadline: .now(), repeating:poolingInterval, leeway: .nanoseconds(0))
        timer.setEventHandler() { [weak self] in
            guard let self = self else {
                return
            }
            self.update()
        }
        timer.resume()
    }
    
    func stopRunning() {
        //displayLink = nil
        //duration = DisplayLinkChoreographer.duration
        isRunning.mutate { $0 = false }
        //timer.cancel()
        addInitialDelay = true
    }
}
