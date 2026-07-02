import 'package:flutter/material.dart';
import 'dart:convert';

import '../myRentals/myRentals.dart';
import '../../bookingDetails.dart';
import 'package:project/renter/api/booking_api.dart';

class UpcomingRentals extends StatefulWidget {
  final String renterId;

  const UpcomingRentals({
    super.key,
    required this.renterId,
  });

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

  DateTime _safeDate(dynamic value) {
    if (value == null) return DateTime(9999);

    return DateTime.tryParse(value.toString()) ?? DateTime(9999);
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';

    return value.toString().split('T').first;
  }

  String getCarImageUrl(dynamic image) {
    // New structure:
    // images: ["https://res.cloudinary.com/..."]
    if (image is String) {
      return image;
    }

    // Old structure fallback:
    // images: [{ filepath: "..." }]
    if (image is Map && image['filepath'] != null) {
      return image['filepath'].toString();
    }

    // Extra fallback:
    // images: [{ url: "..." }]
    if (image is Map && image['url'] != null) {
      return image['url'].toString();
    }

    return '';
  }

  Widget _fallbackCarIcon() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey.shade200,
      child: const Icon(
        Icons.directions_car,
        color: Colors.blueAccent,
        size: 42,
      ),
    );
  }

  Widget _buildCarImage(List images) {
    if (images.isEmpty) {
      return _fallbackCarIcon();
    }

    final firstImage = images.first;
    final imageUrl = getCarImageUrl(firstImage);

    // New Cloudinary image URL
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _fallbackCarIcon();
        },
      );
    }

    // Very old fallback if you still have base64 stored in filename
    if (firstImage is Map && firstImage['filename'] != null) {
      final imageString = firstImage['filename'].toString();

      try {
        final base64String = imageString.contains(',')
            ? imageString.split(',').last
            : imageString;

        return Image.memory(
          base64Decode(base64String),
          width: 60,
          height: 60,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return _fallbackCarIcon();
      }
    }

    return _fallbackCarIcon();
  }

  Widget _buildRentalCard(dynamic rental) {
    final carVariant = rental['carVariant'] ?? {};
    final car = carVariant['car'] ?? {};

    final brand = car['brand']?.toString() ?? '';
    final model = car['model']?.toString() ?? '';

    final carName = [brand, model]
        .where((e) => e.trim().isNotEmpty)
        .join(' ');

    final pickupDate = _formatDate(rental['startDate']);
    final returnDate = _formatDate(rental['endDate']);

    final List images = carVariant['images'] is List
        ? carVariant['images'] as List
        : [];

    final imageWidget = _buildCarImage(images);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageWidget,
        ),
        title: Text(
          carName.isEmpty ? 'Car rental' : carName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          "Pickup: $pickupDate\nReturn: $returnDate",
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
        ),
        onTap: () {
          final bookingId = (rental['_id'] ?? '').toString();

          if (bookingId.isEmpty) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingDetailsPage(
                bookingId: bookingId,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isBookingsLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (renterBookings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text(
          "No upcoming rentals.",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    final sortedBookings = List<dynamic>.from(renterBookings);

    sortedBookings.sort((a, b) {
      final dateA = _safeDate(a['startDate']);
      final dateB = _safeDate(b['startDate']);
      return dateA.compareTo(dateB);
    });

    final shownRentals = sortedBookings.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          ...shownRentals.map((rental) {
            return _buildRentalCard(rental);
          }).toList(),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RenterMyRentals(
                      id: widget.renterId,
                    ),
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