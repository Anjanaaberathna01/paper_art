
import 'package:flutter/material.dart';
import 'detail_screen.dart';

class MatchedCraftsScreen extends StatelessWidget {
  final String detectedMaterial;
  final List<Map<String, dynamic>> crafts;

  const MatchedCraftsScreen({
    super.key,
    required this.detectedMaterial,
    required this.crafts,
  });

  // Build craft image
  Widget _buildCraftImage(Map<String, dynamic> craft) {
    final String imageUrl =
        (craft['imageUrl'] ?? '').toString().trim();

    final String imagePath =
        (craft['imagePath'] ?? '').toString().trim();

    // Support online images
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 40),
          );
        },
      );
    }

    // Support image URLs stored in imagePath
    if (imagePath.startsWith('http://') ||
        imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 40),
          );
        },
      );
    }

    // Support local asset images
    return Image.asset(
      imagePath.isNotEmpty
          ? imagePath
          : 'assets/images/placeholder.jpg',
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.broken_image, size: 40),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Crafts for '$detectedMaterial'"),
        backgroundColor: const Color(0xFF2ECC71),
      ),

      body: crafts.isEmpty
          ? const Center(
              child: Text(
                'No matching crafts found.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12.0),

              child: GridView.builder(
                itemCount: crafts.length,

                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),

                itemBuilder: (context, index) {
                  final craft = crafts[index];

                  final String craftTitle =
                      (craft['title'] ?? 'Craft').toString();

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailScreen(
                            craft: craft,
                          ),
                        ),
                      );
                    },

                    child: Card(
                      elevation: 4,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius:
                                  const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),

                              child: _buildCraftImage(craft),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(10.0),

                            child: Text(
                              craftTitle,
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
    );
  }
}
