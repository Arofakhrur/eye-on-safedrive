import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class VideoBufferService {
  static final VideoBufferService _instance = VideoBufferService._internal();
  factory VideoBufferService() => _instance;
  VideoBufferService._internal();

  final ListQueue<Uint8List> _frameBuffer = ListQueue<Uint8List>();
  final int _maxFrames = 100; // ~10 seconds at 10fps
  bool _isSaving = false;
  int _frameCount = 0;
  
  // Track resolution dynamically
  int _width = 0;
  int _height = 0;

  void addFrame(CameraImage image) {
    if (_isSaving) return;

    _frameCount++;
    if (_frameCount % 3 != 0) return;

    try {
      if (_width == 0) {
        _width = image.width;
        _height = image.height;
      }

      final Uint8List bytes = image.planes[0].bytes;
      _frameBuffer.addLast(Uint8List.fromList(bytes));

      if (_frameBuffer.length > _maxFrames) {
        _frameBuffer.removeFirst();
      }
    } catch (e) {
      debugPrint('Error adding frame to buffer: $e');
    }
  }

  Future<String?> saveBufferToVideo() async {
    if (_frameBuffer.isEmpty) {
      debugPrint('⚠️ Cannot save video: Buffer is empty');
      return null;
    }
    
    _isSaving = true;
    debugPrint('🎬 Processing ${_frameBuffer.length} frames (${_width}x${_height})...');

    try {
      final tempDir = await getTemporaryDirectory();
      final sessionDir = p.join(tempDir.path, 'incident_${DateTime.now().millisecondsSinceEpoch}');
      await Directory(sessionDir).create(recursive: true);

      for (int i = 0; i < _frameBuffer.length; i++) {
        final path = p.join(sessionDir, 'frame_${i.toString().padLeft(3, '0')}.raw');
        await File(path).writeAsBytes(_frameBuffer.elementAt(i));
      }

      final outputPath = p.join(tempDir.path, 'incident_video_${DateTime.now().millisecondsSinceEpoch}.mp4');

      // Standard Mobile Compatible FFmpeg Command:
      // 1. scale=trunc(iw/2)*2... ensures dimensions are even (required by yuv420p/h264)
      // 2. -pix_fmt yuv420p for maximum gallery compatibility
      // 3. -profile:v main -level 3.1 for standard hardware acceleration
      final command = '-f rawvideo -pixel_format gray -video_size ${_width}x${_height} -framerate 10 -i "$sessionDir/frame_%03d.raw" '
                      '-vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -profile:v main -level 3.1 -pix_fmt yuv420p "$outputPath"';
      
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        debugPrint('✅ Incident video created: $outputPath');
        return outputPath;
      } else {
        final logs = await session.getLogs();
        debugPrint('❌ FFmpeg failed: ${logs.isNotEmpty ? logs.last.getMessage() : "Unknown"}');
        return null;
      }
    } catch (e) {
      debugPrint('Error during video creation: $e');
      return null;
    } finally {
      _frameBuffer.clear();
      _isSaving = false;
      _width = 0;
      _height = 0;
    }
  }

  void clear() {
    _frameBuffer.clear();
    _frameCount = 0;
    _width = 0;
    _height = 0;
  }
}
