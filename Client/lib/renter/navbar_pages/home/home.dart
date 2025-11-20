import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';
import '../account/wishlist/myWishlist.dart';
import '../search/search.dart';
import '../myRentals/myRentals.dart';
import 'upcomingRentals.dart';
import 'quickActions.dart';

class RenterHome extends StatefulWidget {
  final String renterId;

  const RenterHome({super.key, required this.renterId});

  @override
  State<RenterHome> createState() => _RenterHomeState();
}

class _RenterHomeState extends State<RenterHome> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  Future<void> getUserData() async {
    try {
      final url = Uri.parse('http://10.0.2.2:8000/user/${widget.renterId}');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          userData = data;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load user');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getUserData();
  }

  void handleQuickAction(String action) {
    if (action == 'favorites') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WishlistPage(renterId: widget.renterId),
        ),
      );
    } else if (action == 'browse') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RenterSearch(id: widget.renterId),
        ),
      );
    } else if (action == 'rentals') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RenterMyRentals(id: widget.renterId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.blueAccent,
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔵 WELCOME SECTION
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome back,",
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${userData?['name'] ?? 'User'}",
                          style: const TextStyle(
                            fontSize: 26,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🔵 QUICK ACTIONS TITLE
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      "Quick Actions:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // 🔵 QUICK ACTIONS SECTION
                  QuickActions(onAction: handleQuickAction),

                  const SizedBox(height: 20),

                  // 🔵 UPCOMING RENTALS TITLE
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      "Upcoming Rental",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                // 🔵 UPCOMING RENTALS LIST
                  UpcomingRentals(
                    renterId: widget.renterId,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        userId: widget.renterId,
      ),
    );
  }
}
