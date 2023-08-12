import AVFoundation
import AVKit
import Foundation
import HaishinKit
import UIKit

final class PlaybackViewController: UIViewController {
    private static let maxRetryCount: Int = 5

    @IBOutlet private weak var playbackButton: UIButton!
    private var rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!
    private var retryCount: Int = 0
    private var pictureInPictureController: AVPictureInPictureController?

    override func viewDidLoad() {
        super.viewDidLoad()
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (view as? (any NetStreamDrawable))?.attachStream(rtmpStream)
        //to delete - testing
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    @IBAction func didEnterPixtureInPicture(_ button: UIButton) {
        print("new playback speed: 0.2")
        rtmpStream.setPlaybackSpeed(playbackSpeed: 0.2)
    }

    @IBAction func didPlaybackButtonTap(_ button: UIButton) {
        if button.isSelected {
            UIApplication.shared.isIdleTimerDisabled = false
            rtmpConnection.close()
            rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            button.setTitle("●", for: [])
        } else {
            UIApplication.shared.isIdleTimerDisabled = true
            rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            button.setTitle("■", for: [])
        }
        button.isSelected.toggle()
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data = e.data as? ASObject, let code = data["code"] as? String else {
            return
        }
        logger.info(code)
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            retryCount = 0
            rtmpStream.play(Preference.defaultInstance.streamName!)
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            guard retryCount <= PlaybackViewController.maxRetryCount else {
                return
            }
            Thread.sleep(forTimeInterval: pow(2.0, Double(retryCount)))
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            retryCount += 1
        default:
            break
        }
    }

    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
        logger.error(notification)
        rtmpConnection.connect(Preference.defaultInstance.uri!)
    }

    @objc
    private func didEnterBackground(_ notification: Notification) {
        logger.info(notification)
        rtmpStream.receiveVideo = false
    }

    @objc
    private func didBecomeActive(_ notification: Notification) {
        logger.info(notification)
        rtmpStream.receiveVideo = true
    }
}

extension PlaybackViewController: NetStreamDelegate {
    
    func stream(_ stream: NetStream, videoBufferSize: Double) {
        print("buffer size is: \(videoBufferSize)")
    }
    
    // MARK: NetStreamDelegate
    func stream(_ stream: NetStream, didOutput audio: AVAudioBuffer, presentationTimeStamp: CMTime) {
    }

    func stream(_ stream: NetStream, didOutput video: CMSampleBuffer) {
    }

    func stream(_ stream: NetStream, sessionWasInterrupted session: AVCaptureSession, reason: AVCaptureSession.InterruptionReason?) {
    }

    func stream(_ stream: NetStream, sessionInterruptionEnded session: AVCaptureSession) {
    }

    func stream(_ stream: NetStream, videoCodecErrorOccurred error: VideoCodec.Error) {
    }

    func stream(_ stream: NetStream, audioCodecErrorOccurred error: HaishinKit.AudioCodec.Error) {
    }

    func streamWillDropFrame(_ stream: NetStream) -> Bool {
        return false
    }

    func streamDidOpen(_ stream: NetStream) {
    }
}
