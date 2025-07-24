import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';
import '../booking_details_page.dart';

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
      final url = Uri.parse('http://10.0.2.2:8000/user/${widget.id}');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          userData = data;
          isUserLoading = false;
        });
        print("User Data: $userData");
      } else {
        throw Exception('Failed to load user');
      }
    } catch (e) {
      print('Error fetching user: $e');
      setState(() => isUserLoading = false);
    }
  }

  Future<void> getRenterBookings() async {
    try {
      final url = Uri.parse('http://10.0.2.2:8000/renter/getBookings/${widget.id}');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          renterBookings = data;
          isBookingsLoading = false;
        });
        print("Bookings: $renterBookings");
      } else {
        throw Exception('Failed to load bookings');
      }
    } catch (e) {
      print('Error fetching bookings: $e');
      setState(() => isBookingsLoading = false);
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


  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('My Rentals'),
      automaticallyImplyLeading: false,
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
                      'You have ${renterBookings.length} bookings',
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
      final variant = booking['carVariant'];
      final car = variant['car'];
      final List images = variant['images']; // List of maps
      
      final status = booking['status'];

      final brand = car?['brand'] ?? 'Unknown';
      final model = car?['model'] ?? '';
      final year = car?['year']?.toString() ?? '';

      return Card(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  elevation: 3,
  margin: const EdgeInsets.symmetric(vertical: 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),

  child: SizedBox(
  height: 160,
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
            width: 400,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
      );
    },
  ),
)
     ), // <--- MISSING THIS CLOSING PARENTHESIS

  
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$brand $model $year',
              style: const TextStyle( fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatDate(booking['startDate'])} - ${formatDate(booking['endDate'])}',
                  style: const TextStyle(color: Colors.grey , fontSize: 16), 
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: getStatusColor(status),
                    fontSize: 20
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: GestureDetector(
  onTap: () {
    // TODO: Navigate to detailed screen
  },
  child:ElevatedButton(
  onPressed: () {
    print(booking['_id']);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailsPage(bookingId: booking['_id'].toString()),
      ),
    );
  },
  style: ElevatedButton.styleFrom(
    elevation: 4,
    backgroundColor: Colors.blueAccent,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  ),
  child: const Text('View Details'),
),

),

            )
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