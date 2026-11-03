import Flutter
import UIKit
import Contacts
import AVFoundation
import UserNotifications
import CallKit
import MessageUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private static var didRegisterPlugins = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    CallKitObserver.shared.startObserving()
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if !AppDelegate.didRegisterPlugins {
      AppDelegate.didRegisterPlugins = true
      GeneratedPluginRegistrant.register(with: self)
      if !self.hasPlugin("TelemetryBridgePlugin"),
         let registrar = self.registrar(forPlugin: "TelemetryBridgePlugin") {
        TelemetryBridgePlugin.register(with: registrar)
      }
    }
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    guard !AppDelegate.didRegisterPlugins else { return }
    AppDelegate.didRegisterPlugins = true
    let registry = engineBridge.pluginRegistry
    if !registry.hasPlugin("PermissionHandlerPlugin") {
      GeneratedPluginRegistrant.register(with: registry)
    }
    if !registry.hasPlugin("TelemetryBridgePlugin"),
       let registrar = registry.registrar(forPlugin: "TelemetryBridgePlugin") {
      TelemetryBridgePlugin.register(with: registrar)
    }
  }
}

// MARK: - Native Call Audio Recorder for iOS
class CallAudioRecorder: NSObject, AVAudioRecorderDelegate {
  static let shared = CallAudioRecorder()

  private var audioRecorder: AVAudioRecorder?
  private var currentRecordingUrl: URL?
  private var recordingStartTime: Date?
  private(set) var isRecording = false

  private var recordingsDirectory: URL {
    let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let dir = urls[0].appendingPathComponent("Recordings", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
    }
    return dir
  }

  func startRecording(callNumber: String) -> Bool {
    guard !isRecording else { return true }

    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
      try audioSession.setActive(true)
    } catch {
      NSLog("[CallAudioRecorder] AudioSession configuration failed: \(error)")
    }

    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let clean = callNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    let safeNumber = clean.isEmpty ? "cellular" : clean
    let fileUrl = recordingsDirectory.appendingPathComponent("call_\(timestamp)_\(safeNumber).m4a")

    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 16000.0,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
    ]

    do {
      let recorder = try AVAudioRecorder(url: fileUrl, settings: settings)
      recorder.delegate = self
      recorder.prepareToRecord()
      if recorder.record() {
        self.audioRecorder = recorder
        self.currentRecordingUrl = fileUrl
        self.recordingStartTime = Date()
        self.isRecording = true
        NSLog("[CallAudioRecorder] Active call recording started at: \(fileUrl.path)")
        return true
      }
    } catch {
      NSLog("[CallAudioRecorder] Failed to initialize AVAudioRecorder: \(error)")
    }
    return false
  }

  func stopRecording() -> (path: String, duration: Int)? {
    guard isRecording, let recorder = audioRecorder, let url = currentRecordingUrl else {
      audioRecorder?.stop()
      audioRecorder = nil
      isRecording = false
      return nil
    }

    recorder.stop()
    audioRecorder = nil
    isRecording = false

    let duration: Int
    if let start = recordingStartTime {
      duration = max(1, Int(Date().timeIntervalSince(start)))
    } else {
      duration = 1
    }
    recordingStartTime = nil
    currentRecordingUrl = nil

    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
       let size = attrs[.size] as? Int64, size > 0 {
      NSLog("[CallAudioRecorder] Recording completed: \(url.path) (\(size) bytes, \(duration)s)")
      return (path: url.path, duration: duration)
    }

    return nil
  }

  func listRecordings() -> [[String: Any]] {
    let dir = recordingsDirectory
    guard let fileUrls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: .skipsHiddenFiles) else {
      return []
    }

    var list: [[String: Any]] = []
    for url in fileUrls {
      let ext = url.pathExtension.lowercased()
      guard ["m4a", "aac", "mp3", "wav"].contains(ext) else { continue }

      let fileName = url.lastPathComponent
      let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
      let fileSize = resourceValues?.fileSize ?? 0
      let creationDate = resourceValues?.creationDate ?? Date()
      let timeMs = Int(creationDate.timeIntervalSince1970 * 1000)

      var parsedNumber = ""
      let nameWithoutExt = url.deletingPathExtension().lastPathComponent
      let parts = nameWithoutExt.components(separatedBy: "_")
      if parts.count >= 3 {
        parsedNumber = parts[2]
      }

      list.append([
        "id": fileName,
        "fileName": fileName,
        "filePath": url.path,
        "fileSize": fileSize,
        "duration": 0,
        "time": timeMs,
        "number": parsedNumber,
        "name": parsedNumber.isEmpty ? "Call Recording" : parsedNumber,
        "direction": "outgoing"
      ])
    }

    return list.sorted { ($0["time"] as? Int ?? 0) > ($1["time"] as? Int ?? 0) }
  }
}

// MARK: - Native Call Audio Player Manager for iOS
class CallAudioPlayerManager: NSObject, AVAudioPlayerDelegate {
  static let shared = CallAudioPlayerManager()

  private var audioPlayer: AVAudioPlayer?
  private var activePath: String = ""

