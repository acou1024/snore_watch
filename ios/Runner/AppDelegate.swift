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
        // 1. 注册Flutter插件（必须最先调用）
        GeneratedPluginRegistrant.register(with: self)
        
        // 2. 调用父类方法
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        // 3. 延迟初始化其他功能，避免启动时崩溃
        DispatchQueue.main.async { [weak self] in
            self?.setupMethodChannel()
            self?.requestNotificationPermission()
            self?.configureAudioSession()
        }
        
        return result
    }
    
    // 设置Flutter MethodChannel
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
                // iOS不需要释放WakeLock，直接返回成功
                result(true)
                
            case "checkPermissions":
                self?.checkPermissions(result: result)
                
            case "openAppSettings":
                self?.openAppSettings()
                result(true)
                
            case "openBatterySettings":
                // iOS没有电池优化设置，打开应用设置
                self?.openAppSettings()
                result(true)
                
            case "openOverlaySettings":
                // iOS没有悬浮窗设置，打开应用设置
                self?.openAppSettings()
                result(true)
                
            case "canDrawOverlays":
                // iOS不需要悬浮窗权限
                result(true)
                
            case "requestBatteryOptimization":
                // iOS不需要电池优化豁免
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
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // 请求通知权限
    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ iOS通知权限已授权")
            } else {
                print("❌ iOS通知权限被拒绝: \(error?.localizedDescription ?? "未知错误")")
            }
        }
        center.delegate = self
    }
    
    // 唤醒屏幕 - iOS通过发送通知来提醒用户
    private func wakeUpScreen() {
        // 1. 震动
        vibrate()
        
        // 2. 发送本地通知
        showAlarmNotification()
        
        print("✅ iOS唤醒提醒已发送")
    }
    
    // 检查权限状态
    private func checkPermissions(result: @escaping FlutterResult) {
        var permissions: [String: Bool] = [:]
        
        // iOS不需要电池优化和悬浮窗权限，直接返回true
        permissions["batteryOptimization"] = true
        permissions["overlay"] = true
        
        // 检查麦克风权限
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            permissions["microphone"] = true
        default:
            permissions["microphone"] = false
        }
        
        // 检查通知权限
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            permissions["notification"] = settings.authorizationStatus == .authorized
            
            DispatchQueue.main.async {
                result(permissions)
            }
        }
    }
    
    // 打开应用设置
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    // 显示报警通知
    private func showAlarmNotification() {
        let content = UNMutableNotificationContent()
        content.title = "检测到持续打鼾"
        content.body = "请调整睡姿缓解呼吸不畅"
        content.sound = UNNotificationSound.default
        content.badge = 1
        
        // 立即触发
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "snore_alarm", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送通知失败: \(error.localizedDescription)")
            } else {
                print("✅ 报警通知已发送")
            }
        }
    }
    
    // 取消通知
    private func cancelNotification() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    // 震动
    private func vibrate() {
        // 使用系统震动
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        
        // 延迟后再次震动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
    
    // 配置音频会话，允许后台录音和播放
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // 设置音频会话类别
            // .playAndRecord 允许同时播放和录音
            // .defaultToSpeaker 默认使用扬声器
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth]
            )
            
            // 激活音频会话
            try audioSession.setActive(true)
            
            print("✅ iOS音频会话配置成功")
        } catch {
            print("❌ iOS音频会话配置失败: \(error.localizedDescription)")
        }
    }
    
    // 应用进入后台时处理
    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        
        // 确保音频可以在后台继续运行
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ 设置后台音频失败: \(error.localizedDescription)")
        }
    }
    
    // 应用即将进入前台时处理
    override func applicationWillEnterForeground(_ application: UIApplication) {
        super.applicationWillEnterForeground(application)
        
        // 重新激活音频会话
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(true)
        } catch {
            print("❌ 重新激活音频失败: \(error.localizedDescription)")
        }
        
        // 通知Flutter应用回到前台
        methodChannel?.invokeMethod("onAppResumed", arguments: nil)
    }
    
    // 允许在前台显示通知
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 即使在前台也显示通知
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    // 用户点击通知时的处理
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 通知Flutter用户点击了通知
        if response.notification.request.identifier == "snore_alarm" {
            methodChannel?.invokeMethod("onAlarmNotificationTapped", arguments: nil)
        }
        completionHandler()
    }
}