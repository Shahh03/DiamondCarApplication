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

Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return Colors.green;
    case 'pending':
      return Colors.orange;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.grey;
  }
}
Color _getStatusTextColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return Colors.green;
    case 'pending':
      return Colors.orange;
    case 'cancelled':
      return Colors.red;
    default:
      return Colors.black;
  }
}

String _capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
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
        provider['companyName'] ,
        style: const TextStyle(
          fontSize: 18,
          color: Color.fromARGB(255, 128, 117, 101),
        ),
      ),
    ],
  ),
),




                const Divider(height: 32),

               Text("Car Overview",style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,)),
                const SizedBox(height: 12),

                Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20, color: Colors.indigoAccent),
                    const SizedBox(width: 12),
                    Text(
                      _capitalize(booking['status']),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: _getStatusTextColor(booking['status']),
                      ),
                    ),
                  ],
                ),
              ),

                _rowItem(Icons.confirmation_number, "ID", booking["_id"]),

                _rowItem(Icons.calendar_today, "Start date", booking['startDate'].split('T')[0]),
                _rowItem(Icons.calendar_today_outlined, "End Date", booking['endDate'].split('T')[0]),

                const Divider(height: 32),

                // Car Info

               Text("Car Overview",style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,)),

                const SizedBox(height: 12),
                _rowItem(Icons.directions_car, "Category", car['category']),
                _rowItem(Icons.color_lens, "Color", carVariant['color']),
                _rowItem(Icons.local_gas_station, "Fuel Type", car['fuelType']),
                _rowItem(Icons.settings, "Gear Box", car['transmission']),
                _rowItem(Icons.event_seat, "Seating Capacity", "${car['seats']} passengers"),
                _rowItem(Icons.confirmation_number, "Registration #", carVariant['registrationNumber']),
                const Divider(height: 32),

                // Provider Info
               Text("Provider Info",style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold,)),
                const SizedBox(height: 8),

              _rowItem(Icons.business, "Listed By", provider['companyName']),
              _rowItem(Icons.email, "Email", provider['contactPerson']['email']),
              //_rowItem(Icons.phone, "Contact", provider['contactPerson']['phoneNumber']),

              
                const Divider(height: 32),

   

                // Payment Info
                Text("Payment Info", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                _rowItem(Icons.attach_money, "Amount", "${payment['amount']} ${payment['currency']}"),
                _rowItem(Icons.credit_card, "Method", payment['paymentMethod']),
              ],
            ),
          );
        },
      ),
    );
  }
}
        
