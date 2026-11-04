
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/services/detection_painter.dart';
import 'package:mobile_app/services/yolo_service.dart';
import 'package:mobile_app/screens/matched_crafts_screen.dart';

class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;

  int? _imageWidth;
  int? _imageHeight;

  List<dynamic>? _recognitions;

  bool _isProcessing = false;

  String _statusMessage = 'Upload an image to detect objects.';

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  // Initialize YOLO model
  void _initializeModel() {
    try {
      YoloService.loadModel();

      if (kDebugMode) {
        debugPrint('YOLO model initialization started.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('YOLO model initialization error: $e');
      }

      _statusMessage = 'Failed to initialize the detection model.';
    }
  }

  // Capture image using camera
  Future<void> pickImageFromCamera() async {
    await _pickImage(ImageSource.camera);
  }

  // Select image from gallery
  Future<void> pickImageFromGallery() async {
    await _pickImage(ImageSource.gallery);
  }

  // Common image picker function
  Future<void> _pickImage(ImageSource source) async {
    if (_isProcessing) return;

    try {
      final XFile? selectedImage = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (selectedImage == null) return;

      final Uint8List imageBytes =
          await selectedImage.readAsBytes();

      // Read the original image dimensions for accurate bounding boxes.
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frame = await codec.getNextFrame();

      final int originalWidth = frame.image.width;
      final int originalHeight = frame.image.height;

      frame.image.dispose();
      codec.dispose();

      if (!mounted) return;

      setState(() {
        _imageBytes = imageBytes;
        _imageWidth = originalWidth;
        _imageHeight = originalHeight;
        _recognitions = null;
        _isProcessing = true;
        _statusMessage = 'Detecting objects...';
      });

      await runModelOnImage(imageBytes);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Image selection error: $e');
      }

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Unable to select the image.';
      });

      _showMessage('Unable to select image. Please try again.');
    }
  }

  // Run YOLO model on selected image
  Future<void> runModelOnImage(Uint8List imageBytes) async {
    try {
        final List<dynamic> recognitions =
          await YoloService.detectImage(imageBytes) ?? <dynamic>[];

      if (!mounted) return;

      setState(() {
        _recognitions = recognitions;
      });

      if (kDebugMode) {
        debugPrint('YOLO detection results: $recognitions');
      }

      if (recognitions.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No objects detected. Try another image.';
        });

        _showMessage('No objects detected. Please try another image.');
        return;
      }

      // Extract unique detected material labels
      final Set<String> detectedMaterials = {};

      for (final result in recognitions) {
        if (result is! Map) continue;

        final String label =
            (result['label'] ?? '').toString().trim().toLowerCase();

        if (label.isNotEmpty) {
          detectedMaterials.add(label);
        }
      }

      if (detectedMaterials.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No valid materials detected.';
        });

        _showMessage('No valid materials detected.');
        return;
      }

      // Search matching crafts in Firestore
      await queryCraftsFromFirestore(
        detectedMaterials.toList(),
      );

    } catch (e) {
      if (kDebugMode) {
        debugPrint('YOLO detection error: $e');
      }

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Object detection failed.';
      });

      _showMessage('Object detection failed. Please try again.');
    }
  }

  // Search Firestore for matching crafts
  Future<void> queryCraftsFromFirestore(
    List<String> materialNames,
  ) async {
    try {
      final Map<String, Map<String, dynamic>> matchedCrafts = {};

      for (final materialName in materialNames) {
        final QuerySnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection('craft')
                .where(
                  'materials',
                  arrayContains: materialName,
                )
                .get();

        for (final doc in snapshot.docs) {
          final Map<String, dynamic> craftData = doc.data();

          if (matchedCrafts.containsKey(doc.id)) {
            final List<String> existingMaterials =
                List<String>.from(
              matchedCrafts[doc.id]!['matchedMaterials'] ?? [],
            );

            if (!existingMaterials.contains(materialName)) {
              existingMaterials.add(materialName);
            }

            matchedCrafts[doc.id]!['matchedMaterials'] =
                existingMaterials;
          } else {
            matchedCrafts[doc.id] = {
              ...craftData,
              'id': doc.id,
              'matchedMaterials': [materialName],
            };
          }
        }
      }

      if (!mounted) return;

      final List<Map<String, dynamic>> crafts =
          matchedCrafts.values.toList();

      if (crafts.isNotEmpty) {
        setState(() {
          _isProcessing = false;
          _statusMessage =
              '${crafts.length} matching crafts found.';
        });

        final String detectedMaterial =
            materialNames.join(', ');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchedCraftsScreen(
              detectedMaterial: detectedMaterial,
              crafts: crafts,
            ),
          ),
        );
      } else {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No matching crafts found.';
        });

        _showMessage(
          'No crafts found for the detected materials.',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore query error: $e');
      }

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Unable to retrieve matching crafts.';
      });

      _showMessage(
        'Failed to retrieve crafts. Check your connection.',
      );
    }
  }

  // Display messages
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Craft Object Detection'),
        backgroundColor: const Color(0xFF2ECC71),
        foregroundColor: Colors.white,
      ),

      body: Column(
        children: [
          const SizedBox(height: 20),

          // Selected image preview
          Container(
            height: 220,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
              ),
            ),
            child: _imageBytes == null
                ? const Center(
                    child: Text(
                      'No image selected.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (_imageWidth == null ||
                            _imageHeight == null ||
                            _imageWidth == 0 ||
                            _imageHeight == 0) {
                          return Image.memory(
                            _imageBytes!,
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.contain,
                          );
                        }

                        // Match the displayed image size to BoxFit.contain.
                        final double scale = [
                          constraints.maxWidth / _imageWidth!,
                          constraints.maxHeight / _imageHeight!,
                        ].reduce((a, b) => a < b ? a : b);

                        final double displayWidth = _imageWidth! * scale;
                        final double displayHeight = _imageHeight! * scale;

                        return Center(
                          child: SizedBox(
                            width: displayWidth,
                            height: displayHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Original image
                                Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.fill,
                                ),

                                // Bounding boxes drawn over the image
                                if (_recognitions != null)
                                  CustomPaint(
                                    painter: DetectionPainter(
                                      detections: _recognitions!,
                                      imageWidth: _imageWidth!.toDouble(),
                                      imageHeight: _imageHeight!.toDouble(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),

          const SizedBox(height: 20),

          // Camera and Gallery buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : pickImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),

              const SizedBox(width: 15),

              ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Processing indicator
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Please wait. Processing image...'),
                ],
              ),
            ),

          // Status message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 10),

          const Divider(),

          // Detection results
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'Detected Objects',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: _recognitions == null
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

                          final String label =
                              (result['label'] ?? 'Unknown')
                                  .toString();

                          final double confidence =
                              (result['confidence'] is num)
                                  ? (result['confidence'] as num)
                                      .toDouble()
                                  : 0.0;

                          return ListTile(
                            leading: const Icon(
                              Icons.check_circle,
                              color: Color(0xFF2ECC71),
                            ),

                            title: Text(label),

                            trailing: Text(
                              '${(confidence * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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
