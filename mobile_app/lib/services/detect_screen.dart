import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/services/mobilenet_service.dart';
import 'package:mobile_app/screens/matched_crafts_screen.dart';

class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  List<dynamic>? _recognitions;
  bool _isProcessing = false;
  String _statusMessage = 'Upload an image to classify objects.';

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      await MobileNetService.loadModel();
      if (kDebugMode) {
        debugPrint('MobileNet model initialization started.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MobileNet model initialization error: $e');
      }
      if (!mounted) return;

      setState(() {
        _statusMessage = 'Failed to initialize the classification model.';
      });
    }
  }

  Future<void> pickImageFromCamera() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> pickImageFromGallery() async {
    await _pickImage(ImageSource.gallery);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isProcessing) return;

    try {
      final XFile? selectedImage = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (selectedImage == null) return;

      final Uint8List imageBytes = await selectedImage.readAsBytes();

      if (!mounted) return;

      setState(() {
        _imageBytes = imageBytes;
        _recognitions = null;
        _isProcessing = true;
        _statusMessage = 'Classifying image...';
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

  Future<void> runModelOnImage(Uint8List imageBytes) async {
    try {
      // Correct classification method call
      final List<Map<String, dynamic>> recognitions =
          await MobileNetService.classifyImage(imageBytes);

      if (!mounted) return;

      setState(() {
        _recognitions = recognitions;
      });

      if (recognitions.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No objects recognized. Try another image.';
        });
        _showMessage('No objects recognized. Please try another image.');
        return;
      }

      final topResult = recognitions.first;
      final String detectedLabel =
          (topResult['label'] ?? '').toString().trim().toLowerCase();
      final double confidence =
          (topResult['confidence'] as num?)?.toDouble() ?? 0.0;

      if (confidence < 0.4) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Low confidence. Try a clearer image.';
        });
        _showMessage('Low confidence detection. Try again.');
        return;
      }

      setState(() {
        _statusMessage = 'Detected: $detectedLabel (${(confidence * 100).toStringAsFixed(1)}%)';
      });

      await queryCraftsFromFirestore([detectedLabel]);

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Classification error: $e');
      }

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Classification failed.';
      });

      _showMessage('Classification failed. Please try again.');
    }
  }

  Future<void> queryCraftsFromFirestore(List<String> materialNames) async {
    try {
      final Map<String, Map<String, dynamic>> matchedCrafts = {};

      for (final materialName in materialNames) {
        final QuerySnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection('craft')
                .where('materials', arrayContains: materialName)
                .get();

        for (final doc in snapshot.docs) {
          final Map<String, dynamic> craftData = doc.data();

          if (matchedCrafts.containsKey(doc.id)) {
            final List<String> existingMaterials =
                List<String>.from(matchedCrafts[doc.id]!['matchedMaterials'] ?? []);

            if (!existingMaterials.contains(materialName)) {
              existingMaterials.add(materialName);
            }
            matchedCrafts[doc.id]!['matchedMaterials'] = existingMaterials;
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

      final List<Map<String, dynamic>> craftsList =
          matchedCrafts.values.toList();

      if (craftsList.isNotEmpty) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '${craftsList.length} matching crafts found.';
        });

        final String detectedMaterial = materialNames.join(', ');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchedCraftsScreen(
              detectedMaterial: detectedMaterial,
              crafts: craftsList,
            ),
          ),
        );
      } else {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No matching crafts found.';
        });

        _showMessage('No crafts found for the detected materials.');
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

      _showMessage('Failed to retrieve crafts. Check your connection.');
    }
  }

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
        title: const Text('Craft Classification'),
        backgroundColor: const Color(0xFF2ECC71),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            height: 220,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _imageBytes == null
                ? const Center(
                    child: Text(
                      'No image selected.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : pickImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 15),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Processing image...'),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'Classification Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _recognitions == null
                ? const Center(child: Text('Upload an image to classify'))
                : _recognitions!.isEmpty
                    ? const Center(child: Text('No objects recognized.'))
                    : ListView.builder(
                        itemCount: _recognitions!.length,
                        itemBuilder: (context, index) {
                          final result = _recognitions![index];
                          final String label = (result['label'] ?? 'Unknown').toString();
                          final double confidence = (result['confidence'] is num)
                              ? (result['confidence'] as num).toDouble()
                              : 0.0;

                          return ListTile(
                            leading: const Icon(
                              Icons.check_circle,
                              color: Color(0xFF2ECC71),
                            ),
                            title: Text(label),
                            trailing: Text(
                              '${(confidence * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
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