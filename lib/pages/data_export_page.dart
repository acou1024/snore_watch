import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sleep_record.dart';
import '../services/sleep_storage_service.dart';
import '../l10n/app_localizations.dart';

class DataExportPage extends StatefulWidget {
  const DataExportPage({super.key});

  @override
  State<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends State<DataExportPage> {
  static const Color _primaryColor = Color(0xFF4ECDC4);
  static const Color _bgColor = Color(0xFF0D1B2A);
  static const Color _cardColor = Color(0xFF1B2838);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BEC5);

  List<SleepRecord> _records = [];
  bool _isLoading = true;
  bool _isExporting = false;
  final GlobalKey _reportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final records = await SleepStorageService.instance.getAllRecords();
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  /// 导出CSV文件
  Future<void> _exportCSV() async {
    if (_records.isEmpty) return;
    setState(() => _isExporting = true);

    try {
      final csvBuffer = StringBuffer();
      // CSV头
      csvBuffer.writeln('Date,Start Time,End Time,Duration (min),Snore Count,Sleep Score,Avg dB,Max dB,Mode');

      for (final record in _records) {
        final startDate = '${record.startTime.year}-${record.startTime.month.toString().padLeft(2, '0')}-${record.startTime.day.toString().padLeft(2, '0')}';
        final startTime = '${record.startTime.hour.toString().padLeft(2, '0')}:${record.startTime.minute.toString().padLeft(2, '0')}';
        final endTime = '${record.endTime.hour.toString().padLeft(2, '0')}:${record.endTime.minute.toString().padLeft(2, '0')}';
        final mode = record.monitorMode == 0 ? 'Record Only' : 'Record & Alarm';

        csvBuffer.writeln('$startDate,$startTime,$endTime,${record.durationMinutes},${record.snoreCount},${record.sleepScore},${record.avgDb.toStringAsFixed(1)},${record.maxDb.toStringAsFixed(1)},$mode');
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/snore_watch_data.csv');
      await file.writeAsString(csvBuffer.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Snore Watch Sleep Data',
      );
    } catch (e) {
      print('导出CSV失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  /// 生成并分享睡眠报告图片
  Future<void> _shareReportImage() async {
    if (_records.isEmpty) return;
    setState(() => _isExporting = true);

    try {
      // 等待渲染完成
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _reportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('无法获取报告渲染对象');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('无法生成图片');

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/snore_watch_report.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Snore Watch Sleep Report',
      );
    } catch (e) {
      print('分享报告失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n?.get('data_export') ?? '数据导出',
          style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _records.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 导出选项
                      _buildExportOptions(),
                      const SizedBox(height: 24),

                      // 报告预览
                      Text(
                        l10n?.get('report_preview') ?? '报告预览',
                        style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      RepaintBoundary(
                        key: _reportKey,
                        child: _buildReportCard(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.file_download_off, color: _primaryColor.withOpacity(0.3), size: 80),
          const SizedBox(height: 20),
          Text(
            l10n?.get('no_data_export') ?? '暂无数据可导出\n完成睡眠监测后即可导出',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSecondary, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOptions() {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // CSV导出
        _buildExportButton(
          icon: Icons.table_chart_rounded,
          title: l10n?.get('export_csv') ?? '导出CSV数据',
          subtitle: l10n?.get('export_csv_desc') ?? '导出所有睡眠数据为CSV表格文件，可在Excel中打开',
          onTap: _exportCSV,
          color: _primaryColor,
        ),
        const SizedBox(height: 12),
        // 报告图片分享
        _buildExportButton(
          icon: Icons.image_rounded,
          title: l10n?.get('share_report') ?? '分享睡眠报告',
          subtitle: l10n?.get('share_report_desc') ?? '生成精美的睡眠报告图片，可分享到社交媒体',
          onTap: _shareReportImage,
          color: const Color(0xFF6C63FF),
        ),
      ],
    );
  }

  Widget _buildExportButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: _isExporting ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isExporting
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: color, strokeWidth: 2),
                    )
                  : Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard() {
    final l10n = AppLocalizations.of(context);
    final overallStats = _calculateOverallStats();
    final recentRecords = _records.take(7).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2A), Color(0xFF1B2838)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.nights_stay, color: _primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n?.get('app_title') ?? '鼾声守望者',
                    style: const TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    l10n?.get('sleep_report') ?? '睡眠报告',
                    style: const TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 评分
          Center(
            child: Column(
              children: [
                Text(
                  '${overallStats['avgScore']}',
                  style: TextStyle(
                    color: _getScoreColor(overallStats['avgScore'] as int),
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  l10n?.get('avg_sleep_score') ?? '平均睡眠评分',
                  style: const TextStyle(color: _textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 统计数据
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildReportStat(l10n?.get('total_records') ?? '监测次数', '${overallStats['totalRecords']}'),
              _buildReportStat(l10n?.get('total_snore') ?? '总打鼾', '${overallStats['totalSnore']}'),
              _buildReportStat(l10n?.get('avg_snore_per_night') ?? '平均/晚', '${(overallStats['avgSnore'] as double).toStringAsFixed(1)}'),
            ],
          ),
          const SizedBox(height: 20),

          // 最近7天柱状图
          if (recentRecords.isNotEmpty) ...[
            Text(
              l10n?.get('recent_7_days') ?? '最近7天',
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final date = DateTime.now().subtract(Duration(days: 6 - i));
                  final dayRecords = _records.where((r) =>
                      r.startTime.year == date.year &&
                      r.startTime.month == date.month &&
                      r.startTime.day == date.day).toList();
                  final snoreCount = dayRecords.fold<int>(0, (sum, r) => sum + r.snoreCount);
                  final maxSnore = _records.isEmpty ? 1 : _records.map((r) => r.snoreCount).reduce((a, b) => a > b ? a : b).clamp(1, 999);
                  final barHeight = (snoreCount / maxSnore * 60).clamp(4.0, 60.0);

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 20,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(dayRecords.isEmpty ? 0.2 : 0.8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.month}/${date.day}',
                        style: const TextStyle(color: _textSecondary, fontSize: 9),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],

          const SizedBox(height: 16),
          // 日期
          Center(
            child: Text(
              '${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}',
              style: const TextStyle(color: _textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: _primaryColor, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11)),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return _primaryColor;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Map<String, dynamic> _calculateOverallStats() {
    if (_records.isEmpty) {
      return {'totalRecords': 0, 'totalSnore': 0, 'avgSnore': 0.0, 'avgScore': 0};
    }

    final totalSnore = _records.fold<int>(0, (sum, r) => sum + r.snoreCount);
    final avgScore = _records.fold<int>(0, (sum, r) => sum + r.sleepScore) ~/ _records.length;

    return {
      'totalRecords': _records.length,
      'totalSnore': totalSnore,
      'avgSnore': totalSnore / _records.length,
      'avgScore': avgScore,
    };
  }
}
