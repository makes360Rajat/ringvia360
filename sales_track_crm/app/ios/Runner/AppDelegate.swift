import Flutter
import UIKit
import Contacts
import AVFoundation
import UserNotifications
import CallKit
import MessageUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "TelemetryBridgePlugin") {
      TelemetryBridgePlugin.register(with: registrar)
    }
    CallKitObserver.shared.startObserving()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TelemetryBridgePlugin") {
      TelemetryBridgePlugin.register(with: registrar)
    }
    CallKitObserver.shared.startObserving()
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
      // Call Answered
      activeCallConnectTime = now
    } else if call.hasEnded {
      // Call Disconnected
      let duration: Int
      if let connected = activeCallConnectTime {
        duration = max(1, Int(now.timeIntervalSince(connected)))
      } else {
        duration = 0
      }

      let direction = call.isOutgoing ? "outgoing" : "incoming"
      let resolvedNumber = currentCallNumber.isEmpty ? "Cellular Call" : currentCallNumber
      let resolvedName = currentCallName.isEmpty ? (call.isOutgoing ? "Outgoing Client" : "Incoming Client") : currentCallName

      TelemetryBridgePlugin.sendEvent([
        "type": "call_completed",
        "uid": "ios-call-\(timestamp)",
        "kind": "call",
        "time": timestamp,
        "direction": direction,
        "number": resolvedNumber,
        "name": resolvedName,
        "duration": duration,
        "recording": false,
        "source": "auto"
      ])

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
    if result == .sent {
      let timestamp = Int(Date().timeIntervalSince1970 * 1000)
      TelemetryBridgePlugin.sendEvent([
        "type": "sms",
        "uid": "ios-sms-\(timestamp)",
        "kind": "sms",
        "time": timestamp,
        "direction": "outgoing",
        "number": lastRecipient,
        "name": lastRecipientName.isEmpty ? "SMS Contact" : lastRecipientName,
        "text": lastText.isEmpty ? "SMS interaction sent from iOS" : lastText,
        "source": "auto"
      ])
    }
  }
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

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {

    case "getDeviceInfo":
      UIDevice.current.isBatteryMonitoringEnabled = true
      let rawBattery = UIDevice.current.batteryLevel
      let battery = rawBattery >= 0 ? Int(rawBattery * 100) : 85

      let defaults = UserDefaults.standard
      var deviceUid = defaults.string(forKey: "device_uid")
      if deviceUid == nil || deviceUid!.isEmpty {
        deviceUid = UUID().uuidString.lowercased()
        defaults.set(deviceUid, forKey: "device_uid")
      }

      let info: [String: Any] = [
        "deviceUid": deviceUid!,
        "model": UIDevice.current.model,
        "manufacturer": "Apple",
        "brand": "Apple",
        "osVersion": UIDevice.current.systemVersion,
        "sdkInt": Int(UIDevice.current.systemVersion.split(separator: ".").first ?? "17") ?? 17,
        "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.2",
        "appBuild": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "3",
        "batteryPercent": battery,
        "isBatteryUnrestricted": true,
        "networkType": "wifi",
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
      if #available(iOS 9.0, *) {
        if CNContactStore.authorizationStatus(for: .contacts) == .notDetermined {
          CNContactStore().requestAccess(for: .contacts) { _, _ in }
        }
      }
      if AVAudioSession.sharedInstance().recordPermission == .undetermined {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
      }
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        if settings.authorizationStatus == .notDetermined {
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
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
              DispatchQueue.main.async { result(granted) }
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
            DispatchQueue.main.async { result(granted) }
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
              DispatchQueue.main.async { result(granted) }
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
      let name = (call.arguments as? [String: Any])?["name"] as? String ?? "WhatsApp Contact"
      let clean = rawNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
      let timestamp = Int(Date().timeIntervalSince1970 * 1000)

      // Emit real-time WhatsApp interaction event!
      TelemetryBridgePlugin.sendEvent([
        "type": "whatsapp_message",
        "uid": "ios-wa-\(timestamp)",
        "kind": "whatsapp_message",
        "time": timestamp,
        "direction": "outgoing",
        "number": clean.isEmpty ? rawNumber : clean,
        "name": name,
        "text": "Initiated WhatsApp interaction",
        "source": "auto"
      ])

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
      let name = (call.arguments as? [String: Any])?["name"] as? String ?? "Client"
      let clean = rawNumber.components(separatedBy: CharacterSet(charactersIn: "+0123456789").inverted).joined()

      DispatchQueue.main.async {
        if MFMessageComposeViewController.canSendText() {
          let composeVC = MFMessageComposeViewController()
          composeVC.recipients = [clean]
          composeVC.body = text
          composeVC.messageComposeDelegate = SMSDelegate.shared
          SMSDelegate.shared.lastRecipient = clean
          SMSDelegate.shared.lastRecipientName = name
          SMSDelegate.shared.lastText = text

          if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            rootVC.present(composeVC, animated: true, completion: nil)
            result(true)
          } else {
            result(false)
          }
        } else if let url = URL(string: "sms:\(clean)") {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
          result(true)
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

    case "pauseAudio", "resumeAudio", "stopAudio", "seekAudio":
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
