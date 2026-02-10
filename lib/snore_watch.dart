import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// 关键修改：为 audioplayers 添加别名 'audio'
import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:noise_meter/noise_meter.dart'; // 真实分贝库
import 'package:flutter_sound/flutter_sound.dart'; // 真实录音库
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart'; // 新增：用于屏幕唤醒
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 新增：本地通知
import 'package:file_picker/file_picker.dart'; // 新增：文件选择器
import 'package:shared_preferences/shared_preferences.dart'; // 新增：本地存储
import 'l10n/app_localizations.dart'; // 多语言支持

void main() {
  runApp(const SnoreWatchApp());
}

// 生命周期处理器类（新增）
class LifecycleEventHandler extends WidgetsBindingObserver {
  final VoidCallback? detach;
  final VoidCallback? resume;

  LifecycleEventHandler({this.detach, this.resume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.paused:
        detach?.call();
        break;
      case AppLifecycleState.resumed:
        resume?.call();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }
}

// 真实录音记录的数据结构
class SnoreRecording {
  final String filePath;
  final DateTime dateTime;
  final Duration duration;
  final double maxDb;

  SnoreRecording({
    required this.filePath,
    required this.dateTime,
    required this.duration,
    required this.maxDb,
  });

  String get fileName => filePath.split('/').last;
  String get displayTime => '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  String get displayDate => '${dateTime.month}/${dateTime.day}';
}

// 全局语言状态管理
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('zh', 'CN');
  
  Locale get locale => _locale;
  
  void toggleLocale() {
    if (_locale.languageCode == 'zh') {
      _locale = const Locale('en', 'US');
    } else {
      _locale = const Locale('zh', 'CN');
    }
    notifyListeners();
  }
  
  bool get isEnglish => _locale.languageCode == 'en';
}

// 全局 LocaleProvider 实例
final localeProvider = LocaleProvider();

class SnoreWatchApp extends StatefulWidget {
  const SnoreWatchApp({super.key});

  @override
  State<SnoreWatchApp> createState() => _SnoreWatchAppState();
}

class _SnoreWatchAppState extends State<SnoreWatchApp> {
  @override
  void initState() {
    super.initState();
    localeProvider.addListener(_onLocaleChanged);
  }
  
  @override
  void dispose() {
    localeProvider.removeListener(_onLocaleChanged);
    super.dispose();
  }
  
  void _onLocaleChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '鼾声守望者',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF4ECDC4),
        scaffoldBackgroundColor: const Color(0xFF0A1A3C),
      ),
      // 多语言支持
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文
        Locale('en', 'US'), // 英文
      ],
      home: const SnoreWatchHomePage(),
    );
  }
}

class SnoreWatchHomePage extends StatefulWidget {
  const SnoreWatchHomePage({super.key});

  @override
  State<SnoreWatchHomePage> createState() => _SnoreWatchHomePageState();
}

class _SnoreWatchHomePageState extends State<SnoreWatchHomePage> with TickerProviderStateMixin {
  // 优化配色常量
  static const Color _primaryColor = Color(0xFF4ECDC4);      // 主色调 - 青绿色
  static const Color _primaryDark = Color(0xFF3BA99C);       // 主色调深色
  static const Color _accentColor = Color(0xFF6C63FF);       // 强调色 - 紫色
  static const Color _bgColor = Color(0xFF0D1B2A);           // 背景色 - 深蓝黑
  static const Color _cardColor = Color(0xFF1B2838);         // 卡片色
  static const Color _cardColorLight = Color(0xFF243447);    // 卡片浅色
  static const Color _textPrimary = Color(0xFFFFFFFF);       // 主文字
  static const Color _textSecondary = Color(0xFFB0BEC5);     // 次要文字
  static const Color _successColor = Color(0xFF4CAF50);      // 成功色
  static const Color _warningColor = Color(0xFFFF9800);      // 警告色
  static const Color _errorColor = Color(0xFFE53935);        // 错误色
  
  // 动画控制器
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // 页面状态：0=准备, 1=设置, 2=监测中
  int _pageState = 0;
  
  // 监测模式：0=仅监测录音（模式A），1=监测并叫醒（模式B，默认）
  int _monitorMode = 1;
  
  // 守护时长
  int _selectedHours = 8;
  final List<int> _hourOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  
  // 叫醒音乐
  String _selectedMusic = '溪流声';
  final List<String> _musicOptions = [
    // 自然音
    '溪流声', '瀑布声', '森林声', '风声', '雷声', '虫鸣声', '蛙鸣声',
    // 轻音乐
    '钢琴曲', '吉他曲', '竖琴曲', '长笛曲', '音乐盒',
    // 白噪音
    '白噪音', '粉噪音', '篝火声',
  ];
  
  // 监测状态
  bool _isRunning = false;
  int _remainingSeconds = 0;
  Timer? _guardTimer;
  
  // 真实分贝监测
  double _currentDb = 0.0;
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  
  // 分贝阈值 - 修改：从55.0改为65.0
  double _thresholdDb = 65.0;
  
  // 打鼾检测
  final List<double> _recentDbValues = []; // 用于计算1分钟内的超阈值次数
  int _snoreCountInCurrentMinute = 0;
  int _totalSnoreEvents = 0; // 整个守护期间的打鼾事件总数
  DateTime? _guardStartTime; // 守护开始时间
  Timer? _snoreAnalysisTimer; // 每分钟分析一次
  
  // 真实录音相关
  final FlutterSoundRecorder _soundRecorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;
  Timer? _recordingStopTimer;
  final List<SnoreRecording> _realRecordings = []; // 真实录音列表
  int _currentSessionRecordingCount = 0; // 本次守护的录音数量
  
  // 报警状态
  bool _isAlarming = false;
  
  // 音频播放器 - 使用别名
  final audio.AudioPlayer _audioPlayer = audio.AudioPlayer();
  
  // 音频文件映射
  final Map<String, String> _musicFiles = {
    // 自然音
    '溪流声': '溪流声.mp3',
    '瀑布声': '瀑布声.mp3',
    '森林声': '森林声.mp3',
    '风声': '风声.mp3',
    '雷声': '雷声.mp3',
    '虫鸣声': '虫鸣声.mp3',
    '蛙鸣声': '蛙鸣声.mp3',
    // 轻音乐
    '钢琴曲': '钢琴曲.mp3',
    '吉他曲': '吉他曲.mp3',
    '竖琴曲': '竖琴曲.mp3',
    '长笛曲': '长笛曲.mp3',
    '音乐盒': '音乐盒.mp3',
    // 白噪音
    '白噪音': '白噪音.mp3',
    '粉噪音': '粉噪音.mp3',
    '篝火声': '篝火声.mp3',
  };
  
  // 新增：防止重复录音的标志
  bool _isInRecordingCycle = false;
  
  // 新增：播放录音时的暂停监测标志
  bool _isPlayingRecording = false;
  
  // 新增：待显示报警弹窗标志（用于息屏后恢复时显示）
  bool _pendingAlarmDialog = false;
  
  // 新增：当前正在播放的录音索引
  int? _currentPlayingIndex;
  
  // 新增：本地通知插件
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  
  // 新增：原生屏幕唤醒通道
  static const MethodChannel _screenWakeChannel = MethodChannel('com.example.slept_well/screen_wake');
  
  // 权限状态缓存（用于权限设置页面刷新）
  Map<dynamic, dynamic>? _cachedPermissions;
  
  // 新增：自定义铃声列表（用户导入的）
  final List<String> _customMusicOptions = [];
  final Map<String, String> _customMusicFiles = {}; // 名称 -> 文件路径
  
