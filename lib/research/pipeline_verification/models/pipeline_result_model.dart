/// Data model representing the EAR detection result for a single image
/// processed during the DDD pipeline verification test.
class PipelineResultModel {
  /// Folder name of the person/subject, parsed from directory structure.
  /// e.g., "person_01" from path `.../drowsy/person_01/frame_001.jpg`
  final String subject;

  /// Drowsiness label parsed from the parent directory.
  /// Either "drowsy" or "non_drowsy".
  final String label;

  /// Filename of the processed image, e.g., "frame_001.jpg".
  final String imageName;

  /// Full absolute path to the image file on device storage.
  final String imagePath;

  /// Raw Eye Aspect Ratio value computed by ML Kit + EAR formula.
  /// 0.0 if face or landmark detection failed.
  final double ear;

  /// Maximum EAR observed for this subject+label combination.
  /// Used as the open-eye baseline for relative EAR calculation.
  /// Set to 0.0 before post-processing.
  final double baseline;

  /// Relative EAR = ear / baseline. Ranges 0.0–1.0 (approximately).
  /// 1.0 means fully open eye relative to baseline.
  /// Set to 0.0 before post-processing.
  final double relativeEar;

  /// True if ML Kit successfully detected a face in the image.
  final bool faceDetected;

  /// True if the required 12 eye landmark points were found with valid indices.
  final bool landmarkFound;

  /// Optional human-readable error note for failed detections.
  final String? errorNote;

  const PipelineResultModel({
    required this.subject,
    required this.label,
    required this.imageName,
    required this.imagePath,
    required this.ear,
    required this.baseline,
    required this.relativeEar,
    required this.faceDetected,
    required this.landmarkFound,
    this.errorNote,
  });

  /// Returns a copy with updated [baseline] and [relativeEar] after post-processing.
  PipelineResultModel withBaseline(double baseline) {
    final rel = (baseline > 0) ? (ear / baseline).clamp(0.0, 2.0) : 0.0;
    return PipelineResultModel(
      subject: subject,
      label: label,
      imageName: imageName,
      imagePath: imagePath,
      ear: ear,
      baseline: baseline,
      relativeEar: rel,
      faceDetected: faceDetected,
      landmarkFound: landmarkFound,
      errorNote: errorNote,
    );
  }

  /// Unique key combining label and subject, used for baseline grouping.
  /// e.g., "drowsy/person_01"
  String get groupKey => '$label/$subject';

  /// CSV header row.
  static String get csvHeader =>
      'Subject,Label,Image,EAR,Baseline_EAR,Relative_EAR,Face_Detected,Landmark_Found,Note';

  /// Converts this result to a single CSV row.
  String toCsvRow() {
    return [
      subject,
      label,
      imageName,
      ear.toStringAsFixed(4),
      baseline.toStringAsFixed(4),
      relativeEar.toStringAsFixed(4),
      faceDetected.toString(),
      landmarkFound.toString(),
      errorNote ?? '',
    ].join(',');
  }
}
