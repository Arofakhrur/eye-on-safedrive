import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

import 'package:eyeon/research/pipeline_verification/models/pipeline_result_model.dart';
import 'package:eyeon/research/pipeline_verification/services/face_detector_service.dart';
import 'package:eyeon/research/pipeline_verification/services/ear_calculator.dart';
import 'package:eyeon/core/constants/app_constants.dart';

/// Progress snapshot emitted by [PipelineTestService] during verification.
class PipelineProgress {
  final int total;
  final int processed;
  final int successful;
  final int failedFace;
  final int failedLandmark;
  final String? currentFile;

  /// Phase label for auto-chaining mode, e.g. "Non Drowsy (1/2)" or "Drowsy (2/2)"
  final String? phase;

  /// Current subject being processed, e.g. "person5"
  final String? currentSubject;

  /// Number of subjects that have been fully calibrated (have baseline)
  final int calibratedSubjects;

  /// Number of subjects skipped (no non_drowsy data)
  final int skippedSubjects;

  const PipelineProgress({
    required this.total,
    required this.processed,
    required this.successful,
    required this.failedFace,
    required this.failedLandmark,
    this.currentFile,
    this.phase,
    this.currentSubject,
    this.calibratedSubjects = 0,
    this.skippedSubjects = 0,
  });

  double get percentage => total == 0 ? 0.0 : processed / total;
  bool get isDone => processed >= total;
}

/// Summary of a completed pipeline run, shown in the UI after processing.
class PipelineRunSummary {
  final int totalImages;
  final int successfulDetections;
  final int failedFace;
  final int failedLandmark;
  final int totalSubjects;
  final int calibratedSubjects;
  final List<String> skippedSubjects;
  final bool wasResumed;

  const PipelineRunSummary({
    required this.totalImages,
    required this.successfulDetections,
    required this.failedFace,
    required this.failedLandmark,
    required this.totalSubjects,
    required this.calibratedSubjects,
    required this.skippedSubjects,
    this.wasResumed = false,
  });
}

/// Orchestrates the full DDD pipeline verification process:
///
/// 1. Scans a root folder recursively for JPEG/PNG images.
/// 2. Parses subject + label from directory structure:
///    `<root>/<label>/<subject>/<image>` → label=drowsy|non_drowsy, subject=person_01
/// 3. Processes each image through ML Kit Face Mesh + EAR calculation.
/// 4. Computes per-subject baseline (robust avg EAR from non_drowsy + IQR) and relative EAR.
/// 5. Exports results as CSV via share_plus.
///
/// Supports two modes:
/// - **Sample mode**: Picks ~30 images (15 non_drowsy + 15 drowsy) from ONE subject
///   for quick validation.
/// - **Full dataset mode**: Auto-chains Non Drowsy → Drowsy across ALL subjects,
///   with progressive CSV writing, checkpoint/resume, and phase-aware progress.
class PipelineTestService extends ChangeNotifier {
  final _progressController = StreamController<PipelineProgress>.broadcast();

  /// Stream of progress updates emitted during [runVerification].
  Stream<PipelineProgress> get progressStream => _progressController.stream;

  List<PipelineResultModel> _results = [];
  bool _isRunning = false;
  bool _isCancelled = false;
  String? _errorMessage;
  PipelineRunSummary? _runSummary;

  List<PipelineResultModel> get results => List.unmodifiable(_results);
  bool get isRunning => _isRunning;
  bool get isCancelled => _isCancelled;
  String? get errorMessage => _errorMessage;
  PipelineRunSummary? get runSummary => _runSummary;

  // ── Step 1: Scan folder ──────────────────────────────────────────────────

