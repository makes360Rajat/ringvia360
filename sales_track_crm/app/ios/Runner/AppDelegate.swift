import Flutter
import UIKit
import Contacts
import AVFoundation
import UserNotifications

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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TelemetryBridgePlugin") {
      TelemetryBridgePlugin.register(with: registrar)
    }
  }
}

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
      let clean = rawNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
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
      let clean = rawNumber.components(separatedBy: CharacterSet(charactersIn: "+0123456789").inverted).joined()
      DispatchQueue.main.async {
        if let url = URL(string: "tel://\(clean)") {
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
