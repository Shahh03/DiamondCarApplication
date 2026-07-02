import 'package:flutter/material.dart';
import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';

import '../../bookingDetails.dart';
import '../../api/renter_api.dart';
import '../../api/booking_api.dart';

class RenterMyRentals extends StatefulWidget {
  final String id;

  const RenterMyRentals({super.key, required this.id});

  @override
  State<RenterMyRentals> createState() => _RenterMyRentalsState();
}

class _RenterMyRentalsState extends State<RenterMyRentals> {
  Map<String, dynamic>? userData;
  List<dynamic> renterBookings = [];

  bool isUserLoading = true;
  bool isBookingsLoading = true;

  bool get isLoading => isUserLoading || isBookingsLoading;

  @override
  void initState() {
    super.initState();
    getUserData();
    getRenterBookings();
  }

  Future<void> getUserData() async {
    try {
      final data = await RenterApi.getUserById(widget.id);

      if (!mounted) return;

      setState(() {
        userData = data;
        isUserLoading = false;
      });

      debugPrint("User Data: $userData");
    } catch (e) {
      debugPrint('Error fetching user: $e');

      if (!mounted) return;

      setState(() {
        isUserLoading = false;
      });
    }
  }

  Future<void> getRenterBookings() async {
    try {
      final bookings = await BookingApi.getRenterBookings(widget.id);

      if (!mounted) return;

      setState(() {
        renterBookings = bookings;
        isBookingsLoading = false;
      });

      debugPrint("Bookings: $renterBookings");
    } catch (e) {
      debugPrint('Error fetching bookings: $e');

      if (!mounted) return;

      setState(() {
        isBookingsLoading = false;
      });
    }
  }

  String formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return '${date.month}/${date.day}/${date.year}';
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String getCarImageUrl(dynamic image) {
    // New structure: images: ["https://res.cloudinary.com/..."]
    if (image is String) {
      return image;
    }

    // Old structure fallback: images: [{ filepath: "..." }]
    if (image is Map && image['filepath'] != null) {
      return image['filepath'].toString();
    }

    return '';
  }

  Widget buildCarImages(List images) {
    if (images.isEmpty) {
      return Container(
        height: 250,
        width: double.infinity,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(
            Icons.directions_car,
            size: 70,
            color: Colors.grey,
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          final imageUrl = getCarImageUrl(images[index]);

          if (imageUrl.isEmpty) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                width: 400,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 400,
                    height: 250,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'My Rentals',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2563EB),
                Color(0xFF60A5FA),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : renterBookings.isEmpty
              ? const Center(child: Text('No bookings found.'))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You have ${renterBookings.length} Rentals',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: renterBookings.length,
                          itemBuilder: (context, index) {
                            final booking = renterBookings[index];

                            final variant = booking['carVariant'] ?? {};
                            final car = variant['car'] ?? {};
                            final List images = variant['images'] ?? [];

                            final status = booking['status'] ?? 'Unknown';

                            final brand = car['brand'] ?? 'Unknown';
                            final model = car['model'] ?? '';
                            final year = car['year']?.toString() ?? '';

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    child: buildCarImages(images),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$brand $model $year',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${formatDate(booking['startDate'])} - ${formatDate(booking['endDate'])}',
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              status,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: getStatusColor(status),
                                                fontSize: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.center,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              print(booking['_id']);

                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      BookingDetailsPage(
                                                    bookingId: booking['_id']
                                                        .toString(),
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              elevation: 4,
                                              backgroundColor:
                                                  Colors.blueAccent,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 28,
                                                vertical: 12,
                                              ),
                                              textStyle: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            child: const Text('View Details'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        userId: widget.id,
      ),
    );
  }
}