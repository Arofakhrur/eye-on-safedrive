import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

class FaceMeshPainter extends CustomPainter {
  final List<FaceMesh> meshes;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool isDrowsy;

  FaceMeshPainter(this.meshes, this.imageSize, this.rotation, this.isDrowsy);

  @override
  void paint(Canvas canvas, Size size) {
    if (meshes.isEmpty) return;

    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0
      ..color = isDrowsy ? Colors.redAccent : const Color(0xFFD7F454); // Neon Green/Yellow when awake, Red when drowsy

    for (final FaceMesh mesh in meshes) {
      for (final FaceMeshPoint point in mesh.points) {
        // Translate points from image resolution to screen canvas resolution
        final double x = translateX(point.x.toDouble(), size, imageSize, rotation);
        final double y = translateY(point.y.toDouble(), size, imageSize, rotation);
        
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(FaceMeshPainter oldDelegate) {
    return oldDelegate.meshes != meshes || oldDelegate.isDrowsy != isDrowsy;
  }

  double translateX(double x, Size canvasSize, Size imageSize, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        // Front camera normally acts as a mirror, so we flip X
        return canvasSize.width - x * canvasSize.width / imageSize.height;
      default:
        return canvasSize.width - x * canvasSize.width / imageSize.width;
    }
  }

  double translateY(double y, Size canvasSize, Size imageSize, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * canvasSize.height / imageSize.width;
      default:
        return y * canvasSize.height / imageSize.height;
    }
  }
}
