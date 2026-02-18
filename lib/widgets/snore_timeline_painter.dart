import 'package:flutter/material.dart';
import '../models/sleep_record.dart';

/// 鼾声时间线画笔 - 绘制一整晚的鼾声分布图
class SnoreTimelinePainter extends CustomPainter {
  final DateTime startTime;
  final DateTime endTime;
  final List<SnoreEvent> events;

  SnoreTimelinePainter({
    required this.startTime,
    required this.endTime,
    required this.events,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalDuration = endTime.difference(startTime).inMinutes.toDouble();
    if (totalDuration <= 0) return;

    final double padding = 8;
    final double timelineY = size.height * 0.5;
    final double barWidth = size.width - padding * 2;

    // 绘制时间轴背景线
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(padding, timelineY),
      Offset(padding + barWidth, timelineY),
      linePaint,
    );

    // 绘制起止时间标签
    final startLabel = _formatTime(startTime);
    final endLabel = _formatTime(endTime);
    _drawText(canvas, startLabel, Offset(padding, size.height - 4), 10, Colors.white54);
    _drawText(canvas, endLabel, Offset(padding + barWidth - 30, size.height - 4), 10, Colors.white54);

    if (events.isEmpty) {
      // 无打鼾事件，显示提示
      _drawText(canvas, '无打鼾事件', Offset(size.width / 2 - 30, timelineY - 20), 11, Colors.white38);
      return;
    }

    // 绘制每个打鼾事件
    for (final event in events) {
      final minutesFromStart = event.time.difference(startTime).inMinutes.toDouble();
      final x = padding + (minutesFromStart / totalDuration) * barWidth;
      if (x < padding || x > padding + barWidth) continue;

      final color = _severityColor(event.severity);
      final radius = _severityRadius(event.severity);

      // 绘制事件柱
      final barPaint = Paint()
        ..color = color.withOpacity(0.7)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, timelineY), width: 6, height: radius * 2 + 8),
          const Radius.circular(3),
        ),
        barPaint,
      );

      // 绘制事件圆点
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, timelineY), radius, dotPaint);

      // 绘制光晕
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, timelineY), radius + 3, glowPaint);
    }

    // 绘制严重度图例
    _drawLegend(canvas, size);
  }

  void _drawLegend(Canvas canvas, Size size) {
    final legends = [
      ('轻微', const Color(0xFF4CAF50)),
      ('中度', const Color(0xFFFF9800)),
      ('严重', const Color(0xFFE53935)),
    ];
    double x = 8;
    final y = 4.0;
    for (final (label, color) in legends) {
      final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x + 4, y + 4), 4, dotPaint);
      _drawText(canvas, label, Offset(x + 12, y + 9), 9, Colors.white54);
      x += 48;
    }
  }

  Color _severityColor(int severity) {
    switch (severity) {
      case 0: return const Color(0xFF4CAF50); // 绿 - 轻微
      case 1: return const Color(0xFFFF9800); // 橙 - 中度
      case 2: return const Color(0xFFE53935); // 红 - 严重
      default: return Colors.white54;
    }
  }

  double _severityRadius(int severity) {
    switch (severity) {
      case 0: return 4;
      case 1: return 6;
      case 2: return 8;
      default: return 4;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _drawText(Canvas canvas, String text, Offset offset, double fontSize, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant SnoreTimelinePainter oldDelegate) {
    return events.length != oldDelegate.events.length;
  }
}

/// 鼾声时间线Widget - 封装CustomPainter
class SnoreTimelineWidget extends StatelessWidget {
  final DateTime startTime;
  final DateTime endTime;
  final List<SnoreEvent> events;
  final double height;

  const SnoreTimelineWidget({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.events,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: SnoreTimelinePainter(
          startTime: startTime,
          endTime: endTime,
          events: events,
        ),
      ),
    );
  }
}
