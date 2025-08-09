import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'bookCarVariant.dart';

class WishlistPage extends StatefulWidget {
  final String renterId;

  const WishlistPage({super.key, required this.renterId});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  List<dynamic> wishlist = [];
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    fetchWishlist();
  }

  Future<void> fetchWishlist() async {
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/renter/getWishlist/${widget.renterId}"),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          wishlist = data;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load wishlist");
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  Future<void> removeFromWishlist(String carVariantId) async {
    try {
      // TODO: Replace with your real API endpoint for removing from wishlist
      final response = await http.delete(
        Uri.parse("http://10.0.2.2:8000/renter/removeFromWishlist/${widget.renterId}/$carVariantId"),
      );

      if (response.statusCode == 200) {

           Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => WishlistPage(renterId: widget.renterId)),
        );
        
      } else {
        throw Exception("Failed to remove");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

 void _showConfirmationDialog(String carVariantId) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      title: Row(
        children: const [
          Icon(Icons.delete_forever, color: Colors.redAccent, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Remove from Wishlist?',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to remove this car from your wishlist?',
        style: TextStyle(fontSize: 16, color: Colors.black54),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            Navigator.pop(context); // Close the dialog first
            await removeFromWishlist(carVariantId);

            // Show success feedback after removal
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Removed from wishlist!'),
                backgroundColor: Colors.green,
              ),
            );

            // Refresh wishlist page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => WishlistPage(renterId: widget.renterId),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text('Yes'),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black87,
            backgroundColor: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.pop(context); // Close dialog only
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text('No'),
          ),
        ),
      ],
    ),
  );
}


  void bookCar(String carVariantId) {
    // TODO: Implement booking flow
    Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RenterBookCarVariantPage(renterId: widget.renterId)),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Wishlist"),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? const Center(child: Text("Error loading wishlist"))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: wishlist.length,
                  itemBuilder: (context, index) {
                    final carData = wishlist[index];
                    final car = carData['car'];
                    final insurance = carData['insuranceDetails'];
                    final images = carData['images'] as List<dynamic>;

                    return Card(
                      elevation: 5,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Horizontal Images
                          SizedBox(
  height: 200,
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    itemCount: images.length,
    itemBuilder: (context, index) {
      final imgPath = images[index]['filepath'];
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            "$imgPath", // adjust if you have /uploads or a different folder
            width: 400,
            height: 250,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 160,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
              );
            },
          ),
        ),
      );
    },
  ),
),

                          // Car Info
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${car['brand']} ${car['model']} (${car['year']})",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Color: ${carData['color']} • ${car['category']} • ${car['fuelType']}",
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Seats: ${car['seats']} • ${car['transmission']}",
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "\$${carData['rentalPricePerDay']}/day",
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    Text(
                                      "Deposit: \$${carData['depositAmount']}",
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                            
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: carData['isAvailable'] ? Colors.green[100] : Colors.red[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    carData['isAvailable'] ? "Available" : "Not Available",
                                    style: TextStyle(
                                      color: carData['isAvailable'] ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Buttons Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (carData['isAvailable'])
                                      ElevatedButton(
                                        onPressed: () => bookCar(carData['_id']),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueAccent,
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 3,
                                        ),
                                        child: const Text(
                                          "Book Now",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      )

                                      ,


                                   OutlinedButton.icon(
                                    onPressed: () => _showConfirmationDialog(carData['_id']),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.redAccent, width: 1.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    ),
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    label: const Text(
                                      "Remove",
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )

                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}




