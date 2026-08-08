import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

/// Result of processing a single static image file through ML Kit Face Mesh Detection.
class FaceMeshDetectionResult {
  /// All 478 face mesh points detected by ML Kit.
  final List<FaceMeshPoint> points;

  const FaceMeshDetectionResult({required this.points});
}

/// Singleton wrapper around [FaceMeshDetector] for processing static image files
/// (JPEG/PNG from device storage) during pipeline verification.
///
/// This is isolated from the real-time camera pipeline used in monitoring
/// and calibration screens. It uses [InputImage.fromFilePath] instead of
/// the NV21 camera stream conversion used in [CameraUtils].
class FaceDetectorService {
  FaceDetectorService._();

  static FaceDetectorService? _instance;

  /// Returns the singleton instance, creating it on first access.
  static FaceDetectorService get instance {
    _instance ??= FaceDetectorService._();
    return _instance!;
  }

  FaceMeshDetector? _detector;

  /// Lazily initialise the [FaceMeshDetector].
  FaceMeshDetector get _meshDetector {
    _detector ??= FaceMeshDetector(
      option: FaceMeshDetectorOptions.faceMesh,
    );
    return _detector!;
  }

  /// Processes a static image file at [filePath] through ML Kit Face Mesh Detection.
  ///
  /// Returns a [FaceMeshDetectionResult] with the 478 face mesh points if a face
  /// was detected, or `null` if:
  /// - The file could not be read
  /// - No face was detected in the image
  /// - An exception occurred during processing
  Future<FaceMeshDetectionResult?> processFile(String filePath) async {
    try {
      // ML Kit can directly read image files via fromFilePath —
      // no NV21 byte conversion needed (unlike the camera stream path).
      final inputImage = InputImage.fromFilePath(filePath);

      final meshes = await _meshDetector.processImage(inputImage);

      if (meshes.isEmpty) {
        debugPrint('🟡 [FaceDetectorService] No face in: $filePath');
        return null;
      }

      return FaceMeshDetectionResult(points: meshes.first.points);
    } catch (e) {
      debugPrint('🔴 [FaceDetectorService] Error processing $filePath: $e');
      return null;
    }
  }

  /// Releases the ML Kit detector resources.
  /// Call this when the pipeline verification session ends.
  void dispose() {
    _detector?.close();
    _detector = null;
    _instance = null;
  }
}
