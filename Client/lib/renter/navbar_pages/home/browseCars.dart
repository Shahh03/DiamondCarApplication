// browse_cars.dart
import 'package:flutter/material.dart';
import '../search/search.dart'; // adjust path if needed

/// Note:
/// - Place your type images in assets/images/ (e.g. assets/images/sedan.png)
/// - Add them to pubspec.yaml:
///   flutter:
///     assets:
///       - assets/images/sedan.png
///       - assets/images/suv.png
///       - assets/images/luxury.png
///       - assets/images/compact.png
///       - assets/images/electric.png
///       - assets/images/convertible.png
///
/// The widget is embeddable and uses shrinkWrap so it can be placed inside a SizedBox
/// in your home page (so only the browse area scrolls).
class BrowseCars extends StatefulWidget {
  final String renterId;

  const BrowseCars({super.key, required this.renterId});

  @override
  State<BrowseCars> createState() => _BrowseCarsState();
}

class _BrowseCarsState extends State<BrowseCars> {
  final List<Map<String, dynamic>> categories = [
    {
      'key': 'sedan',
      'title': 'Sedan',
      'image': 'Client\images\dac117c0-c7fb-4de5-a067-a682385f89c7.png',
      'color': Colors.blueAccent.shade100,
    },
    {
      'key': 'suv',
      'title': 'SUV',
      'image': 'assets/images/suv.png',
      'color': Colors.greenAccent.shade100,
    },
    {
      'key': 'luxury',
      'title': 'Luxury',
      'image': 'assets/images/luxury.png',
      'color': Colors.purpleAccent.shade100,
    },
    {
      'key': 'compact',
      'title': 'Compact',
      'image': 'assets/images/compact.png',
      'color': Colors.orangeAccent.shade100,
    },
    {
      'key': 'electric',
      'title': 'Electric',
      'image': 'assets/images/electric.png',
      'color': Colors.tealAccent.shade100,
    },
    {
      'key': 'convertible',
      'title': 'Convertible',
      'image': 'assets/images/convertible.png',
      'color': Colors.pinkAccent.shade100,
    },
     {
      'key': 'sports',
      'title': 'Sports',
      'image': 'assets/images/sports.png',
      'color': Colors.pinkAccent.shade100,
    },
  ];

  void _onCategoryTap(String key, String title) {
    // Navigate to RenterSearch and pass the category so the search screen can filter.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RenterSearch(id: widget.renterId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always show 3 columns per row as requested.
    const crossAxisCount = 3;

    return GridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.70, // taller card so label is under the image
      physics: const BouncingScrollPhysics(),
      shrinkWrap: true,
      children: categories.map((cat) => _buildCategoryTile(cat)).toList(),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> cat) {
    final String title = cat['title'] as String;
    final String imagePath = cat['image'] as String;
    final Color bg = cat['color'] as Color;

    return InkWell(
      onTap: () => _onCategoryTap(cat['key'] as String, title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: bg.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            // Image area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: Colors.white, // small white bg for images
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        // fallback to icon if asset not found
                        return Center(
                          child: Icon(
                            Icons.directions_car,
                            size: 40,
                            color: Colors.grey.shade700,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Label under the image
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white, // label background contrast
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
