import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/services/yolo_service.dart';

class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  Uint8List? _imageBytes;

  List<dynamic>? _recognitions;

  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _modelReady = false;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  // Load YOLO model
  Future<void> _initializeModel() async {
    try {
      await YoloService.loadModel();

      if (!mounted) return;

      setState(() {
        _modelReady = true;
      });

      debugPrint('YOLO model ready.');
    } catch (e) {
      debugPrint('Model initialization error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Model loading failed: $e'),
        ),
      );
    }
  }

  // Camera image selection
  Future<void> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        await runModelOnImage(bytes);
      }
    } catch (e) {
      _showError('Camera error: $e');
    }
  }

  // Gallery image selection
  Future<void> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        await runModelOnImage(bytes);
      }
    } catch (e) {
      _showError('Image selection error: $e');
    }
  }

  // Run YOLO object detection
  Future<void> runModelOnImage(Uint8List imageBytes) async {
    if (!_modelReady) {
      await _initializeModel();
    }

    if (!_modelReady) {
      _showError('Model is not ready. Please try again.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _imageBytes = imageBytes;
      _recognitions = null;
      _isLoading = true;
    });

    try {
      final results = await YoloService.detectImage(imageBytes);

      if (!mounted) return;

      setState(() {
        _recognitions = results ?? [];
        _isLoading = false;
      });

      if (results == null) {
        _showError('Object detection failed.');
      } else if (results.isEmpty) {
        debugPrint('No objects detected.');
      } else {
        debugPrint('Detected ${results.length} objects.');

        for (final result in results) {
          debugPrint(
            'Object: ${result['label']} '
            'Confidence: ${result['confidence']}',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('Detection error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Craft Object Detection'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          _imageBytes == null
              ? Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const Text('No image selected.'),
                )
              : Image.memory(
                  _imageBytes!,
                  height: 200,
                  fit: BoxFit.cover,
                ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : pickImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),

              const SizedBox(width: 15),

              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (_isLoading)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Detecting objects...'),
              ],
            ),

          Expanded(
            child: _isLoading
                ? const SizedBox()
                : _recognitions == null
                    ? const Center(
                        child: Text('Upload an image to detect'),
                      )
                    : _recognitions!.isEmpty
                        ? const Center(
                            child: Text('No objects detected.'),
                          )
                        : ListView.builder(
                            itemCount: _recognitions!.length,
                            itemBuilder: (context, index) {
                              final result = _recognitions![index];

                              final label =
                                  result['label'] ?? '';

                              final confidence =
                                  (result['confidence'] ?? 0)
                                      .toDouble();

                              return ListTile(
                                leading: const Icon(
                                  Icons.check_circle_outline,
                                ),
                                title: Text(label),
                                trailing: Text(
                                  '${(confidence * 100).toStringAsFixed(0)}%',
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
