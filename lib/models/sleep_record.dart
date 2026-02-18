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

  /// 睡眠质量评分 (0-100)
  int get sleepScore {
    if (durationMinutes == 0) return 0;
    
    // 基础分100分
    double score = 100.0;
    
    // 每次打鼾扣5分，最多扣50分
    score -= (snoreCount * 5).clamp(0, 50);
    
    // 如果平均分贝超过70，额外扣分
    if (avgDb > 70) {
      score -= ((avgDb - 70) * 2).clamp(0, 20);
    }
    
    return score.clamp(0, 100).toInt();
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

  SnoreEvent({
    required this.time,
    required this.db,
    this.durationSeconds = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'time': time.toIso8601String(),
      'db': db,
      'durationSeconds': durationSeconds,
    };
  }

  factory SnoreEvent.fromJson(Map<String, dynamic> json) {
    return SnoreEvent(
      time: DateTime.parse(json['time'] as String),
      db: (json['db'] as num).toDouble(),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
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
