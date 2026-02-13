package com.songshike.snorewatch

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.Bundle
import android.os.PowerManager
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.view.WindowManager
import android.os.Build
import android.os.Vibrator
import android.os.VibrationEffect
import android.provider.Settings
import android.net.Uri
import android.app.AppOpsManager
import android.os.Process

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.songshike.snorewatch/screen_wake"
    private val PERMISSION_EVENT_CHANNEL = "com.songshike.snorewatch/permission_events"
    private var wakeLock: PowerManager.WakeLock? = null
    private var screenWakeLock: PowerManager.WakeLock? = null
    private var methodChannel: MethodChannel? = null
    private var permissionEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "wakeUpScreen" -> {
                    wakeUpScreen()
                    result.success(true)
                }
                "releaseWakeLock" -> {
                    releaseWakeLock()
                    result.success(true)
                }
                "requestBatteryOptimization" -> {
                    requestIgnoreBatteryOptimization()
                    result.success(true)
                }
                "checkPermissions" -> {
                    val permissions = checkAllPermissions()
                    result.success(permissions)
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(true)
                }
                "openBatterySettings" -> {
                    openBatterySettings()
                    result.success(true)
                }
                "canDrawOverlays" -> {
                    result.success(canDrawOverlays())
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun wakeUpScreen() {
        runOnUiThread {
            try {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                
                // 1. 首先使用 PARTIAL_WAKE_LOCK 确保 CPU 运行
                if (wakeLock == null || !wakeLock!!.isHeld) {
                    wakeLock = powerManager.newWakeLock(
                        PowerManager.PARTIAL_WAKE_LOCK,
                        "SnoreWatch:CpuWakeLock"
                    )
                    wakeLock?.acquire(5 * 60 * 1000L) // 5分钟
                }
                
                // 2. 使用 SCREEN_BRIGHT_WAKE_LOCK 点亮屏幕
                @Suppress("DEPRECATION")
                screenWakeLock = powerManager.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "SnoreWatch:ScreenWakeLock"
                )
                screenWakeLock?.acquire(60 * 1000L) // 60秒
                
                // 3. 设置窗口标志
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
                )
                
                // 4. Android O+ 使用新API
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    setShowWhenLocked(true)
                    setTurnScreenOn(true)
                    
                    val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                    keyguardManager.requestDismissKeyguard(this, null)
                } else {
                    @Suppress("DEPRECATION")
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                    )
                }
                
                // 5. 震动提醒
                vibrateDevice()
                
                // 6. 将应用带到前台
                bringAppToForeground()
                
                println("屏幕唤醒成功 - isScreenOn: ${powerManager.isInteractive}")
            } catch (e: Exception) {
                println("屏幕唤醒失败: ${e.message}")
                e.printStackTrace()
            }
        }
    }
    
    private fun vibrateDevice() {
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // 震动模式: 等待0ms, 震动500ms, 等待200ms, 震动500ms, 等待200ms, 震动500ms
                val pattern = longArrayOf(0, 500, 200, 500, 200, 500)
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                val pattern = longArrayOf(0, 500, 200, 500, 200, 500)
                vibrator.vibrate(pattern, -1)
            }
            println("震动已触发")
        } catch (e: Exception) {
            println("震动失败: ${e.message}")
        }
    }
    
    private fun requestIgnoreBatteryOptimization() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                val packageName = packageName
                if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                }
            }
        } catch (e: Exception) {
            println("请求电池优化豁免失败: ${e.message}")
        }
    }
    
    private fun bringAppToForeground() {
        try {
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
            )
            startActivity(intent)
            println("已尝试将应用带到前台")
        } catch (e: Exception) {
            println("将应用带到前台失败: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            wakeLock = null
            
            screenWakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
            screenWakeLock = null
            
            // 清除窗口标志
            window.clearFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
            
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) {
                @Suppress("DEPRECATION")
                window.clearFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                )
            }
            
            println("WakeLock已释放")
        } catch (e: Exception) {
            println("释放WakeLock失败: ${e.message}")
        }
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }
    
    // 当用户从设置页面返回时，通知Flutter刷新权限状态
    override fun onResume() {
        super.onResume()
        // 延迟一点时间确保系统权限状态已更新
        window.decorView.postDelayed({
            notifyPermissionChanged()
        }, 500)
    }
    
    private fun notifyPermissionChanged() {
        try {
            val permissions = checkAllPermissions()
            methodChannel?.invokeMethod("onPermissionChanged", permissions)
            println("权限状态已通知Flutter: $permissions")
        } catch (e: Exception) {
            println("通知权限变化失败: ${e.message}")
        }
    }
    
    private fun checkAllPermissions(): Map<String, Boolean> {
        val permissions = mutableMapOf<String, Boolean>()
        
        // 检查电池优化豁免
        permissions["batteryOptimization"] = checkBatteryOptimization()
        
        // 检查悬浮窗权限 - 使用多种方式检测以适配不同机型
        permissions["overlay"] = checkOverlayPermission()
        
        // 添加设备信息用于调试
        permissions["deviceBrand"] = true // 仅用于标记
        println("设备信息: ${Build.MANUFACTURER} ${Build.MODEL}, Android ${Build.VERSION.SDK_INT}")
        println("权限检测结果: batteryOptimization=${permissions["batteryOptimization"]}, overlay=${permissions["overlay"]}")
        
        return permissions
    }
    
    private fun checkBatteryOptimization(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                powerManager.isIgnoringBatteryOptimizations(packageName)
            } catch (e: Exception) {
                println("检查电池优化权限失败: ${e.message}")
                false
            }
        } else {
            true
        }
    }
    
    // 适配多种机型的悬浮窗权限检测
    private fun checkOverlayPermission(): Boolean {
        // Android M (6.0) 以下不需要悬浮窗权限
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        
        // 方法1: 使用标准API (适用于大多数设备)
        val standardCheck = try {
            Settings.canDrawOverlays(this)
        } catch (e: Exception) {
            println("标准悬浮窗检测失败: ${e.message}")
            null
        }
        
        // 方法2: 使用AppOpsManager (适用于部分国产机型如小米、华为)
        val appOpsCheck = try {
            checkOverlayPermissionViaAppOps()
        } catch (e: Exception) {
            println("AppOps悬浮窗检测失败: ${e.message}")
            null
        }
        
        // 综合判断：只要有一个方法返回true就认为有权限
        val result = when {
            standardCheck == true -> true
            appOpsCheck == true -> true
            standardCheck == false && appOpsCheck == false -> false
            standardCheck != null -> standardCheck
            appOpsCheck != null -> appOpsCheck
            else -> false
        }
        
        println("悬浮窗权限检测: standardCheck=$standardCheck, appOpsCheck=$appOpsCheck, result=$result")
        return result
    }
    
    // 使用AppOpsManager检测悬浮窗权限（适配小米、华为等国产机型）
    private fun checkOverlayPermissionViaAppOps(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        
        return try {
            val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOpsManager.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW,
                    Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOpsManager.checkOpNoThrow(
                    AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW,
                    Process.myUid(),
                    packageName
                )
            }
            
            when (mode) {
                AppOpsManager.MODE_ALLOWED -> true
                AppOpsManager.MODE_DEFAULT -> {
                    // MODE_DEFAULT时需要额外检查
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                }
                else -> false
            }
        } catch (e: Exception) {
            println("AppOps检测异常: ${e.message}")
            // 发生异常时回退到标准检测
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(this)
            } else {
                true
            }
        }
    }
    
    private fun canDrawOverlays(): Boolean {
        return checkOverlayPermission()
    }
    
    private fun openAppSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
            println("打开应用设置失败: ${e.message}")
        }
    }
    
    private fun openBatterySettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        } catch (e: Exception) {
            println("打开电池设置失败: ${e.message}")
        }
    }
    
    private fun openOverlaySettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                intent.data = Uri.parse("package:$packageName")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            }
        } catch (e: Exception) {
            println("打开悬浮窗设置失败: ${e.message}")
        }
    }
}