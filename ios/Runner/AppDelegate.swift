import UIKit
import Flutter
import AVFoundation
import UserNotifications
import AudioToolbox

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var methodChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        // 延迟初始化，避免启动时崩溃
        DispatchQueue.main.async { [weak self] in
            self?.setupMethodChannel()
            self?.requestAllPermissions()
        }
        
        return result
    }
    
    private func setupMethodChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }
        
        methodChannel = FlutterMethodChannel(
            name: "com.example.slept_well/screen_wake",
            binaryMessenger: controller.binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "wakeUpScreen":
                self?.wakeUpScreen()
                result(true)
            case "releaseWakeLock":
                result(true)
            case "checkPermissions":
                self?.checkPermissions(result: result)
            case "openAppSettings":
                self?.openAppSettings()
                result(true)
            case "openBatterySettings", "openOverlaySettings":
                self?.openAppSettings()
                result(true)
            case "canDrawOverlays", "requestBatteryOptimization":
                result(true)
            case "showAlarmNotification":
                self?.showAlarmNotification()
                result(true)
            case "cancelNotification":
                self?.cancelNotification()
                result(true)
            case "vibrate":
                self?.vibrate()
                result(true)
            case "configureAudioForPlayback":
                self?.configureAudioSessionForPlayback()
                result(true)
            case "configureAudioForRecording":
                self?.configureAudioSessionForRecording()
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // 启动时申请所有权限
    private func requestAllPermissions() {
        // 1. 申请通知权限
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("通知权限: \(granted), error: \(String(describing: error))")
        }
        center.delegate = self
        
        // 2. 申请麦克风权限
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("麦克风权限: \(granted)")
            if granted {
                // 权限获取后配置音频会话
                DispatchQueue.main.async { [weak self] in
                    self?.configureAudioSession()
                }
            }
        }
    }
    
    private func wakeUpScreen() {
        vibrate()
        showAlarmNotification()
    }
    
    private func checkPermissions(result: @escaping FlutterResult) {
        var permissions: [String: Bool] = [
            "batteryOptimization": true,
            "overlay": true
        ]
        
        permissions["microphone"] = AVAudioSession.sharedInstance().recordPermission == .granted
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            permissions["notification"] = settings.authorizationStatus == .authorized
            DispatchQueue.main.async {
                result(permissions)
            }
        }
    }
    
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func showAlarmNotification() {
        let content = UNMutableNotificationContent()
        content.title = "检测到持续打鼾"
        content.body = "请调整睡姿缓解呼吸不畅"
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "snore_alarm", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    private func cancelNotification() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    private func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord, 
                mode: .default, 
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try audioSession.setActive(true)
            try audioSession.overrideOutputAudioPort(.speaker)
        } catch {
            print("音频会话配置失败: \(error)")
        }
    }
    
    private func configureAudioSessionForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // 使用纯播放模式，获得最大音量
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
            // 强制使用扬声器输出
            try audioSession.overrideOutputAudioPort(.speaker)
            print("已切换到扬声器播放模式")
        } catch {
            print("播放音频会话配置失败: \(error)")
        }
    }
    
    private func configureAudioSessionForRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord, 
                mode: .default, 
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("录音音频会话配置失败: \(error)")
        }
    }
    
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier == "snore_alarm" {
            methodChannel?.invokeMethod("onAlarmNotificationTapped", arguments: nil)
        }
        completionHandler()
    }
}