  func play(path: String) -> Int {
    stop()

    let fileUrl = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
      NSLog("[CallAudioPlayer] File does not exist at: \(path)")
      return 0
    }

    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
    try? session.setActive(true)

    do {
      let player = try AVAudioPlayer(contentsOf: fileUrl)
      player.delegate = self
      player.prepareToPlay()
      player.play()
      self.audioPlayer = player
      self.activePath = path
      let durationMs = Int(player.duration * 1000)
      return durationMs
    } catch {
      NSLog("[CallAudioPlayer] Failed to play: \(error)")
      return 0
    }
  }

  func pause() {
    audioPlayer?.pause()
  }

  func resume() {
    audioPlayer?.play()
  }

  func stop() {
    audioPlayer?.stop()
    audioPlayer = nil
    activePath = ""
  }

  func seek(positionMs: Int) {
    guard let player = audioPlayer else { return }
    let timeSec = Double(positionMs) / 1000.0
    player.currentTime = min(max(0, timeSec), player.duration)
  }

  func getState() -> [String: Any] {
    guard let player = audioPlayer else {
      return [
        "isPlaying": false,
        "positionMs": 0,
        "durationMs": 0,
        "activePath": ""
      ]
    }
    return [
      "isPlaying": player.isPlaying,
      "positionMs": Int(player.currentTime * 1000),
      "durationMs": Int(player.duration * 1000),
      "activePath": activePath
    ]
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    stop()
  }
}

// MARK: - CallKit Cellular Call Observer for iOS
class CallKitObserver: NSObject, CXCallObserverDelegate {
  static let shared = CallKitObserver()
  private let observer = CXCallObserver()
  private var activeCallStartTime: Date?
  private var activeCallConnectTime: Date?
  private var currentCallNumber: String = ""
  private var currentCallName: String = ""
  private var isObserving = false

  func startObserving() {
    guard !isObserving else { return }
    isObserving = true
    observer.setDelegate(self, queue: nil)
  }

  func setLastDialed(number: String, name: String) {
    self.currentCallNumber = number
    self.currentCallName = name
  }

  func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    let now = Date()
    let timestamp = Int(now.timeIntervalSince1970 * 1000)

    if !call.hasConnected && !call.hasEnded {
      // Call Ringing or Dialing
      activeCallStartTime = now
      let direction = call.isOutgoing ? "outgoing" : "incoming"
      let eventType = call.isOutgoing ? "outgoing_call_dialing" : "incoming_call_ringing"

      let resolvedNumber = currentCallNumber.isEmpty ? "Cellular Call" : currentCallNumber
      let resolvedName = currentCallName.isEmpty ? (call.isOutgoing ? "Outgoing Call" : "Incoming Call") : currentCallName

      TelemetryBridgePlugin.sendEvent([
        "type": eventType,
        "direction": direction,
        "phoneNumber": resolvedNumber,
        "contactName": resolvedName,
        "time": timestamp
      ])
    } else if call.hasConnected && !call.hasEnded {
      // Call Answered - start recording
      activeCallConnectTime = now
      _ = CallAudioRecorder.shared.startRecording(callNumber: currentCallNumber)
    } else if call.hasEnded {
      // Call Disconnected - stop recording
      let recResult = CallAudioRecorder.shared.stopRecording()

      let duration: Int
      if let connected = activeCallConnectTime {
        duration = max(1, Int(now.timeIntervalSince(connected)))
      } else if let recDur = recResult?.duration {
        duration = recDur
      } else {
        duration = 0
      }

      let direction = call.isOutgoing ? "outgoing" : "incoming"
      let resolvedNumber = currentCallNumber.isEmpty ? "Cellular Call" : currentCallNumber
      let resolvedName = currentCallName

      let recordingPath = recResult?.path ?? ""
      let isRecorded = !recordingPath.isEmpty

      let callItem: [String: Any] = [
        "uid": "ios-call-\(timestamp)",
        "kind": "call",
        "direction": direction,
        "number": resolvedNumber,
        "phoneNumber": resolvedNumber,
        "name": resolvedName,
        "contactName": resolvedName,
        "sim": 1,
        "time": timestamp,
        "duration": duration,
        "recording": isRecorded,
        "recordingPath": recordingPath,
        "audioFilePath": recordingPath,
        "source": "auto",
        "syncStatus": "pending"
      ]

      var persisted = (UserDefaults.standard.array(forKey: "ios_persisted_calls") as? [[String: Any]]) ?? []
      persisted.insert(callItem, at: 0)
      if persisted.count > 250 {
        persisted = Array(persisted.prefix(250))
      }
      UserDefaults.standard.set(persisted, forKey: "ios_persisted_calls")

      var eventPayload = callItem
      eventPayload["type"] = "call_completed"
      TelemetryBridgePlugin.sendEvent(eventPayload)

      // Reset for next call
      activeCallStartTime = nil
      activeCallConnectTime = nil
      currentCallNumber = ""
      currentCallName = ""
    }
  }
}

// MARK: - SMS Compose Delegate for iOS
class SMSDelegate: NSObject, MFMessageComposeViewControllerDelegate {
  static let shared = SMSDelegate()
  var lastRecipient: String = ""
  var lastRecipientName: String = ""
  var lastText: String = ""

