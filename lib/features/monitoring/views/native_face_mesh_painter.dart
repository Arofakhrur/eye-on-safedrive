import 'package:flutter/material.dart';
import 'package:eyeon/core/theme/app_theme.dart';

class NativeFaceMeshPainter extends CustomPainter {
  final List<double> points;
  final Size imageSize;
  final int rotation;
  final bool isDrowsy;
  final bool showEyeLandmarks;

  NativeFaceMeshPainter(
    this.points,
    this.imageSize,
    this.rotation,
    this.isDrowsy, {
    this.showEyeLandmarks = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final Color mainColor = isDrowsy ? Colors.redAccent : AppColors.primary;



    final Paint boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = mainColor.withValues(alpha: 0.3);

    final Paint dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = mainColor.withValues(alpha: 0.5);

    final Paint eyeHighlightPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF00E5FF); // Cyan highlight untuk titik EAR

    final Paint earLinePaintH = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.85); // Garis horizontal p1-p4

    final Paint earLinePaintV = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFFF9100).withValues(alpha: 0.85); // Garis vertikal p2-p6, p3-p5

    final Paint contourPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.4);

    // 1. Hitung Bounding Box & Gambar semua 468 titik Face Mesh
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (int i = 0; i < points.length; i += 2) {
      final double x = translateX(points[i], size, imageSize, rotation);
      final double y = translateY(points[i + 1], size, imageSize, rotation);

      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;

      // Gambar setiap titik Face Mesh umum (titik halus)
      canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
    }

    // 2. Gambar Face Bounding Box
    if (minX.isFinite && maxX.isFinite && minY.isFinite && maxY.isFinite) {
      canvas.drawRect(Rect.fromLTRB(minX, minY, maxX, maxY), boxPaint);
    }

    // 3. Highlight 12 Titik Kunci EAR + Nomor Indeks Landmark (Bukti Empiris Skripsi)
    if (showEyeLandmarks && points.length >= 468 * 2) {
      // Mata Kanan: p1=33, p2=160, p3=158, p4=133, p5=153, p6=144
      _drawEyeEAR(
        canvas: canvas,
        size: size,
        indices: const [33, 160, 158, 133, 153, 144],
        eyeLabel: 'MATA KANAN',
        eyeHighlightPaint: eyeHighlightPaint,
        earLinePaintH: earLinePaintH,
        earLinePaintV: earLinePaintV,
        contourPaint: contourPaint,
      );

      // Mata Kiri: p1=362, p2=385, p3=387, p4=263, p5=373, p6=380
      _drawEyeEAR(
        canvas: canvas,
        size: size,
        indices: const [362, 385, 387, 263, 373, 380],
        eyeLabel: 'MATA KIRI',
        eyeHighlightPaint: eyeHighlightPaint,
        earLinePaintH: earLinePaintH,
        earLinePaintV: earLinePaintV,
        contourPaint: contourPaint,
      );
    }
  }

  void _drawEyeEAR({
    required Canvas canvas,
    required Size size,
    required List<int> indices,
    required String eyeLabel,
    required Paint eyeHighlightPaint,
    required Paint earLinePaintH,
    required Paint earLinePaintV,
    required Paint contourPaint,
  }) {
    final offsets = <Offset>[];
    for (int idx in indices) {
      final x = translateX(points[idx * 2], size, imageSize, rotation);
      final y = translateY(points[idx * 2 + 1], size, imageSize, rotation);
      offsets.add(Offset(x, y));
    }

    final p1 = offsets[0]; // lateral canthus
    final p2 = offsets[1]; // top outer
    final p3 = offsets[2]; // top inner
    final p4 = offsets[3]; // medial canthus
    final p5 = offsets[4]; // bottom inner
    final p6 = offsets[5]; // bottom outer

    // Garis Kontur Kelopak Mata (p1 -> p2 -> p3 -> p4 -> p5 -> p6 -> p1)
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..lineTo(p5.dx, p5.dy)
      ..lineTo(p6.dx, p6.dy)
      ..close();
    canvas.drawPath(path, contourPaint);

    // Garis Ukur EAR: Horizontal ||p1 - p4|| (Cyan)
    canvas.drawLine(p1, p4, earLinePaintH);

    // Garis Ukur EAR: Vertikal ||p2 - p6|| dan ||p3 - p5|| (Oranye)
    canvas.drawLine(p2, p6, earLinePaintV);
    canvas.drawLine(p3, p5, earLinePaintV);

    // Hitung orientasi relatif untuk penempatan teks fanning-out (anti tumpang tindih)
    final int leftCanthusIdx = p1.dx < p4.dx ? 0 : 3;
    final int rightCanthusIdx = p1.dx < p4.dx ? 3 : 0;
    final int leftUpperIdx = p2.dx < p3.dx ? 1 : 2;
    final int rightUpperIdx = p2.dx < p3.dx ? 2 : 1;
    final int leftLowerIdx = p6.dx < p5.dx ? 5 : 4;
    final int rightLowerIdx = p6.dx < p5.dx ? 4 : 5;

    final bool staggerUpper = (offsets[rightUpperIdx].dx - offsets[leftUpperIdx].dx).abs() < 16.0;
    final bool staggerLower = (offsets[rightLowerIdx].dx - offsets[leftLowerIdx].dx).abs() < 16.0;

    final pointNames = ['p₁', 'p₂', 'p₃', 'p₄', 'p₅', 'p₆'];
    final pointBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.black;

    for (int i = 0; i < 6; i++) {
      final pt = offsets[i];
      final idxNum = indices[i];

      // Titik Highlight dibuat lebih tipis dan presisi (radius 1.8 px)
      canvas.drawCircle(pt, 1.8, eyeHighlightPaint);
      canvas.drawCircle(pt, 1.8, pointBorderPaint);

      // Warna pembeda kontras (Cyan untuk titik horizontal p1 & p4, Amber untuk vertikal)
      final Color tagColor = (i == 0 || i == 3)
          ? const Color(0xFF00E5FF)
          : const Color(0xFFFFB300);

      final prefix = '${pointNames[i]} ';
      final number = '$idxNum';

      final fillSpan = TextSpan(
        children: [
          TextSpan(text: prefix, style: TextStyle(color: tagColor)),
          TextSpan(text: number, style: const TextStyle(color: Colors.white)),
        ],
        style: const TextStyle(
          fontSize: 6.8,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      );

      final textPainter = TextPainter(
        text: fillSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Penempatan teks menjauhi pusat mata agar visibilitas mata & teks tidak tertutup
      double offsetX = pt.dx;
      double offsetY = pt.dy;

      if (i == leftCanthusIdx) {
        offsetX = pt.dx - textPainter.width - 3;
        offsetY = pt.dy - (textPainter.height / 2);
      } else if (i == rightCanthusIdx) {
        offsetX = pt.dx + 3;
        offsetY = pt.dy - (textPainter.height / 2);
      } else if (i == leftUpperIdx) {
        offsetX = pt.dx - (textPainter.width * 0.85);
        offsetY = pt.dy - textPainter.height - 2 - (staggerUpper ? 6.0 : 0.0);
      } else if (i == rightUpperIdx) {
        offsetX = pt.dx - (textPainter.width * 0.15);
        offsetY = pt.dy - textPainter.height - 2;
      } else if (i == leftLowerIdx) {
        offsetX = pt.dx - (textPainter.width * 0.85);
        offsetY = pt.dy + 2;
      } else if (i == rightLowerIdx) {
        offsetX = pt.dx - (textPainter.width * 0.15);
        offsetY = pt.dy + 2 + (staggerLower ? 6.0 : 0.0);
      }

      // Kontras tinggi tanpa box background: stroke hitam di belakang teks + teks berwarna terang
      final strokeSpan = TextSpan(
        children: [
          TextSpan(text: prefix),
          TextSpan(text: number),
        ],
        style: TextStyle(
          fontSize: 6.8,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = Colors.black,
        ),
      );

      final strokePainter = TextPainter(
        text: strokeSpan,
        textDirection: TextDirection.ltr,
      );
      strokePainter.layout();
      strokePainter.paint(canvas, Offset(offsetX, offsetY));

      textPainter.paint(canvas, Offset(offsetX, offsetY));
    }
  }

  @override
  bool shouldRepaint(NativeFaceMeshPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.isDrowsy != isDrowsy ||
        oldDelegate.showEyeLandmarks != showEyeLandmarks;
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
