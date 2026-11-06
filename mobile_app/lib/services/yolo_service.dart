
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

  // Initial class-wise confidence thresholds.
  static const Map<int, double> classThresholds = {
    0: 0.10, // Cardboard
    1: 0.15, // Ruler
    2: 0.20, // glue
    3: 0.25, // paper
    4: 0.20, // paper cup
    5: 0.10, // pen
    6: 0.15, // pencil
    7: 0.10, // plastic
    8: 0.20, // scissor
    9: 0.15, // straw
    10: 0.20, // wool
    11: 0.20, // yarn cone
  };

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

      if (_labels.length != numClasses) {
        throw Exception(
          'Expected $numClasses labels, found ${_labels.length}.',
        );
      }

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

      final int originalWidth = originalImage.width;
      final int originalHeight = originalImage.height;

      // Letterbox preprocessing.
      final double scale = inputSize /
          (originalWidth > originalHeight
              ? originalWidth
              : originalHeight);

      final int resizedWidth = (originalWidth * scale).round();
      final int resizedHeight = (originalHeight * scale).round();

      final resizedImage = img.copyResize(
        originalImage,
        width: resizedWidth,
        height: resizedHeight,
        interpolation: img.Interpolation.linear,
      );

      final int padX = (inputSize - resizedWidth) ~/ 2;
      final int padY = (inputSize - resizedHeight) ~/ 2;

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

      // Input shape: [1, 3, 640, 640] (NCHW).
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

      // Output shape: [1, 16, 8400].
      final output = List.generate(
        1,
        (_) => List.generate(
          numClasses + 4,
          (_) => List<double>.filled(numDetections, 0.0),
        ),
      );

      _interpreter!.run(input, output);

      // Maximum confidence for each class.
      final List<double> maxClassScores =
          List<double>.filled(numClasses, 0.0);

      // Store raw predictions for debugging.
      // Class 0 = Cardboard
      // Class 3 = Paper
      // Class 4 = Paper cup
      final List<List<Map<String, dynamic>>> topPredictions =
          List.generate(numClasses, (_) => []);

      final detections = <Map<String, dynamic>>[];

      for (int i = 0; i < numDetections; i++) {
        final double rawCenterX =
            (output[0][0][i] as num).toDouble();

        final double rawCenterY =
            (output[0][1][i] as num).toDouble();

        final double rawBoxWidth =
            (output[0][2][i] as num).toDouble();

        final double rawBoxHeight =
            (output[0][3][i] as num).toDouble();

        // Support normalized or pixel coordinates.
        final double coordinateScale =
            (rawCenterX.abs() <= 1.5 &&
                    rawCenterY.abs() <= 1.5 &&
                    rawBoxWidth.abs() <= 1.5 &&
                    rawBoxHeight.abs() <= 1.5)
                ? inputSize.toDouble()
                : 1.0;

        final double centerX = rawCenterX * coordinateScale;
        final double centerY = rawCenterY * coordinateScale;
        final double boxWidth = rawBoxWidth * coordinateScale;
        final double boxHeight = rawBoxHeight * coordinateScale;

        // Convert letterbox coordinates to original image coordinates.
        final double x1 =
            ((centerX - boxWidth / 2 - padX) / scale)
                .clamp(0.0, originalWidth.toDouble());

        final double y1 =
            ((centerY - boxHeight / 2 - padY) / scale)
                .clamp(0.0, originalHeight.toDouble());

        final double x2 =
            ((centerX + boxWidth / 2 - padX) / scale)
                .clamp(0.0, originalWidth.toDouble());

        final double y2 =
            ((centerY + boxHeight / 2 - padY) / scale)
                .clamp(0.0, originalHeight.toDouble());

        if (x2 <= x1 || y2 <= y1) {
          continue;
        }

        // Evaluate all 12 class scores.
        for (int classId = 0; classId < numClasses; classId++) {
          final double score =
              (output[0][classId + 4][i] as num).toDouble();

          // Update maximum raw confidence.
          if (score > maxClassScores[classId]) {
            maxClassScores[classId] = score;
          }

          // Save raw predictions for selected classes.
          // This happens BEFORE threshold filtering.
          if (classId == 0 || classId == 3 || classId == 4) {
            topPredictions[classId].add({
              'score': score,
              'index': i,
              'x': x1,
              'y': y1,
              'width': x2 - x1,
              'height': y2 - y1,
            });
          }

          final double threshold =
              classThresholds[classId] ?? 0.25;

          // Apply class-wise threshold.
          if (score < threshold) {
            continue;
          }

          detections.add({
            'label': _labels[classId],
            'confidence': score,
            'x': x1,
            'y': y1,
            'width': x2 - x1,
            'height': y2 - y1,
            'classId': classId,
          });
        }
      }

      // ==========================================
      // TOP 5 RAW PREDICTIONS DEBUG
      // ==========================================

      debugPrint('');
      debugPrint('========== TOP 5 RAW PREDICTIONS ==========');

      for (final classId in [0, 3, 4]) {
        final predictions = topPredictions[classId];

        predictions.sort(
          (a, b) => (b['score'] as double)
              .compareTo(a['score'] as double),
        );

        debugPrint('');
        debugPrint('===== ${_labels[classId]} TOP 5 =====');

        if (predictions.isEmpty) {
          debugPrint('No valid predictions found.');
          continue;
        }

        for (final prediction in predictions.take(5)) {
          final double score = prediction['score'] as double;

          debugPrint(
            'Confidence: ${(score * 100).toStringAsFixed(2)}% '
            '| Index: ${prediction['index']} '
            '| Box: '
            'x=${prediction['x']}, '
            'y=${prediction['y']}, '
            'w=${prediction['width']}, '
            'h=${prediction['height']}',
          );
        }
      }

      debugPrint('');
      debugPrint('===========================================');

      // ==========================================
      // CLASS-WISE CONFIDENCE DEBUG
      // ==========================================

      debugPrint('');
      debugPrint('========== CLASS-WISE CONFIDENCE ==========');

      for (int classId = 0; classId < numClasses; classId++) {
        final double threshold =
            classThresholds[classId] ?? 0.25;

        debugPrint(
          '${_labels[classId]}: '
          'Max ${(maxClassScores[classId] * 100).toStringAsFixed(2)}% '
          '| Threshold ${(threshold * 100).toStringAsFixed(0)}%',
        );
      }

      debugPrint('===========================================');

      // ==========================================
      // NON-MAXIMUM SUPPRESSION
      // ==========================================

      debugPrint('Detections before NMS: ${detections.length}');

      final results = _applyNms(detections);

      debugPrint('');
      debugPrint('========== FINAL DETECTIONS ==========');
      debugPrint('Detection count: ${results.length}');

      for (final result in results) {
        debugPrint(
          '${result['label']} | '
          'Confidence: '
          '${((result['confidence'] as double) * 100).toStringAsFixed(2)}% '
          '| Box: '
          'x=${result['x']}, '
          'y=${result['y']}, '
          'w=${result['width']}, '
          'h=${result['height']}',
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

  // Class-wise Non-Maximum Suppression.
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
        // Do not suppress different classes.
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

  static double _calculateIou(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final double ax1 = a['x'] as double;
    final double ay1 = a['y'] as double;
    final double ax2 = ax1 + (a['width'] as double);
    final double ay2 = ay1 + (a['height'] as double);

    final double bx1 = b['x'] as double;
    final double by1 = b['y'] as double;
    final double bx2 = bx1 + (b['width'] as double);
    final double by2 = by1 + (b['height'] as double);

    final double intersectionWidth =
        (ax2 < bx2 ? ax2 : bx2) -
        (ax1 > bx1 ? ax1 : bx1);

    final double intersectionHeight =
        (ay2 < by2 ? ay2 : by2) -
        (ay1 > by1 ? ay1 : by1);

    if (intersectionWidth <= 0 || intersectionHeight <= 0) {
      return 0.0;
    }

    final double intersection =
        intersectionWidth * intersectionHeight;

    final double areaA = (ax2 - ax1) * (ay2 - ay1);
    final double areaB = (bx2 - bx1) * (by2 - by1);

    final double union = areaA + areaB - intersection;

    return union <= 0 ? 0.0 : intersection / union;
  }

  static void disposeModel() {
    _interpreter?.close();
    _interpreter = null;
    _loadingFuture = null;
  }
}
