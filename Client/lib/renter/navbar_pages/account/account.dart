import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';
import 'editProfile.dart';
import 'currencySelecetor.dart';
import 'Settings/settings.dart';
import 'wishlist/myWishlist.dart';
class RenterProfile extends StatefulWidget {
  final String id;

  const RenterProfile({super.key, required this.id});

  @override
  State<RenterProfile> createState() => _RenterProfileState();
}

class _RenterProfileState extends State<RenterProfile> {

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
Future<void> logOut() async {
  try {
    // Clear tokens, user data, or call logout endpoint if your backend supports it
    // For now, just pop to login page or clear local storage if any

    Navigator.pushReplacementNamed(context, '/login'); // or any login route

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged Out')),
    );
  } catch (e) {
    print('Error logging out: $e');
  }
}


 void showLogOutDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Are you sure you want to log out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            logOut(); // calls the actual logout
          },
          child: const Text('Log Out'),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        backgroundColor: Colors.blueAccent,
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
              ? const Center(child: Text('Failed to load data'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Profile Header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(userData!['profileImage'] ??
                                'https://via.placeholder.com/150'),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userData!['username'] ?? 'Username',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                userData!['email'] ?? 'Email',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quick Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statItem('Rentals', userData!['rentals']?.toString() ?? '0'),
                         // _statItem('Listings', userData!['listings']?.toString() ?? '0'),
                          _statItem('Rating', "${userData!['rating'] ?? '0'} ⭐"),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Settings / Options
                      Column(
                        children: [

                          _settingItem(Icons.person, 'Edit Profile', () { final userId = userData!["_id"]; Navigator.push(context,MaterialPageRoute(builder: (context) => EditProfilePage(id: userId),),);}),
                          _settingItem(Icons.favorite_border, 'My Wishlist', () { final userId = userData!["_id"]; Navigator.push(context,MaterialPageRoute(builder: (context) => WishlistPage(renterId: userId),),);}),
                          _settingItem(Icons.currency_exchange, 'Change Currerncy', () { final userId = userData!["_id"]; Navigator.push(context,MaterialPageRoute(builder: (context) => CurrencySelectorPage(id: userId),),);}),
                          _settingItem(Icons.help_outline, 'Help & Support', () {}),
                          _settingItem(Icons.settings, 'Settings', () { final userId = userData!["_id"]; Navigator.push(context,MaterialPageRoute(builder: (context) => SettingsPage(id: userId),),);}),
                          _settingItem(Icons.logout, 'Log Out', () {showLogOutDialog();}),
                        ],
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        userId: widget.id,
      ),
    );
  }

  

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _settingItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(label),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
