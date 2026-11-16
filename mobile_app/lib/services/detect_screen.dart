import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/services/mobilenet_service.dart';
import 'package:mobile_app/screens/detail_screen.dart';

class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  bool _isProcessing = false;
  String _statusMessage = 'Upload or capture an image to find matching crafts.';

  // හඳුනාගත් ද්‍රව්‍ය සහ ඒවායේ ප්‍රතිශත (percentages) තබා ගැනීමට
  List<Map<String, dynamic>> _detectedItems = [];

  // හඳුනාගත් ද්‍රව්‍යවලට අදාළව Firestore එකෙන් ගෙන එන Hand Crafts ලැයිස්තුව
  List<Map<String, dynamic>> _suggestedCrafts = [];

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  void _initializeModel() {
    try {
      MobileNetService.loadModel();
      if (kDebugMode) {
        debugPrint('MobileNet model initialization started.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MobileNet model initialization error: $e');
      }
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
        _detectedItems = [];
        _suggestedCrafts = [];
        _isProcessing = true;
        _statusMessage = 'Analyzing image...';
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
      final List<Map<String, dynamic>> recognitions =
          await MobileNetService.classifyImage(imageBytes);

      if (!mounted) return;

      if (recognitions.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No objects recognized. Try another image.';
        });
        _showMessage('No objects recognized. Please try again.');
        return;
      }

      // -------------------------------------------------------------
      // 5% (0.05) හෝ ඊට වැඩි ඕනෑම ප්‍රතිශතයක් හඳුනාගැනීම (ඉතා සංවේදීයි)
      // -------------------------------------------------------------
      final List<Map<String, dynamic>> validDetections = [];
      final List<String> materialNames = [];

      for (final result in recognitions) {
        final double confidence = (result['confidence'] as num).toDouble();
        final String label = (result['label'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (confidence >= 0.05 && label.isNotEmpty) {
          validDetections.add({'label': label, 'confidence': confidence});
          materialNames.add(label);
        }
      }

      // කිසිවක් 5% ඉක්මවා නැතත්, ලැයිස්තුවේ උඩින්ම ඇති හොඳම ප්‍රතිඵලය අනිවාර්යයෙන්ම ගනියි
      if (validDetections.isEmpty && recognitions.isNotEmpty) {
        final top = recognitions.first;
        final String label = (top['label'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final double conf = (top['confidence'] as num).toDouble();
        validDetections.add({'label': label, 'confidence': conf});
        materialNames.add(label);
      }

      setState(() {
        _detectedItems = validDetections;
      });

      // -------------------------------------------------------------
      // Firestore එකෙන් මෙම ද්‍රව්‍යවලට අදාළ Hand Crafts සෙවීම
      // -------------------------------------------------------------
      await queryCraftsFromFirestore(materialNames);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Classification error: $e');
      }

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Detection failed.';
      });

      _showMessage('Detection failed. Please try again.');
    }
  }

  Future<void> queryCraftsFromFirestore(List<String> materialNames) async {
    try {
      if (materialNames.isEmpty) {
        setState(() {
          _isProcessing = false;
          _suggestedCrafts = [];
          _statusMessage = 'No valid materials detected.';
        });
        return;
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('craft')
              .where('materials', arrayContainsAny: materialNames)
              .get();

      final List<Map<String, dynamic>> craftsList = [];

      for (final doc in snapshot.docs) {
        final Map<String, dynamic> craftData = doc.data();
        craftData['id'] = doc.id;

        if (!craftsList.any((c) => c['id'] == doc.id)) {
          craftsList.add(craftData);
        }
      }

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _suggestedCrafts = craftsList;
        _statusMessage = craftsList.isNotEmpty
            ? '${craftsList.length} matching crafts found!'
            : 'No crafts found in database for detected items.';
      });
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
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan & Suggest Crafts'),
        backgroundColor: const Color(0xFF2ECC71),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          // Uploaded Image Preview
          Container(
            height: 180,
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
                      style: TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                  ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),

          // Camera / Gallery Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : pickImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 15),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF26C6DA),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: Color(0xFF2ECC71)),
            ),

          // Status & Detected Objects Percentage List
          if (_detectedItems.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Detected Objects:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _detectedItems.length,
                itemBuilder: (context, index) {
                  final item = _detectedItems[index];
                  final label = item['label'].toString().toUpperCase();
                  final conf = (item['confidence'] as double) * 100;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2ECC71)),
                    ),
                    child: Center(
                      child: Text(
                        '$label (${conf.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const Divider(height: 20),

          // Suggested Hand Crafts Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Suggested Hand Crafts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_suggestedCrafts.length} found',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Suggested Crafts Grid View
          Expanded(
            child: _suggestedCrafts.isEmpty
                ? Center(
                    child: Text(
                      _isProcessing
                          ? 'Searching crafts...'
                          : 'No crafts available for this item yet.',
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _suggestedCrafts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                    itemBuilder: (context, index) {
                      final craft = _suggestedCrafts[index];
                      final title = craft['title'] ?? 'Craft';
                      final imagePath =
                          craft['imagePath'] ?? 'assets/images/placeholder.jpg';

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailScreen(craft: craft),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: Image.asset(
                                    imagePath,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (_, _, ___) => const Center(
                                      child: Icon(Icons.broken_image, size: 40),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
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