  /// Scans [rootPath] recursively and returns all image file paths.
  ///
  /// Expected folder structure (Driver Drowsiness Dataset):
  /// ```
  /// Driver Drowsiness Dataset (DDD)/
  ///   Drowsy/
  ///     Person1/ ... Person28/
  ///       A0001.png
  ///   Non Drowsy/
  ///     Person1/ ... Person27/
  ///       A0001.png
  /// ```
  Future<List<String>> scanImageFiles(String rootPath) async {
    final dir = Directory(rootPath);
    final exists = await dir.exists();
    debugPrint('🔍 scanImageFiles → root: $rootPath');
    debugPrint('🔍 Directory exists: $exists');

    if (!exists) return [];

    // ── Enhanced logging: list top-level folders ──
    debugPrint('📂 ── Top-level folders in root ──');
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory) {
        final folderName = p.basename(entity.path);
        debugPrint('📂   ├─ $folderName');
        // List sub-folders (Person1, Person2, etc.)
        int subCount = 0;
        await for (final sub in entity.list(followLinks: false)) {
          if (sub is Directory) {
            subCount++;
            debugPrint('📂   │  ├─ ${p.basename(sub.path)}');
          }
        }
        debugPrint('📂   │  └─ ($subCount sub-folders)');
      }
    }
    debugPrint('📂 ── End folder listing ──');

    final files = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (['jpg', 'jpeg', 'png'].contains(ext)) {
          files.add(entity.path);
        }
      }
    }
    // Sort such that Non Drowsy comes before Drowsy for the same subject
    files.sort((a, b) {
      final isNonDrowsyA = a.toLowerCase().contains('non');
      final isNonDrowsyB = b.toLowerCase().contains('non');
      if (isNonDrowsyA && !isNonDrowsyB) return -1;
      if (!isNonDrowsyA && isNonDrowsyB) return 1;
      return a.compareTo(b); // Alphabetical fallback
    });

    // ── Enhanced logging: count files by label ──
    int nNonDrowsy = 0;
    int nDrowsy = 0;
    for (final f in files) {
      final comp = parsePathComponents(f, rootPath);
      if (comp['label'] == 'non_drowsy') {
        nNonDrowsy++;
      } else {
        nDrowsy++;
      }
    }
    debugPrint('🔍 Total images found: ${files.length} '
        '(Non Drowsy: $nNonDrowsy, Drowsy: $nDrowsy)');
    if (files.isNotEmpty) {
      debugPrint('🔍 First file: ${files.first}');
      debugPrint('🔍 Last file:  ${files.last}');
    }
    return files;
  }

  /// Parses the label and subject from a file path relative to [rootPath].
  ///
  /// Handles real DDD folder naming:
  ///   - `Drowsy`       → label `drowsy`
  ///   - `Non Drowsy`   → label `non_drowsy`
  ///
  /// Subject is lowercased for consistent grouping (e.g. `Person1` → `person1`).
  Map<String, String> parsePathComponents(String filePath, String rootPath) {
    // Normalize separators
    final normalized = filePath.replaceAll('\\', '/');
    final rootNorm = rootPath.replaceAll('\\', '/');

    // Strip root prefix
    String relative = normalized;
    if (relative.startsWith(rootNorm)) {
      relative = relative.substring(rootNorm.length);
    }

    // Remove leading slash
    if (relative.startsWith('/')) relative = relative.substring(1);

    // Split: [label, subject, filename, ...]
    final parts = relative.split('/');

    // Normalize label: case-insensitive, handle 'Non Drowsy' with space
    String rawLabel = parts.isNotEmpty ? parts[0] : 'unknown';
    String label;
    final labelLower = rawLabel.toLowerCase().replaceAll(' ', '_');
    if (labelLower.contains('non')) {
      label = 'non_drowsy';
    } else if (labelLower.contains('drowsy')) {
      label = 'drowsy';
    } else {
      label = labelLower; // keep as-is for unexpected folder names
    }

    final subject = parts.length >= 2 ? parts[1].toLowerCase() : 'unknown';

    return {'label': label, 'subject': subject};
  }

  // ── Step 2: Run verification ─────────────────────────────────────────────

  /// Runs the verification pipeline on images found in [rootPath].
  ///
  /// - [sampleMode] = true: Picks ~30 images from ONE subject (mixed labels)
  /// - [sampleMode] = false: Auto-chains Non Drowsy → Drowsy across ALL subjects
  ///
  /// Emits [PipelineProgress] updates via [progressStream].
  /// After completion, results are available via [results].
  Future<void> runVerification(String rootPath, {bool sampleMode = false}) async {
    if (_isRunning) return;

    _isRunning = true;
    _isCancelled = false; // Reset cancellation flag
    _results = [];
    _errorMessage = null;
    _runSummary = null;
    notifyListeners();

    try {
      final files = await scanImageFiles(rootPath);

      if (files.isEmpty) {
        _errorMessage =
            'Tidak ada file gambar ditemukan di folder ini.\n'
            'Pastikan struktur folder:\n'
            'DDD/Drowsy/Person1/*.png\n'
            'DDD/Non Drowsy/Person1/*.png';
        _isRunning = false;
        notifyListeners();
        return;
      }

      // ── Parse all files into label+subject first ──
      final parsed = <String, Map<String, String>>{};
      for (final f in files) {
        parsed[f] = parsePathComponents(f, rootPath);
      }

      List<String> filesToProcess;

      if (sampleMode) {
        filesToProcess = _buildSampleFileList(files, parsed);
        debugPrint('🧪 [Sample Mode] ${filesToProcess.length} files selected');
      } else {
        // Full dataset: Non Drowsy first, then Drowsy (already sorted)
        filesToProcess = files;
        debugPrint('🚀 [Full Dataset Mode] ${filesToProcess.length} files');
      }

      if (filesToProcess.isEmpty) {
        _errorMessage =
            'Tidak dapat menemukan subject dengan foto drowsy DAN non_drowsy.\n'
            'Pastikan folder DDD punya subfolder Drowsy/ dan Non Drowsy/ '
            'dengan PersonX/ yang sama.';
        _isRunning = false;
        notifyListeners();
        return;
      }

      // ── Check for checkpoint (resume support) ──
      Set<String> alreadyProcessed = {};
      File? checkpointFile;
      File? csvFile;
      bool wasResumed = false;

      if (!sampleMode) {
        final appDir = await getApplicationDocumentsDirectory();
        checkpointFile = File(p.join(appDir.path, 'pipeline_checkpoint.txt'));
        csvFile = File(p.join(appDir.path, 'pipeline_progressive.csv'));

        if (checkpointFile.existsSync()) {
          final checkpointContent = await checkpointFile.readAsString();
          alreadyProcessed = checkpointContent
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .toSet();
          wasResumed = alreadyProcessed.isNotEmpty;
          debugPrint('📌 [Checkpoint] Resuming — ${alreadyProcessed.length} files already processed');
        } else {
          // Start fresh CSV
          await csvFile.writeAsString('${PipelineResultModel.csvHeader}\n');
        }
      }

      int processed = 0;
      int successful = 0;
      int failedFace = 0;
      int failedLandmark = 0;
      final total = filesToProcess.length - alreadyProcessed.length;

      // Track per-subject non_drowsy EARs for baseline computation
      final Map<String, List<double>> subjectNonDrowsyEars = {};
      // Track computed baselines
      final Map<String, Map<String, dynamic>> subjectMetrics = {};
      // Track all subjects seen
      final Set<String> allSubjects = {};

      for (final filePath in filesToProcess) {
        // ── Check cancellation ──
        if (_isCancelled) {
          debugPrint('🛑 [PipelineTestService] Cancelled at $processed/$total');
          break;
        }

        // ── Skip already-processed files (resume) ──
        if (alreadyProcessed.contains(filePath)) continue;

        final comp = parsed[filePath] ?? parsePathComponents(filePath, rootPath);
        final label = comp['label']!;
        final subject = comp['subject']!;
        final imageName = filePath.split('/').last.split('\\').last;
        allSubjects.add(subject);

        // Determine current phase for progress display
        final phase = label == 'non_drowsy'
            ? 'Non Drowsy (Fase 1/2)'
            : 'Drowsy (Fase 2/2)';

        // Emit progress
        _progressController.add(
          PipelineProgress(
            total: total,
            processed: processed,
            successful: successful,
            failedFace: failedFace,
            failedLandmark: failedLandmark,
            currentFile: imageName,
            phase: sampleMode ? null : phase,
            currentSubject: subject,
            calibratedSubjects: subjectMetrics.values
                .where((m) => m['baseline'] != null)
                .length,
            skippedSubjects: subjectMetrics.values
                .where((m) => m['baseline'] == null)
                .length,
          ),
        );

        PipelineResultModel result;

        try {
          // Run ML Kit face mesh detection
          final detection = await FaceDetectorService.instance.processFile(
            filePath,
          );

          if (detection == null) {
            // Face not detected
            failedFace++;
            result = PipelineResultModel(
              subject: subject,
              label: label,
              imageName: imageName,
              imagePath: filePath,
              ear: 0.0,
              faceDetected: false,
              landmarkFound: false,
              errorNote: 'face_not_detected',
            );
          } else {
            // Face detected — compute EAR
            final detailedEar = EarCalculator.calculateDetailedEar(detection.points);

            if (detailedEar == null) {
              // Landmarks found but EAR calculation returned null
              failedLandmark++;
              result = PipelineResultModel(
                subject: subject,
                label: label,
                imageName: imageName,
                imagePath: filePath,
                ear: 0.0,
                faceDetected: true,
                landmarkFound: false,
                errorNote: 'landmark_ear_invalid',
              );
            } else {
              successful++;

              // Collect non_drowsy EARs for baseline computation
              if (label == 'non_drowsy') {
                subjectNonDrowsyEars
                    .putIfAbsent(subject, () => [])
                    .add(detailedEar.avgEar);
              }

              result = PipelineResultModel(
                subject: subject,
                label: label,
                imageName: imageName,
                imagePath: filePath,
                ear: detailedEar.avgEar,
                earL: detailedEar.leftEar,
                earR: detailedEar.rightEar,
                pointsL: detailedEar.leftPoints,
                pointsR: detailedEar.rightPoints,
                faceDetected: true,
                landmarkFound: true,
              );
            }
          }
        } catch (e) {
          failedFace++;
          result = PipelineResultModel(
            subject: subject,
            label: label,
            imageName: imageName,
            imagePath: filePath,
            ear: 0.0,
            faceDetected: false,
            landmarkFound: false,
            errorNote: 'exception: $e',
          );
        }

        _results.add(result);
        processed++;

        // ── Progressive CSV + checkpoint for full mode ──
        if (!sampleMode && csvFile != null && checkpointFile != null) {
          // Append result to CSV (post-processing will be done at end)
          await checkpointFile.writeAsString('$filePath\n', mode: FileMode.append);
        }

        // Small yield to keep UI responsive
        if (processed % 5 == 0) {
          await Future.delayed(const Duration(milliseconds: 2));
        }
      }

      // ── Post-process: compute baselines and apply to all results ──
      // Recompute baselines from accumulated non_drowsy EARs
      for (final subject in allSubjects) {
        final nonDrowsyEars = subjectNonDrowsyEars[subject];
        if (nonDrowsyEars == null || nonDrowsyEars.isEmpty) {
          subjectMetrics[subject] = {
            'baseline': null,
            'nValid': 0,
            'threshold': null,
          };
          debugPrint('⚠️ [Baseline] $subject — SKIPPED (no non_drowsy data)');
          continue;
        }

        final metrics = _computeSubjectBaseline(nonDrowsyEars);
        subjectMetrics[subject] = metrics;
        debugPrint(
          '✅ [Baseline] $subject — baseline=${(metrics['baseline'] as double?)?.toStringAsFixed(4)}, '
          'nValid=${metrics['nValid']}, '
          'threshold=${(metrics['threshold'] as double?)?.toStringAsFixed(4)}',
        );
      }

      // Apply baselines to all results
      _results = _results.map((r) {
        final metrics = subjectMetrics[r.subject];
        if (metrics != null) {
          return r.withPostProcessing(
            newBaseline: metrics['baseline'],
            nValid: metrics['nValid'],
            threshold: metrics['threshold'],
          );
        }
        return r;
      }).toList();

      // ── Write final CSV for full mode (with post-processed data) ──
      if (!sampleMode && csvFile != null) {
        final buffer = StringBuffer();
        buffer.writeln(PipelineResultModel.csvHeader);
        for (final r in _results) {
          buffer.writeln(r.toCsvRow());
        }
        await csvFile.writeAsString(buffer.toString());
        debugPrint('📝 [Progressive CSV] Written ${_results.length} rows to ${csvFile.path}');

        // Clean up checkpoint on successful completion
        if (!_isCancelled && checkpointFile != null && checkpointFile.existsSync()) {
          await checkpointFile.delete();
          debugPrint('🧹 [Checkpoint] Cleared — run completed successfully');
        }
      }

      // ── Build summary ──
      final calibrated = subjectMetrics.values
          .where((m) => m['baseline'] != null)
          .length;
      final skippedList = subjectMetrics.entries
          .where((e) => e.value['baseline'] == null)
          .map((e) => e.key)
          .toList();

      _runSummary = PipelineRunSummary(
        totalImages: processed,
        successfulDetections: successful,
        failedFace: failedFace,
        failedLandmark: failedLandmark,
        totalSubjects: allSubjects.length,
        calibratedSubjects: calibrated,
        skippedSubjects: skippedList,
        wasResumed: wasResumed,
      );

      // Emit final completed progress
      _progressController.add(
        PipelineProgress(
          total: total,
          processed: total,
          successful: successful,
          failedFace: failedFace,
          failedLandmark: failedLandmark,
          calibratedSubjects: calibrated,
          skippedSubjects: skippedList.length,
        ),
      );

      debugPrint(
        '✅ [PipelineTestService] Done: $processed images | '
        '$successful ok | $failedFace no-face | $failedLandmark no-landmark | '
        '$calibrated calibrated | ${skippedList.length} skipped',
      );
      if (skippedList.isNotEmpty) {
        debugPrint('⚠️ [Skipped subjects] ${skippedList.join(', ')}');
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      debugPrint('🔴 [PipelineTestService] Fatal error: $e');
    } finally {
      _isRunning = false;
      _isCancelled = false;
      FaceDetectorService.instance.dispose();
      notifyListeners();
    }
  }

  /// Builds a sample file list (~30 files) from ONE subject that has both
  /// drowsy AND non_drowsy images. Non_drowsy files are placed first so
  /// the baseline is computed before drowsy evaluation.
  List<String> _buildSampleFileList(
    List<String> allFiles,
    Map<String, Map<String, String>> parsed,
  ) {
    // Group files by subject and label
    final Map<String, List<String>> nonDrowsyBySubject = {};
    final Map<String, List<String>> drowsyBySubject = {};

    for (final f in allFiles) {
      final comp = parsed[f]!;
      final subject = comp['subject']!;
      final label = comp['label']!;

      if (label == 'non_drowsy') {
        nonDrowsyBySubject.putIfAbsent(subject, () => []).add(f);
      } else if (label == 'drowsy') {
        drowsyBySubject.putIfAbsent(subject, () => []).add(f);
      }
    }

    debugPrint('🧪 [Sample] Subjects with Non Drowsy: ${nonDrowsyBySubject.keys.toList()}');
    debugPrint('🧪 [Sample] Subjects with Drowsy: ${drowsyBySubject.keys.toList()}');

    // Find subjects that have BOTH labels
    final subjectsWithBoth = nonDrowsyBySubject.keys
        .where((s) => drowsyBySubject.containsKey(s))
        .toList();

    debugPrint('🧪 [Sample] Subjects with BOTH labels: $subjectsWithBoth');

    if (subjectsWithBoth.isEmpty) {
      debugPrint('⚠️ [Sample] No subject has both drowsy AND non_drowsy!');
      // Fallback: just take first 30 files
      return allFiles.take(30).toList();
    }

    // Pick the first subject with both labels
    final targetSubject = subjectsWithBoth.first;
    final ndFiles = nonDrowsyBySubject[targetSubject]!;
    final dFiles = drowsyBySubject[targetSubject]!;

    debugPrint('🧪 [Sample] Selected subject: $targetSubject');
    debugPrint('🧪 [Sample]   Non Drowsy files: ${ndFiles.length}');
    debugPrint('🧪 [Sample]   Drowsy files: ${dFiles.length}');

    // Take up to 15 of each, non_drowsy FIRST
    final selected = <String>[
      ...ndFiles.take(15),
      ...dFiles.take(15),
    ];

    debugPrint('🧪 [Sample] Final selection: ${selected.length} files '
        '(${ndFiles.take(15).length} non_drowsy + ${dFiles.take(15).length} drowsy)');

    return selected;
  }

  /// Signals the verification loop to stop after the current image.
  /// Results collected so far are preserved for export.
  void cancelVerification() {
    if (_isRunning) {
      _isCancelled = true;
      debugPrint('🛑 [PipelineTestService] Cancel requested');
    }
  }

  /// Returns true if a checkpoint file exists (incomplete previous run).
  Future<bool> hasCheckpoint() async {
    final appDir = await getApplicationDocumentsDirectory();
    final checkpointFile = File(p.join(appDir.path, 'pipeline_checkpoint.txt'));
    return checkpointFile.existsSync();
  }

  /// Deletes the checkpoint file to start fresh.
  Future<void> clearCheckpoint() async {
    final appDir = await getApplicationDocumentsDirectory();
    final checkpointFile = File(p.join(appDir.path, 'pipeline_checkpoint.txt'));
    final csvFile = File(p.join(appDir.path, 'pipeline_progressive.csv'));
    if (checkpointFile.existsSync()) await checkpointFile.delete();
    if (csvFile.existsSync()) await csvFile.delete();
    debugPrint('🧹 [Checkpoint] Cleared manually');
  }

  // ── Step 3: Compute baselines ────────────────────────────────────────────

  /// Computes baseline metrics for a single subject from their non_drowsy EAR values.
  /// Uses IQR filtering for robust average.
  Map<String, dynamic> _computeSubjectBaseline(List<double> nonDrowsyEars) {
    if (nonDrowsyEars.isEmpty) {
      return {'baseline': null, 'nValid': 0, 'threshold': null};
    }

    // Apply IQR filtering
    final sorted = List<double>.from(nonDrowsyEars)..sort();
    final q1 = sorted[(sorted.length * 0.25).floor()];
    final q3 = sorted[(sorted.length * 0.75).floor()];
    final iqr = q3 - q1;
    final lower = q1 - 1.5 * iqr;
    final upper = q3 + 1.5 * iqr;

    final filtered = sorted.where((v) => v >= lower && v <= upper).toList();
    final nValid = filtered.length;

    final robustAverage = filtered.isNotEmpty
        ? filtered.reduce((a, b) => a + b) / filtered.length
        : (sorted.reduce((a, b) => a + b) / sorted.length);

    // Threshold is 74% of baseline, clamped between 0.18 and 0.35
    final threshold = (robustAverage * DetectionConfig.earThresholdMultiplier).clamp(0.18, 0.35);

    return {
      'baseline': robustAverage,
      'nValid': nValid,
      'threshold': threshold,
    };
  }

  // ── Step 4: Export CSV ───────────────────────────────────────────────────

  /// Writes all results to a CSV file in the temp directory and shares it.
  ///
  /// File is named `eyeon_pipeline_verification_<timestamp>.csv`.
  Future<void> exportCsv() async {
    if (_results.isEmpty) return;

    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-')
          .substring(0, 19);
      final file = File(
        p.join(dir.path, 'eyeon_pipeline_verification_$timestamp.csv'),
      );

      final buffer = StringBuffer();
      buffer.writeln(PipelineResultModel.csvHeader);
      for (final r in _results) {
        buffer.writeln(r.toCsvRow());
      }

      await file.writeAsString(buffer.toString());

      debugPrint('📤 [PipelineTestService] Exporting CSV: ${file.path}');

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'EYE-ON Pipeline Verification Results',
        text:
            'EAR pipeline verification — ${_results.length} images processed.',
      );
    } catch (e) {
      debugPrint('🔴 [PipelineTestService] CSV export error: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _progressController.close();
    super.dispose();
  }
}
