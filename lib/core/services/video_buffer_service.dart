import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Optimized video buffer that stores JPEG-compressed frames on disk
/// instead of raw YUV frames in RAM.
///
/// Key optimizations:
/// - Uses a long-running isolate (spawned once) for JPEG encoding
///   instead of `compute()` per-frame, eliminating isolate spawn overhead.
/// - Frame buffer stored in app support directory (OS-sandboxed) for security.
/// - FFmpeg runs asynchronously to avoid blocking the main thread.
/// - File names are obfuscated (no obvious .jpg extension).
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



  // ── Long-Running Isolate ───────────────────────────────────────────
  Isolate? _encoderIsolate;
  SendPort? _encoderSendPort;
  ReceivePort? _encoderReceivePort;
  bool _isolateReady = false;

  /// Initialize the encoder isolate and buffer directory.
  /// Must be called before [addFrame].
  Future<void> init() async {
    await _ensureBufferDir();
    await _spawnEncoderIsolate();
  }

  /// Spawn a single long-running isolate for JPEG encoding.
  Future<void> _spawnEncoderIsolate() async {
    if (_isolateReady) return;

    _encoderReceivePort = ReceivePort();
    _encoderIsolate = await Isolate.spawn(
      _encoderIsolateEntryPoint,
      _encoderReceivePort!.sendPort,
    );

    // First message from the isolate is its SendPort for communication
    final completer = Completer<SendPort>();

    _encoderReceivePort!.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is _EncodedFrame) {
        // Handle the encoded frame result on the main isolate
        _handleEncodedFrame(message);
      }
    });

    _encoderSendPort = await completer.future;
    _isolateReady = true;
    debugPrint('🔧 Encoder isolate spawned and ready');
  }

  /// Initialize the buffer directory in app-support (OS-sandboxed).
  Future<void> _ensureBufferDir() async {
    if (_bufferDir != null && Directory(_bufferDir!).existsSync()) return;
    final supportDir = await getApplicationSupportDirectory();
    _bufferDir = p.join(supportDir.path, 'eyeon_fbuf');
    final dir = Directory(_bufferDir!);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
  }

  /// Add a camera frame to the rolling buffer.
  /// Frames are compressed to JPEG via the long-running isolate, keeping RAM usage minimal.
  void addFrame(CameraImage image) {
    if (_isSaving) return;
    if (!_isolateReady || _encoderSendPort == null) return;

    _frameCount++;
    // Sample every 3rd frame (~10 fps from a 30fps stream)
    if (_frameCount % 3 != 0) return;

    try {
      // Send frame data to the encoder isolate (no spawning overhead)
      _encoderSendPort!.send(_FrameData(
        yPlane: Uint8List.fromList(image.planes[0].bytes),
        width: image.width,
        height: image.height,
        bufferDir: _bufferDir!,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    } catch (e) {
      debugPrint('Error sending frame to encoder isolate: $e');
    }
  }

  /// Handle encoded frame result from the isolate.
  void _handleEncodedFrame(_EncodedFrame result) {
    if (result.path == null) return;

    _framePaths.addLast(result.path!);

    // Remove oldest frame if over limit
    while (_framePaths.length > _maxFrames) {
      final oldPath = _framePaths.removeFirst();
      try {
        final oldFile = File(oldPath);
        if (oldFile.existsSync()) oldFile.deleteSync();
      } catch (_) {}
    }
  }

  /// Save the buffered frames as an MP4 video file.
  /// Uses FFmpegKit.executeAsync to avoid blocking the main thread.
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

      // FFmpeg: JPEG sequence → MP4 (async, non-blocking)
      final command =
          '-framerate 10 -i "$sessionDir/frame_%03d.jpg" '
          '-c:v libx264 -profile:v main -level 3.1 -pix_fmt yuv420p '
          '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" "$outputPath"';

      final completer = Completer<String?>();

      FFmpegKit.executeAsync(
        command,
        (FFmpegSession session) async {
          // Complete callback — runs when FFmpeg finishes
          final returnCode = await session.getReturnCode();

          // Clean up session directory
          try {
            await Directory(sessionDir).delete(recursive: true);
          } catch (_) {}

          if (ReturnCode.isSuccess(returnCode)) {
            debugPrint('✅ Incident video created: $outputPath');
            completer.complete(outputPath);
          } else {
            final logs = await session.getLogs();
            debugPrint(
              '❌ FFmpeg failed: ${logs.isNotEmpty ? logs.last.getMessage() : "Unknown"}',
            );
            completer.complete(null);
          }
        },
      );

      final result = await completer.future;
      return result;
    } catch (e) {
      debugPrint('Error during video creation: $e');
      return null;
    } finally {
      _framePaths.clear();
      _isSaving = false;
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
  }

  /// Dispose the encoder isolate.
  void dispose() {
    _encoderIsolate?.kill(priority: Isolate.immediate);
    _encoderReceivePort?.close();
    _encoderIsolate = null;
    _encoderSendPort = null;
    _encoderReceivePort = null;
    _isolateReady = false;
    clear();
    debugPrint('🔧 Encoder isolate disposed');
  }
}

// ══════════════════════════════════════════════════════════════════════
// Isolate Communication DTOs
// ══════════════════════════════════════════════════════════════════════

/// Data sent TO the encoder isolate.
class _FrameData {
  final Uint8List yPlane;
  final int width;
  final int height;
  final String bufferDir;
  final int timestamp;

  _FrameData({
    required this.yPlane,
    required this.width,
    required this.height,
    required this.bufferDir,
    required this.timestamp,
  });
}

/// Result sent BACK from the encoder isolate.
class _EncodedFrame {
  final String? path;
  _EncodedFrame(this.path);
}

// ══════════════════════════════════════════════════════════════════════
// Long-Running Encoder Isolate
// ══════════════════════════════════════════════════════════════════════

/// Entry point for the long-running encoder isolate.
/// Listens for [_FrameData] messages and encodes them to JPEG on disk.
void _encoderIsolateEntryPoint(SendPort mainSendPort) {
  final isolateReceivePort = ReceivePort();

  // Send our receive port back to the main isolate
  mainSendPort.send(isolateReceivePort.sendPort);

  // Listen for incoming frame data
  isolateReceivePort.listen((message) {
    if (message is _FrameData) {
      final result = _encodeAndSaveFrame(message);
      mainSendPort.send(result);
    }
  });
}

/// Encode a grayscale Y-plane to JPEG and save to disk.
/// Runs inside the long-running isolate.
_EncodedFrame _encodeAndSaveFrame(_FrameData data) {
  try {
    // Create grayscale image from Y plane
    final grayscale = img.Image(
      width: data.width,
      height: data.height,
      numChannels: 1,
    );
    for (int y = 0; y < data.height; y++) {
      for (int x = 0; x < data.width; x++) {
        final int index = y * data.width + x;
        if (index < data.yPlane.length) {
          final int luminance = data.yPlane[index];
          grayscale.setPixelRgb(x, y, luminance, luminance, luminance);
        }
      }
    }

    // Encode to JPEG with moderate quality
    final jpegBytes = Uint8List.fromList(img.encodeJpg(grayscale, quality: 60));

    // Obfuscated filename: hex timestamp + no .jpg extension visible
    final hex = data.timestamp.toRadixString(16);
    final framePath = p.join(data.bufferDir, 'fb_$hex.dat');

    File(framePath).writeAsBytesSync(jpegBytes, flush: false);

    return _EncodedFrame(framePath);
  } catch (e) {
    return _EncodedFrame(null);
  }
}
