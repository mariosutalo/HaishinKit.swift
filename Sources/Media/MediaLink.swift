import AVFoundation

#if canImport(SwiftPMSupport)
import SwiftPMSupport
#endif


protocol MediaLinkDelegate: AnyObject {
    func mediaLink(_ mediaLink: MediaLink, dequeue sampleBuffer: CMSampleBuffer)
    func mediaLink(_ mediaLink: MediaLink, _ isBuffering: Bool)
    func mediaLink(_ mediaLink: MediaLink, bufferSize bufferSizeSec: Double)
    func mediaLink(_ mediaLind: MediaLink, frameRate: Double)
}

final class MediaLink {
    // added code
    enum Constants {
        // on player start, wait 1 seconds for buffer to fill, then start dequeing buffer
        static let initialBufferSizeForDequeue = 1.0
        // minimum buffer size for dequeue
        static let bufferSizeForDequeue = 0.0
        // minimum buffer size for dequeue after player is buffering, doesnt start dequeing until this values
        static let bufferSizeForDequeueAfterBuffering = 0.6
        // send isBuffering signal to delegate when buffer is this value or lower
        static let startBufferingBufferSize = 0.2
        // maximum buffer size, when this size is exceeded, buffer is dequeued to initial buffer size
        static let maxBufferSize = 3.0
    }
    // end added code
    
    private static let bufferTime = 0.2
    private static let bufferingTime = 0.0

    var isPaused = false /*{
                          didSet {
                          guard isPaused != oldValue else {
                          return
                          }
                          choreographer.isPaused = isPaused
                          nstry({
                          if self.isPaused {
                          self.playerNode.pause()
                          } else {
                          self.playerNode.play()
                          }
                          }, { exeption in
                          logger.warn(exeption)
                          })
                          }
                          }*/
    var hasVideo = false
    var bufferTime = MediaLink.bufferTime
    weak var delegate: (any MediaLinkDelegate)?
    private(set) lazy var playerNode = AVAudioPlayerNode()
    private(set) var isRunning: Atomic<Bool> = .init(false)
    private var isBuffering = true {
        didSet {
            if !isBuffering {
                bufferingTime = 0.0
            }
            isPaused = isBuffering
            //delegate?.mediaLink(self, isBuffering)
        }
    }
    // added code
    private var dequeueVideo = false
    private var minimumBufferSizeForDequeue = Constants.initialBufferSizeForDequeue
    private var isVideoBuffering = true {
        willSet {
            if isVideoBuffering != newValue {
                if newValue {
                    minimumBufferSizeForDequeue = Constants.bufferSizeForDequeueAfterBuffering
                }
                bufferInfoQueue.async {[weak self] in
                    guard let self = self else {
                        return
                    }
                    self.delegate?.mediaLink(self, newValue)
                }
            }
        }
    }
    // end added code
    private var bufferingTime = MediaLink.bufferingTime
    private lazy var choreographer: any Choreographer = {
        var choreographer = DisplayLinkChoreographer()
        choreographer.delegate = self
        return choreographer
    }()
    private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.DisplayLinkedQueue.lock")
    private var bufferQueue: CMBufferQueue?
    private var scheduledAudioBuffers: Atomic<Int> = .init(0)
    private var lastPresentationTimeStamp: CMTime = .invalid
    // added code
    public var bufferSize: Double {
        bufferQueue?.duration.seconds ?? 0
    }
    let bufferInfoQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.BufferQueue")
    // end added code
    
