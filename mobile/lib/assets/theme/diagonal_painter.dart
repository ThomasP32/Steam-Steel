import 'package:flutter/material.dart';

class DiagonalStripePainter extends CustomPainter {
  DiagonalStripePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint =
        Paint()
          ..color = color.withValues(alpha: 0.1)
          ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final stripePaint =
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;

    const patternSize = 20.0;

    canvas
      ..save()
      ..clipRect(Offset.zero & size);

    final diagonal = size.width + size.height;

    for (var i = -diagonal; i < diagonal; i += patternSize) {
      final path =
          Path()
            ..moveTo(i, 0)
            ..lineTo(i + 10, 0)
            ..lineTo(i + 10 + size.height, size.height)
            ..lineTo(i + size.height, size.height)
            ..close();
      canvas.drawPath(path, stripePaint);
    }

    canvas.restore();

    final borderPaint =
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    final borderRect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawRect(borderRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PathPreviewPainter extends CustomPainter {
  PathPreviewPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint =
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final borderPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;

    final borderRect = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    canvas.drawRect(borderRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