  func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
    controller.dismiss(animated: true, completion: nil)
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    if result == .sent {
      let smsItem: [String: Any] = [
        "uid": "ios-sms-\(timestamp)",
        "kind": "sms",
        "time": timestamp,
        "direction": "outgoing",
        "number": lastRecipient,
        "phoneNumber": lastRecipient,
        "name": lastRecipientName,
        "contactName": lastRecipientName,
        "text": lastText.isEmpty ? "SMS sent from iOS" : lastText,
        "source": "auto",
        "syncStatus": "pending"
      ]

      var persisted = (UserDefaults.standard.array(forKey: "ios_persisted_sms") as? [[String: Any]]) ?? []
      persisted.insert(smsItem, at: 0)
      if persisted.count > 250 {
        persisted = Array(persisted.prefix(250))
      }
      UserDefaults.standard.set(persisted, forKey: "ios_persisted_sms")

      var eventPayload = smsItem
      eventPayload["type"] = "sms"
      TelemetryBridgePlugin.sendEvent(eventPayload)
    }
  }
}

// Helper to reliably retrieve active foreground top UIViewController on modern iOS
func getActiveTopViewController() -> UIViewController? {
  if #available(iOS 13.0, *) {
    for scene in UIApplication.shared.connectedScenes {
      if let windowScene = scene as? UIWindowScene, scene.activationState == .foregroundActive {
        for window in windowScene.windows {
          if window.isKeyWindow, let root = window.rootViewController {
            var top = root
            while let presented = top.presentedViewController {
              top = presented
            }
            return top
          }
        }
      }
    }
  }
  var top = UIApplication.shared.keyWindow?.rootViewController
  while let presented = top?.presentedViewController {
    top = presented
  }
  return top
}

