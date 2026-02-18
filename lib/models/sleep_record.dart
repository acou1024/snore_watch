import 'dart:convert';

/// 睡眠记录数据模型
class SleepRecord {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final int snoreCount;
  final int recordingCount;
  final int monitorMode; // 0=仅监测, 1=监测并叫醒
  final double avgDb;
  final double maxDb;
  final List<SnoreEvent> snoreEvents;

  SleepRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.snoreCount,
    required this.recordingCount,
    required this.monitorMode,
    this.avgDb = 0.0,
    this.maxDb = 0.0,
    this.snoreEvents = const [],
  });

  /// 睡眠时长（分钟）
  int get durationMinutes => endTime.difference(startTime).inMinutes;

  /// 睡眠时长格式化
  String get durationFormatted {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    return '$minutes分钟';
  }

  /// 睡眠质量评分 (0-100)，基于严重度分级
  int get sleepScore {
    if (durationMinutes == 0) return 0;
    
    double score = 100.0;
    
    if (snoreEvents.isNotEmpty) {
      // 基于严重度扣分：轻微-5, 中度-10, 严重-20
      for (final event in snoreEvents) {
        switch (event.severity) {
          case 0: score -= 5; break;
          case 1: score -= 10; break;
          case 2: score -= 20; break;
        }
      }
      
      // 连续打鼾超过30分钟额外扣15分
      if (_hasConsecutiveSnoring(30)) {
        score -= 15;
      }
    } else {
      // 兼容旧数据：无事件详情时用总次数估算
      score -= (snoreCount * 5).clamp(0, 50);
      if (avgDb > 70) {
        score -= ((avgDb - 70) * 2).clamp(0, 20);
      }
    }
    
    return score.clamp(0, 100).toInt();
  }
  
  /// 检测是否有连续打鼾超过指定分钟数
  bool _hasConsecutiveSnoring(int minutes) {
    if (snoreEvents.length < 2) return false;
    final sorted = List<SnoreEvent>.from(snoreEvents)..sort((a, b) => a.time.compareTo(b.time));
    int consecutiveCount = 1;
    for (int i = 1; i < sorted.length; i++) {
      final gap = sorted[i].time.difference(sorted[i - 1].time).inMinutes;
      if (gap <= 2) {
        consecutiveCount++;
        if (consecutiveCount * 1 >= minutes) return true;
      } else {
        consecutiveCount = 1;
      }
    }
    return false;
  }

  /// 睡眠质量等级
  String get sleepQuality {
    final score = sleepScore;
    if (score >= 90) return '优秀';
    if (score >= 75) return '良好';
    if (score >= 60) return '一般';
    return '较差';
  }

  /// 睡眠质量等级（英文）
  String get sleepQualityEn {
    final score = sleepScore;
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Fair';
    return 'Poor';
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'snoreCount': snoreCount,
      'recordingCount': recordingCount,
      'monitorMode': monitorMode,
      'avgDb': avgDb,
      'maxDb': maxDb,
      'snoreEvents': snoreEvents.map((e) => e.toJson()).toList(),
    };
  }

  /// 从JSON创建
  factory SleepRecord.fromJson(Map<String, dynamic> json) {
    return SleepRecord(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      snoreCount: json['snoreCount'] as int,
      recordingCount: json['recordingCount'] as int,
      monitorMode: json['monitorMode'] as int? ?? 1,
      avgDb: (json['avgDb'] as num?)?.toDouble() ?? 0.0,
      maxDb: (json['maxDb'] as num?)?.toDouble() ?? 0.0,
      snoreEvents: (json['snoreEvents'] as List<dynamic>?)
          ?.map((e) => SnoreEvent.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

/// 打鼾事件
class SnoreEvent {
  final DateTime time;
  final double db;
  final int durationSeconds;
  final int severity; // 0=轻微, 1=中度, 2=严重
  final String? audioPath; // 对应录音文件路径

  SnoreEvent({
    required this.time,
    required this.db,
    this.durationSeconds = 0,
    this.severity = 0,
    this.audioPath,
  });
  
  /// 根据分贝和阈值计算严重度
  static int calculateSeverity(double db, double threshold) {
    if (db >= threshold + 20) return 2; // 严重
    if (db >= threshold + 10) return 1; // 中度
    return 0; // 轻微
  }
  
  /// 严重度标签
  String get severityLabel {
    switch (severity) {
      case 0: return '轻微';
      case 1: return '中度';
      case 2: return '严重';
      default: return '未知';
    }
  }
  
  String get severityLabelEn {
    switch (severity) {
      case 0: return 'Mild';
      case 1: return 'Moderate';
      case 2: return 'Severe';
      default: return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time.toIso8601String(),
      'db': db,
      'durationSeconds': durationSeconds,
      'severity': severity,
      'audioPath': audioPath,
    };
  }

  factory SnoreEvent.fromJson(Map<String, dynamic> json) {
    return SnoreEvent(
      time: DateTime.parse(json['time'] as String),
      db: (json['db'] as num).toDouble(),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      severity: json['severity'] as int? ?? 0,
      audioPath: json['audioPath'] as String?,
    );
  }
}

/// 每日统计数据
class DailyStats {
  final DateTime date;
  final int totalSnoreCount;
  final int totalDurationMinutes;
  final int avgSleepScore;
  final int recordCount;

  DailyStats({
    required this.date,
    required this.totalSnoreCount,
    required this.totalDurationMinutes,
    required this.avgSleepScore,
    required this.recordCount,
  });
}
