import 'dart:io';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

class CameraUtils {
  static final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Convert a CameraImage frame to InputImage for ML Kit processing.
  static InputImage? inputImageFromCameraImage(
    CameraImage image,
    CameraController? controller,
  ) {
    if (controller == null) return null;
    if (image.planes.isEmpty) return null;

    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;

      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // ── Android: Use NV21 format directly ──────────────────────────
    if (Platform.isAndroid) {
      if (format != InputImageFormat.nv21) {
        if (format == InputImageFormat.yuv_420_888) {
           return _processYuv420(image, rotation);
        }
        return null;
      }

      // NV21 is passed efficiently without manual conversions
      final bytes = image.planes.length == 1 
          ? image.planes[0].bytes 
          : _concatenatePlanes(image.planes); // Safeguard if plugin separates Y and UV

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }

    // ── iOS: BGRA8888 ────────────────────────────────────────────────
    if (format != InputImageFormat.bgra8888) return null;

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }
  
  static Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }
  
  static InputImage? _processYuv420(CameraImage image, InputImageRotation rotation) {
     try {
       final int width = image.width;
       final int height = image.height;
       final int uvRowStride = image.planes[1].bytesPerRow;
       final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

       final nv21 = Uint8List(width * height + (width * height ~/ 2));

       final yPlane = image.planes[0].bytes;
       final int yRowStride = image.planes[0].bytesPerRow;
       for (int row = 0; row < height; row++) {
         final srcStart = row * yRowStride;
         final dstStart = row * width;
         nv21.setRange(dstStart, dstStart + width, yPlane, srcStart);
       }

       final uPlane = image.planes[1].bytes;
       final vPlane = image.planes[2].bytes;
       int uvIndex = width * height;
       final int uvHeight = height ~/ 2;
       final int uvWidth = width ~/ 2;

       for (int row = 0; row < uvHeight; row++) {
         for (int col = 0; col < uvWidth; col++) {
           final int uvOffset = row * uvRowStride + col * uvPixelStride;
           if (uvIndex + 1 < nv21.length) {
             nv21[uvIndex++] = vPlane[uvOffset];
             nv21[uvIndex++] = uPlane[uvOffset];
           }
         }
       }

       return InputImage.fromBytes(
         bytes: nv21,
         metadata: InputImageMetadata(
           size: Size(image.width.toDouble(), image.height.toDouble()),
           rotation: rotation,
           format: InputImageFormat.nv21,
           bytesPerRow: width,
         ),
       );
     } catch (_) {
       return null;
     }
  }
}