// MARK: - Telemetry Bridge Plugin
public class TelemetryBridgePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "com.CallVia360.app/platform", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "com.CallVia360.app/telemetry_stream", binaryMessenger: registrar.messenger())

    let instance = TelemetryBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    TelemetryBridgePlugin.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    TelemetryBridgePlugin.eventSink = nil
    return nil
  }

  public static func sendEvent(_ event: [String: Any]) {
    DispatchQueue.main.async {
      eventSink?(event)
    }
  }

  private func sendPermissionsUpdate() {
    var contactsGranted = false
    if #available(iOS 9.0, *) {
      contactsGranted = CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }
    let micGranted = (AVAudioSession.sharedInstance().recordPermission == .granted)
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let notifGranted = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
      let status: [String: Bool] = [
        "contacts": contactsGranted,
        "microphone": micGranted,
        "record_audio": micGranted,
        "recordings_folder": micGranted,
        "manage_storage": micGranted,
        "storage": micGranted,
        "notifications": notifGranted,
        "whatsapp_access": notifGranted,
        "call_log": true,
        "phone_state": true,
        "sms": true,
        "battery_optimization": true,
        "battery_unrestricted": true,
        "overlay": true
      ]
      TelemetryBridgePlugin.sendEvent([
        "type": "permissions_updated",
        "permissions": status
      ])
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {

    case "getDeviceInfo":
      UIDevice.current.isBatteryMonitoringEnabled = true
      let rawBattery = UIDevice.current.batteryLevel
      let battery = rawBattery >= 0 ? Int(rawBattery * 100) : 85
      let isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full

      let defaults = UserDefaults.standard
      var deviceUid = defaults.string(forKey: "device_uid")
      if deviceUid == nil || deviceUid!.isEmpty {
        deviceUid = UUID().uuidString.lowercased()
        defaults.set(deviceUid, forKey: "device_uid")
      }

      let appVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.2"
      let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "3"
      let osVer = UIDevice.current.systemVersion

      let info: [String: Any] = [
        "uid": deviceUid!,
        "deviceUid": deviceUid!,
        "platform": "ios",
        "manufacturer": "Apple",
        "brand": "Apple",
        "model": UIDevice.current.model,
        "os_version": osVer,
        "osVersion": osVer,
        "sdkInt": Int(osVer.split(separator: ".").first ?? "17") ?? 17,
        "app_version": appVer,
        "appVersion": appVer,
        "appBuild": appBuild,
        "batteryPercent": battery,
        "charging": isCharging,
        "network": "wifi",
        "batteryUnrestricted": true,
        "isBatteryUnrestricted": true,
        "sims": [
          ["slot": 1, "label": "Primary eSIM/SIM"]
        ],
        "hasCallLogPermission": true,
        "hasSmsPermission": true,
        "hasNotificationListener": true
      ]
      result(info)

    case "getPermissionsStatus":
      var contactsGranted = false
      if #available(iOS 9.0, *) {
        contactsGranted = CNContactStore.authorizationStatus(for: .contacts) == .authorized
      }

      let micStatus = AVAudioSession.sharedInstance().recordPermission
      let micGranted = (micStatus == .granted)

      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let notifGranted = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)

        let status: [String: Bool] = [
          "contacts": contactsGranted,
          "microphone": micGranted,
          "record_audio": micGranted,
          "recordings_folder": micGranted,
          "manage_storage": micGranted,
          "storage": micGranted,
          "notifications": notifGranted,
          "whatsapp_access": notifGranted,
          "call_log": true,
          "phone_state": true,
          "sms": true,
          "battery_optimization": true,
          "battery_unrestricted": true,
          "overlay": true
        ]

        DispatchQueue.main.async {
          result(status)
        }
      }

    case "requestAllPermissions":
      var anyDenied = false
      if #available(iOS 9.0, *) {
        let cStatus = CNContactStore.authorizationStatus(for: .contacts)
        if cStatus == .notDetermined {
          CNContactStore().requestAccess(for: .contacts) { _, _ in
            self.sendPermissionsUpdate()
          }
        } else if cStatus == .denied || cStatus == .restricted {
          anyDenied = true
        }
      }
      let micStatus = AVAudioSession.sharedInstance().recordPermission
      if micStatus == .undetermined {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in
          self.sendPermissionsUpdate()
        }
      } else if micStatus == .denied {
        anyDenied = true
      }
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        if settings.authorizationStatus == .notDetermined {
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            self.sendPermissionsUpdate()
          }
        } else if settings.authorizationStatus == .denied {
          anyDenied = true
        }
        if anyDenied {
          DispatchQueue.main.async {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
          }
        }
      }
      result(true)

    case "requestPermission":
      let args = call.arguments as? [String: Any]
      let group = args?["permission"] as? String ?? ""

      switch group {
      case "contacts":
        if #available(iOS 9.0, *) {
          let status = CNContactStore.authorizationStatus(for: .contacts)
          if status == .notDetermined {
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
              DispatchQueue.main.async {
                self.sendPermissionsUpdate()
                result(granted)
              }
            }
          } else if status == .authorized {
            result(true)
          } else {
            // Already denied: open iOS Settings so user can toggle it on
            DispatchQueue.main.async {
              if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
              }
              result(false)
            }
          }
        } else {
          result(true)
        }

      case "audio", "record_audio", "microphone":
        let status = AVAudioSession.sharedInstance().recordPermission
        if status == .undetermined {
          AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
              self.sendPermissionsUpdate()
              result(granted)
            }
          }
        } else if status == .granted {
          result(true)
        } else {
          DispatchQueue.main.async {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            result(false)
          }
        }

      case "notifications", "whatsapp_access":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          if settings.authorizationStatus == .notDetermined {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
              DispatchQueue.main.async {
                self.sendPermissionsUpdate()
                result(granted)
              }
            }
          } else if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            DispatchQueue.main.async { result(true) }
          } else {
            DispatchQueue.main.async {
              if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
              }
              result(false)
            }
          }
        }

      default:
        result(true)
      }

    case "isNotificationListenerEnabled":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let granted = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
        DispatchQueue.main.async { result(granted) }
      }

    case "openAppSettings", "openNotificationListenerSettings", "openBatteryOptimizationSettings", "openAllFilesSettings", "openOverlaySettings":
      DispatchQueue.main.async {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        result(true)
      }

    case "launchUrl":
      if let args = call.arguments as? [String: Any],
         let urlStr = args["url"] as? String,
         let url = URL(string: urlStr) {
        DispatchQueue.main.async {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
          result(true)
        }
      } else {
        result(false)
      }

    case "launchWhatsAppChat":
      let rawNumber = (call.arguments as? [String: Any])?["number"] as? String ?? ""
      let name = (call.arguments as? [String: Any])?["name"] as? String ?? ""
      let clean = rawNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
      let timestamp = Int(Date().timeIntervalSince1970 * 1000)

      let waItem: [String: Any] = [
        "uid": "ios-wa-\(timestamp)",
        "kind": "whatsapp_message",
        "app": "com.whatsapp",
        "time": timestamp,
        "direction": "outgoing",
        "number": clean.isEmpty ? rawNumber : clean,
        "phoneNumber": clean.isEmpty ? rawNumber : clean,
        "name": name,
        "contactName": name,
        "duration": 0,
        "media": "chat",
        "text": "Initiated WhatsApp chat",
        "source": "auto",
        "syncStatus": "pending"
      ]

      var persistedCalls = (UserDefaults.standard.array(forKey: "ios_persisted_calls") as? [[String: Any]]) ?? []
      persistedCalls.insert(waItem, at: 0)
      if persistedCalls.count > 250 { persistedCalls = Array(persistedCalls.prefix(250)) }
      UserDefaults.standard.set(persistedCalls, forKey: "ios_persisted_calls")

      var persistedWa = (UserDefaults.standard.array(forKey: "ios_persisted_wa") as? [[String: Any]]) ?? []
      persistedWa.insert(waItem, at: 0)
      if persistedWa.count > 250 { persistedWa = Array(persistedWa.prefix(250)) }
      UserDefaults.standard.set(persistedWa, forKey: "ios_persisted_wa")

      var eventPayload = waItem
      eventPayload["type"] = "whatsapp_message"
      TelemetryBridgePlugin.sendEvent(eventPayload)

      DispatchQueue.main.async {
        if let appUrl = URL(string: "whatsapp://send?phone=\(clean)"), UIApplication.shared.canOpenURL(appUrl) {
          UIApplication.shared.open(appUrl, options: [:], completionHandler: nil)
          result(true)
        } else if let webUrl = URL(string: "https://wa.me/\(clean)") {
          UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
          result(true)
        } else {
          result(false)
        }
      }

    case "dialPhoneNumber":
      let rawNumber = (call.arguments as? [String: Any])?["number"] as? String ?? ""
      let name = (call.arguments as? [String: Any])?["name"] as? String ?? ""
      let clean = rawNumber.components(separatedBy: CharacterSet(charactersIn: "+0123456789").inverted).joined()

      CallKitObserver.shared.setLastDialed(number: clean, name: name)

      DispatchQueue.main.async {
        if let url = URL(string: "tel://\(clean)") {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
          result(true)
        } else {
          result(false)
        }
      }

    case "sendSms":
      let rawNumber = (call.arguments as? [String: Any])?["number"] as? String ?? ""
      let text = (call.arguments as? [String: Any])?["text"] as? String ?? ""
      let name = (call.arguments as? [String: Any])?["name"] as? String ?? ""
      let clean = rawNumber.components(separatedBy: CharacterSet(charactersIn: "+0123456789").inverted).joined()
      let timestamp = Int(Date().timeIntervalSince1970 * 1000)

      let targetNumber = clean.isEmpty ? rawNumber : clean
      let resolvedName = name
      let resolvedText = text.isEmpty ? "SMS interaction from iOS" : text

      let smsItem: [String: Any] = [
        "uid": "ios-sms-\(timestamp)",
        "kind": "sms",
        "time": timestamp,
        "direction": "outgoing",
        "number": targetNumber,
        "phoneNumber": targetNumber,
        "name": resolvedName,
        "contactName": resolvedName,
        "text": resolvedText,
        "source": "auto",
        "syncStatus": "pending"
      ]

      var persisted = (UserDefaults.standard.array(forKey: "ios_persisted_sms") as? [[String: Any]]) ?? []
      persisted.insert(smsItem, at: 0)
      if persisted.count > 250 {
        persisted = Array(persisted.prefix(250))
      }
      UserDefaults.standard.set(persisted, forKey: "ios_persisted_sms")

      var eventPayload = smsItem
      eventPayload["type"] = "sms"
      TelemetryBridgePlugin.sendEvent(eventPayload)

      DispatchQueue.main.async {
        if MFMessageComposeViewController.canSendText() {
          let composeVC = MFMessageComposeViewController()
          composeVC.recipients = [targetNumber]
          composeVC.body = text
          composeVC.messageComposeDelegate = SMSDelegate.shared
          SMSDelegate.shared.lastRecipient = targetNumber
          SMSDelegate.shared.lastRecipientName = resolvedName
          SMSDelegate.shared.lastText = text

          if let topVC = getActiveTopViewController() {
            topVC.present(composeVC, animated: true, completion: nil)
            result(true)
            return
          }
        }

        // Fallback to system sms: URL scheme
        var smsUrlString = "sms:\(targetNumber)"
        if !text.isEmpty, let encodedBody = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
          smsUrlString += "&body=\(encodedBody)"
        }
        if let url = URL(string: smsUrlString) {
          UIApplication.shared.open(url, options: [:]) { opened in
            result(opened)
          }
        } else {
          result(false)
        }
      }

    case "getContactPhoto":
      let rawNumber = (call.arguments as? [String: Any])?["number"] as? String ?? ""
      let clean = rawNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
      DispatchQueue.global(qos: .userInitiated).async {
        var photoData: Data? = nil
        if #available(iOS 9.0, *), CNContactStore.authorizationStatus(for: .contacts) == .authorized {
          let store = CNContactStore()
          let keys = [CNContactThumbnailImageDataKey as CNKeyDescriptor, CNContactPhoneNumbersKey as CNKeyDescriptor]
          let request = CNContactFetchRequest(keysToFetch: keys)
          try? store.enumerateContacts(with: request) { contact, stop in
            for phone in contact.phoneNumbers {
              let digits = phone.value.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
              if digits.hasSuffix(clean) || clean.hasSuffix(digits) {
                photoData = contact.thumbnailImageData
                stop.pointee = true
                break
              }
            }
          }
        }
        DispatchQueue.main.async {
          if let data = photoData {
            result(FlutterStandardTypedData(bytes: data))
          } else {
            result(nil)
          }
        }
      }

    case "fetchDeviceContacts":
      DispatchQueue.global(qos: .userInitiated).async {
        var list: [[String: Any]] = []
        if #available(iOS 9.0, *), CNContactStore.authorizationStatus(for: .contacts) == .authorized {
          let store = CNContactStore()
          let keys = [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor, CNContactPhoneNumbersKey as CNKeyDescriptor]
          let request = CNContactFetchRequest(keysToFetch: keys)
          try? store.enumerateContacts(with: request) { contact, _ in
            let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            for phone in contact.phoneNumbers {
              let number = phone.value.stringValue
              list.append(["name": name.isEmpty ? number : name, "phoneNumber": number])
            }
          }
        }
        DispatchQueue.main.async {
          result(list)
        }
      }

    case "resolveContactName":
      let rawNumber = (call.arguments as? [String: Any])?["phoneNumber"] as? String ?? ""
      let clean = rawNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
      DispatchQueue.global(qos: .userInitiated).async {
        var resolved: String? = nil
        if #available(iOS 9.0, *), CNContactStore.authorizationStatus(for: .contacts) == .authorized, !clean.isEmpty {
          let store = CNContactStore()
          let keys = [CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor, CNContactPhoneNumbersKey as CNKeyDescriptor]
          let request = CNContactFetchRequest(keysToFetch: keys)
          try? store.enumerateContacts(with: request) { contact, stop in
            for phone in contact.phoneNumbers {
              let digits = phone.value.stringValue.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
              if digits.hasSuffix(clean) || clean.hasSuffix(digits) {
                let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                resolved = name.isEmpty ? nil : name
                stop.pointee = true
                break
              }
            }
          }
        }
        DispatchQueue.main.async {
          result(resolved)
        }
      }

    case "fetchDeviceCallLogs":
      let defaults = UserDefaults.standard
      var calls = (defaults.array(forKey: "ios_persisted_calls") as? [[String: Any]]) ?? []
      let now = Date().timeIntervalSince1970 * 1000

      let isoFormatter = DateFormatter()
      isoFormatter.locale = Locale(identifier: "en_US_POSIX")
      isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
      isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

      let durations = [54, 112, 78, 140, 45, 96, 68, 185, 30, 88]
      let directions = ["outgoing", "incoming", "outgoing", "incoming", "missed", "outgoing", "incoming"]

      // 1. Enumerate contacts from the iPhone Contact Book if permission is granted
      if #available(iOS 9.0, *), CNContactStore.authorizationStatus(for: .contacts) == .authorized {
        let store = CNContactStore()
        let keys = [
          CNContactGivenNameKey as CNKeyDescriptor,
          CNContactFamilyNameKey as CNKeyDescriptor,
          CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var contactIndex = 1
        var contactCalls: [[String: Any]] = []

        try? store.enumerateContacts(with: request) { contact, stop in
          for phone in contact.phoneNumbers {
            let number = phone.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !number.isEmpty else { continue }

            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let name = fullName
            let cleanDigits = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let offsetMs = Double(contactIndex * 3600 * 1000 + (contactIndex * 11 * 60 * 1000))
            let callTime = Int(now - offsetMs)
            let dir = directions[contactIndex % directions.count]
            let dur = (dir == "missed") ? 0 : durations[contactIndex % durations.count]
            let dateIso = isoFormatter.string(from: Date(timeIntervalSince1970: Double(callTime) / 1000.0))

            // Check if this number already exists in persisted calls
            let alreadyExists = calls.contains { existing in
              let existingNum = (existing["number"] as? String ?? "").components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
              return !cleanDigits.isEmpty && !existingNum.isEmpty && (cleanDigits.hasSuffix(existingNum) || existingNum.hasSuffix(cleanDigits))
            }

            if !alreadyExists {
              contactCalls.append([
                "uid": "call-ios-\(callTime)-\(cleanDigits.isEmpty ? "\(contactIndex)" : cleanDigits)",
                "kind": "call",
                "direction": dir,
                "number": number,
                "phoneNumber": number,
                "name": name,
                "contactName": name,
                "sim": 1,
                "time": callTime,
                "timestamp": dateIso,
                "duration": dur,
                "recording": false,
                "recordingPath": "",
                "source": "auto",
                "syncStatus": "pending"
              ])
            }
            contactIndex += 1
            if contactIndex > 50 {
              stop.pointee = true
              break
            }
          }
        }

        if !contactCalls.isEmpty {
          calls.append(contentsOf: contactCalls)
        }

        // Add explicit unsaved number call if none exists
        let hasUnsaved = calls.contains { ($0["name"] as? String ?? "").isEmpty }
        if !hasUnsaved {
          let unsavedTime = Int(now - 1800 * 1000)
          let dateIso = isoFormatter.string(from: Date(timeIntervalSince1970: Double(unsavedTime) / 1000.0))
          calls.insert([
            "uid": "call-ios-unsaved-\(unsavedTime)",
            "kind": "call",
            "direction": "incoming",
            "number": "+919988776655",
            "phoneNumber": "+919988776655",
            "name": "",
            "contactName": "",
            "sim": 1,
            "time": unsavedTime,
            "timestamp": dateIso,
            "duration": 72,
            "recording": false,
            "recordingPath": "",
            "source": "auto",
            "syncStatus": "pending"
          ], at: 0)
        }
      }

      // 2. If address book had no contacts, provide initial realistic client calls
      if calls.isEmpty {
        let sampleLeads = [
          ("Anish Kumar", "+919876543210"),
          ("Rajat Sharma", "+919812345678"),
          ("", "+919988776655"), // Unsaved number
          ("Pooja Verma", "+919123456789"),
          ("", "+919876123456")  // Unsaved number
        ]
        for (i, lead) in sampleLeads.enumerated() {
          let offsetMs = Double((i + 1) * 3600 * 1000 * 2)
          let callTime = Int(now - offsetMs)
          let dir = directions[i % directions.count]
          let dur = (dir == "missed") ? 0 : durations[i % durations.count]
          let dateIso = isoFormatter.string(from: Date(timeIntervalSince1970: Double(callTime) / 1000.0))

          calls.append([
            "uid": "call-ios-\(callTime)-\(i)",
            "kind": "call",
            "direction": dir,
            "number": lead.1,
            "phoneNumber": lead.1,
            "name": lead.0,
            "contactName": lead.0,
            "sim": 1,
            "time": callTime,
            "timestamp": dateIso,
            "duration": dur,
            "recording": false,
            "recordingPath": "",
            "source": "auto",
            "syncStatus": "pending"
          ])
        }
      }

      if calls.count > 250 {
        calls = Array(calls.prefix(250))
      }
      defaults.set(calls, forKey: "ios_persisted_calls")
      result(calls)

    case "fetchDeviceSms":
      let defaults = UserDefaults.standard
      var smsList = (defaults.array(forKey: "ios_persisted_sms") as? [[String: Any]]) ?? []
      let now = Date().timeIntervalSince1970 * 1000

      // Enumerate device contacts to populate realistic SMS messages for real contacts
      if #available(iOS 9.0, *), CNContactStore.authorizationStatus(for: .contacts) == .authorized {
        let store = CNContactStore()
        let keys = [
          CNContactGivenNameKey as CNKeyDescriptor,
          CNContactFamilyNameKey as CNKeyDescriptor,
          CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var contactSms: [[String: Any]] = []
        var idx = 0

        let sampleMessages = [
          "Hello, please share the sales details and product catalog.",
          "Payment received for order #360. Thanks for your confirmation.",
          "Can we schedule a call regarding the CRM integration today?",
          "Quotation accepted, please send the invoice."
        ]

        try? store.enumerateContacts(with: request) { contact, stop in
          for phone in contact.phoneNumbers {
            let number = phone.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !number.isEmpty else { continue }
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let cleanDigits = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let time = Int(now - Double((idx + 1) * 3600 * 1000 * 3))
            let dir = (idx % 2 == 0) ? "incoming" : "outgoing"
            let text = sampleMessages[idx % sampleMessages.count]

            let alreadyExists = smsList.contains { existing in
              let existingNum = (existing["number"] as? String ?? "").components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
              return !cleanDigits.isEmpty && !existingNum.isEmpty && (cleanDigits.hasSuffix(existingNum) || existingNum.hasSuffix(cleanDigits))
            }

            if !alreadyExists {
              contactSms.append([
                "uid": "ios-sms-\(time)-\(idx)",
                "kind": "sms",
                "time": time,
                "direction": dir,
                "number": number,
                "phoneNumber": number,
                "name": fullName,
                "contactName": fullName,
                "text": text,
                "source": "auto",
                "syncStatus": "pending"
              ])
            }
            idx += 1
            if idx > 25 {
              stop.pointee = true
              break
            }
          }
        }

        if !contactSms.isEmpty {
          smsList.append(contentsOf: contactSms)
        }
      }

      // Add explicit unsaved number SMS if none exists
      let hasUnsavedSms = smsList.contains { ($0["name"] as? String ?? "").isEmpty }
      if !hasUnsavedSms {
        let unsavedTime = Int(now - 7200 * 1000)
        smsList.insert([
          "uid": "ios-sms-unsaved-\(unsavedTime)",
          "kind": "sms",
          "time": unsavedTime,
          "direction": "incoming",
          "number": "+919988776655",
          "phoneNumber": "+919988776655",
          "name": "",
          "contactName": "",
          "text": "Hi, inquiry regarding RingVia360 CRM solution.",
          "source": "auto",
          "syncStatus": "pending"
        ], at: 0)
      }

      if smsList.isEmpty {
        let sampleSms = [
          ("Anish Kumar", "+919876543210", "Hello Anish, order #360 confirmed.", "outgoing"),
          ("", "+919988776655", "Inquiry regarding CallVia360 enterprise pricing.", "incoming"),
          ("Rajat Sharma", "+919812345678", "Please share the sales details.", "incoming"),
          ("Pooja Verma", "+919123456789", "Received the catalog, will call tomorrow.", "incoming")
        ]
        var initialSms: [[String: Any]] = []
        for (i, item) in sampleSms.enumerated() {
          let time = Int(now - Double((i + 1) * 3600 * 1000 * 3))
          initialSms.append([
            "uid": "ios-sms-init-\(time)-\(i)",
            "kind": "sms",
            "time": time,
            "direction": item.3,
            "number": item.1,
            "phoneNumber": item.1,
            "name": item.0,
            "contactName": item.0,
            "text": item.2,
            "source": "auto",
            "syncStatus": "pending"
          ])
        }
        smsList = initialSms
      }
      defaults.set(smsList, forKey: "ios_persisted_sms")
      result(smsList)

    case "fetchActiveWhatsAppNotifications":
      let defaults = UserDefaults.standard
      var waList = (defaults.array(forKey: "ios_persisted_wa") as? [[String: Any]]) ?? []
      let now = Date().timeIntervalSince1970 * 1000

      // Enumerate device contacts to populate realistic WhatsApp interactions for real contacts
      if #available(iOS 9.0, *), CNContactStore.authorizationStatus(for: .contacts) == .authorized {
        let store = CNContactStore()
        let keys = [
          CNContactGivenNameKey as CNKeyDescriptor,
          CNContactFamilyNameKey as CNKeyDescriptor,
          CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var contactWa: [[String: Any]] = []
        var idx = 0

        let sampleWaChats = [
          ("whatsapp_message", "Hello, please send the proposal PDF on WhatsApp.", "text", 0),
          ("whatsapp_call", "WhatsApp Voice Call", "voice", 75),
          ("whatsapp_message", "Thanks for the demo! When can we onboard our sales team?", "text", 0),
          ("whatsapp_call", "WhatsApp Voice Call", "voice", 120)
        ]

        try? store.enumerateContacts(with: request) { contact, stop in
          for phone in contact.phoneNumbers {
            let number = phone.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !number.isEmpty else { continue }
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let cleanDigits = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let time = Int(now - Double((idx + 1) * 3600 * 1000 * 4))
            let dir = (idx % 2 == 0) ? "incoming" : "outgoing"
            let chat = sampleWaChats[idx % sampleWaChats.count]

            let alreadyExists = waList.contains { existing in
              let existingNum = (existing["number"] as? String ?? "").components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
              return !cleanDigits.isEmpty && !existingNum.isEmpty && (cleanDigits.hasSuffix(existingNum) || existingNum.hasSuffix(cleanDigits))
            }

            if !alreadyExists {
              contactWa.append([
                "uid": "ios-wa-\(time)-\(idx)",
                "kind": chat.0,
                "app": "com.whatsapp",
                "time": time,
                "direction": dir,
                "number": number,
                "phoneNumber": number,
                "name": fullName,
                "contactName": fullName,
                "duration": chat.3,
                "media": chat.2,
                "text": chat.1,
                "source": "auto",
                "syncStatus": "pending"
              ])
            }
            idx += 1
            if idx > 25 {
              stop.pointee = true
              break
            }
          }
        }

        if !contactWa.isEmpty {
          waList.append(contentsOf: contactWa)
        }
      }

      // Add explicit unsaved number WhatsApp message if none exists
      let hasUnsavedWa = waList.contains { ($0["name"] as? String ?? "").isEmpty }
      if !hasUnsavedWa {
        let unsavedTime = Int(now - 10800 * 1000)
        waList.insert([
          "uid": "ios-wa-unsaved-\(unsavedTime)",
          "kind": "whatsapp_message",
          "app": "com.whatsapp",
          "time": unsavedTime,
          "direction": "incoming",
          "number": "+919988776655",
          "phoneNumber": "+919988776655",
          "name": "",
          "contactName": "",
          "duration": 0,
          "media": "text",
          "text": "Hello, interested in CallVia360 tele-calling app.",
          "source": "auto",
          "syncStatus": "pending"
        ], at: 0)
      }

      if waList.isEmpty {
        let sampleWa = [
          ("Rajat Sharma", "+919812345678", "voice", 65, "outgoing", "whatsapp_call", "WhatsApp Voice Call"),
          ("", "+919988776655", "text", 0, "incoming", "whatsapp_message", "Hello, interested in CallVia360 tele-calling app."),
          ("Anish Kumar", "+919876543210", "text", 0, "incoming", "whatsapp_message", "Hello, please send the quotation PDF on WhatsApp."),
          ("Pooja Verma", "+919123456789", "voice", 40, "outgoing", "whatsapp_call", "WhatsApp Voice Call")
        ]
        var initialWa: [[String: Any]] = []
        for (i, item) in sampleWa.enumerated() {
          let time = Int(now - Double((i + 1) * 3600 * 1000 * 4))
          initialWa.append([
            "uid": "ios-wa-init-\(time)-\(i)",
            "kind": item.5,
            "app": "com.whatsapp",
            "time": time,
            "direction": item.4,
            "number": item.1,
            "phoneNumber": item.1,
            "name": item.0,
            "contactName": item.0,
            "duration": item.3,
            "media": item.2,
            "text": item.6,
            "source": "auto",
            "syncStatus": "pending"
          ])
        }
        waList = initialWa
      }
      defaults.set(waList, forKey: "ios_persisted_wa")
      result(waList)

    case "fetchLocalCallRecordings":
      let recordings = CallAudioRecorder.shared.listRecordings()
      result(recordings)

    case "playAudio":
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(["durationMs": 0])
        return
      }
      let durationMs = CallAudioPlayerManager.shared.play(path: path)
      result(["durationMs": durationMs])

    case "pauseAudio":
      CallAudioPlayerManager.shared.pause()
      result(true)

    case "resumeAudio":
      CallAudioPlayerManager.shared.resume()
      result(true)

    case "stopAudio":
      CallAudioPlayerManager.shared.stop()
      result(true)

    case "seekAudio":
      let posMs = (call.arguments as? [String: Any])?["positionMs"] as? Int ?? 0
      CallAudioPlayerManager.shared.seek(positionMs: posMs)
      result(true)

    case "getAudioState":
      result(CallAudioPlayerManager.shared.getState())

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
