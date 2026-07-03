import 'dart:math';
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

    final Color mainColor = isDrowsy ? Colors.redAccent : AppColors.primary;



    final Paint boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = mainColor.withValues(alpha: 0.3);

    // 1. Calculate Bounding Box
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (int i = 0; i < points.length; i += 2) {
      final double x = translateX(points[i], size, imageSize, rotation);
      final double y = translateY(points[i + 1], size, imageSize, rotation);
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    // Draw Face Bounding Box
    canvas.drawRect(Rect.fromLTRB(minX, minY, maxX, maxY), boxPaint);

    // 2. Draw Eye/Cheek/Eyebrow "Mask" using distance from eye centers
    final List<int> rightEye = [33, 160, 158, 133, 153, 144];
    final List<int> leftEye = [362, 385, 387, 263, 373, 380];

    double rx = 0, ry = 0;
    for (int idx in rightEye) {
      if (idx * 2 + 1 >= points.length) continue;
      rx += translateX(points[idx * 2], size, imageSize, rotation);
      ry += translateY(points[idx * 2 + 1], size, imageSize, rotation);
    }
    rx /= rightEye.length;
    ry /= rightEye.length;

    double lx = 0, ly = 0;
    for (int idx in leftEye) {
      if (idx * 2 + 1 >= points.length) continue;
      lx += translateX(points[idx * 2], size, imageSize, rotation);
      ly += translateY(points[idx * 2 + 1], size, imageSize, rotation);
    }
    lx /= leftEye.length;
    ly /= leftEye.length;

    // Calculate distance between eyes
    double eyeDist = sqrt(pow(lx - rx, 2) + pow(ly - ry, 2));
    double thresholdRadius = eyeDist * 1.0; // Covers eyebrows and upper cheeks

    final Paint dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = mainColor;

    for (int i = 0; i < points.length; i += 2) {
      final double x = translateX(points[i], size, imageSize, rotation);
      final double y = translateY(points[i + 1], size, imageSize, rotation);
      
      double distR = sqrt(pow(x - rx, 2) + pow(y - ry, 2));
      double distL = sqrt(pow(x - lx, 2) + pow(y - ly, 2));

      // Draw dot if it's close to either eye (forming a mask over the upper face)
      if (distR < thresholdRadius || distL < thresholdRadius) {
        canvas.drawCircle(Offset(x, y), 1.8, dotPaint);
      }
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
