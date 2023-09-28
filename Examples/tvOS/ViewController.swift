import HaishinKit
import AVFAudio
import CoreMedia
import UIKit

final class ViewController: UIViewController {
    @IBOutlet private weak var lfView: MTHKView!
    @IBOutlet weak var pipHKView: PiPHKView!
    
    var rtmpConnection = RTMPConnection()
    var rtmpStream: RTMPStream!

    override func viewDidLoad() {
        super.viewDidLoad()
        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.delegate = self
        rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
        rtmpConnection.connect(Preference.defaultInstance.uri!)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //lfView?.attachStream(rtmpStream)
    }

    @objc
    func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)

        guard
            let data: ASObject = e.data as? ASObject,
            let code: String = data["code"] as? String else {
            return
        }

        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            rtmpStream!.play(Preference.defaultInstance.streamName)
        default:
            break
        }
    }
}

extension ViewController : NetStreamDelegate {
    func stream(_ stream: HaishinKit.NetStream, videoBufferSize: Double) {
        
    }
    
    func stream(_ stream: HaishinKit.NetStream, isVideoBuffering: Bool) {
        
    }
    
    func stream(_ strem: HaishinKit.NetStream, frameRate: Double) {
        
    }
    
    func stream(_ stream: HaishinKit.NetStream, didOutput audio: AVAudioBuffer, presentationTimeStamp: CMTime) {
        
    }
    
    func stream(_ stream: HaishinKit.NetStream, didOutput video: CMSampleBuffer) {
        pipHKView.enqueue(video)
    }
    
    func stream(_ stream: HaishinKit.NetStream, videoCodecErrorOccurred error: HaishinKit.VideoCodec.Error) {
        
    }
    
    func stream(_ stream: HaishinKit.NetStream, audioCodecErrorOccurred error: HaishinKit.AudioCodec.Error) {
        
    }
    
    func streamWillDropFrame(_ stream: HaishinKit.NetStream) -> Bool {
        return true
    }
    
    func streamDidOpen(_ stream: HaishinKit.NetStream) {
        
    }
    
    
}
