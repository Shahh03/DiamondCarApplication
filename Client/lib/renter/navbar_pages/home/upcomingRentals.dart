import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../myRentals/myRentals.dart'; // Import your full rentals page
import 'package:project/renter/api/booking_api.dart';

class UpcomingRentals extends StatefulWidget {
  final String renterId;

  const UpcomingRentals({Key? key, required this.renterId}) : super(key: key);

  @override
  State<UpcomingRentals> createState() => _UpcomingRentalsState();
}

class _UpcomingRentalsState extends State<UpcomingRentals> {
  List<dynamic> renterBookings = [];
  bool isBookingsLoading = true;

  @override
  void initState() {
    super.initState();
    getRenterUpcomingBookings();
  }

Future<void> getRenterUpcomingBookings() async {
  try {
    final bookings = await BookingApi.getUpcomingBookings(widget.renterId);

    if (!mounted) return;

    setState(() {
      renterBookings = bookings;
      isBookingsLoading = false;
    });
  } catch (e) {
    debugPrint('Error fetching bookings: $e');

    if (!mounted) return;

    setState(() {
      renterBookings = [];
      isBookingsLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    if (isBookingsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (renterBookings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text(
          "No upcoming rentals.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // Only show the first upcoming rental
    final rental = renterBookings[0];
  final carVariant = rental['carVariant'] ?? {};
  final car = carVariant['car'] ?? {};

  final brand = car['brand'] ?? '';
  final model = car['model'] ?? '';
  final carName = "$brand $model";

  final pickupDate = rental['startDate'] != null
      ? rental['startDate'].toString().split('T').first
      : '-';

  final returnDate = rental['endDate'] != null
      ? rental['endDate'].toString().split('T').first
      : '-';

  final images = carVariant['images'] as List<dynamic>? ?? [];

  Widget imageWidget;

  if (images.isNotEmpty && images[0]['filename'] != null) {
    final imageString = images[0]['filename'].toString();

    try {
      final base64String = imageString.contains(',')
          ? imageString.split(',').last
          : imageString;

      imageWidget = Image.memory(
        base64Decode(base64String),
        width: 60,
        height: 60,
        fit: BoxFit.cover,
      );
    } catch (e) {
      imageWidget = const Icon(
        Icons.directions_car,
        color: Colors.blueAccent,
        size: 50,
      );
    }
  } else {
    imageWidget = const Icon(
      Icons.directions_car,
      color: Colors.blueAccent,
      size: 50,
    );
  }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 2,
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageWidget,
              ),
              title: Text(carName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Pickup: $pickupDate\nReturn: $returnDate"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Optional: navigate to rental details
              },
            ),
          ),

          // See All button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RenterMyRentals(id: widget.renterId), // Full rentals page
                  ),
                );
              },
              child: const Text(
                "See All",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
