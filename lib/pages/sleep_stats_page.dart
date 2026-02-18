import 'package:flutter/material.dart';
import '../models/sleep_record.dart';
import '../services/sleep_storage_service.dart';
import '../l10n/app_localizations.dart';

class SleepStatsPage extends StatefulWidget {
  const SleepStatsPage({super.key});

  @override
  State<SleepStatsPage> createState() => _SleepStatsPageState();
}

class _SleepStatsPageState extends State<SleepStatsPage> with SingleTickerProviderStateMixin {
  static const Color _primaryColor = Color(0xFF4ECDC4);
  static const Color _bgColor = Color(0xFF0D1B2A);
  static const Color _cardColor = Color(0xFF1B2838);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BEC5);

  late TabController _tabController;
  List<SleepRecord> _records = [];
  List<DailyStats> _dailyStats = [];
  Map<String, dynamic> _overallStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final storage = SleepStorageService.instance;
    final records = await storage.getAllRecords();
    final dailyStats = await storage.getDailyStats(7);
    final overallStats = await storage.getOverallStats();
    
    setState(() {
      _records = records;
      _dailyStats = dailyStats;
      _overallStats = overallStats;
      _isLoading = false;
    });
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
          l10n?.get('sleep_stats') ?? '睡眠统计',
          style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primaryColor,
          labelColor: _primaryColor,
          unselectedLabelColor: _textSecondary,
          tabs: [
            Tab(text: l10n?.get('overview') ?? '概览'),
            Tab(text: l10n?.get('history') ?? '历史'),
            Tab(text: l10n?.get('trends') ?? '趋势'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildHistoryTab(),
                _buildTrendsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final l10n = AppLocalizations.of(context);
    final totalRecords = _overallStats['totalRecords'] ?? 0;
    
    if (totalRecords == 0) {
      return _buildEmptyState(l10n?.get('no_sleep_data') ?? '暂无睡眠数据\n开始监测后将在这里显示统计');
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 总体评分卡片
          _buildScoreCard(),
          const SizedBox(height: 20),
          
          // 统计数据网格
          _buildStatsGrid(),
          const SizedBox(height: 20),
          
          // 最近7天趋势
          Text(
            l10n?.get('recent_7_days') ?? '最近7天',
            style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildMiniChart(),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    final l10n = AppLocalizations.of(context);
    final avgScore = _overallStats['avgSleepScore'] ?? 0;
    final quality = avgScore >= 90 ? (l10n?.get('excellent') ?? '优秀')
        : avgScore >= 75 ? (l10n?.get('good') ?? '良好')
        : avgScore >= 60 ? (l10n?.get('fair') ?? '一般')
        : (l10n?.get('poor') ?? '较差');
    
    final qualityColor = avgScore >= 90 ? Colors.green
        : avgScore >= 75 ? _primaryColor
        : avgScore >= 60 ? Colors.orange
        : Colors.red;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardColor, _cardColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            l10n?.get('avg_sleep_score') ?? '平均睡眠评分',
            style: const TextStyle(color: _textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$avgScore',
                style: TextStyle(
                  color: qualityColor,
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '/100',
                  style: TextStyle(color: _textSecondary, fontSize: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: qualityColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              quality,
              style: TextStyle(color: qualityColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final l10n = AppLocalizations.of(context);
    final totalRecords = _overallStats['totalRecords'] ?? 0;
    final totalSleepMinutes = _overallStats['totalSleepMinutes'] ?? 0;
    final totalSnoreCount = _overallStats['totalSnoreCount'] ?? 0;
    final avgSnorePerNight = _overallStats['avgSnorePerNight'] ?? 0.0;
    
    final totalHours = totalSleepMinutes ~/ 60;
    final totalMins = totalSleepMinutes % 60;
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          icon: Icons.nights_stay,
          label: l10n?.get('total_records') ?? '监测次数',
          value: '$totalRecords',
          unit: l10n?.get('times') ?? '次',
        ),
        _buildStatCard(
          icon: Icons.access_time,
          label: l10n?.get('total_sleep_time') ?? '总睡眠时长',
          value: '$totalHours',
          unit: l10n?.get('hours') ?? '小时',
          subValue: '$totalMins${l10n?.get('minutes') ?? '分钟'}',
        ),
        _buildStatCard(
          icon: Icons.mic,
          label: l10n?.get('total_snore') ?? '总打鼾次数',
          value: '$totalSnoreCount',
          unit: l10n?.get('times') ?? '次',
        ),
        _buildStatCard(
          icon: Icons.trending_down,
          label: l10n?.get('avg_snore_per_night') ?? '平均每晚打鼾',
          value: avgSnorePerNight.toStringAsFixed(1),
          unit: l10n?.get('times') ?? '次',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    String? subValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(color: _textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          if (subValue != null)
            Text(
              subValue,
              style: const TextStyle(color: _textSecondary, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniChart() {
    if (_dailyStats.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final maxSnore = _dailyStats.map((s) => s.totalSnoreCount).reduce((a, b) => a > b ? a : b);
    final chartHeight = 120.0;
    
    return Container(
      height: chartHeight + 40,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _dailyStats.reversed.map((stat) {
          final barHeight = maxSnore > 0 
              ? (stat.totalSnoreCount / maxSnore * chartHeight).clamp(4.0, chartHeight)
              : 4.0;
          final isToday = stat.date.day == DateTime.now().day;
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 24,
                height: barHeight,
                decoration: BoxDecoration(
                  color: isToday ? _primaryColor : _primaryColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${stat.date.month}/${stat.date.day}',
                style: TextStyle(
                  color: isToday ? _primaryColor : _textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final l10n = AppLocalizations.of(context);
    
    if (_records.isEmpty) {
      return _buildEmptyState(l10n?.get('no_history') ?? '暂无历史记录\n完成睡眠监测后将在这里显示');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return _buildHistoryCard(record);
      },
    );
  }

  Widget _buildHistoryCard(SleepRecord record) {
    final l10n = AppLocalizations.of(context);
    final scoreColor = record.sleepScore >= 90 ? Colors.green
        : record.sleepScore >= 75 ? _primaryColor
        : record.sleepScore >= 60 ? Colors.orange
        : Colors.red;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: _primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${record.startTime.month}/${record.startTime.day} ${record.startTime.hour.toString().padLeft(2, '0')}:${record.startTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${record.sleepScore}分',
                  style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHistoryDetail(Icons.access_time, l10n?.get('duration') ?? '时长', record.durationFormatted),
              const SizedBox(width: 24),
              _buildHistoryDetail(Icons.mic, l10n?.get('snore') ?? '打鼾', '${record.snoreCount}${l10n?.get('times') ?? '次'}'),
              const SizedBox(width: 24),
              _buildHistoryDetail(Icons.folder, l10n?.get('recordings') ?? '录音', '${record.recordingCount}${l10n?.get('count_unit') ?? '个'}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: _textSecondary, size: 14),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(color: _textSecondary, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(color: _textPrimary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTrendsTab() {
    final l10n = AppLocalizations.of(context);
    
    if (_records.isEmpty) {
      return _buildEmptyState(l10n?.get('no_trends') ?? '暂无趋势数据\n需要至少2次监测记录');
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 打鼾趋势图
          Text(
            l10n?.get('snore_trend') ?? '打鼾趋势（最近7天）',
            style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTrendChart(_dailyStats, (s) => s.totalSnoreCount.toDouble(), l10n?.get('snore_count') ?? '打鼾次数'),
          const SizedBox(height: 24),
          
          // 睡眠评分趋势
          Text(
            l10n?.get('score_trend') ?? '睡眠评分趋势（最近7天）',
            style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTrendChart(_dailyStats, (s) => s.avgSleepScore.toDouble(), l10n?.get('sleep_score') ?? '睡眠评分', maxValue: 100),
          const SizedBox(height: 24),
          
          // 睡眠建议
          _buildSleepAdvice(),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<DailyStats> stats, double Function(DailyStats) getValue, String label, {double? maxValue}) {
    if (stats.isEmpty) return const SizedBox.shrink();
    
    final values = stats.map(getValue).toList();
    final max = maxValue ?? (values.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1.0, double.infinity);
    final chartHeight = 150.0;
    
    return Container(
      height: chartHeight + 60,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: stats.reversed.toList().asMap().entries.map((entry) {
                final stat = entry.value;
                final value = getValue(stat);
                final barHeight = max > 0 ? (value / max * chartHeight).clamp(4.0, chartHeight) : 4.0;
                final isToday = stat.date.day == DateTime.now().day;
                
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      value.toInt().toString(),
                      style: TextStyle(color: _textSecondary, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 28,
                      height: barHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [_primaryColor.withOpacity(0.6), _primaryColor],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: isToday ? [
                          BoxShadow(color: _primaryColor.withOpacity(0.4), blurRadius: 8),
                        ] : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${stat.date.month}/${stat.date.day}',
                      style: TextStyle(
                        color: isToday ? _primaryColor : _textSecondary,
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepAdvice() {
    final l10n = AppLocalizations.of(context);
    final avgScore = _overallStats['avgSleepScore'] ?? 0;
    final avgSnore = _overallStats['avgSnorePerNight'] ?? 0.0;
    
    String advice;
    IconData icon;
    Color color;
    
    if (avgScore >= 90) {
      advice = l10n?.get('advice_excellent') ?? '您的睡眠质量非常好！继续保持良好的睡眠习惯。';
      icon = Icons.sentiment_very_satisfied;
      color = Colors.green;
    } else if (avgScore >= 75) {
      advice = l10n?.get('advice_good') ?? '睡眠质量良好。建议保持规律作息，避免睡前使用电子设备。';
      icon = Icons.sentiment_satisfied;
      color = _primaryColor;
    } else if (avgScore >= 60) {
      advice = l10n?.get('advice_fair') ?? '睡眠质量一般。建议调整睡姿，保持侧卧位可以减少打鼾。';
      icon = Icons.sentiment_neutral;
      color = Colors.orange;
    } else {
      advice = l10n?.get('advice_poor') ?? '打鼾较为频繁，建议关注睡眠健康。可尝试抬高枕头、减轻体重或咨询医生。';
      icon = Icons.sentiment_dissatisfied;
      color = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.get('sleep_advice') ?? '睡眠建议',
                  style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  advice,
                  style: const TextStyle(color: _textPrimary, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.nights_stay, color: _primaryColor.withOpacity(0.3), size: 80),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSecondary, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }
}
