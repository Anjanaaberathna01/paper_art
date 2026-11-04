
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

class YoloService {
  static Interpreter? _interpreter;
  static Future<void>? _loadingFuture;

  static List<String> _labels = [];

  static const int inputSize = 640;
  static const int numClasses = 12;
  static const int numDetections = 8400;

  static const int paperClassId = 3;
  static const int paperOutputIndex = paperClassId + 4;

  static const double confidenceThreshold = 0.10;
  static const double iouThreshold = 0.45;

  static Future<void> loadModel() async {
    if (_interpreter != null) return;

    _loadingFuture ??= _initializeModel();

    try {
      await _loadingFuture;
    } catch (e) {
      _loadingFuture = null;
      rethrow;
    }
  }

  static Future<void> _initializeModel() async {
    try {
      debugPrint('YOLO model initialization started.');

      if (kIsWeb) {
        await initializeWeb();
      }

      _labels = (await rootBundle.loadString(
        'assets/model/labels.txt',
      ))
          .split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();

      _interpreter = await Interpreter.fromAsset(
        'assets/model/yolo_model.tflite',
      );

      final inputTensors = _interpreter!.getInputTensors();

      for (int i = 0; i < inputTensors.length; i++) {
        debugPrint(
          'INPUT $i: Shape = ${inputTensors[i].shape}, '
          'Type = ${inputTensors[i].type}',
        );
      }

      final outputTensors = _interpreter!.getOutputTensors();

      for (int i = 0; i < outputTensors.length; i++) {
        debugPrint(
          'OUTPUT $i: Shape = ${outputTensors[i].shape}, '
          'Type = ${outputTensors[i].type}',
        );
      }

      if (_labels.length != numClasses) {
        throw Exception(
          'Expected $numClasses labels, found ${_labels.length}.',
        );
      }

      debugPrint('YOLO model loaded successfully.');
      debugPrint('Labels: ${_labels.length}');
    } catch (e) {
      debugPrint('Model loading failed: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>?> detectImage(
    Uint8List imageBytes,
  ) async {
    try {
      await loadModel();

      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('Unable to decode image.');
      }

      final originalWidth = originalImage.width;
      final originalHeight = originalImage.height;

      // YOLO letterbox preprocessing
      final scale = inputSize /
          (originalWidth > originalHeight
              ? originalWidth
              : originalHeight);

      final resizedWidth = (originalWidth * scale).round();
      final resizedHeight = (originalHeight * scale).round();

      final resizedImage = img.copyResize(
        originalImage,
        width: resizedWidth,
        height: resizedHeight,
        interpolation: img.Interpolation.linear,
      );

      final padX = (inputSize - resizedWidth) ~/ 2;
      final padY = (inputSize - resizedHeight) ~/ 2;

      final canvas = img.Image(
        width: inputSize,
        height: inputSize,
      );

      img.fill(
        canvas,
        color: img.ColorRgb8(114, 114, 114),
      );

      img.compositeImage(
        canvas,
        resizedImage,
        dstX: padX,
        dstY: padY,
      );

      // Model input: [1, 3, 640, 640] - NCHW
      final input = List.generate(
        1,
        (_) => List.generate(
          3,
          (channel) => List.generate(
            inputSize,
            (y) => List.generate(
              inputSize,
              (x) {
                final pixel = canvas.getPixel(x, y);

                final value = channel == 0
                    ? pixel.r
                    : channel == 1
                        ? pixel.g
                        : pixel.b;

                return value.toDouble() / 255.0;
              },
            ),
          ),
        ),
      );

      // Model output: [1, 16, 8400]
      final output = List.generate(
        1,
        (_) => List.generate(
          16,
          (_) => List.filled(numDetections, 0.0),
        ),
      );

      _interpreter!.run(input, output);

      // ========== CLASS DEBUG ==========
      for (final classInfo in [
        {'name': 'Cardboard', 'id': 0},
        {'name': 'Paper', 'id': 3},
      ]) {
        final String name = classInfo['name'] as String;
        final int classId = classInfo['id'] as int;

        double maxConfidence = 0;
        int count005 = 0;
        int count010 = 0;
        int count025 = 0;

        for (int i = 0; i < numDetections; i++) {
          final confidence =
              (output[0][classId + 4][i] as num).toDouble();

          if (confidence > maxConfidence) {
            maxConfidence = confidence;
          }

          if (confidence >= 0.05) count005++;
          if (confidence >= 0.10) count010++;
          if (confidence >= 0.25) count025++;
        }

        print('========== $name DEBUG ==========');
        print('Maximum $name Confidence: $maxConfidence');
        print('$name scores >= 0.05: $count005');
        print('$name scores >= 0.10: $count010');
        print('$name scores >= 0.25: $count025');
        print('================================');
      }

      // ==========================================
      // MULTIPLE OBJECT DETECTION
      // ==========================================

      final detections = <Map<String, dynamic>>[];

      int paperBoxCount = 0;
      int invalidPaperBoxCount = 0;

      for (int i = 0; i < numDetections; i++) {
        double bestScore = 0.0;
        int bestClass = -1;

        // Find highest class confidence
        for (int c = 0; c < numClasses; c++) {
          final score = (output[0][c + 4][i] as num)
              .toDouble();

          if (score > bestScore) {
            bestScore = score;
            bestClass = c;
          }
        }

        // Paper bounding-box debug
        if (bestClass == paperClassId &&
            bestScore >= confidenceThreshold) {
          debugPrint('========== PAPER BOX DEBUG ==========');
          debugPrint('Index: $i');
          debugPrint('Class: $bestClass');
          debugPrint('Confidence: $bestScore');
          debugPrint('CenterX: ${output[0][0][i]}');
          debugPrint('CenterY: ${output[0][1][i]}');
          debugPrint('Width: ${output[0][2][i]}');
          debugPrint('Height: ${output[0][3][i]}');
          debugPrint('=====================================');
        }

        if (bestScore < confidenceThreshold ||
            bestClass < 0 ||
            bestClass >= _labels.length) {
          continue;
        }

        final rawCenterX = (output[0][0][i] as num).toDouble();
final rawCenterY = (output[0][1][i] as num).toDouble();
final rawBoxWidth = (output[0][2][i] as num).toDouble();
final rawBoxHeight = (output[0][3][i] as num).toDouble();

// Detect whether coordinates are normalized (0-1)
// or already in 640x640 pixel coordinates.
final coordinateScale =
    (rawCenterX.abs() <= 1.5 &&
     rawCenterY.abs() <= 1.5 &&
     rawBoxWidth.abs() <= 1.5 &&
     rawBoxHeight.abs() <= 1.5)
        ? inputSize.toDouble()
        : 1.0;

final centerX = rawCenterX * coordinateScale;
final centerY = rawCenterY * coordinateScale;
final boxWidth = rawBoxWidth * coordinateScale;
final boxHeight = rawBoxHeight * coordinateScale;

        final x1 = ((centerX - boxWidth / 2 - padX) / scale)
            .clamp(0.0, originalWidth.toDouble());

        final y1 = ((centerY - boxHeight / 2 - padY) / scale)
            .clamp(0.0, originalHeight.toDouble());

        final x2 = ((centerX + boxWidth / 2 - padX) / scale)
            .clamp(0.0, originalWidth.toDouble());

        final y2 = ((centerY + boxHeight / 2 - padY) / scale)
            .clamp(0.0, originalHeight.toDouble());

        // Paper coordinate debug
        if (bestClass == paperClassId &&
            bestScore >= confidenceThreshold) {
          debugPrint('Paper coordinates:');
          debugPrint('x1=$x1, y1=$y1, x2=$x2, y2=$y2');
          debugPrint('Original: $originalWidth x $originalHeight');
          debugPrint('Scale: $scale, padX: $padX, padY: $padY');
        }

        if (x2 <= x1 || y2 <= y1) {
          if (bestClass == paperClassId) {
            invalidPaperBoxCount++;
            debugPrint('INVALID PAPER BOX - Index: $i');
          }
          continue;
        }

        if (bestClass == paperClassId) {
          paperBoxCount++;
        }

        detections.add({
          'label': _labels[bestClass],
          'confidence': bestScore,
          'x': x1,
          'y': y1,
          'width': x2 - x1,
          'height': y2 - y1,
          'classId': bestClass,
        });
      }

      debugPrint('========== BEFORE NMS ==========');
      debugPrint('Total detections: ${detections.length}');
      debugPrint('Valid Paper boxes: $paperBoxCount');
      debugPrint('Invalid Paper boxes: $invalidPaperBoxCount');
      debugPrint('================================');

      // Non-Maximum Suppression
      final results = _applyNms(detections);

      debugPrint('========== FINAL DETECTIONS ==========');
      debugPrint('Detection count: ${results.length}');

      for (final result in results) {
        debugPrint(
          '${result['label']} | '
          'Confidence: ${result['confidence']}',
        );
      }

      debugPrint('======================================');

      return results;
    } catch (e, stackTrace) {
      debugPrint('Detection error: $e');
      debugPrint('$stackTrace');
      return null;
    }
  }

  // ==========================================
  // NON-MAXIMUM SUPPRESSION
  // ==========================================

  static List<Map<String, dynamic>> _applyNms(
    List<Map<String, dynamic>> detections,
  ) {
    detections.sort(
      (a, b) => (b['confidence'] as double)
          .compareTo(a['confidence'] as double),
    );

    final selected = <Map<String, dynamic>>[];

    for (final candidate in detections) {
      bool shouldKeep = true;

      for (final existing in selected) {
        if (candidate['classId'] != existing['classId']) {
          continue;
        }

        if (_calculateIou(candidate, existing) > iouThreshold) {
          shouldKeep = false;
          break;
        }
      }

      if (shouldKeep) {
        selected.add(candidate);
      }
    }

    return selected;
  }

  // ==========================================
  // INTERSECTION OVER UNION
  // ==========================================

  static double _calculateIou(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final ax1 = a['x'] as double;
    final ay1 = a['y'] as double;
    final ax2 = ax1 + (a['width'] as double);
    final ay2 = ay1 + (a['height'] as double);

    final bx1 = b['x'] as double;
    final by1 = b['y'] as double;
    final bx2 = bx1 + (b['width'] as double);
    final by2 = by1 + (b['height'] as double);

    final intersectionWidth =
        (ax2 < bx2 ? ax2 : bx2) -
        (ax1 > bx1 ? ax1 : bx1);

    final intersectionHeight =
        (ay2 < by2 ? ay2 : by2) -
        (ay1 > by1 ? ay1 : by1);

    if (intersectionWidth <= 0 || intersectionHeight <= 0) {
      return 0.0;
    }

    final intersection =
        intersectionWidth * intersectionHeight;

    final areaA =
        (ax2 - ax1) * (ay2 - ay1);

    final areaB =
        (bx2 - bx1) * (by2 - by1);

    final union = areaA + areaB - intersection;

    return union <= 0 ? 0.0 : intersection / union;
  }

  static void disposeModel() {
    _interpreter?.close();
    _interpreter = null;
    _loadingFuture = null;
  }
}
