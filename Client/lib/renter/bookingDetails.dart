import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BookingDetailsPage extends StatefulWidget {
  final String bookingId;

  const BookingDetailsPage({super.key, required this.bookingId});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  late Future<Map<String, dynamic>> _bookingFuture;

  @override
  void initState() {
    super.initState();
    _bookingFuture = fetchBookingDetails();
  }

  Future<Map<String, dynamic>> fetchBookingDetails() async {
    final url = Uri.parse(
      'http://10.0.2.2:8000/booking/get/${widget.bookingId}',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load booking details');
    }
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

    return '';
  }

  Widget buildCarImages(List images) {
    if (images.isEmpty) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.25,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
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
      height: MediaQuery.of(context).size.height * 0.25,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (context, index) {
          final imgPath = getCarImageUrl(images[index]);

          if (imgPath.isEmpty) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imgPath,
                width: MediaQuery.of(context).size.width - 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: MediaQuery.of(context).size.width - 32,
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

  Widget _rowItem(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.indigoAccent),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: "$label: ",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: value ?? 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.black;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    return date.toString().split('T')[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Details"),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _bookingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final booking = snapshot.data!;

          final carVariant = booking['carVariant'] ?? {};
          final car = carVariant['car'] ?? {};
          final provider = carVariant['provider'] ?? {};
          final payment = booking['payment'] ?? {};

          final List images = carVariant['images'] ?? [];

          final providerAddress = provider['address'] ?? {};
          final contactPerson = provider['contactPerson'] ?? {};

          final status = booking['status']?.toString() ?? 'unknown';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildCarImages(images),

                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${car['brand'] ?? 'Unknown'} ${car['model'] ?? ''} ${car['year'] ?? ''}",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 18,
                            color: Colors.indigoAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${providerAddress['state'] ?? 'N/A'}, ${providerAddress['country'] ?? 'N/A'}",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color.fromARGB(255, 128, 117, 101),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.business,
                        size: 18,
                        color: Colors.indigoAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        provider['companyName']?.toString() ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color.fromARGB(255, 128, 117, 101),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 32),

                Text(
                  "Booking Overview",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.indigoAccent,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _capitalize(status),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: _getStatusTextColor(status),
                        ),
                      ),
                    ],
                  ),
                ),

                _rowItem(
                  Icons.confirmation_number,
                  "ID",
                  booking["_id"]?.toString(),
                ),
                _rowItem(
                  Icons.calendar_today,
                  "Start Date",
                  _formatDate(booking['startDate']),
                ),
                _rowItem(
                  Icons.calendar_today_outlined,
                  "End Date",
                  _formatDate(booking['endDate']),
                ),

                const Divider(height: 32),

                Text(
                  "Car Overview",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 12),

                _rowItem(
                  Icons.directions_car,
                  "Category",
                  car['category']?.toString(),
                ),
                _rowItem(
                  Icons.color_lens,
                  "Color",
                  carVariant['color']?.toString(),
                ),
                _rowItem(
                  Icons.local_gas_station,
                  "Fuel Type",
                  car['fuelType']?.toString(),
                ),
                _rowItem(
                  Icons.settings,
                  "Gear Box",
                  car['transmission']?.toString(),
                ),
                _rowItem(
                  Icons.event_seat,
                  "Seating Capacity",
                  car['seats'] != null ? "${car['seats']} passengers" : null,
                ),
                _rowItem(
                  Icons.confirmation_number,
                  "Registration #",
                  carVariant['registrationNumber']?.toString(),
                ),

                const Divider(height: 32),

                Text(
                  "Provider Info",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 8),

                _rowItem(
                  Icons.business,
                  "Listed By",
                  provider['companyName']?.toString(),
                ),
                _rowItem(
                  Icons.email,
                  "Email",
                  contactPerson['email']?.toString(),
                ),

                const Divider(height: 32),

                Text(
                  "Payment Info",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 8),

                _rowItem(
                  Icons.attach_money,
                  "Amount",
                  payment['amount'] != null && payment['currency'] != null
                      ? "${payment['amount']} ${payment['currency']}"
                      : null,
                ),
                _rowItem(
                  Icons.credit_card,
                  "Method",
                  payment['paymentMethod']?.toString(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}