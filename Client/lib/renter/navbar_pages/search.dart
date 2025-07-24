import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';

class RenterSearch extends StatefulWidget {
  final String id;

  const RenterSearch({super.key, required this.id});

  @override
  State<RenterSearch> createState() => _RenterSearchState();
}

class _RenterSearchState extends State<RenterSearch> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  Future<void> getUserData() async {
    try {
      final url = Uri.parse('http://10.0.2.2:8000/user/${widget.id}');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          userData = data;
          isLoading = false;
                          print(userData);

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


@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Search'),
      automaticallyImplyLeading: false, // ✅ removes back button
    ),
    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: Text(
              'Welcome, ${userData?['username'] ?? 'User'}',
              style: const TextStyle(fontSize: 18),
            ),
          ),
    bottomNavigationBar: BottomNavBar(
      currentIndex: 1, // This is the Home screen
      userId: widget.id,
    ),
  );
}






}