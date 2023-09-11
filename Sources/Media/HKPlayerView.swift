//
//  HKPlayerView.swift
//  HaishinKit
//
//  Created by Mario Šutalo on 14.08.2023..
//  Copyright © 2023 Shogo Endo. All rights reserved.
//
#if os(iOS) || os(tvOS)
import Foundation
import UIKit
import AVFoundation

public class HKPlayerView: UIView {
    /// The view’s background color.
    public static var defaultBackgroundColor: UIColor = .lightGray

    /// Returns the class used to create the layer for instances of this class.
    override public class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }
    /// The view’s Core Animation layer used for rendering.
    override public var layer: AVSampleBufferDisplayLayer {
        super.layer as! AVSampleBufferDisplayLayer
    }

    /// A value that specifies how the video is displayed within a player layer’s bounds.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            layer.videoGravity = videoGravity
        }
    }

    /// A value that displays a video format.
    public var videoFormatDescription: CMVideoFormatDescription? {
        currentStream?.mixer.videoIO.formatDescription
    }

    #if !os(tvOS)
    public var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            if Thread.isMainThread {
                layer.flushAndRemoveImage()
            } else {
                DispatchQueue.main.sync {
                    layer.flushAndRemoveImage()
                }
            }
        }
    }
    #endif
    private var currentSampleBuffer: CMSampleBuffer?

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.drawable = nil
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Self.defaultBackgroundColor
        layer.backgroundColor = Self.defaultBackgroundColor.cgColor
        layer.videoGravity = videoGravity
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public func enqueueNextFrame(_ sampleBuffer: CMSampleBuffer?) {
        if Thread.isMainThread {
            currentSampleBuffer = sampleBuffer
            if let sampleBuffer = sampleBuffer {
                layer.enqueue(sampleBuffer)
            }
        } else {
            DispatchQueue.main.async {
                self.enqueue(sampleBuffer)
            }
        }
        
    }
    
}

extension HKPlayerView {

    public func enqueue(_ sampleBuffer: CMSampleBuffer?) {
        if Thread.isMainThread {
            currentSampleBuffer = sampleBuffer
            if let sampleBuffer = sampleBuffer {
                if layer.status == .failed {
                    layer.flushAndRemoveImage()
                }
                layer.enqueue(sampleBuffer)
            }
        } else {
            DispatchQueue.main.async {
                self.enqueue(sampleBuffer)
            }
        }
    }
}
#else

import AppKit
import AVFoundation

/// A view that displays a video content of a NetStream object which uses AVSampleBufferDisplayLayer api.
public class HKPlayerView: NSView {
    /// The view’s background color.
    public static var defaultBackgroundColor: NSColor = .black

    /// A value that specifies how the video is displayed within a player layer’s bounds.
    public var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            layer?.setValue(videoGravity, forKey: "videoGravity")
        }
    }

    /// A value that displays a video format.
    public var videoFormatDescription: CMVideoFormatDescription? {
        currentStream?.mixer.videoIO.formatDescription
    }

    public var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            if Thread.isMainThread {
                (layer as? AVSampleBufferDisplayLayer)?.flushAndRemoveImage()
            } else {
                DispatchQueue.main.sync {
                    (layer as? AVSampleBufferDisplayLayer)?.flushAndRemoveImage()
                }
            }
        }
    }

    private var currentSampleBuffer: CMSampleBuffer?

    private weak var currentStream: NetStream? {
        didSet {
            oldValue?.mixer.videoIO.drawable = nil
        }
    }

    /// Initializes and returns a newly allocated view object with the specified frame rectangle.
    override public init(frame: CGRect) {
        super.init(frame: frame)
        awakeFromNib()
    }

    /// Returns an object initialized from data in a given unarchiver.
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    /// Prepares the receiver for service after it has been loaded from an Interface Builder archive, or nib file.
    override public func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layer = AVSampleBufferDisplayLayer()
        layer?.backgroundColor = HKView.defaultBackgroundColor.cgColor
        layer?.setValue(videoGravity, forKey: "videoGravity")
    }
}

extension HKPlayerView {

    public func enqueue(_ sampleBuffer: CMSampleBuffer?) {
        if Thread.isMainThread {
            currentSampleBuffer = sampleBuffer
            if let sampleBuffer = sampleBuffer {
                (layer as? AVSampleBufferDisplayLayer)?.enqueue(sampleBuffer)
            }
        } else {
            DispatchQueue.main.async {
                self.enqueue(sampleBuffer)
            }
        }
    }
}

#endif

