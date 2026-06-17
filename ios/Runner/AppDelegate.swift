import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var audioEngine: AVAudioEngine?
  fileprivate var eventSink: FlutterEventSink?
  private let AUDIO_CHANNEL = "com.tuningvibes/audio"
  private let CONTROL_CHANNEL = "com.tuningvibes/control"
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    
    let audioChannel = FlutterEventChannel(name: AUDIO_CHANNEL, binaryMessenger: controller.binaryMessenger)
    audioChannel.setStreamHandler(AudioStreamHandler(delegate: self))
    
    let controlChannel = FlutterMethodChannel(name: CONTROL_CHANNEL, binaryMessenger: controller.binaryMessenger)
    controlChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "start" {
        let args = call.arguments as? [String: Any]
        let sampleRate = args?["sampleRate"] as? Double ?? 22050.0
        let success = self.startRecording(sampleRate: sampleRate)
        result(success)
      } else if call.method == "stop" {
        self.stopRecording()
        result(true)
      } else if call.method == "hasPermission" {
        let status = AVAudioSession.sharedInstance().recordPermission
        result(status == .granted)
      } else if call.method == "requestPermission" {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          result(granted)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func startRecording(sampleRate: Double) -> Bool {
    audioEngine = AVAudioEngine()
    guard let audioEngine = audioEngine else { return false }
    
    let inputNode = audioEngine.inputNode
    let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
    
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, time) in
      guard let channelData = buffer.floatChannelData else { return }
      let frameLength = Int(buffer.frameLength)
      var samples = [Double]()
      for i in 0..<frameLength {
        samples.append(Double(channelData[0][i]))
      }
      DispatchQueue.main.async {
        self.eventSink?(samples)
      }
    }
    
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
      try session.setActive(true)
      try audioEngine.start()
      return true
    } catch {
      return false
    }
  }
  
  private func stopRecording() {
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    audioEngine = nil
  }
}

class AudioStreamHandler: NSObject, FlutterStreamHandler {
  weak var delegate: AppDelegate?
  
  init(delegate: AppDelegate) {
    self.delegate = delegate
  }
  
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    delegate?.eventSink = events
    return nil
  }
  
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    delegate?.eventSink = nil
    return nil
  }
}
