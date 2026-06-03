import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Optimized video buffer that stores JPEG-compressed frames on disk
/// instead of raw YUV frames in RAM.
///
/// Memory usage: ~50 frames × 30-50 KB = 1.5-2.5 MB (vs 200-500 MB raw).
class VideoBufferService {
  static final VideoBufferService _instance = VideoBufferService._internal();
  factory VideoBufferService() => _instance;
  VideoBufferService._internal();

  final ListQueue<String> _framePaths = ListQueue<String>();
  final int _maxFrames = 50; // ~5 seconds at 10fps
  bool _isSaving = false;
  int _frameCount = 0;
  String? _bufferDir;

  // Track resolution dynamically
  int _width = 0;
  int _height = 0;

  /// Initialize the temporary buffer directory on disk.
  Future<void> _ensureBufferDir() async {
    if (_bufferDir != null && Directory(_bufferDir!).existsSync()) return;
    final tempDir = await getTemporaryDirectory();
    _bufferDir = p.join(tempDir.path, 'eyeon_frame_buffer');
    final dir = Directory(_bufferDir!);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  /// Add a camera frame to the rolling buffer.
  /// Frames are compressed to JPEG and written to disk, keeping RAM usage minimal.
  void addFrame(CameraImage image) {
    if (_isSaving) return;

    _frameCount++;
    // Sample every 3rd frame (~10 fps from a 30fps stream)
    if (_frameCount % 3 != 0) return;

    try {
      if (_width == 0) {
        _width = image.width;
        _height = image.height;
      }

      // Compress and save asynchronously to avoid blocking the UI thread
      _compressAndSaveFrame(image);
    } catch (e) {
      debugPrint('Error adding frame to buffer: $e');
    }
  }

  /// Convert NV21/YUV camera image to JPEG and save to disk.
  Future<void> _compressAndSaveFrame(CameraImage image) async {
    await _ensureBufferDir();

    final int width = image.width;
    final int height = image.height;

    // Get the Y plane (grayscale) — this is memory-efficient and sufficient
    // for incident evidence purposes.
    final Uint8List yPlane = image.planes[0].bytes;

    // Run compression in an isolate to avoid jank
    final Uint8List? jpegBytes = await compute(_encodeGrayscaleToJpeg, {
      'yPlane': yPlane,
      'width': width,
      'height': height,
    });

    if (jpegBytes == null) return;

    final framePath = p.join(
      _bufferDir!,
      'frame_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    try {
      await File(framePath).writeAsBytes(jpegBytes, flush: false);
      _framePaths.addLast(framePath);

      // Remove oldest frame if over limit
      while (_framePaths.length > _maxFrames) {
        final oldPath = _framePaths.removeFirst();
        try {
          final oldFile = File(oldPath);
          if (oldFile.existsSync()) oldFile.deleteSync();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error saving frame to disk: $e');
    }
  }

  /// Static isolate function: encode grayscale Y-plane to JPEG bytes.
  static Uint8List? _encodeGrayscaleToJpeg(Map<String, dynamic> params) {
    try {
      final Uint8List yPlane = params['yPlane'];
      final int width = params['width'];
      final int height = params['height'];

      // Create grayscale image from Y plane
      final grayscale = img.Image(width: width, height: height, numChannels: 1);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int index = y * width + x;
          if (index < yPlane.length) {
            final int luminance = yPlane[index];
            grayscale.setPixelRgb(x, y, luminance, luminance, luminance);
          }
        }
      }

      // Encode to JPEG with moderate quality (good enough for evidence, small file size)
      return Uint8List.fromList(img.encodeJpg(grayscale, quality: 60));
    } catch (e) {
      return null;
    }
  }

  /// Save the buffered frames as an MP4 video file.
  /// Returns the path to the created video, or null on failure.
  Future<String?> saveBufferToVideo() async {
    if (_framePaths.isEmpty) {
      debugPrint('⚠️ Cannot save video: Buffer is empty');
      return null;
    }

    _isSaving = true;
    debugPrint('🎬 Processing ${_framePaths.length} JPEG frames...');

    try {
      final tempDir = await getTemporaryDirectory();
      final sessionDir = p.join(
        tempDir.path,
        'incident_${DateTime.now().millisecondsSinceEpoch}',
      );
      await Directory(sessionDir).create(recursive: true);

      // Copy and rename frames sequentially for FFmpeg
      final frames = _framePaths.toList();
      for (int i = 0; i < frames.length; i++) {
        final src = File(frames[i]);
        if (src.existsSync()) {
          final dst = p.join(
            sessionDir,
            'frame_${i.toString().padLeft(3, '0')}.jpg',
          );
          await src.copy(dst);
        }
      }

      final outputPath = p.join(
        tempDir.path,
        'incident_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      // FFmpeg: JPEG sequence → MP4
      // Much simpler command since input is already JPEG images
      final command =
          '-framerate 10 -i "$sessionDir/frame_%03d.jpg" '
          '-c:v libx264 -profile:v main -level 3.1 -pix_fmt yuv420p '
          '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clean up session directory
      try {
        await Directory(sessionDir).delete(recursive: true);
      } catch (_) {}

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('✅ Incident video created: $outputPath');
        return outputPath;
      } else {
        final logs = await session.getLogs();
        debugPrint(
          '❌ FFmpeg failed: ${logs.isNotEmpty ? logs.last.getMessage() : "Unknown"}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error during video creation: $e');
      return null;
    } finally {
      _framePaths.clear();
      _isSaving = false;
      _width = 0;
      _height = 0;
    }
  }

  /// Clear all buffered frames and delete temp files.
  void clear() {
    for (final path in _framePaths) {
      try {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
    _framePaths.clear();
    _frameCount = 0;
    _width = 0;
    _height = 0;
  }
}
