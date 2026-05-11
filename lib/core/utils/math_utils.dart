import 'dart:math';

class MathUtils {
  /// Calculate Euclidean distance between two 2D points
  static double euclideanDistance(Point<int> p1, Point<int> p2) {
    return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2));
  }

  /// Calculate Euclidean distance between two 3D points
  static double euclideanDistance3D(
      double x1, double y1, double z1, double x2, double y2, double z2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2) + pow(z2 - z1, 2));
  }

  /// Calculate Eye Aspect Ratio (EAR) based on MediaPipe Face Mesh landmarks.
  /// 
  /// The formula is:
  /// EAR = (||p2-p6|| + ||p3-p5||) / (2 * ||p1-p4||)
  ///
  /// For MediaPipe:
  /// Right Eye:
  /// p1 (Left corner): 33
  /// p2 (Top-left): 160
  /// p3 (Top-right): 158
  /// p4 (Right corner): 133
  /// p5 (Bottom-right): 153
  /// p6 (Bottom-left): 144
  ///
  /// Left Eye:
  /// p1 (Left corner): 362
  /// p2 (Top-left): 385
  /// p3 (Top-right): 387
  /// p4 (Right corner): 263
  /// p5 (Bottom-right): 373
  /// p6 (Bottom-left): 380
  static double calculateEAR({
    required Point<int> p1,
    required Point<int> p2,
    required Point<int> p3,
    required Point<int> p4,
    required Point<int> p5,
    required Point<int> p6,
  }) {
    double vertical1 = euclideanDistance(p2, p6);
    double vertical2 = euclideanDistance(p3, p5);
    double horizontal = euclideanDistance(p1, p4);

    if (horizontal == 0.0) return 0.0; // Prevent division by zero

    return (vertical1 + vertical2) / (2.0 * horizontal);
  }
}
