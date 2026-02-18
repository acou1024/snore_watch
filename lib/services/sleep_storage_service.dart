import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_record.dart';

/// 睡眠数据存储服务
class SleepStorageService {
  static const String _storageKey = 'sleep_records';
  static SleepStorageService? _instance;
  
  SleepStorageService._();
  
  static SleepStorageService get instance {
    _instance ??= SleepStorageService._();
    return _instance!;
  }

  /// 保存睡眠记录
  Future<void> saveSleepRecord(SleepRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getAllRecords();
    records.add(record);
    
    // 只保留最近90天的记录
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
    records.removeWhere((r) => r.startTime.isBefore(cutoffDate));
    
    final jsonList = records.map((r) => r.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  /// 获取所有记录
  Future<List<SleepRecord>> getAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => SleepRecord.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime)); // 按时间倒序
    } catch (e) {
      print('解析睡眠记录失败: $e');
      return [];
    }
  }

  /// 获取最近N天的记录
  Future<List<SleepRecord>> getRecentRecords(int days) async {
    final records = await getAllRecords();
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return records.where((r) => r.startTime.isAfter(cutoffDate)).toList();
  }

  /// 获取今天的记录
  Future<List<SleepRecord>> getTodayRecords() async {
    final records = await getAllRecords();
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    return records.where((r) => r.startTime.isAfter(startOfDay)).toList();
  }

  /// 获取每日统计数据（最近N天）
  Future<List<DailyStats>> getDailyStats(int days) async {
    final records = await getRecentRecords(days);
    final Map<String, List<SleepRecord>> groupedByDate = {};
    
    for (final record in records) {
      final dateKey = '${record.startTime.year}-${record.startTime.month}-${record.startTime.day}';
      groupedByDate.putIfAbsent(dateKey, () => []);
      groupedByDate[dateKey]!.add(record);
    }
    
    final stats = <DailyStats>[];
    final now = DateTime.now();
    
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month}-${date.day}';
      final dayRecords = groupedByDate[dateKey] ?? [];
      
      if (dayRecords.isNotEmpty) {
        final totalSnore = dayRecords.fold<int>(0, (sum, r) => sum + r.snoreCount);
        final totalDuration = dayRecords.fold<int>(0, (sum, r) => sum + r.durationMinutes);
        final avgScore = dayRecords.fold<int>(0, (sum, r) => sum + r.sleepScore) ~/ dayRecords.length;
        
        stats.add(DailyStats(
          date: DateTime(date.year, date.month, date.day),
          totalSnoreCount: totalSnore,
          totalDurationMinutes: totalDuration,
          avgSleepScore: avgScore,
          recordCount: dayRecords.length,
        ));
      } else {
        stats.add(DailyStats(
          date: DateTime(date.year, date.month, date.day),
          totalSnoreCount: 0,
          totalDurationMinutes: 0,
          avgSleepScore: 0,
          recordCount: 0,
        ));
      }
    }
    
    return stats;
  }

  /// 获取总体统计
  Future<Map<String, dynamic>> getOverallStats() async {
    final records = await getAllRecords();
    
    if (records.isEmpty) {
      return {
        'totalRecords': 0,
        'totalSleepMinutes': 0,
        'totalSnoreCount': 0,
        'avgSleepScore': 0,
        'avgSnorePerNight': 0.0,
        'bestScore': 0,
        'worstScore': 0,
      };
    }
    
    final totalSleepMinutes = records.fold<int>(0, (sum, r) => sum + r.durationMinutes);
    final totalSnoreCount = records.fold<int>(0, (sum, r) => sum + r.snoreCount);
    final avgSleepScore = records.fold<int>(0, (sum, r) => sum + r.sleepScore) ~/ records.length;
    final scores = records.map((r) => r.sleepScore).toList();
    
    return {
      'totalRecords': records.length,
      'totalSleepMinutes': totalSleepMinutes,
      'totalSnoreCount': totalSnoreCount,
      'avgSleepScore': avgSleepScore,
      'avgSnorePerNight': totalSnoreCount / records.length,
      'bestScore': scores.reduce((a, b) => a > b ? a : b),
      'worstScore': scores.reduce((a, b) => a < b ? a : b),
    };
  }

  /// 删除记录
  Future<void> deleteRecord(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getAllRecords();
    records.removeWhere((r) => r.id == id);
    
    final jsonList = records.map((r) => r.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  /// 清空所有记录
  Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
