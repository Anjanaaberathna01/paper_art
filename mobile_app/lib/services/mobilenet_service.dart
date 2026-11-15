import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart';
import 'package:image/image.dart' as img;

class MobileNetService {
  static Interpreter? _interpreter;
  static List<String> _labels = [];
  static const int inputSize = 224; // MobileNetV2 standard input size

  static Future<void> loadModel() async {
    if (_interpreter != null) return;

    try {
      // 1. Labels load කරගැනීම
      final labelsData = await rootBundle.loadString('assets/model/labels.txt');
      _labels = labelsData
          .split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();

      // 2. TFLite Model load කරගැනීම
      _interpreter = await Interpreter.fromAsset(
        'assets/model/mobilenet_paper_model.tflite',
      );

      debugPrint(
        'MobileNet model loaded successfully. Labels: ${_labels.length}',
      );
    } catch (e) {
      debugPrint('Model loading failed: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> classifyImage(
    Uint8List imageBytes,
  ) async {
    try {
      await loadModel();

      // 1. Image එක decode කර 224x224 سائز එකට resize කිරීම
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) throw Exception('Unable to decode image.');

      final resizedImage = img.copyResize(
        originalImage,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );

      // 2. Input tensor එක සකස් කිරීම [1, 224, 224, 3] (Normalized 0.0 to 1.0)
      final input = List.generate(
        1,
        (batch) => List.generate(
          inputSize,
          (y) => List.generate(inputSize, (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              pixel.r.toDouble() / 255.0,
              pixel.g.toDouble() / 255.0,
              pixel.b.toDouble() / 255.0,
            ];
          }),
        ),
      );

      // 3. Output tensor එක සකස් කිරීම [1, numClasses]
      final output = List.generate(
        1,
        (_) => List<double>.filled(_labels.length, 0.0),
      );

      _interpreter!.run(input, output);

      // 4. Results සකස් කිරීම
      final probabilities = output[0];
      final List<Map<String, dynamic>> results = [];

      for (int i = 0; i < probabilities.length; i++) {
        if (i < _labels.length) {
          results.add({'label': _labels[i], 'confidence': probabilities[i]});
        }
      }

      // වැඩිම confidence එක ඇති එක උඩට එනសේ sort කිරීම
      results.sort(
        (a, b) =>
            (b['confidence'] as double).compareTo(a['confidence'] as double),
      );

      return results;
    } catch (e) {
      debugPrint('Classification error: $e');
      return [];
    }
  }

  static void disposeModel() {
    _interpreter?.close();
    _interpreter = null;
  }
}
