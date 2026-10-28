import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50], // කොළ පාට ලා පසුබිමක්
      appBar: AppBar(
        title: const Text(
          '🎨 Kids Hand Craft App',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('craft').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No crafts found in database!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          // ඩේටා ටික Map ලැයිස්තුවකට ලබා ගැනීම
          final docs = snapshot.data!.docs;
          
          // Categories අනුව Crafts ටික Group කිරීම
          Map<String, List<Map<String, dynamic>>> categorizedCrafts = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final category = data['category'] ?? 'Other Crafts';
            
            if (!categorizedCrafts.containsKey(category)) {
              categorizedCrafts[category] = [];
            }
            categorizedCrafts[category]!.add(data);
          }

          // ListView එක හරහා Category එකින් එක පෙන්වීම
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: categorizedCrafts.entries.map((entry) {
              String categoryName = entry.key;
              List<Map<String, dynamic>> craftsList = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Title එක
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87, // නිවැරදි කළ වර්ණය
                      ),
                    ),
                  ),
                  
                  // ඒ Category එකට අදාළ Crafts ටික හරස් අතට (Horizontal) පෙන්වීම
                  SizedBox(
                    height: 210,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: craftsList.length,
                      itemBuilder: (context, index) {
                        final craft = craftsList[index];

                        return Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(15),
                              onTap: () {
                                // මෙතැනදී Craft Detail Screen එකට යා හැක
                                debugPrint("Clicked on: ${craft['title']}");
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Craft එකේ Final Look Image එක
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(15),
                                    ),
                                    child: Image.network(
                                      craft['imageUrl'] ?? '',
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                        height: 120,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image,
                                            size: 40, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  // Craft Title එක
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      craft['title'] ?? 'Craft',
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
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }).toList(),
          );
        },
      ),
      // දකුණු පැත්තේ පහළින් කැමරා අයිකන් එක (Floating Action Button)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // මෙතැනින් Scanner Screen එකට යාමේ කේතය ලියන්න පුළුවන්
          debugPrint("Camera Scanner Clicked!");
        },
        backgroundColor: Colors.green[700],
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text('Scan & Find', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}