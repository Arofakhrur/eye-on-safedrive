import 'dart:math';

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
  final double earL;
  final double earR;
  final List<Point<int>> pointsL;
  final List<Point<int>> pointsR;

  /// Base metrics computed in post-processing
  final double? baseline;
  final int nValidCalibration;
  final double? thresholdPersonal;

  /// Relative EAR = ear / baseline. Ranges 0.0–1.0 (approximately).
  final double? relativeEar;
  
  /// Classification results
  final int? predictedLabel; // 1 (drowsy), 0 (non-drowsy)
  final String? classification; // TP, TN, FP, FN

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
    this.earL = 0.0,
    this.earR = 0.0,
    this.pointsL = const [],
    this.pointsR = const [],
    this.baseline,
    this.nValidCalibration = 0,
    this.thresholdPersonal,
    this.relativeEar,
    this.predictedLabel,
    this.classification,
    required this.faceDetected,
    required this.landmarkFound,
    this.errorNote,
  });

  /// Returns a copy with updated [baseline], [thresholdPersonal], [nValidCalibration], and classifications after post-processing.
  PipelineResultModel withPostProcessing({
    required double? newBaseline,
    required int nValid,
    required double? threshold,
  }) {
    double? rel;
    int? pred;
    String? cls;
    
    if (newBaseline != null && threshold != null) {
      rel = (newBaseline > 0) ? (ear / newBaseline).clamp(0.0, 2.0) : 0.0;
      
      // Calculate prediction based on threshold
      if (faceDetected && landmarkFound) {
        pred = (ear < threshold) ? 1 : 0;
        
        // Calculate TP/TN/FP/FN
        final int groundTruth = label == 'drowsy' ? 1 : 0;
        
        if (groundTruth == 1 && pred == 1) cls = 'TP';
        else if (groundTruth == 1 && pred == 0) cls = 'FN';
        else if (groundTruth == 0 && pred == 1) cls = 'FP';
        else if (groundTruth == 0 && pred == 0) cls = 'TN';
      }
    }

    return PipelineResultModel(
      subject: subject,
      label: label,
      imageName: imageName,
      imagePath: imagePath,
      ear: ear,
      earL: earL,
      earR: earR,
      pointsL: pointsL,
      pointsR: pointsR,
      baseline: newBaseline,
      nValidCalibration: nValid,
      thresholdPersonal: threshold,
      relativeEar: rel,
      predictedLabel: pred,
      classification: cls,
      faceDetected: faceDetected,
      landmarkFound: landmarkFound,
      errorNote: errorNote,
    );
  }

  /// Unique key combining label and subject, used for baseline grouping.
  /// e.g., "drowsy/person_01"
  String get groupKey => '$label/$subject';

  /// Converts point list to CSV string x,y,x,y...
  String _pointsToCsv(List<Point<int>> pts) {
    if (pts.isEmpty) return ',,,,,,,,,,,';
    return pts.map((p) => '${p.x},${p.y}').join(',');
  }

  /// CSV header row.
  static String get csvHeader =>
      'Subject,Image,Label_GT,'
      'Face_Detection,Landmark_Found,'
      'L_p1_x,L_p1_y,L_p2_x,L_p2_y,L_p3_x,L_p3_y,L_p4_x,L_p4_y,L_p5_x,L_p5_y,L_p6_x,L_p6_y,'
      'R_p1_x,R_p1_y,R_p2_x,R_p2_y,R_p3_x,R_p3_y,R_p4_x,R_p4_y,R_p5_x,R_p5_y,R_p6_x,R_p6_y,'
      'EAR_L,EAR_R,EAR_final,'
      'Baseline_EAR,N_valid_calibration,Threshold_personal,Relative_EAR,'
      'Predicted_label,Classification,Note';

  /// Converts this result to a single CSV row.
  String toCsvRow() {
    final gt = label == 'drowsy' ? '1' : '0';
    final fd = faceDetected ? '1' : '0';
    final lf = landmarkFound ? '1' : '0';
    
    return [
      subject,
      imageName,
      gt,
      fd,
      lf,
      _pointsToCsv(pointsL),
      _pointsToCsv(pointsR),
      earL.toStringAsFixed(4),
      earR.toStringAsFixed(4),
      ear.toStringAsFixed(4),
      baseline?.toStringAsFixed(4) ?? '',
      nValidCalibration.toString(),
      thresholdPersonal?.toStringAsFixed(4) ?? '',
      relativeEar?.toStringAsFixed(4) ?? '',
      predictedLabel?.toString() ?? '',
      classification ?? '',
      errorNote ?? '',
    ].join(',');
  }
}
