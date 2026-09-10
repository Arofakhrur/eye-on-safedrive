import 'dart:math';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:eyeon/core/utils/math_utils.dart';

class EarResult {
  final double ear;
  final List<Point<int>> points;
  const EarResult(this.ear, this.points);
}

class DetailedEarResult {
  final double leftEar;
  final double rightEar;
  final double avgEar;
  final List<Point<int>> leftPoints;
  final List<Point<int>> rightPoints;

  const DetailedEarResult({
    required this.leftEar,
    required this.rightEar,
    required this.avgEar,
    required this.leftPoints,
    required this.rightPoints,
  });
}

/// Rumus EAR: (||p2−p6|| + ||p3−p5||) / (2 × ||p1−p4||)
class EarCalculator {
  EarCalculator._();

  /// MediaPipe Face Mesh indices for the right eye.
  /// Order: [p1_outer, p2_top_outer, p3_top_inner, p4_inner, p5_bot_inner, p6_bot_outer]
  /// Same as used in CalibrationController and the native Android pipeline.
  static const List<int> rightEyeIndices = [33, 160, 158, 133, 153, 144];

  /// MediaPipe Face Mesh indices for the left eye.
  static const List<int> leftEyeIndices = [362, 385, 387, 263, 373, 380];

  /// Minimum number of face mesh points required for valid landmark access.
  static const int minPoints = 468;

  /// Calculates EAR for one eye given all 478 face mesh points and 6 landmark indices.
  ///
  /// Returns EarResult with 0.0 if invalid.
  static EarResult calculateForEye(
    List<FaceMeshPoint> allPoints,
    List<int> indices,
  ) {
    if (allPoints.length < minPoints) return const EarResult(0.0, []);

    final p1 = Point<int>(
      allPoints[indices[0]].x.toInt(),
      allPoints[indices[0]].y.toInt(),
    );
    final p2 = Point<int>(
      allPoints[indices[1]].x.toInt(),
      allPoints[indices[1]].y.toInt(),
    );
    final p3 = Point<int>(
      allPoints[indices[2]].x.toInt(),
      allPoints[indices[2]].y.toInt(),
    );
    final p4 = Point<int>(
      allPoints[indices[3]].x.toInt(),
      allPoints[indices[3]].y.toInt(),
    );
    final p5 = Point<int>(
      allPoints[indices[4]].x.toInt(),
      allPoints[indices[4]].y.toInt(),
    );
    final p6 = Point<int>(
      allPoints[indices[5]].x.toInt(),
      allPoints[indices[5]].y.toInt(),
    );

    final ear = MathUtils.calculateEAR(
      p1: p1,
      p2: p2,
      p3: p3,
      p4: p4,
      p5: p5,
      p6: p6,
    );
    
    return EarResult(ear, [p1, p2, p3, p4, p5, p6]);
  }

  /// Calculates the detailed EAR across both eyes from all face mesh points.
  static DetailedEarResult? calculateDetailedEar(List<FaceMeshPoint> allPoints) {
    if (allPoints.length < minPoints) return null;

    final right = calculateForEye(allPoints, rightEyeIndices);
    final left = calculateForEye(allPoints, leftEyeIndices);

    // Return null if both are zero (likely bad detection)
    if (right.ear == 0.0 && left.ear == 0.0) return null;

    return DetailedEarResult(
      leftEar: left.ear,
      rightEar: right.ear,
      avgEar: (right.ear + left.ear) / 2.0,
      leftPoints: left.points,
      rightPoints: right.points,
    );
  }
}
