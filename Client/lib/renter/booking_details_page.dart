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
    final url = Uri.parse('http://10.0.2.2:8000/booking/get/${widget.bookingId}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load booking details');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Booking Details")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _bookingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final booking = snapshot.data!;
          final renter = booking['renter'];
          final carVariant = booking['carVariant'];
          final car = carVariant['car'];
          final provider = carVariant['provider'];
          final payment = booking['payment'];

          final List images = carVariant['images']; // List of maps


          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [



                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.25,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final imgPath = images[index]['filepath'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                "assets/images/cars/$imgPath",
                                width: MediaQuery.of(context).size.width,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

Padding(
  padding: const EdgeInsets.only(top: 16.0),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "${car['brand']} ${car['model']} ${car['year']}",
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
            "${provider['address']['state']}, ${provider['address']['country']}",
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    ],
  ),
),


                  Padding(
                    padding: const EdgeInsets.only(top: 5.0), // 16 pixels top margin
                    child: Text(
                      "${provider['companyName']}",
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),




                const Divider(height: 32),                 

                Text("Status: ${booking['status']}"),
                Text("From: ${booking['startDate']}"),
                Text("To: ${booking['endDate']}"),
                const Divider(height: 32),

                // Car Info
                const SizedBox(height: 8),
                Text("Brand: ${car['brand']}"),
                Text("Model: ${car['model']}"),
                Text("Year: ${car['year']}"),
                Text("Category: ${car['category']}"),
                Text("Color: ${carVariant['color']}"),
                Text("Registration #: ${carVariant['registrationNumber']}"),
                Text("Rental Price/Day: ${carVariant['rentalPricePerDay']} AED"),
                const Divider(height: 32),

                // Provider Info
                Text("Provider Info", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text("Username: ${provider['username']}"),
                Text("Company: ${provider['companyName']}"),
                Text("Email: ${provider['contactPerson']['email']}"),
                Text("Phone: ${provider['contactPerson']['phoneNumber']}"),
                const Divider(height: 32),

   

                // Payment Info
                Text("Payment Info", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text("Amount: ${payment['amount']} ${payment['currency']}"),
                Text("Status: ${payment['paymentStatus']}"),
                Text("Method: ${payment['paymentMethod']}"),
                Text("Transaction ID: ${payment['transactionId']}"),
              ],
            ),
          );
        },
      ),
    );
  }
}
        
