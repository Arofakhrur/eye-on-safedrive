import 'package:flutter/material.dart';
import 'package:eyeon/core/theme/app_theme.dart';

class NativeFaceMeshPainter extends CustomPainter {
  final List<double> points;
  final Size imageSize;
  final int rotation;
  final bool isDrowsy;

  NativeFaceMeshPainter(this.points, this.imageSize, this.rotation, this.isDrowsy);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0
      ..color = isDrowsy ? Colors.redAccent : AppColors.primary; // Neon Green/Yellow when awake, Red when drowsy

    // points is a flat array of [x, y, x, y, ...]
    for (int i = 0; i < points.length; i += 2) {
      final double x = translateX(points[i], size, imageSize, rotation);
      final double y = translateY(points[i + 1], size, imageSize, rotation);
      
      canvas.drawCircle(Offset(x, y), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(NativeFaceMeshPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.isDrowsy != isDrowsy;
  }

  double translateX(double x, Size canvasSize, Size imageSize, int rotation) {
    switch (rotation) {
      case 90:
      case 270:
        // Front camera normally acts as a mirror, so we flip X
        return canvasSize.width - x * canvasSize.width / imageSize.height;
      default:
        return canvasSize.width - x * canvasSize.width / imageSize.width;
    }
  }

  double translateY(double y, Size canvasSize, Size imageSize, int rotation) {
    switch (rotation) {
      case 90:
      case 270:
        return y * canvasSize.height / imageSize.width;
      default:
        return y * canvasSize.height / imageSize.height;
    }
  }
}
