import UIKit
import Flutter
import AVFoundation
import UserNotifications
import AudioToolbox
import HealthKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var methodChannel: FlutterMethodChannel?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var audioPlayer: AVAudioPlayer?
    private var systemSoundTimer: Timer?
    private let healthStore = HKHealthStore()

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
            name: "com.songshike.snorewatch/screen_wake",
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
            case "clearBadge":
                self?.clearBadge()
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
            case "playAlarmAudio":
                if let args = call.arguments as? [String: Any],
                   let filePath = args["filePath"] as? String {
                    self?.playAlarmAudio(filePath: filePath)
                } else {
                    self?.playDefaultAlarmAudio()
                }
                result(true)
            case "stopAlarmAudio":
                self?.stopAlarmAudio()
                result(true)
            case "requestHealthKitPermission":
                self?.requestHealthKitPermission(result: result)
            case "saveHealthKitSleepData":
                if let args = call.arguments as? [String: Any] {
                    self?.saveHealthKitSleepData(args: args, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                }
            case "isHealthKitAvailable":
                result(HKHealthStore.isHealthDataAvailable())
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
        
        // 2. 申请麦克风权限（不在这里配置音频会话，避免影响其他应用）
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("麦克风权限: \(granted)")
            // 不再自动配置音频会话，等到实际需要录音时再配置
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
    
    private func clearBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("iOS角标已清除")
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
            // 使用纯播放模式，无选项以确保后台播放正常工作
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true, options: [])
            // 强制使用扬声器输出
            try audioSession.overrideOutputAudioPort(.speaker)
            print("已切换到扬声器播放模式（支持后台）")
            
            // 开始后台任务，防止应用被挂起
            startBackgroundTask()
        } catch {
            print("播放音频会话配置失败: \(error)")
        }
    }
    
    private func startBackgroundTask() {
        // 结束之前的后台任务（如果有）
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        // 开始新的后台任务
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "SnoreWatchAlarm") { [weak self] in
            // 后台任务即将过期时的处理
            print("后台任务即将过期")
            if let task = self?.backgroundTask, task != .invalid {
                UIApplication.shared.endBackgroundTask(task)
                self?.backgroundTask = .invalid
            }
        }
        print("已开始后台任务: \(backgroundTask)")
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            print("已结束后台任务")
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
    
    // 播放指定路径的音频文件
    private func playAlarmAudio(filePath: String) {
        configureAudioSessionForPlayback()
        let url = URL(fileURLWithPath: filePath)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            print("原生播放音频: \(filePath)")
        } catch {
            print("原生播放音频失败: \(error)")
            playDefaultAlarmAudio()
        }
    }
    
    // 播放默认报警音频
    private func playDefaultAlarmAudio() {
        configureAudioSessionForPlayback()
        // 使用系统声音循环播放
        print("使用系统声音作为备用")
        AudioServicesPlaySystemSound(1005)
        systemSoundTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            AudioServicesPlaySystemSound(1005)
            self?.vibrate()
        }
    }
    
    // MARK: - HealthKit
    
    private func requestHealthKitPermission(result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result(false)
            return
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let typesToWrite: Set<HKSampleType> = [sleepType]
        let typesToRead: Set<HKObjectType> = [sleepType]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("HealthKit授权失败: \(error)")
                }
                result(success)
            }
        }
    }
    
    private func saveHealthKitSleepData(args: [String: Any], result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result(FlutterError(code: "UNAVAILABLE", message: "HealthKit not available", details: nil))
            return
        }
        
        guard let startTimeMs = args["startTime"] as? Double,
              let endTimeMs = args["endTime"] as? Double else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing startTime or endTime", details: nil))
            return
        }
        
        let startDate = Date(timeIntervalSince1970: startTimeMs / 1000.0)
        let endDate = Date(timeIntervalSince1970: endTimeMs / 1000.0)
        
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            result(FlutterError(code: "TYPE_ERROR", message: "Cannot create sleep type", details: nil))
            return
        }
        
        // 保存为 asleepUnspecified（iOS 16+）或 inBed
        let value: Int
        if #available(iOS 16.0, *) {
            value = HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        } else {
            value = HKCategoryValueSleepAnalysis.inBed.rawValue
        }
        
        let sample = HKCategorySample(
            type: sleepType,
            value: value,
            start: startDate,
            end: endDate
        )
        
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("HealthKit保存睡眠数据失败: \(error)")
                    result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
                } else {
                    print("HealthKit睡眠数据已保存: \(startDate) - \(endDate)")
                    result(success)
                }
            }
        }
    }
    
    // 停止音频播放
    private func stopAlarmAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        systemSoundTimer?.invalidate()
        systemSoundTimer = nil
        endBackgroundTask()
        print("原生停止音频播放")
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
