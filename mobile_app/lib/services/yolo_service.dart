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

  static const double confidenceThreshold = 0.25;
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

      final detections = <Map<String, dynamic>>[];

      for (int i = 0; i < numDetections; i++) {
        double bestScore = 0;
        int bestClass = -1;

        for (int c = 0; c < numClasses; c++) {
          final score = output[0][c + 4][i];

          if (score > bestScore) {
            bestScore = score;
            bestClass = c;
          }
        }

        if (bestScore < confidenceThreshold ||
            bestClass < 0 ||
            bestClass >= _labels.length) {
          continue;
        }

        final centerX = output[0][0][i];
        final centerY = output[0][1][i];
        final boxWidth = output[0][2][i];
        final boxHeight = output[0][3][i];

        final x1 = ((centerX - boxWidth / 2 - padX) / scale)
            .clamp(0.0, originalWidth.toDouble());

        final y1 = ((centerY - boxHeight / 2 - padY) / scale)
            .clamp(0.0, originalHeight.toDouble());

        final x2 = ((centerX + boxWidth / 2 - padX) / scale)
            .clamp(0.0, originalWidth.toDouble());

        final y2 = ((centerY + boxHeight / 2 - padY) / scale)
            .clamp(0.0, originalHeight.toDouble());

        if (x2 <= x1 || y2 <= y1) continue;

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

      final results = _applyNms(detections);

      debugPrint('Detection count: ${results.length}');

      return results;
    } catch (e) {
      debugPrint('Detection error: $e');
      return null;
    }
  }

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
      return 0;
    }

    final intersection =
        intersectionWidth * intersectionHeight;

    final areaA =
        (ax2 - ax1) * (ay2 - ay1);

    final areaB =
        (bx2 - bx1) * (by2 - by1);

    final union = areaA + areaB - intersection;

    return union <= 0 ? 0 : intersection / union;
  }

  static void disposeModel() {
    _interpreter?.close();
    _interpreter = null;
    _loadingFuture = null;
  }
}