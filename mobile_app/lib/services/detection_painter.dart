import 'package:flutter/material.dart';

class DetectionPainter extends CustomPainter {
  final List<dynamic> detections;
  final double imageWidth;
  final double imageHeight;

  DetectionPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    final double scaleX = size.width / imageWidth;
    final double scaleY = size.height / imageHeight;

    final Paint boxPaint = Paint()
      ..color = const Color(0xFF2ECC71)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final Paint labelPaint = Paint()..color = const Color(0xFF2ECC71);

    for (final detection in detections) {
      if (detection is! Map) continue;

      final double x = (detection['x'] as num?)?.toDouble() ?? 0;

      final double y = (detection['y'] as num?)?.toDouble() ?? 0;

      final double width = (detection['width'] as num?)?.toDouble() ?? 0;

      final double height = (detection['height'] as num?)?.toDouble() ?? 0;

      final String label = (detection['label'] ?? 'Unknown').toString();

      final double confidence =
          (detection['confidence'] as num?)?.toDouble() ?? 0;

      if (width <= 0 || height <= 0) continue;

      final double left = x * scaleX;
      final double top = y * scaleY;
      final double right = (x + width) * scaleX;
      final double bottom = (y + height) * scaleY;

      final Rect rect = Rect.fromLTRB(left, top, right, bottom);

      canvas.drawRect(rect, boxPaint);

      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: '$label ${(confidence * 100).toStringAsFixed(1)}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      final double labelTop = (top - textPainter.height - 6).clamp(
        0.0,
        size.height,
      );

      final Rect background = Rect.fromLTWH(
        left,
        labelTop,
        textPainter.width + 12,
        textPainter.height + 6,
      );

      canvas.drawRect(background, labelPaint);

      textPainter.paint(canvas, Offset(left + 6, labelTop + 3));
    }
  }

  @override
  bool shouldRepaint(covariant DetectionPainter oldDelegate) {
    return true;
  }
}