  @override
  void initState() {
    super.initState();
    
    // 初始化脉冲动画
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _initializeRecorder();
    _loadExistingRecordings();
    _initializeNotifications(); // 初始化通知
    _loadCustomRingtones(); // 加载自定义铃声
    _loadUserSettings(); // 加载用户设置
    
    // 新增：监听应用生命周期
    _setupBackButtonHandler();
    
    // 新增：设置原生权限变化监听
    _setupPermissionChangeListener();
    
    // 新增：延迟检查权限并显示提示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestAllPermissionsOnStartup();
      _clearBadgeOnStartup(); // 启动时清除角标
    });
  }
  
  // 新增：启动时清除角标
  Future<void> _clearBadgeOnStartup() async {
    if (Platform.isIOS) {
      try {
        await _screenWakeChannel.invokeMethod('clearBadge');
        print('启动时清除iOS角标');
      } catch (e) {
        print('启动时清除角标失败: $e');
      }
    }
  }
  
  // 新增：设置原生端权限变化监听
  void _setupPermissionChangeListener() {
    if (!Platform.isAndroid) return;
    
    _screenWakeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPermissionChanged') {
        final permissions = call.arguments as Map<dynamic, dynamic>?;
        if (permissions != null) {
          print('收到权限变化通知: $permissions');
          _cachedPermissions = permissions;
          // 刷新UI
          if (mounted) {
            setState(() {});
          }
        }
      }
      return null;
    });
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _guardTimer?.cancel();
    _stopNoiseMonitoring();
    _soundRecorder.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  // 新增：初始化本地通知
  void _initializeNotifications() {
    try {
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS初始化设置
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
      ).then((_) {
        print('✅ 本地通知初始化成功');
      }).catchError((e) {
        print('❌ 本地通知初始化失败: $e');
      });
    } catch (e) {
      print('❌ 本地通知初始化异常: $e');
    }
  }
  
  // 新增：显示全屏通知（用于锁屏唤醒）- 仅Android
  Future<void> _showFullScreenNotification() async {
    // iOS不需要全屏通知，因为iOS有专门的音频会话处理
    if (Platform.isIOS) {
      return;
    }
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'snore_watch_channel',
      '鼾声守望者',
      channelDescription: '睡眠监测报警通知',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true, // 全屏意图
      autoCancel: false,
      ongoing: true,
      visibility: NotificationVisibility.public,
      playSound: false, // 我们自己播放音乐，不需要系统声音
      enableVibration: false, // 我们自己处理震动
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await _flutterLocalNotificationsPlugin.show(
      0,
      '检测到持续打鼾',
      '请调整睡姿缓解呼吸不畅',
      platformChannelSpecifics,
    );
  }
  
  // 新增：取消通知并清除角标
  Future<void> _cancelNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(0);
    await _flutterLocalNotificationsPlugin.cancelAll(); // 取消所有通知
    
    // iOS清除角标 - 通过原生通道
    if (Platform.isIOS) {
      try {
        await _screenWakeChannel.invokeMethod('clearBadge');
        print('iOS角标已清除');
      } catch (e) {
        print('清除iOS角标失败: $e');
      }
    }
  }
  
  // 新增：设置返回键处理器
  void _setupBackButtonHandler() {
    WidgetsBinding.instance.addObserver(
      LifecycleEventHandler(
        detach: () {
          print('应用进入后台');
          // 如果应用进入后台，确保屏幕唤醒在报警时保持
          if (_isAlarming && _isRunning) {
            _ensureScreenWakeForAlarm();
          }
        },
        resume: () {
          print('应用回到前台');
          // 如果正在报警中，确保屏幕唤醒并显示弹窗
          if (_isAlarming && _isRunning) {
            _ensureScreenWakeForAlarm();
            // 如果有待显示的弹窗，显示它
            if (_pendingAlarmDialog) {
              _pendingAlarmDialog = false;
              _showAlarmDialog();
            }
          }
        },
      ),
    );
  }
  
  // 新增：显示报警弹窗（独立方法，方便复用）
  void _showAlarmDialog() {
    if (!mounted) return;
    
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B2838),
                  Color(0xFF243447),
                  Color(0xFF1B2838),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF4ECDC4).withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4ECDC4).withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFF9800).withOpacity(0.2),
                        const Color(0xFFFF5722).withOpacity(0.2),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.nightlight_round,
                    color: Color(0xFFFFB74D),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n?.get('snoring_detected') ?? '检测到持续打鼾',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n?.get('adjust_position') ?? '请调整睡姿缓解呼吸不畅',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFB74D),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _stopAlarm();
                      print('用户确认报警，继续监测');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n?.get('ok_continue') ?? '好的，继续监测',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // 新增：确保报警时屏幕唤醒（优化版 - 支持iOS和Android）
  Future<void> _ensureScreenWakeForAlarm() async {
    if (_isAlarming) {
      print('尝试点亮屏幕...');
      
      // 1. 保持屏幕常亮
      await WakelockPlus.enable();
      
      if (Platform.isAndroid) {
        // Android: 显示全屏通知
        await _showFullScreenNotification();
        
        // 使用原生代码唤醒屏幕
        try {
          await _screenWakeChannel.invokeMethod('wakeUpScreen');
          print('Android原生屏幕唤醒调用成功');
        } catch (e) {
          print('Android原生屏幕唤醒失败: $e');
        }
        
        // 发送震动提示
        try {
          HapticFeedback.vibrate();
          print('已发送震动提示');
        } catch (e) {
          print('震动失败: $e');
        }
      } else if (Platform.isIOS) {
        // iOS: 通过原生通道发送通知和震动
        try {
          await _screenWakeChannel.invokeMethod('wakeUpScreen');
          print('iOS通知和震动已发送');
        } catch (e) {
          print('iOS唤醒提醒失败: $e');
        }
      }
      
      // 延迟一下，确保屏幕有足够时间点亮
      await Future.delayed(const Duration(milliseconds: 500));
      print('屏幕唤醒尝试完成');
    }
  }
  
  // 新增：释放屏幕唤醒锁
  Future<void> _releaseScreenWakeLock() async {
    if (Platform.isAndroid) {
      try {
        await _screenWakeChannel.invokeMethod('releaseWakeLock');
        print('屏幕唤醒锁已释放');
      } catch (e) {
        print('释放屏幕唤醒锁失败: $e');
      }
    }
  }
  
  // 新增：请求电池优化豁免
  Future<void> _requestBatteryOptimization() async {
    if (Platform.isAndroid) {
      try {
        await _screenWakeChannel.invokeMethod('requestBatteryOptimization');
        print('已请求电池优化豁免');
      } catch (e) {
        print('请求电池优化豁免失败: $e');
      }
    }
  }
  
  // 新增：检查权限并显示提示对话框
  Future<void> _checkAndShowPermissionDialog() async {
    if (!Platform.isAndroid) return;
    
    try {
      final permissions = await _screenWakeChannel.invokeMethod('checkPermissions');
      final bool batteryOptimization = permissions['batteryOptimization'] ?? false;
      final bool overlay = permissions['overlay'] ?? false;
      
      // 如果有权限未授权，显示提示
      if (!batteryOptimization || !overlay) {
        if (mounted) {
          _showPermissionCheckDialog(batteryOptimization, overlay);
        }
      }
    } catch (e) {
      print('检查权限失败: $e');
    }
  }
  
  // 新增：显示权限检查对话框
  void _showPermissionCheckDialog(bool batteryGranted, bool overlayGranted) {
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security, color: Color(0xFF4ECDC4), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n?.get('permission_check_title') ?? '权限检查',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.get('permission_check_msg') ?? '为了确保应用能在息屏时正常工作，请授予以下权限：',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              
              // 电池优化权限
              _buildPermissionItem(
                icon: Icons.battery_charging_full,
                title: l10n?.get('battery_optimization') ?? '电池优化',
                description: l10n?.get('battery_optimization_desc') ?? '允许应用在后台持续运行',
                warning: l10n?.get('battery_optimization_warning') ?? '未开启可能导致后台被杀死',
                isGranted: batteryGranted,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _screenWakeChannel.invokeMethod('openBatterySettings');
                },
              ),
              
              const SizedBox(height: 12),
              
              // 悬浮窗权限
              _buildPermissionItem(
                icon: Icons.picture_in_picture,
                title: l10n?.get('overlay_permission') ?? '悬浮窗权限',
                description: l10n?.get('overlay_permission_desc') ?? '允许显示报警弹窗',
                warning: l10n?.get('overlay_permission_warning') ?? '未开启可能导致弹窗不显示',
                isGranted: overlayGranted,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _screenWakeChannel.invokeMethod('openOverlaySettings');
                },
              ),
              
              const SizedBox(height: 16),
              
              // 提示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n?.get('permission_tip') ?? '提示：部分权限需要在系统设置中手动开启',
                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n?.get('skip') ?? '跳过',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _screenWakeChannel.invokeMethod('openAppSettings');
            },
            child: Text(
              l10n?.get('open_app_settings') ?? '打开应用设置',
              style: const TextStyle(color: Color(0xFF4ECDC4), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
  
  // 新增：构建权限项
  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required String warning,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isGranted ? Colors.green : Colors.red, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isGranted ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isGranted
                    ? (l10n?.get('permission_granted') ?? '已授权')
                    : (l10n?.get('permission_not_granted') ?? '未授权'),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (!isGranted) ...[
            const SizedBox(height: 8),
            Text(
              warning,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(l10n?.get('go_to_settings') ?? '去设置', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // 新增：显示权限设置页面
  void _showPermissionSettingsPage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PermissionSettingsSheet(
        screenWakeChannel: _screenWakeChannel,
        onRefresh: () async {
          final result = await _getPermissionStatus();
          _cachedPermissions = result;
          if (mounted) setState(() {});
        },
      ),
    );
  }
  
  // 新增：获取权限状态
  Future<Map<dynamic, dynamic>> _getPermissionStatus() async {
    if (!Platform.isAndroid) {
      return {'batteryOptimization': true, 'overlay': true};
    }
    try {
      final result = await _screenWakeChannel.invokeMethod('checkPermissions');
      return result as Map<dynamic, dynamic>;
    } catch (e) {
      print('获取权限状态失败: $e');
      return {'batteryOptimization': false, 'overlay': false};
    }
  }
  
  // 初始化录音器
  Future<void> _initializeRecorder() async {
    try {
      await _soundRecorder.openRecorder();
      await _soundRecorder.setSubscriptionDuration(const Duration(milliseconds: 10));
      print('录音器初始化成功');
    } catch (e) {
      print('录音器初始化失败: $e');
    }
    
    await Permission.microphone.request();
  }
  
  // 加载本地已保存的真实录音文件
  Future<void> _loadExistingRecordings() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/snore_recordings');
      if (await recordingsDir.exists()) {
        final files = recordingsDir.listSync();
        
        // 清空现有列表，避免重复
        _realRecordings.clear();
        
        for (var file in files) {
          if (file is File && 
              (file.path.endsWith('.m4a') || 
               file.path.endsWith('.wav') || 
               file.path.endsWith('.aac') ||
               file.path.endsWith('.ogg'))) {
            try {
              final stat = await file.stat();
              // 只添加最近7天的录音，避免太多旧文件
              final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
              if (stat.modified.isAfter(sevenDaysAgo)) {
                _realRecordings.add(SnoreRecording(
                  filePath: file.path,
                  dateTime: stat.modified,
                  duration: const Duration(seconds: 60),
                  maxDb: 65.0, // 默认值
                ));
              }
            } catch (e) {
              print('读取文件信息失败: ${file.path} - $e');
            }
          }
        }
        // 按时间排序，最新的在前面
        _realRecordings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('加载录音失败: $e');
    }
  }
  
  // 新增：加载自定义铃声
  Future<void> _loadCustomRingtones() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ringtonesDir = Directory('${dir.path}/custom_ringtones');
      if (await ringtonesDir.exists()) {
        final files = ringtonesDir.listSync();
        _customMusicOptions.clear();
        _customMusicFiles.clear();
        
        for (var file in files) {
          if (file is File && _isAudioFile(file.path)) {
            final fileName = file.path.split(Platform.pathSeparator).last;
            final displayName = fileName.replaceAll(RegExp(r'\.(mp3|wav|m4a|aac|ogg|flac)$'), '');
            _customMusicOptions.add(displayName);
            _customMusicFiles[displayName] = file.path;
          }
        }
        
        if (mounted) {
          setState(() {});
        }
        print('已加载 ${_customMusicOptions.length} 个自定义铃声');
      }
    } catch (e) {
      print('加载自定义铃声失败: $e');
    }
  }
  
  // 新增：检查是否为音频文件
  bool _isAudioFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp3') || 
           ext.endsWith('.wav') || 
           ext.endsWith('.m4a') || 
           ext.endsWith('.aac') || 
           ext.endsWith('.ogg') ||
           ext.endsWith('.flac');
  }
  
  // 新增：导入自定义铃声
  Future<void> _importCustomRingtone() async {
    try {
      // 使用custom类型，允许选择任意文件（包括"文件"App中的文件）
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        final sourcePath = result.files.single.path!;
        final fileName = result.files.single.name;
        
        // 创建自定义铃声目录
        final dir = await getApplicationDocumentsDirectory();
        final ringtonesDir = Directory('${dir.path}/custom_ringtones');
        if (!await ringtonesDir.exists()) {
          await ringtonesDir.create(recursive: true);
        }
        
        // 复制文件到应用目录
        final destPath = '${ringtonesDir.path}/$fileName';
        final sourceFile = File(sourcePath);
        await sourceFile.copy(destPath);
        
        // 获取显示名称（去掉扩展名）
        final displayName = fileName.replaceAll(RegExp(r'\.(mp3|wav|m4a|aac|ogg|flac)$'), '');
        
        // 检查是否已存在
        if (!_customMusicOptions.contains(displayName)) {
          setState(() {
            _customMusicOptions.add(displayName);
            _customMusicFiles[displayName] = destPath;
            _selectedMusic = displayName; // 自动选择新导入的铃声
          });
          
          _showSuccessSnackBar('已导入: $displayName');
        } else {
          _showErrorSnackBar('铃声已存在: $displayName');
        }
      }
    } catch (e) {
      print('导入铃声失败: $e');
      _showErrorSnackBar('导入失败，请重试');
    }
  }
  
  // 新增：删除自定义铃声
  Future<void> _deleteCustomRingtone(String name) async {
    try {
      final filePath = _customMusicFiles[name];
      if (filePath != null) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        
        setState(() {
          _customMusicOptions.remove(name);
          _customMusicFiles.remove(name);
          // 如果删除的是当前选中的铃声，切换到默认铃声
          if (_selectedMusic == name) {
            _selectedMusic = '海浪声';
          }
        });
        
        _showSuccessSnackBar('已删除: $name');
      }
    } catch (e) {
      print('删除铃声失败: $e');
      _showErrorSnackBar('删除失败');
    }
  }
  
  // 新增：获取所有可用的音乐选项（内置 + 自定义）
  List<String> get _allMusicOptions {
    return [..._musicOptions, ..._customMusicOptions];
  }
  
  // 新增：检查是否为自定义铃声
  bool _isCustomRingtone(String name) {
    return _customMusicOptions.contains(name);
  }
  
  // 新增：加载用户设置
  Future<void> _loadUserSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _selectedHours = prefs.getInt('selectedHours') ?? 8;
        _thresholdDb = prefs.getDouble('thresholdDb') ?? 65.0;
        _monitorMode = prefs.getInt('monitorMode') ?? 1;
        final savedMusic = prefs.getString('selectedMusic');
        if (savedMusic != null && (_musicOptions.contains(savedMusic) || _customMusicOptions.contains(savedMusic))) {
          _selectedMusic = savedMusic;
        }
      });
      
      print('用户设置已加载: 时长=$_selectedHours, 阈值=$_thresholdDb, 模式=$_monitorMode, 铃声=$_selectedMusic');
    } catch (e) {
      print('加载用户设置失败: $e');
    }
  }
  
  // 新增：保存用户设置
  Future<void> _saveUserSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt('selectedHours', _selectedHours);
      await prefs.setDouble('thresholdDb', _thresholdDb);
      await prefs.setInt('monitorMode', _monitorMode);
      await prefs.setString('selectedMusic', _selectedMusic);
      
      print('用户设置已保存');
    } catch (e) {
      print('保存用户设置失败: $e');
    }
  }
  
  // 启动时申请所有权限
  Future<void> _requestAllPermissionsOnStartup() async {
    print('启动时申请所有权限...');
    
    // 1. 申请麦克风权限（录音必需）
    final micStatus = await Permission.microphone.request();
    print('麦克风权限: $micStatus');
    
    // 2. 申请通知权限
    final notifStatus = await Permission.notification.request();
    print('通知权限: $notifStatus');
    
    if (Platform.isAndroid) {
      // Android: 申请音频权限
      final audioStatus = await Permission.audio.request();
      print('音频权限: $audioStatus');
      
      // Android: 申请存储权限（用于保存录音）
      final storageStatus = await Permission.storage.request();
      print('存储权限: $storageStatus');
    }
    
    if (Platform.isIOS) {
      // iOS: 申请媒体库权限（用于导入铃声）
      final mediaStatus = await Permission.mediaLibrary.request();
      print('媒体库权限: $mediaStatus');
      
      // iOS: 申请相册权限（file_picker可能需要）
      final photosStatus = await Permission.photos.request();
      print('相册权限: $photosStatus');
    }
  }
  
  // 请求权限 - 修改：添加iOS兼容性
  Future<void> _requestPermissions() async {
    // iOS和Android的权限处理方式不同
    if (Platform.isIOS) {
      // iOS只需要请求麦克风权限
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        print('iOS麦克风权限被拒绝');
      }
    } else {
      // Android需要请求多个权限
      await Permission.microphone.request();
      await Permission.notification.request();
      await Permission.audio.request();
    }
  }
  
  // 点击大圆形按钮
  void _onMainButtonTap() {
    if (_pageState == 0) {
      setState(() => _pageState = 1);
    } else if (_pageState == 1) {
      _startRealGuard();
    }
  }
  
  // 开始真实守护 - 修改：添加iOS音频配置
  Future<void> _startRealGuard() async {
    // iOS: 原生已申请权限，直接检查
    // Android: 使用permission_handler申请
    if (Platform.isAndroid) {
      await _requestPermissions();
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        _showPermissionSnackBar();
        return;
      }
    }
    // iOS不再使用permission_handler检查，因为原生已处理
    
    // iOS特殊处理：检查后台音频权限
    if (Platform.isIOS) {
      try {
        // 确保音频会话已配置
        await _audioPlayer.setPlayerMode(audio.PlayerMode.lowLatency);
      } catch (e) {
        print('iOS音频配置失败: $e');
        // 继续执行，因为有些iOS版本可能不需要这个
      }
    }
    
    // 重置录音状态
    _recordingStopTimer?.cancel();
    try {
      if (_soundRecorder.isRecording) {
        await _soundRecorder.stopRecorder();
      }
    } catch (e) {
      print('重置录音器失败: $e');
    }
    
    if (mounted) {
      setState(() {
        _pageState = 2;
        _isRunning = true;
        _remainingSeconds = _selectedHours * 3600;
        _isAlarming = false;
        _recentDbValues.clear();
        _snoreCountInCurrentMinute = 0;
        _totalSnoreEvents = 0; // 重置总打鼾事件计数
        _guardStartTime = DateTime.now(); // 记录守护开始时间
        _isInRecordingCycle = false;
        _isRecording = false; // 重置录音状态
        _currentRecordingPath = null; // 重置录音路径
        _isPlayingRecording = false; // 重置播放状态
        _currentPlayingIndex = null; // 重置播放索引
        _realRecordings.clear(); // 清空本次守护的录音列表
        _currentSessionRecordingCount = 0; // 重置本次守护录音计数
      });
    }
    
    print('=== 开始真实守护 $_selectedHours 小时 ===');
    
    // 新增：在守护开始时启用屏幕唤醒
    await WakelockPlus.enable();
    
    // 新增：请求电池优化豁免（仅Android）
    await _requestBatteryOptimization();
    
    // 总时长计时器
    _guardTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() => _remainingSeconds--);
      }
      if (_remainingSeconds <= 0) {
        _stopGuard();
      }
    });
    
    // 启动真实分贝监测
    _startRealNoiseMonitoring();
    
    // 每分钟分析一次打鼾模式
    _snoreAnalysisTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_isRunning || _isAlarming || _isPlayingRecording) return;
      _analyzeSnorePattern();
    });
  }
  
  // 开始真实噪音监测
  void _startRealNoiseMonitoring() {
    _noiseMeter = NoiseMeter();
    
    _noiseSubscription = _noiseMeter!.noise.listen((NoiseReading noiseReading) {
      // 新增：如果正在播放录音，暂停监测
      if (!_isRunning || _isAlarming || _isPlayingRecording) return;
      
      final double currentDb = noiseReading.meanDecibel;
      
      if (mounted) {
        setState(() {
          _currentDb = currentDb.isNaN ? 0.0 : currentDb;
          _recentDbValues.add(_currentDb);
          
          if (_recentDbValues.length > 60) {
            _recentDbValues.removeAt(0);
          }
          
          if (_currentDb >= _thresholdDb) {
            _snoreCountInCurrentMinute++;
            
            // 修改：添加 _isInRecordingCycle 检查，防止重复录音
            if (!_isRecording && _currentRecordingPath == null && !_isInRecordingCycle) {
              _startTemporaryRecording();
            }
          }
        });
      }
    }, onError: (error) {
      print('监听噪音流错误: $error');
      if (_isRunning) {
        _stopNoiseMonitoring();
        Timer(const Duration(seconds: 2), () {
          if (_isRunning) _startRealNoiseMonitoring();
        });
      }
    });
  }
  
  // 开始一段临时录音（用于记录可能的打鼾事件）
  Future<void> _startTemporaryRecording() async {
    // 添加检查：防止重复进入录音周期
    if (_isInRecordingCycle) {
      print('已经在录音周期中，跳过重复录音');
      return;
    }
    
    try {
      // 设置录音周期标志
      if (mounted) {
        setState(() {
          _isInRecordingCycle = true;
        });
      }
      
      // iOS: 切换到录音模式
      if (Platform.isIOS) {
        try {
          await _screenWakeChannel.invokeMethod('configureAudioForRecording');
          print('iOS: 已切换到录音模式');
        } catch (e) {
          print('iOS录音模式切换失败: $e');
        }
      }
      
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/snore_recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${recordingsDir.path}/snore_$timestamp.m4a';
      final codec = Codec.aacMP4;
      
      print('开始录音: $path, 编码: $codec');
      
      await _soundRecorder.startRecorder(
        toFile: path,
        codec: codec,
        sampleRate: 16000,
      );
      
      if (mounted) {
        setState(() {
          _isRecording = true;
          _currentRecordingPath = path;
        });
      }
      
      print('开始临时录音成功');
      
      // 注意：不再使用定时器自动停止录音，改由 _analyzeSnorePattern 决定是否保存
      // 录音会在分析完成后由 _analyzeSnorePattern 调用 _stopTemporaryRecording
      _recordingStopTimer = Timer(const Duration(seconds: 65), () async {
        // 只有在录音仍在进行且未被分析处理时才停止（作为安全保障）
        if (_isRecording && _isInRecordingCycle) {
          print('录音超时，安全停止');
          await _stopTemporaryRecording(saveToHistory: false);
        }
      });
      
    } catch (e) {
      print('开始录音失败: $e');
      // 重置录音周期标志
      if (mounted) {
        setState(() {
          _isInRecordingCycle = false;
        });
      }
      await _startPcmRecordingAsFallback();
    }
  }
  
  // 备用PCM录音方法（兼容性最好）
  Future<void> _startPcmRecordingAsFallback() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/snore_recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${recordingsDir.path}/snore_${timestamp}_pcm.wav';
      
      print('尝试PCM录音: $path');
      
      await _soundRecorder.startRecorder(
        toFile: path,
        codec: Codec.pcm16,
        sampleRate: 16000,
      );
      
      if (mounted) {
        setState(() {
          _isRecording = true;
          _currentRecordingPath = path;
        });
      }
      
      print('PCM录音开始成功');
      
      _recordingStopTimer = Timer(const Duration(seconds: 60), () async {
        if (_isRecording) {
          await _stopTemporaryRecording(saveToHistory: false);
        }
      });
      
    } catch (e) {
      print('PCM录音也失败: $e');
      // 重置录音周期标志
      if (mounted) {
        setState(() {
          _isInRecordingCycle = false;
        });
      }
    }
  }
  
  // 停止临时录音
  Future<void> _stopTemporaryRecording({bool saveToHistory = false}) async {
    try {
      if (_isRecording) {
        await _soundRecorder.stopRecorder();
        
        // 只有在分析后确定是打鼾才保存
        if (saveToHistory && _currentRecordingPath != null) {
          double maxDb = _thresholdDb + 5.0;
          if (_recentDbValues.isNotEmpty) {
            maxDb = _recentDbValues.reduce((a, b) => a > b ? a : b);
          }
          
          final file = File(_currentRecordingPath!);
          if (await file.exists()) {
            final stat = await file.stat();
            
            _realRecordings.insert(0, SnoreRecording(
              filePath: _currentRecordingPath!,
              dateTime: stat.modified,
              duration: const Duration(seconds: 60),
              maxDb: maxDb,
            ));
            
            // 限制最多保存20个录音文件
            if (_realRecordings.length > 20) {
              // 删除最旧的文件
              final oldestRecording = _realRecordings.removeLast();
              try {
                final oldFile = File(oldestRecording.filePath);
                if (await oldFile.exists()) {
                  await oldFile.delete();
                }
              } catch (e) {
                print('删除旧文件失败: $e');
              }
            }
            
            _realRecordings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
            if (mounted) {
              setState(() {});
            }
            
            print('录音已保存到历史: ${_currentRecordingPath}');
          }
        } else if (!saveToHistory && _currentRecordingPath != null) {
          // 如果不是打鼾，删除临时录音文件
          try {
            final file = File(_currentRecordingPath!);
            if (await file.exists()) {
              await file.delete();
              print('临时录音文件已删除: ${_currentRecordingPath}');
            }
          } catch (e) {
            print('删除临时文件失败: $e');
          }
        }
        
        if (mounted) {
          setState(() {
            _isRecording = false;
            _currentRecordingPath = null;
            _isInRecordingCycle = false; // 重置录音周期标志
          });
        }
        _recordingStopTimer?.cancel();
        print('临时录音已停止');
      }
    } catch (e) {
      print('停止录音失败: $e');
      // 确保重置录音周期标志
      if (mounted) {
        setState(() {
          _isInRecordingCycle = false;
        });
      }
    }
  }
  
  // 分析打鼾模式（每分钟调用一次）
  Future<void> _analyzeSnorePattern() async {
    if (_recentDbValues.isEmpty) return;
    
    print('分钟分析: 超阈值次数 = $_snoreCountInCurrentMinute, 模式 = ${_monitorMode == 0 ? "仅监测" : "监测+叫醒"}, 录音状态 = $_isRecording, 录音路径 = $_currentRecordingPath');
    
    // 1分钟内超阈值次数 >= 8 判定为持续打鼾
    if (_snoreCountInCurrentMinute >= 8) {
      // 增加总打鼾事件计数
      _totalSnoreEvents++;
      print('检测到打鼾事件，总计: $_totalSnoreEvents 次');
      
      // 保存录音（无论哪种模式都保存）
      // 关键修复：检查录音状态或录音路径是否存在
      if (_isRecording || _currentRecordingPath != null) {
        final pathToSave = _currentRecordingPath;
        print('准备保存录音: $pathToSave');
        await _stopTemporaryRecordingAndSave(pathToSave, true);
      } else {
        print('警告：没有正在进行的录音可保存');
      }
      
      // 只有模式B（监测+叫醒）才触发报警
      if (_monitorMode == 1) {
        await _triggerRealAlarm();
      } else {
        print('模式A：仅保存录音，不触发叫醒');
      }
    } else {
      // 如果不是打鼾，删除临时录音
      if (_isRecording || _currentRecordingPath != null) {
        await _stopTemporaryRecordingAndSave(_currentRecordingPath, false);
      }
    }
    
    if (mounted) {
      setState(() => _snoreCountInCurrentMinute = 0);
    }
    
    // 重置录音周期标志，允许下一分钟开始新录音
    if (mounted) {
      setState(() {
        _isInRecordingCycle = false;
      });
    }
  }
  
  // 新增：停止录音并保存的辅助方法
  Future<void> _stopTemporaryRecordingAndSave(String? recordingPath, bool saveToHistory) async {
    try {
      // 先停止录音器（无论_isRecording状态如何，都尝试停止）
      try {
        if (_soundRecorder.isRecording) {
          await _soundRecorder.stopRecorder();
          print('录音器已停止');
        }
      } catch (e) {
        print('停止录音器时出错: $e');
      }
      _recordingStopTimer?.cancel();
      
      // 处理录音文件
      if (saveToHistory && recordingPath != null) {
        double maxDb = _thresholdDb + 5.0;
        if (_recentDbValues.isNotEmpty) {
          maxDb = _recentDbValues.reduce((a, b) => a > b ? a : b);
        }
        
        final file = File(recordingPath);
        print('检查录音文件是否存在: $recordingPath');
        
        // 等待一小段时间确保文件写入完成
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (await file.exists()) {
          final stat = await file.stat();
          final fileSize = stat.size;
          print('录音文件存在，大小: $fileSize bytes');
          
          // 只保存有内容的文件（大于1KB）
          if (fileSize > 1024) {
            _realRecordings.insert(0, SnoreRecording(
              filePath: recordingPath,
              dateTime: stat.modified,
              duration: const Duration(seconds: 60),
              maxDb: maxDb,
            ));
            
            // 限制最多保存20个录音文件
            if (_realRecordings.length > 20) {
              final oldestRecording = _realRecordings.removeLast();
              try {
                final oldFile = File(oldestRecording.filePath);
                if (await oldFile.exists()) {
                  await oldFile.delete();
                }
              } catch (e) {
                print('删除旧文件失败: $e');
              }
            }
            
            _realRecordings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
            if (mounted) {
              setState(() {}); // 刷新UI显示新录音
            }
            _currentSessionRecordingCount++; // 增加本次守护录音计数
            print('录音已保存到历史: $recordingPath, 本次守护录音数: $_currentSessionRecordingCount, 总录音数: ${_realRecordings.length}');
          } else {
            print('警告：录音文件太小，跳过保存: $fileSize bytes');
          }
        } else {
          print('警告：录音文件不存在: $recordingPath');
        }
      } else if (!saveToHistory && recordingPath != null) {
        // 删除临时录音文件
        try {
          final file = File(recordingPath);
          if (await file.exists()) {
            await file.delete();
            print('临时录音文件已删除: $recordingPath');
          }
        } catch (e) {
          print('删除临时文件失败: $e');
        }
      }
      
      // 重置状态
      if (mounted) {
        setState(() {
          _isRecording = false;
          _currentRecordingPath = null;
        });
      }
      
    } catch (e) {
      print('停止录音并保存失败: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _currentRecordingPath = null;
        });
      }
    }
  }
  
  // 触发真实报警
  Future<void> _triggerRealAlarm() async {
    if (_isAlarming) return;
    
    print('=== 检测到持续打鼾，触发真实报警 ===');
    print('当前录音数: ${_realRecordings.length}');
    
    // 停止噪音监测
    _stopNoiseMonitoring();
    
    // 注意：录音已经在 _stopTemporaryRecordingAndSave 中停止并保存了
    // 这里只需要确保录音器已停止（不要关闭，以便后续可以继续录音）
    try {
      if (_soundRecorder.isRecording) {
        await _soundRecorder.stopRecorder();
        print('报警前停止录音器');
      }
    } catch (e) {
      print('停止录音器失败: $e');
    }
    
    // 设置报警状态
    if (mounted) {
      setState(() {
        _isAlarming = true;
        _isRecording = false;
        _pendingAlarmDialog = true; // 标记有待显示的弹窗
      });
    }
    
    // 关键修改：在播放音乐之前先尝试点亮屏幕
    await _ensureScreenWakeForAlarm();
    
    // 播放报警音乐
    await _playAlarmMusic();
    
    // 显示弹窗（使用独立方法）
    if (mounted) {
      _pendingAlarmDialog = false;
      _showAlarmDialog();
    }
  }
  
  // 新增：尝试播放音频的辅助方法
  Future<bool> _tryPlayAudio(String path) async {
    try {
      await _audioPlayer.play(audio.AssetSource(path));
      await Future.delayed(const Duration(seconds: 2));
      return _audioPlayer.state == audio.PlayerState.playing;
    } catch (e) {
      print('播放 $path 失败: $e');
      return false;
    }
  }
  
  // 新增：尝试播放自定义音频的辅助方法
  Future<bool> _tryPlayCustomAudio(String path) async {
    try {
      await _audioPlayer.play(audio.DeviceFileSource(path));
      await Future.delayed(const Duration(seconds: 2));
      return _audioPlayer.state == audio.PlayerState.playing;
    } catch (e) {
      print('播放 $path 失败: $e');
      return false;
    }
  }
  
  // 新增：将Flutter asset复制到临时目录（iOS原生播放需要）
  Future<String?> _copyAssetToTemp(String assetPath) async {
    try {
      final byteData = await rootBundle.load('assets/$assetPath');
      final tempDir = await getTemporaryDirectory();
      final fileName = assetPath.split('/').last;
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      print('Asset已复制到临时目录: ${tempFile.path}');
      return tempFile.path;
    } catch (e) {
      print('复制asset到临时目录失败: $e');
      return null;
    }
  }
  
  // 播放报警音乐 - 优化版本（支持自定义铃声）
  Future<void> _playAlarmMusic() async {
    try {
      // iOS: 使用原生AVAudioPlayer播放，确保息屏时也能播放
      if (Platform.isIOS) {
        try {
          String? audioFilePath;
          
          // 检查是否为自定义铃声
          if (_isCustomRingtone(_selectedMusic)) {
            audioFilePath = _customMusicFiles[_selectedMusic];
          } else {
            // 内置铃声：需要将asset复制到临时目录
            final musicFile = _musicFiles[_selectedMusic];
            if (musicFile != null) {
              audioFilePath = await _copyAssetToTemp('audio/$musicFile');
            }
          }
          
          if (audioFilePath != null) {
            await _screenWakeChannel.invokeMethod('playAlarmAudio', {'filePath': audioFilePath});
            print('iOS原生播放铃声: $_selectedMusic, 路径: $audioFilePath');
          } else {
            await _screenWakeChannel.invokeMethod('playAlarmAudio');
            print('iOS原生播放默认铃声');
          }
          return; // iOS使用原生播放，直接返回
        } catch (e) {
          print('iOS原生音频播放失败: $e');
          // 失败时回退到Flutter播放
        }
      }
      
      // Android或iOS回退：使用Flutter audioplayers
      await _audioPlayer.stop();
      // 设置最大音量
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setReleaseMode(audio.ReleaseMode.loop);
      
      bool success = false;
      
      // 检查是否为自定义铃声
      if (_isCustomRingtone(_selectedMusic)) {
        // 播放自定义铃声（从文件路径）
        final customFilePath = _customMusicFiles[_selectedMusic];
        if (customFilePath != null) {
          success = await _tryPlayCustomAudio(customFilePath);
          print('播放自定义铃声: $_selectedMusic');
        }
      } else {
        // 播放内置铃声
        final musicFile = _musicFiles[_selectedMusic];
        if (musicFile != null) {
          success = await _tryPlayAudio('audio/$musicFile');
        }
      }
      
      if (!success) {
        print('主音频文件播放失败，尝试备用文件...');
        // 尝试播放第一个可用的内置备用文件
        for (final file in _musicFiles.values) {
          success = await _tryPlayAudio('audio/$file');
          if (success) break;
        }
      }
      
      if (success) {
        print('开始播放报警音乐: $_selectedMusic');
        
        // 逐渐提高音量（从0.5提高到1.0）
        for (int i = 0; i < 6; i++) {
          await Future.delayed(const Duration(seconds: 2));
          double newVolume = 0.5 + (i * 0.1);
          if (newVolume > 1.0) newVolume = 1.0;
          await _audioPlayer.setVolume(newVolume);
          print('音量调整到: $newVolume');
        }
      } else {
        print('所有音频文件播放均失败');
      }
    } catch (e) {
      print('播放音乐失败: $e');
    }
  }
  
  // 停止报警
  Future<void> _stopAlarm() async {
    await _audioPlayer.stop();
    
    // iOS: 停止原生音频播放
    if (Platform.isIOS) {
      try {
        await _screenWakeChannel.invokeMethod('stopAlarmAudio');
        print('iOS原生音频已停止');
      } catch (e) {
        print('停止iOS原生音频失败: $e');
      }
    }
    
    await _cancelNotification(); // 取消通知
    await _releaseScreenWakeLock(); // 释放屏幕唤醒锁
    if (mounted) {
      setState(() => _isAlarming = false);
    }
    
    // 恢复噪音监测
    if (_isRunning) {
      _startRealNoiseMonitoring();
    }
  }
  
  // 暂停监测10分钟
  void _pauseMonitoring() {
    if (mounted) {
      setState(() => _isRunning = false);
    }
    _stopNoiseMonitoring();
    
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n?.get('monitoring_paused_10min') ?? '监测已暂停10分钟'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
    
    Timer(const Duration(minutes: 10), () {
      if (mounted && _pageState == 2) {
        setState(() => _isRunning = true);
        _startRealNoiseMonitoring();
        print('10分钟暂停结束，恢复监测');
      }
    });
  }
  
  // 停止守护
  Future<void> _stopGuard() async {
    _guardTimer?.cancel();
    _stopNoiseMonitoring();
    _snoreAnalysisTimer?.cancel();
    await _stopTemporaryRecording(saveToHistory: false); // 停止时不保存
    await _stopAlarm();
    await _cancelNotification(); // 取消通知
    
    // 关键修复：守护结束后关闭录音器，释放麦克风
    try {
      await _soundRecorder.closeRecorder();
      print('守护结束，录音器已关闭');
    } catch (e) {
      print('关闭录音器失败: $e');
    }
    
    // 新增：确保在守护结束时禁用屏幕唤醒
    await WakelockPlus.disable();
    
    if (mounted) {
      setState(() {
        _isRunning = false;
        _pageState = 0;
        _recentDbValues.clear();
        _snoreCountInCurrentMinute = 0;
        _isAlarming = false;
        _isInRecordingCycle = false;
        _isPlayingRecording = false;
        _currentPlayingIndex = null;
      });
    }
    
    await _loadExistingRecordings();
    
    // 显示美化的守护结束总结弹窗
    _showGuardSummaryDialog();
    
    print('=== 守护结束 ===');
  }
  
  // 显示守护结束总结弹窗
  void _showGuardSummaryDialog() {
    if (!mounted) return;
    
    // 计算实际守护时长
    final l10n = AppLocalizations.of(context);
    String actualDuration = '';
    if (_guardStartTime != null) {
      final duration = DateTime.now().difference(_guardStartTime!);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (hours > 0) {
        actualDuration = '$hours${l10n?.get('hour') ?? '小时'}$minutes${l10n?.get('minute') ?? '分钟'}';
      } else {
        actualDuration = '$minutes${l10n?.get('minute') ?? '分钟'}';
      }
    } else {
      actualDuration = '$_selectedHours${l10n?.get('hour') ?? '小时'}';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.nights_stay, color: Color(0xFF4ECDC4), size: 28),
            ),
            const SizedBox(width: 12),
            Text(l10n?.get('guard_complete') ?? '守护完成', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // 守护时长
            _buildSummaryRow(Icons.access_time, l10n?.get('guard_duration') ?? '守护时长', actualDuration),
            const SizedBox(height: 16),
            // 打鼾次数
            _buildSummaryRow(Icons.mic, l10n?.get('snore_count') ?? '打鼾次数', '$_totalSnoreEvents ${l10n?.get('times') ?? '次'}'),
            const SizedBox(height: 16),
            // 监测模式
            _buildSummaryRow(
              _monitorMode == 0 ? Icons.mic : Icons.alarm,
              l10n?.get('monitor_mode') ?? '监测模式',
              _monitorMode == 0 ? (l10n?.get('mode_record_only') ?? '仅监测录音') : (l10n?.get('mode_record_alarm') ?? '监测并叫醒'),
            ),
            const SizedBox(height: 16),
            // 录音数量（显示本次守护的录音数）
            _buildSummaryRow(Icons.folder, l10n?.get('saved_recordings') ?? '保存录音', '$_currentSessionRecordingCount ${l10n?.get('count_unit') ?? '个'}'),
            const SizedBox(height: 20),
            // 评价
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _totalSnoreEvents == 0 
                    ? Colors.green.withOpacity(0.2) 
                    : (_totalSnoreEvents <= 3 ? Colors.orange.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _totalSnoreEvents == 0 ? Icons.sentiment_very_satisfied 
                        : (_totalSnoreEvents <= 3 ? Icons.sentiment_neutral : Icons.sentiment_dissatisfied),
                    color: _totalSnoreEvents == 0 ? Colors.green 
                        : (_totalSnoreEvents <= 3 ? Colors.orange : Colors.red),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _totalSnoreEvents == 0 
                          ? (l10n?.get('sleep_quality_good') ?? '太棒了！今晚睡眠质量很好') 
                          : (_totalSnoreEvents <= 3 ? (l10n?.get('sleep_quality_fair') ?? '睡眠质量一般，注意调整睡姿') : (l10n?.get('sleep_quality_poor') ?? '打鼾较多，建议关注睡眠健康')),
                      style: TextStyle(
                        color: _totalSnoreEvents == 0 ? Colors.green 
                            : (_totalSnoreEvents <= 3 ? Colors.orange : Colors.red),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n?.get('confirm') ?? '确定', style: const TextStyle(color: Color(0xFF4ECDC4), fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  // 构建总结弹窗的行
  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
  
  // 停止噪音监测
  void _stopNoiseMonitoring() {
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _noiseMeter = null;
  }
  
  // 播放真实的录音文件（通用方法，用于首页和监测中）
  Future<void> _playRealRecording(int index) async {
    if (index < _realRecordings.length) {
      final recording = _realRecordings[index];
      try {
        // 如果正在播放其他录音，先停止
        if (_isPlayingRecording && _currentPlayingIndex != null && _currentPlayingIndex != index) {
          await _stopPlayingRecording();
        }
        
        // 如果当前没有播放，设置播放状态
        if (!_isPlayingRecording) {
          if (_isRunning) {
            // 如果在监测中，暂停监测
            _stopNoiseMonitoring();
            print('播放录音时暂停监测');
          }
          
          if (mounted) {
            setState(() {
              _isPlayingRecording = true;
              _currentPlayingIndex = index;
            });
          }
        }
        
        await _audioPlayer.stop();
        await _audioPlayer.setVolume(0.7);
        await _audioPlayer.play(audio.DeviceFileSource(recording.filePath));
        
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n?.get('playing') ?? '正在播放'}: ${recording.displayTime} ${l10n?.get('recording_of') ?? '的录音'}'),
            backgroundColor: const Color(0xFF4ECDC4),
            duration: const Duration(seconds: 2),
          ),
        );
        
      } catch (e) {
        print('播放录音失败: $e');
        final l10nErr = AppLocalizations.of(context);
        _showErrorSnackBar(l10nErr?.get('play_failed') ?? '播放失败，文件可能已损坏');
        
        // 如果播放失败，确保重置状态
        if (_isPlayingRecording && _currentPlayingIndex == index) {
          await _stopPlayingRecording();
        }
      }
    }
  }
  
  // 新增：停止播放录音（通用方法）
  Future<void> _stopPlayingRecording() async {
    try {
      if (_audioPlayer.state == audio.PlayerState.playing) {
        await _audioPlayer.stop();
      }
      
      // 恢复状态
      if (_isPlayingRecording) {
        if (mounted) {
          setState(() {
            _isPlayingRecording = false;
            _currentPlayingIndex = null;
          });
        }
        
        // 如果在监测中，恢复监测
        if (_isRunning) {
          _startRealNoiseMonitoring();
          print('停止播放录音，恢复监测');
        }
        
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.get('stopped_playing') ?? '已停止播放录音'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('停止播放录音失败: $e');
      // 即使失败也要重置状态
      if (mounted) {
        setState(() {
          _isPlayingRecording = false;
          _currentPlayingIndex = null;
        });
      }
    }
  }
  
  // 删除真实录音
  Future<void> _deleteRealRecording(int index) async {
    if (index < _realRecordings.length) {
      final recording = _realRecordings[index];
      
      // 如果正在播放要删除的录音，先停止播放
      if (_isPlayingRecording && _currentPlayingIndex == index) {
        await _stopPlayingRecording();
      }
      
      try {
        final file = File(recording.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        _realRecordings.removeAt(index);
        if (mounted) {
          setState(() {});
        }
        
        _showSuccessSnackBar('已删除录音: ${recording.displayTime}');
      } catch (e) {
        print('删除录音失败: $e');
        _showErrorSnackBar('删除失败');
      }
    }
  }
  
  // 工具方法：显示SnackBar
  void _showPermissionSnackBar() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n?.get('mic_permission_needed') ?? '需要麦克风权限才能开始监测'), backgroundColor: Colors.red),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  // 格式化剩余时间
  String _formatRemainingTime() {
    int hours = _remainingSeconds ~/ 3600;
    int minutes = (_remainingSeconds % 3600) ~/ 60;
    int seconds = _remainingSeconds % 60;
    
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 处理Android返回键
        if (_pageState == 2 && _isRunning) {
          bool? shouldStop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context)?.get('confirm_exit') ?? '确认退出监测'),
              content: Text(AppLocalizations.of(context)?.get('confirm_exit_msg') ?? '监测正在进行中，确定要退出吗？退出将停止本次监测。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(AppLocalizations.of(context)?.get('cancel') ?? '取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(AppLocalizations.of(context)?.get('exit') ?? '退出'),
                ),
              ],
            ),
          );
          
          if (shouldStop == true) {
            await _stopGuard();
            return true;
          }
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1A3C),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_pageState != 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        Text(
                          AppLocalizations.of(context)?.appTitle ?? '鼾声守望者',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        // 权限设置按钮
                        if (Platform.isAndroid)
                          GestureDetector(
                            onTap: _showPermissionSettingsPage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ECDC4).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.security, color: Color(0xFF4ECDC4), size: 18),
                            ),
                          ),
                        // 语言切换按钮
                        GestureDetector(
                          onTap: () {
                            localeProvider.toggleLocale();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ECDC4).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF4ECDC4), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.language, color: Color(0xFF4ECDC4), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  localeProvider.isEnglish ? 'EN' : '中',
                                  style: const TextStyle(color: Color(0xFF4ECDC4), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 10),
                
                Expanded(flex: 6, child: _buildMainContent()),
                
                if (_pageState == 2) _buildMonitoringPanel(),
                
                Expanded(flex: 4, child: _buildRecordsList()),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // 构建主要内容
  Widget _buildMainContent() {
    switch (_pageState) {
      case 0:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 带脉冲动画的主按钮
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: GestureDetector(
                      onTap: _onMainButtonTap,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF4ECDC4), Color(0xFF4ECDC4)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF4ECDC4).withOpacity(0.4),
                              blurRadius: 25,
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: Color(0xFF4ECDC4).withOpacity(0.2),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.nights_stay_rounded, color: Colors.white, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.of(context)?.get('start_sleep_guard') ?? '开始睡眠守护',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // 提示文字
              Text(
                '点击开始守护您的睡眠',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
        
      case 1:
        return Column(
          children: [
            // 顶部导航栏
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _pageState = 0),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    AppLocalizations.of(context)?.get('monitor_mode') ?? '监测设置',
                    style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const SizedBox(width: 36), // 平衡布局
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                physics: const BouncingScrollPhysics(),
                children: [
                  // 监测模式选择 - 卡片式设计
                  _buildSectionTitle(Icons.tune_rounded, AppLocalizations.of(context)?.get('monitor_mode') ?? '监测模式'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildModeCard(
                        isSelected: _monitorMode == 0,
                        icon: Icons.mic_rounded,
                        title: AppLocalizations.of(context)?.get('mode_record_only') ?? '仅监测录音',
                        subtitle: AppLocalizations.of(context)?.get('mode_record_only_desc') ?? '记录打鼾，不叫醒',
                        onTap: () {
                          setState(() => _monitorMode = 0);
                          _saveUserSettings();
                        },
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _buildModeCard(
                        isSelected: _monitorMode == 1,
                        icon: Icons.alarm_rounded,
                        title: AppLocalizations.of(context)?.get('mode_record_alarm') ?? '监测并叫醒',
                        subtitle: AppLocalizations.of(context)?.get('mode_record_alarm_desc') ?? '检测打鼾时播放音乐',
                        onTap: () {
                          setState(() => _monitorMode = 1);
                          _saveUserSettings();
                        },
                      )),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 守护时长选择
                  _buildSectionTitle(Icons.schedule_rounded, AppLocalizations.of(context)?.get('select_duration') ?? '选择守护时长'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _cardColorLight.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        // 当前选择显示
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bedtime_rounded, color: _primaryColor, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              '$_selectedHours ${AppLocalizations.of(context)?.get('hours') ?? '小时'}',
                              style: const TextStyle(color: _primaryColor, fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                          children: _hourOptions.map((hour) => GestureDetector(
                            onTap: () {
                              setState(() => _selectedHours = hour);
                              _saveUserSettings();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: hour == _selectedHours
                                    ? const LinearGradient(colors: [_primaryColor, _primaryDark])
                                    : null,
                                color: hour == _selectedHours ? null : _cardColorLight,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: hour == _selectedHours
                                    ? [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 8)]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '$hour',
                                  style: TextStyle(
                                    color: hour == _selectedHours ? Colors.white : _textSecondary,
                                    fontSize: 16,
                                    fontWeight: hour == _selectedHours ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 叫醒音乐选择（仅在模式B时显示）
                  if (_monitorMode == 1) ...[
                    Text(AppLocalizations.of(context)?.get('select_alarm_music') ?? '选择叫醒音乐', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(height: 15),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                      child: DropdownButton<String>(
                        value: _allMusicOptions.contains(_selectedMusic) ? _selectedMusic : _musicOptions.first,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E3A5F),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        underline: const SizedBox(),
                        items: _allMusicOptions.map((music) => DropdownMenuItem(
                          value: music, 
                          child: Row(
                            children: [
                              if (_isCustomRingtone(music)) ...[
                                const Icon(Icons.person, color: Color(0xFF4ECDC4), size: 16),
                                const SizedBox(width: 8),
                              ],
                              Expanded(child: Text(music)),
                              if (_isCustomRingtone(music))
                                GestureDetector(
                                  onTap: () => _deleteCustomRingtone(music),
                                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                ),
                            ],
                          ),
                        )).toList(),
                        onChanged: (value) {
                          setState(() => _selectedMusic = value!);
                          _saveUserSettings();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 导入自定义铃声按钮
                    GestureDetector(
                      onTap: _importCustomRingtone,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFF4ECDC4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFF4ECDC4), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Color(0xFF4ECDC4), size: 20),
                            SizedBox(width: 8),
                            Text(AppLocalizations.of(context)?.get('import_custom_ringtone') ?? '导入自定义铃声', style: TextStyle(color: Color(0xFF4ECDC4), fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    if (_customMusicOptions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '已导入 ${_customMusicOptions.length} 个自定义铃声',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 25),
                  ],
                  // 分贝阈值设置
                  Column(
                    children: [
                      Text(AppLocalizations.of(context)?.get('db_threshold') ?? '分贝阈值设置', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('${_thresholdDb.toInt()}dB', textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF4ECDC4), fontSize: 18, fontWeight: FontWeight.bold)),
                      Slider(
                        value: _thresholdDb, min: 40, max: 80, divisions: 40,
                        label: '${_thresholdDb.toInt()}dB',
                        onChanged: (value) => setState(() => _thresholdDb = value),
                        onChangeEnd: (value) => _saveUserSettings(),
                        activeColor: const Color(0xFF4ECDC4),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text('${AppLocalizations.of(context)?.get('normal_snore') ?? '普通鼾声: 50-60dB'}\n${AppLocalizations.of(context)?.get('loud_snore') ?? '较大鼾声: 60-70dB'}\n${AppLocalizations.of(context)?.get('recommended') ?? '建议设置: 55-65dB'}',
                          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: ElevatedButton(
                onPressed: _startRealGuard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(AppLocalizations.of(context)?.get('start_sleep_guard') ?? '开始睡眠守护', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
        
      case 2:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(AppLocalizations.of(context)?.get('confirm_end') ?? '确认结束'),
                    content: Text(AppLocalizations.of(context)?.get('confirm_end_msg') ?? '确定要结束本次睡眠守护吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)?.get('cancel') ?? '取消')),
                      TextButton(onPressed: () { Navigator.pop(context); _stopGuard(); }, child: Text(AppLocalizations.of(context)?.get('end') ?? '结束')),
                    ],
                  ),
                ),
                child: Container(
                  width: 150, height: 150,
                  decoration: BoxDecoration(
                    color: _isAlarming ? Colors.orange : Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: (_isAlarming ? Colors.orange : Colors.green).withOpacity(0.5), blurRadius: 15, spreadRadius: 3)],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isAlarming ? Icons.warning : Icons.nights_stay, size: 32, color: Colors.white),
                        const SizedBox(height: 8),
                        Text(_formatRemainingTime(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        // 修改：报警中 -> 叫醒中
                        Text(_isAlarming ? (AppLocalizations.of(context)?.get('waking_up') ?? '叫醒中') : (AppLocalizations.of(context)?.get('tap_to_end') ?? '点击结束'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        if (_isPlayingRecording) Text(AppLocalizations.of(context)?.get('playing_recording') ?? '播放录音中', style: const TextStyle(color: Colors.yellow, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: _noiseMeter != null && !_isPlayingRecording ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [if (_noiseMeter != null && !_isPlayingRecording) BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 5)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isPlayingRecording ? (AppLocalizations.of(context)?.get('playing_recording') ?? '播放录音中') : (_noiseMeter != null ? (AppLocalizations.of(context)?.get('sleep_guarding') ?? '睡眠守护中') : (AppLocalizations.of(context)?.get('monitoring_paused') ?? '暂停打鼾监测')),
                    style: TextStyle(
                      color: _isPlayingRecording ? Colors.yellow : (_noiseMeter != null ? Colors.green : Colors.red),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        
      default:
        return Center(child: Text(AppLocalizations.of(context)?.get('unknown') ?? '未知状态', style: const TextStyle(color: Colors.white)));
    }
  }
  
  // 构建监测信息面板
  Widget _buildMonitoringPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _currentDb >= _thresholdDb ? Icons.volume_up : Icons.volume_down,
                size: 16,
                color: _currentDb >= _thresholdDb ? Colors.orange : const Color(0xFF4ECDC4),
              ),
              const SizedBox(width: 8),
              Text(
                '${AppLocalizations.of(context)?.get('current') ?? '当前'}: ${_currentDb.toStringAsFixed(1)}dB',
                style: TextStyle(
                  color: _currentDb >= _thresholdDb ? Colors.orange : Colors.white70,
                  fontSize: 16,
                  fontWeight: _currentDb >= _thresholdDb ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.hearing, size: 16, color: Color(0xFF4ECDC4)),
              const SizedBox(width: 8),
              Text('${AppLocalizations.of(context)?.get('threshold') ?? '阈值'}: ${_thresholdDb.toInt()}dB', style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _isPlayingRecording ? (AppLocalizations.of(context)?.get('playing_recording') ?? '播放录音中') : (_noiseMeter != null ? (AppLocalizations.of(context)?.get('snore_monitoring') ?? '打鼾监测中') : (AppLocalizations.of(context)?.get('monitoring_paused') ?? '暂停打鼾监测')),
            style: TextStyle(
              color: _isPlayingRecording ? Colors.yellow : (_noiseMeter != null ? Colors.green : Colors.red),
              fontSize: 12,
            ),
          ),
          if (_isAlarming) Text(AppLocalizations.of(context)?.get('waking_up') ?? '叫醒中', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  Widget _buildRecordsList() {
    if (_realRecordings.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primaryColor.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.nights_stay_rounded, size: 36, color: _primaryColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)?.get('no_recordings') ?? '暂无录音记录',
              style: TextStyle(color: _textSecondary, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                AppLocalizations.of(context)?.get('auto_save_hint') ?? '监测到打鼾后会自动保存录音',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary.withOpacity(0.6), fontSize: 12),
              ),
            ),
          ],
        ),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.graphic_eq_rounded, color: _primaryColor, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  AppLocalizations.of(context)?.get('snore_records') ?? '打鼾记录',
                  style: const TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_realRecordings.length}',
                    style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _realRecordings.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final recording = _realRecordings[index];
                final bool isPlaying = _isPlayingRecording && _currentPlayingIndex == index;
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    gradient: isPlaying
                        ? LinearGradient(
                            colors: [_primaryColor.withOpacity(0.2), _cardColor],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: isPlaying ? null : _cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPlaying ? _primaryColor.withOpacity(0.5) : _cardColorLight.withOpacity(0.3),
                      width: isPlaying ? 1.5 : 1,
                    ),
                    boxShadow: isPlaying
                        ? [BoxShadow(color: _primaryColor.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // 左侧图标
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isPlaying ? _primaryColor : _primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.mic_rounded,
                            color: isPlaying ? Colors.white : _primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // 中间信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${recording.displayDate} ${recording.displayTime}',
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.show_chart_rounded, size: 14, color: _warningColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${AppLocalizations.of(context)?.get('peak') ?? '峰值'}: ${recording.maxDb.toStringAsFixed(1)}dB',
                                    style: TextStyle(color: _textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // 右侧操作按钮
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 播放/停止按钮
                            GestureDetector(
                              onTap: () => isPlaying ? _stopPlayingRecording() : _playRealRecording(index),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isPlaying ? _errorColor.withOpacity(0.15) : _successColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                  color: isPlaying ? _errorColor : _successColor,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 删除按钮
                            GestureDetector(
                              onTap: () => _deleteRealRecording(index),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.delete_outline_rounded, color: _errorColor, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
  }
  
  // 构建设置页面的区块标题
  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _primaryColor, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
  
  // 构建模式选择卡片
  Widget _buildModeCard({
    required bool isSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_primaryColor, _primaryDark],
                )
              : null,
          color: isSelected ? null : _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primaryColor : _cardColorLight.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : _primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : _primaryColor, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : _textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white70 : _textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // 构建权限状态行
  Widget _buildPermissionRow(String name, PermissionStatus status) {
    Color color;
    String statusText;
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case PermissionStatus.granted: color = Colors.green; statusText = l10n?.get('granted') ?? '已授权'; break;
      case PermissionStatus.denied: color = Colors.orange; statusText = l10n?.get('denied') ?? '已拒绝'; break;
      case PermissionStatus.restricted: color = Colors.red; statusText = l10n?.get('restricted') ?? '受限制'; break;
      case PermissionStatus.limited: color = Colors.blue; statusText = l10n?.get('limited') ?? '部分授权'; break;
      case PermissionStatus.permanentlyDenied: color = Colors.red; statusText = l10n?.get('permanently_denied') ?? '永久拒绝'; break;
      default: color = Colors.grey; statusText = l10n?.get('unknown') ?? '未知';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$name: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(statusText, style: TextStyle(color: color)),
          const SizedBox(width: 8),
          Icon(status == PermissionStatus.granted ? Icons.check_circle : Icons.error, color: color, size: 16),
        ],
      ),
    );
  }
}

// 权限设置页面组件 - 独立的StatefulWidget，支持实时刷新
class _PermissionSettingsSheet extends StatefulWidget {
  final MethodChannel screenWakeChannel;
  final VoidCallback onRefresh;
  
  const _PermissionSettingsSheet({
    required this.screenWakeChannel,
    required this.onRefresh,
  });
  
  @override
  State<_PermissionSettingsSheet> createState() => _PermissionSettingsSheetState();
}

class _PermissionSettingsSheetState extends State<_PermissionSettingsSheet> {
  bool _isLoading = true;
  bool _batteryGranted = false;
  bool _overlayGranted = false;
  bool _microphoneGranted = false;
  bool _notificationGranted = false;
  
  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }
  
  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    
    try {
      // 获取原生权限状态
      if (Platform.isAndroid) {
        final result = await widget.screenWakeChannel.invokeMethod('checkPermissions');
        _batteryGranted = result['batteryOptimization'] ?? false;
        _overlayGranted = result['overlay'] ?? false;
      } else {
        _batteryGranted = true;
        _overlayGranted = true;
      }
      
      // 获取Flutter权限状态
      _microphoneGranted = await Permission.microphone.isGranted;
      _notificationGranted = await Permission.notification.isGranted;
      
    } catch (e) {
      print('加载权限状态失败: $e');
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E3A5F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 拖动指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Color(0xFF4ECDC4), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n?.get('permission_settings') ?? '权限设置',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // 刷新按钮
                  IconButton(
                    onPressed: _loadPermissions,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Color(0xFF4ECDC4), strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, color: Color(0xFF4ECDC4)),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            // 权限列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4ECDC4)))
                  : ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // 麦克风权限
                        _buildPermissionCard(
                          icon: Icons.mic_rounded,
                          title: l10n?.get('microphone') ?? '麦克风权限',
                          description: l10n?.get('microphone_desc') ?? '用于监测打鼾声音',
                          warning: l10n?.get('microphone_warning') ?? '未授权将无法监测打鼾',
                          isGranted: _microphoneGranted,
                          onTap: () async {
                            final status = await Permission.microphone.request();
                            if (status.isPermanentlyDenied) {
                              await openAppSettings();
                            }
                            await _loadPermissions();
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        // 通知权限
                        _buildPermissionCard(
                          icon: Icons.notifications_rounded,
                          title: l10n?.get('notification') ?? '通知权限',
                          description: l10n?.get('notification_desc') ?? '用于显示报警通知',
                          warning: l10n?.get('notification_warning') ?? '未授权将无法收到报警通知',
                          isGranted: _notificationGranted,
                          onTap: () async {
                            final status = await Permission.notification.request();
                            if (status.isPermanentlyDenied) {
                              await openAppSettings();
                            }
                            await _loadPermissions();
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        // 电池优化权限（仅Android）
                        if (Platform.isAndroid) ...[
                          _buildPermissionCard(
                            icon: Icons.battery_charging_full_rounded,
                            title: l10n?.get('battery_optimization') ?? '电池优化',
                            description: l10n?.get('battery_optimization_desc') ?? '允许应用在后台持续运行',
                            warning: l10n?.get('battery_optimization_warning') ?? '未开启可能导致后台被杀死',
                            isGranted: _batteryGranted,
                            onTap: () async {
                              await widget.screenWakeChannel.invokeMethod('openBatterySettings');
                            },
                          ),
                          const SizedBox(height: 12),
                          
                          // 悬浮窗权限
                          _buildPermissionCard(
                            icon: Icons.picture_in_picture_rounded,
                            title: l10n?.get('overlay_permission') ?? '悬浮窗权限',
                            description: l10n?.get('overlay_permission_desc') ?? '允许显示报警弹窗',
                            warning: l10n?.get('overlay_permission_warning') ?? '未开启可能导致弹窗不显示',
                            isGranted: _overlayGranted,
                            onTap: () async {
                              await widget.screenWakeChannel.invokeMethod('openOverlaySettings');
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        const SizedBox(height: 12),
                        
                        // 提示信息
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n?.get('permission_tip') ?? '提示：从系统设置返回后，点击刷新按钮更新权限状态',
                                  style: const TextStyle(color: Colors.blue, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 打开应用设置按钮
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await openAppSettings();
                            },
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: Text(l10n?.get('open_app_settings') ?? '打开应用设置'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4ECDC4),
                              side: const BorderSide(color: Color(0xFF4ECDC4)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required String warning,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isGranted 
            ? const Color(0xFF4CAF50).withOpacity(0.1) 
            : const Color(0xFFE53935).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted 
              ? const Color(0xFF4CAF50).withOpacity(0.3) 
              : const Color(0xFFE53935).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isGranted 
                      ? const Color(0xFF4CAF50).withOpacity(0.2) 
                      : const Color(0xFFE53935).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon, 
                  color: isGranted ? const Color(0xFF4CAF50) : const Color(0xFFE53935), 
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isGranted ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isGranted 
                      ? (l10n?.get('permission_granted') ?? '已授权')
                      : (l10n?.get('permission_not_granted') ?? '未授权'),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (!isGranted) ...[
            const SizedBox(height: 10),
            Text(
              warning,
              style: const TextStyle(color: Color(0xFFE53935), fontSize: 11),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: Text(l10n?.get('go_to_settings') ?? '去设置'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ECDC4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}