    func enqueueVideo(_ buffer: CMSampleBuffer) {
        guard buffer.presentationTimeStamp != .invalid else {
            return
        }
        if lastPresentationTimeStamp == .invalid {
            choreographer.frameDurationSeconds = buffer.presentationTimeStamp.seconds
        } else {
            let difference = buffer.presentationTimeStamp.seconds - lastPresentationTimeStamp.seconds
            delegate?.mediaLink(self, frameRate: 1 / difference)
            choreographer.frameDurationSeconds = difference
        }
        lastPresentationTimeStamp = buffer.presentationTimeStamp

        guard let bufferQueue = bufferQueue else {
            return
        }
        
        CMBufferQueueEnqueue(bufferQueue, buffer: buffer)
        let bufferQueueDuration = bufferQueue.duration.seconds
        delegate?.mediaLink(self, bufferSize: bufferQueueDuration)
        if !dequeueVideo && bufferQueueDuration >= Constants.initialBufferSizeForDequeue {
            dequeueVideo = true
        }
        if !dequeueVideo {
            return
        }
        isVideoBuffering = bufferQueueDuration <= Constants.startBufferingBufferSize
        if bufferQueueDuration > Constants.bufferSizeForDequeueAfterBuffering {
            minimumBufferSizeForDequeue = Constants.bufferSizeForDequeue
        }
    }
    
    func enqueueAudio(_ buffer: AVAudioPCMBuffer) {
        /*
         nstry({
         self.scheduledAudioBuffers.mutate { $0 += 1 }
         self.playerNode.scheduleBuffer(buffer, completionHandler: self.didAVAudioNodeCompletion)
         if !self.hasVideo && !self.playerNode.isPlaying && 10 <= self.scheduledAudioBuffers.value {
         self.playerNode.play()
         }
         }, { exeption in
         logger.warn(exeption)
         })*/
    }
    
    private func duration(_ duraiton: Double) -> Double {
        if playerNode.isPlaying {
            guard let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
                return 0.0
            }
            return TimeInterval(playerTime.sampleTime) / playerTime.sampleRate
        }
        return duraiton
    }
    
    private func didAVAudioNodeCompletion() {
        scheduledAudioBuffers.mutate {
            $0 -= 1
            if $0 == 0 {
                isBuffering = true
            }
        }
    }
    
    private func removeTimestampFromBuffer (_ sampleBuffer: CMSampleBuffer) {
        let attachments: CFArray! = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true)
        let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
        let key = Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque()
        let value = Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
        CFDictionarySetValue(dictionary, key, value)
    }
    
    private func makeBufferkQueue() {
        CMBufferQueueCreate(
            allocator: kCFAllocatorDefault,
            capacity: 1024,
            callbacks: CMBufferQueueGetCallbacksForSampleBuffersSortedByOutputPTS(),
            queueOut: &bufferQueue
        )
    }
}

extension MediaLink: ChoreographerDelegate {

    func choreographer(_ choreographer: any Choreographer, didFrame duration: Double) {
        guard let bufferQueue else {
            return
        }
        if bufferSize < minimumBufferSizeForDequeue {
            return
        }
        if bufferSize > Constants.maxBufferSize {
            while bufferSize > Constants.initialBufferSizeForDequeue {
                CMBufferQueueDequeue(bufferQueue)
            }
        }
        guard let head = CMBufferQueueGetHead(bufferQueue) else {
            return
        }
        let first = head as! CMSampleBuffer
        CMBufferQueueDequeue(bufferQueue)
        removeTimestampFromBuffer(first)
        delegate?.mediaLink(self, dequeue: first)
    }
}

extension MediaLink: Running {
    // MARK: Running
    func startRunning() {
        lockQueue.async {
            guard !self.isRunning.value else {
                return
            }
            self.hasVideo = false
            self.bufferingTime = Self.bufferingTime
            self.isBuffering = true
            self.minimumBufferSizeForDequeue = Constants.initialBufferSizeForDequeue
            self.dequeueVideo = false
            self.choreographer.startRunning()
            self.makeBufferkQueue()
            self.isRunning.mutate { $0 = true }
        }
    }
    
    func stopRunning() {
        lockQueue.async {
            guard self.isRunning.value else {
                return
            }
            self.choreographer.stopRunning()
            do {
                try self.bufferQueue?.reset()
            } catch {
                logger.error("Buffer queue reset error")
            }
            self.bufferQueue = nil
            self.scheduledAudioBuffers.mutate { $0 = 0 }
            self.lastPresentationTimeStamp = .invalid
            self.isRunning.mutate { $0 = false }
        }
    }
}

extension MediaLink {
    var playbackChoreographer: Choreographer {
        return choreographer
    }
}
