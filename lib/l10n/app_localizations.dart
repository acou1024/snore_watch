import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);
  
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }
  
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  
  static final Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      // 应用标题
      'app_title': '鼾声守望者',
      
      // 主页
      'start_guard': '开始睡眠\n守护',
      'start_sleep_guard': '开始睡眠守护',
      
      // 设置页
      'monitor_mode': '监测模式',
      'mode_record_only': '仅监测录音',
      'mode_record_only_desc': '记录打鼾，不叫醒',
      'mode_record_alarm': '监测并叫醒',
      'mode_record_alarm_desc': '检测打鼾时播放音乐',
      'select_duration': '选择守护时长',
      'hours': '小时',
      'select_alarm_music': '选择叫醒音乐',
      'db_threshold': '分贝阈值设置',
      'normal_snore': '普通鼾声: 50-60dB',
      'loud_snore': '较大鼾声: 60-70dB',
      'recommended': '建议设置: 55-65dB',
      
      // 监测页
      'waking_up': '叫醒中',
      'tap_to_end': '点击结束',
      'playing_recording': '播放录音中',
      'sleep_guarding': '睡眠守护中',
      'monitoring_paused': '暂停打鼾监测',
      'snore_monitoring': '打鼾监测中',
      'current': '当前',
      'threshold': '阈值',
      
      // 弹窗
      'confirm_end': '确认结束',
      'confirm_end_msg': '确定要结束本次睡眠守护吗？',
      'cancel': '取消',
      'end': '结束',
      'confirm_exit': '确认退出监测',
      'confirm_exit_msg': '监测正在进行中，确定要退出吗？退出将停止本次监测。',
      'exit': '退出',
      
      // 报警弹窗
      'sleep_reminder': '睡眠提醒',
      'snore_detected': '检测到持续打鼾',
      'snoring_detected': '检测到持续打鼾',
      'adjust_position': '请调整睡姿缓解呼吸不畅',
      'ok_continue': '好的，继续监测',
      
      // 守护完成弹窗
      'guard_complete': '守护完成',
      'guard_duration': '守护时长',
      'snore_count': '打鼾次数',
      'times': '次',
      'saved_recordings': '保存录音',
      'count_unit': '个',
      'sleep_quality_good': '太棒了！今晚睡眠质量很好',
      'sleep_quality_fair': '睡眠质量一般，注意调整睡姿',
      'sleep_quality_poor': '打鼾较多，建议关注睡眠健康',
      'confirm': '确定',
      
      // 录音列表
      'snore_records': '打鼾记录',
      'no_recordings': '暂无录音记录',
      'auto_save_hint': '监测到打鼾后会自动保存录音',
      'check_permissions': '检查权限状态',
      'peak': '峰值',
      
      // 权限
      'permission_status': '权限状态',
      'microphone': '麦克风',
      'notification': '通知',
      'granted': '已授权',
      'denied': '已拒绝',
      'restricted': '受限制',
      'limited': '部分授权',
      'permanently_denied': '永久拒绝',
      'unknown': '未知',
      'permissions_needed': '应用需要这些权限以正常工作',
      'go_settings': '去设置',
      'mic_permission_needed': '需要麦克风权限才能开始监测',
      
      // 音乐名称
      'ocean_waves': '海浪声',
      'rain': '雨声',
      'stream': '溪流声',
      'waterfall': '瀑布声',
      'forest': '森林声',
      'wind': '风声',
      'thunder': '雷声',
      'insects': '虫鸣声',
      'frogs': '蛙鸣声',
      'birds': '鸟鸣',
      'piano': '钢琴曲',
      'guitar': '吉他曲',
      'harp': '竖琴曲',
      'flute': '长笛曲',
      'music_box': '音乐盒',
      'wind_chimes': '风铃声',
      'white_noise': '白噪音',
      'pink_noise': '粉噪音',
      'campfire': '篝火声',
      
      // 其他
      'deleted_recording': '已删除录音',
      'delete_failed': '删除失败',
      'play_failed': '播放失败，文件可能已损坏',
      'stopped_playing': '已停止播放录音',
      'playing': '正在播放',
      'recording_of': '的录音',
      'monitoring_paused_10min': '监测已暂停10分钟',
      
      // 自定义铃声
      'import_custom_ringtone': '导入自定义铃声',
      'custom_ringtones_count': '已导入 %d 个自定义铃声',
      'imported': '已导入',
      'ringtone_exists': '铃声已存在',
      'import_failed': '导入失败，请重试',
      'deleted': '已删除',
      
      // 时间单位
      'hour': '小时',
      'minute': '分钟',
      'hours_minutes': '%d小时%d分钟',
      'minutes_only': '%d分钟',
      
      // 权限设置
      'permission_settings': '权限设置',
      'battery_optimization': '电池优化',
      'battery_optimization_desc': '允许应用在后台持续运行，确保息屏时能正常监测和报警',
      'battery_optimization_warning': '未开启此权限可能导致应用在后台被系统杀死，无法正常监测',
      'overlay_permission': '悬浮窗权限',
      'overlay_permission_desc': '允许应用在其他应用上方显示报警弹窗',
      'overlay_permission_warning': '未开启此权限可能导致报警时无法显示提醒弹窗',
      'background_popup': '后台弹出界面',
      'background_popup_desc': '允许应用在后台时弹出界面显示报警',
      'background_popup_warning': '未开启此权限可能导致息屏报警时无法自动显示应用',
      'autostart': '自启动',
      'autostart_desc': '允许应用开机自启动',
      'go_to_settings': '去设置',
      'permission_granted': '已授权',
      'permission_not_granted': '未授权',
      'permission_check_title': '权限检查',
      'permission_check_msg': '为了确保应用能在息屏时正常工作，请授予以下权限：',
      'permission_required': '需要授权',
      'skip': '跳过',
      'open_app_settings': '打开应用设置',
      'permission_tip': '提示：部分权限需要在系统设置中手动开启',
      
      // 睡眠统计
      'sleep_stats': '睡眠统计',
      'overview': '概览',
      'history': '历史',
      'trends': '趋势',
      'no_sleep_data': '暂无睡眠数据\n开始监测后将在这里显示统计',
      'no_history': '暂无历史记录\n完成睡眠监测后将在这里显示',
      'no_trends': '暂无趋势数据\n需要至少2次监测记录',
      'avg_sleep_score': '平均睡眠评分',
      'excellent': '优秀',
      'good': '良好',
      'fair': '一般',
      'poor': '较差',
      'total_records': '监测次数',
      'total_sleep_time': '总睡眠时长',
      'total_snore': '总打鼾次数',
      'avg_snore_per_night': '平均每晚打鼾',
      'recent_7_days': '最近7天',
      'duration': '时长',
      'snore': '打鼾',
      'recordings': '录音',
      'snore_trend': '打鼾趋势（最近7天）',
      'score_trend': '睡眠评分趋势（最近7天）',
      'snore_count_label': '打鼾次数',
      'sleep_score': '睡眠评分',
      'sleep_advice': '睡眠建议',
      'advice_excellent': '您的睡眠质量非常好！继续保持良好的睡眠习惯。',
      'advice_good': '睡眠质量良好。建议保持规律作息，避免睡前使用电子设备。',
      'advice_fair': '睡眠质量一般。建议调整睡姿，保持侧卧位可以减少打鼾。',
      'advice_poor': '打鼾较为频繁，建议关注睡眠健康。可尝试抬高枕头、减轻体重或咨询医生。',
      'minutes': '分钟',
      'view_stats': '查看统计',
    },
    'en': {
      // App title
      'app_title': 'Snore Watch',
      
      // Home page
      'start_guard': 'Start Sleep\nGuard',
      'start_sleep_guard': 'Start Sleep Guard',
      
      // Settings page
      'monitor_mode': 'Monitor Mode',
      'mode_record_only': 'Record Only',
      'mode_record_only_desc': 'Record snoring, no alarm',
      'mode_record_alarm': 'Record & Alarm',
      'mode_record_alarm_desc': 'Play music when snoring detected',
      'select_duration': 'Select Duration',
      'hours': 'hours',
      'select_alarm_music': 'Select Alarm Music',
      'db_threshold': 'Decibel Threshold',
      'normal_snore': 'Normal snore: 50-60dB',
      'loud_snore': 'Loud snore: 60-70dB',
      'recommended': 'Recommended: 55-65dB',
      
      // Monitoring page
      'waking_up': 'Waking Up',
      'tap_to_end': 'Tap to End',
      'playing_recording': 'Playing Recording',
      'sleep_guarding': 'Sleep Guarding',
      'monitoring_paused': 'Monitoring Paused',
      'snore_monitoring': 'Snore Monitoring',
      'current': 'Current',
      'threshold': 'Threshold',
      
      // Dialogs
      'confirm_end': 'Confirm End',
      'confirm_end_msg': 'Are you sure you want to end this sleep guard session?',
      'cancel': 'Cancel',
      'end': 'End',
      'confirm_exit': 'Confirm Exit',
      'confirm_exit_msg': 'Monitoring is in progress. Are you sure you want to exit? This will stop the current session.',
      'exit': 'Exit',
      
      // Alarm dialog
      'sleep_reminder': 'Sleep Reminder',
      'snore_detected': 'Continuous snoring detected',
      'snoring_detected': 'Continuous snoring detected',
      'adjust_position': 'Please adjust your sleeping position',
      'ok_continue': 'OK, Continue Monitoring',
      
      // Guard complete dialog
      'guard_complete': 'Guard Complete',
      'guard_duration': 'Duration',
      'snore_count': 'Snore Count',
      'times': 'times',
      'saved_recordings': 'Saved Recordings',
      'count_unit': 'items',
      'sleep_quality_good': 'Excellent! Great sleep quality tonight',
      'sleep_quality_fair': 'Average sleep quality, try adjusting position',
      'sleep_quality_poor': 'Frequent snoring, consider sleep health',
      'confirm': 'OK',
      
      // Recording list
      'snore_records': 'Snore Records',
      'no_recordings': 'No recordings yet',
      'auto_save_hint': 'Recordings are saved automatically when snoring is detected',
      'check_permissions': 'Check Permission Status',
      'peak': 'Peak',
      
      // Permissions
      'permission_status': 'Permission Status',
      'microphone': 'Microphone',
      'notification': 'Notification',
      'granted': 'Granted',
      'denied': 'Denied',
      'restricted': 'Restricted',
      'limited': 'Limited',
      'permanently_denied': 'Permanently Denied',
      'unknown': 'Unknown',
      'permissions_needed': 'These permissions are required for the app to work properly',
      'go_settings': 'Go to Settings',
      'mic_permission_needed': 'Microphone permission is required to start monitoring',
      
      // Music names
      'ocean_waves': 'Ocean Waves',
      'rain': 'Rain',
      'stream': 'Stream',
      'waterfall': 'Waterfall',
      'forest': 'Forest',
      'wind': 'Wind',
      'thunder': 'Thunder',
      'insects': 'Insects',
      'frogs': 'Frogs',
      'birds': 'Birds',
      'piano': 'Piano',
      'guitar': 'Guitar',
      'harp': 'Harp',
      'flute': 'Flute',
      'music_box': 'Music Box',
      'wind_chimes': 'Wind Chimes',
      'white_noise': 'White Noise',
      'pink_noise': 'Pink Noise',
      'campfire': 'Campfire',
      
      // Others
      'deleted_recording': 'Recording deleted',
      'delete_failed': 'Delete failed',
      'play_failed': 'Playback failed, file may be corrupted',
      'stopped_playing': 'Stopped playing recording',
      'playing': 'Playing',
      'recording_of': 'recording',
      'monitoring_paused_10min': 'Monitoring paused for 10 minutes',
      
      // Custom ringtones
      'import_custom_ringtone': 'Import Custom Ringtone',
      'custom_ringtones_count': '%d custom ringtones imported',
      'imported': 'Imported',
      'ringtone_exists': 'Ringtone already exists',
      'import_failed': 'Import failed, please try again',
      'deleted': 'Deleted',
      
      // Time units
      'hour': 'hour',
      'minute': 'minute',
      'hours_minutes': '%dh %dm',
      'minutes_only': '%d minutes',
      
      // Permission settings
      'permission_settings': 'Permission Settings',
      'battery_optimization': 'Battery Optimization',
      'battery_optimization_desc': 'Allow app to run in background for monitoring and alarms',
      'battery_optimization_warning': 'Without this permission, the app may be killed by system and cannot monitor properly',
      'overlay_permission': 'Overlay Permission',
      'overlay_permission_desc': 'Allow app to display alarm dialogs over other apps',
      'overlay_permission_warning': 'Without this permission, alarm dialogs may not appear',
      'background_popup': 'Background Popup',
      'background_popup_desc': 'Allow app to show interface when in background',
      'background_popup_warning': 'Without this permission, app may not show when alarm triggers',
      'autostart': 'Auto Start',
      'autostart_desc': 'Allow app to start on boot',
      'go_to_settings': 'Go to Settings',
      'permission_granted': 'Granted',
      'permission_not_granted': 'Not Granted',
      'permission_check_title': 'Permission Check',
      'permission_check_msg': 'To ensure the app works properly when screen is off, please grant the following permissions:',
      'permission_required': 'Required',
      'skip': 'Skip',
      'open_app_settings': 'Open App Settings',
      'permission_tip': 'Tip: Some permissions need to be enabled manually in system settings',
      
      // Sleep stats
      'sleep_stats': 'Sleep Stats',
      'overview': 'Overview',
      'history': 'History',
      'trends': 'Trends',
      'no_sleep_data': 'No sleep data yet\nStart monitoring to see statistics here',
      'no_history': 'No history yet\nComplete a sleep session to see records here',
      'no_trends': 'No trend data yet\nNeed at least 2 monitoring sessions',
      'avg_sleep_score': 'Average Sleep Score',
      'excellent': 'Excellent',
      'good': 'Good',
      'fair': 'Fair',
      'poor': 'Poor',
      'total_records': 'Total Sessions',
      'total_sleep_time': 'Total Sleep Time',
      'total_snore': 'Total Snore Count',
      'avg_snore_per_night': 'Avg Snore Per Night',
      'recent_7_days': 'Last 7 Days',
      'duration': 'Duration',
      'snore': 'Snore',
      'recordings': 'Recordings',
      'snore_trend': 'Snore Trend (Last 7 Days)',
      'score_trend': 'Sleep Score Trend (Last 7 Days)',
      'snore_count_label': 'Snore Count',
      'sleep_score': 'Sleep Score',
      'sleep_advice': 'Sleep Advice',
      'advice_excellent': 'Your sleep quality is excellent! Keep up the good habits.',
      'advice_good': 'Good sleep quality. Try to maintain regular sleep schedule and avoid screens before bed.',
      'advice_fair': 'Average sleep quality. Try sleeping on your side to reduce snoring.',
      'advice_poor': 'Frequent snoring detected. Consider elevating your pillow, losing weight, or consulting a doctor.',
      'minutes': 'min',
      'view_stats': 'View Stats',
    },
  };
  
  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? 
           _localizedValues['zh']?[key] ?? 
           key;
  }
  
  // 便捷方法
  String get appTitle => get('app_title');
  String get startGuard => get('start_guard');
  String get startSleepGuard => get('start_sleep_guard');
  String get monitorMode => get('monitor_mode');
  String get modeRecordOnly => get('mode_record_only');
  String get modeRecordOnlyDesc => get('mode_record_only_desc');
  String get modeRecordAlarm => get('mode_record_alarm');
  String get modeRecordAlarmDesc => get('mode_record_alarm_desc');
  String get selectDuration => get('select_duration');
  String get hours => get('hours');
  String get selectAlarmMusic => get('select_alarm_music');
  String get dbThreshold => get('db_threshold');
  String get guardComplete => get('guard_complete');
  String get guardDuration => get('guard_duration');
  String get snoreCount => get('snore_count');
  String get times => get('times');
  String get confirm => get('confirm');
  String get cancel => get('cancel');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  
  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en'].contains(locale.languageCode);
  }
  
  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }
  
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
