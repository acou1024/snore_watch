import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';

class RecordingLibraryPage extends StatefulWidget {
  const RecordingLibraryPage({super.key});

  @override
  State<RecordingLibraryPage> createState() => _RecordingLibraryPageState();
}

class _RecordingLibraryPageState extends State<RecordingLibraryPage> {
  static const Color _primaryColor = Color(0xFF4ECDC4);
  static const Color _bgColor = Color(0xFF0D1B2A);
  static const Color _cardColor = Color(0xFF1B2838);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BEC5);
  static const Color _errorColor = Color(0xFFE53935);
  static const Color _successColor = Color(0xFF4CAF50);
  static const Color _warningColor = Color(0xFFFF9800);

  final audio.AudioPlayer _audioPlayer = audio.AudioPlayer();
  List<_RecordingItem> _recordings = [];
  int? _currentPlayingIndex;
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _setupAudioListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _currentPosition = position);
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _totalDuration = duration);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPlayingIndex = null;
          _currentPosition = Duration.zero;
        });
      }
    });
  }

  Future<void> _loadRecordings() async {
    setState(() => _isLoading = true);
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final snoreDir = Directory('${dir.path}/snore_recordings');
      
      if (!await snoreDir.exists()) {
        setState(() {
          _recordings = [];
          _isLoading = false;
        });
        return;
      }
      
      final files = await snoreDir.list().toList();
      final recordings = <_RecordingItem>[];
      
      for (final file in files) {
        if (file is File && _isAudioFile(file.path)) {
          final stat = await file.stat();
          final fileName = file.path.split('/').last.split('\\').last;
          
          // 从文件名解析日期时间
          DateTime? dateTime;
          try {
            // 文件名格式: snore_1708234567890.m4a (毫秒时间戳)
            final nameWithoutExt = fileName.split('.').first;
            final tsStr = nameWithoutExt.replaceAll('snore_', '').replaceAll('_pcm', '');
            final ts = int.tryParse(tsStr);
            if (ts != null) {
              dateTime = DateTime.fromMillisecondsSinceEpoch(ts);
            }
          } catch (_) {}
          
          dateTime ??= stat.modified;
          
          recordings.add(_RecordingItem(
            filePath: file.path,
            fileName: fileName,
            dateTime: dateTime,
            fileSize: stat.size,
          ));
        }
      }
      
      // 按时间倒序排列
      recordings.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      
      setState(() {
        _recordings = recordings;
        _isLoading = false;
      });
    } catch (e) {
      print('加载录音失败: $e');
      setState(() {
        _recordings = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _playRecording(int index) async {
    if (index >= _recordings.length) return;
    
    final recording = _recordings[index];
    
    try {
      if (_isPlaying && _currentPlayingIndex == index) {
        // 暂停当前播放
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
        return;
      }
      
      if (_isPlaying) {
        await _audioPlayer.stop();
      }
      
      await _audioPlayer.play(audio.DeviceFileSource(recording.filePath));
      setState(() {
        _isPlaying = true;
        _currentPlayingIndex = index;
      });
    } catch (e) {
      print('播放录音失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败'), backgroundColor: _errorColor),
        );
      }
    }
  }

  Future<void> _stopPlaying() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _currentPlayingIndex = null;
      _currentPosition = Duration.zero;
    });
  }

  Future<void> _deleteRecording(int index) async {
    if (index >= _recordings.length) return;
    
    final recording = _recordings[index];
    final l10n = AppLocalizations.of(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n?.get('confirm_delete') ?? '确认删除', style: const TextStyle(color: _textPrimary)),
        content: Text(l10n?.get('confirm_delete_recording') ?? '确定要删除这条录音吗？', style: const TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.get('cancel') ?? '取消', style: const TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.get('confirm') ?? '确定', style: const TextStyle(color: _errorColor)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    // 如果正在播放要删除的录音，先停止
    if (_isPlaying && _currentPlayingIndex == index) {
      await _stopPlaying();
    }
    
    try {
      final file = File(recording.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      setState(() => _recordings.removeAt(index));
    } catch (e) {
      print('删除录音失败: $e');
    }
  }

  Future<void> _deleteAllRecordings() async {
    final l10n = AppLocalizations.of(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n?.get('confirm_delete_all') ?? '确认全部删除', style: const TextStyle(color: _textPrimary)),
        content: Text(l10n?.get('confirm_delete_all_msg') ?? '确定要删除所有录音吗？此操作不可恢复。', style: const TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.get('cancel') ?? '取消', style: const TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n?.get('confirm') ?? '确定', style: const TextStyle(color: _errorColor)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    await _stopPlaying();
    
    for (final recording in _recordings) {
      try {
        final file = File(recording.filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    
    setState(() => _recordings.clear());
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool _isAudioFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.m4a') || ext.endsWith('.wav') || 
           ext.endsWith('.aac') || ext.endsWith('.ogg');
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
          l10n?.get('recording_library') ?? '录音库',
          style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_recordings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: _errorColor),
              onPressed: _deleteAllRecordings,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _recordings.isEmpty
              ? _buildEmptyState()
              : _buildRecordingList(),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mic_off_rounded, color: _primaryColor.withOpacity(0.5), size: 64),
          ),
          const SizedBox(height: 24),
          Text(
            l10n?.get('no_recordings_library') ?? '录音库为空',
            style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n?.get('no_recordings_library_hint') ?? '开始睡眠监测后，检测到的鼾声录音将保存在这里',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingList() {
    final l10n = AppLocalizations.of(context);
    
    // 按日期分组
    final Map<String, List<int>> groupedByDate = {};
    for (int i = 0; i < _recordings.length; i++) {
      final dateKey = '${_recordings[i].dateTime.year}-${_recordings[i].dateTime.month.toString().padLeft(2, '0')}-${_recordings[i].dateTime.day.toString().padLeft(2, '0')}';
      groupedByDate.putIfAbsent(dateKey, () => []);
      groupedByDate[dateKey]!.add(i);
    }
    
    return Column(
      children: [
        // 统计信息
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.mic, '${_recordings.length}', l10n?.get('total_recordings') ?? '总录音'),
              Container(width: 1, height: 30, color: _textSecondary.withOpacity(0.2)),
              _buildStatItem(Icons.storage, _formatFileSize(_recordings.fold(0, (sum, r) => sum + r.fileSize)), l10n?.get('total_size') ?? '总大小'),
              Container(width: 1, height: 30, color: _textSecondary.withOpacity(0.2)),
              _buildStatItem(Icons.calendar_today, '${groupedByDate.length}', l10n?.get('total_days') ?? '天数'),
            ],
          ),
        ),
        
        // 播放器（正在播放时显示）
        if (_isPlaying && _currentPlayingIndex != null)
          _buildPlayerBar(),
        
        // 录音列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recordings.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) => _buildRecordingCard(index),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: _primaryColor, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: _textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildPlayerBar() {
    final recording = _recordings[_currentPlayingIndex!];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor.withOpacity(0.2), _cardColor],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _playRecording(_currentPlayingIndex!),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${recording.dateTime.month}/${recording.dateTime.day} ${recording.dateTime.hour.toString().padLeft(2, '0')}:${recording.dateTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                      style: const TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _stopPlaying,
                child: Icon(Icons.stop_rounded, color: _errorColor, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _totalDuration.inMilliseconds > 0
                  ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                  : 0,
              backgroundColor: _textSecondary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(int index) {
    final recording = _recordings[index];
    final isPlaying = _isPlaying && _currentPlayingIndex == index;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isPlaying ? _primaryColor.withOpacity(0.1) : _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlaying ? _primaryColor.withOpacity(0.4) : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isPlaying ? _primaryColor : _primaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isPlaying ? Icons.graphic_eq_rounded : Icons.mic_rounded,
            color: isPlaying ? Colors.white : _primaryColor,
            size: 22,
          ),
        ),
        title: Text(
          '${recording.dateTime.month}/${recording.dateTime.day} ${recording.dateTime.hour.toString().padLeft(2, '0')}:${recording.dateTime.minute.toString().padLeft(2, '0')}:${recording.dateTime.second.toString().padLeft(2, '0')}',
          style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _formatFileSize(recording.fileSize),
          style: const TextStyle(color: _textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _playRecording(index),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isPlaying ? _warningColor.withOpacity(0.15) : _successColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isPlaying ? _warningColor : _successColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _deleteRecording(index),
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
      ),
    );
  }
}

class _RecordingItem {
  final String filePath;
  final String fileName;
  final DateTime dateTime;
  final int fileSize;

  _RecordingItem({
    required this.filePath,
    required this.fileName,
    required this.dateTime,
    required this.fileSize,
  });
}
