import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';
import 'editProfile.dart';
// Ensure this filename is correct in your project:
import 'currencySelector.dart'; // <-- if your file is actually currencySelecetor.dart, revert this line
import 'Settings/settings.dart';
import 'wishlist/myWishlist.dart';


import 'package:http_parser/http_parser.dart';

class RenterProfile extends StatefulWidget {
  final String id;
  const RenterProfile({super.key, required this.id});

  @override
  State<RenterProfile> createState() => _RenterProfileState();
}

class _RenterProfileState extends State<RenterProfile> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  // Image picking state
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    getUserData();
  }

  Future<void> getUserData() async {
    try {
      final url = Uri.parse('http://10.0.2.2:8000/user/${widget.id}');
      final response = await http.get(url);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          userData = data as Map<String, dynamic>;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load user (status ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }


String _fullUrl(String p) {
   const String _base = 'http://10.0.2.2:8000'; // emulator -> host machine
  if (p.startsWith('http://') || p.startsWith('https://')) return p;
  if (p.startsWith('/')) return '$_base$p';
  return '$_base/$p';
}

String _profileImageUrl(Map<String, dynamic> u) {
  // correct key: profilePicture (lowercase p)
  final pic = u['profilePicture'];
  if (pic is Map<String, dynamic>) {
    final fp = pic['filepath'];
    if (fp is String && fp.isNotEmpty) return _fullUrl(fp);
  }

  // optional direct absolute string your API might return someday
  final direct = u['profileImage'];
  if (direct is String && direct.isNotEmpty) return _fullUrl(direct);

  return 'https://via.placeholder.com/150';
}


  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        // TODO: Upload the new image to your backend, then refresh user data.
        // Example (adjust endpoint and field name):
        // await _uploadProfileImage(_imageFile!);
        // await getUserData();
      }
    } catch (e) {
      debugPrint('pickImage error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick image')),
      );
    }
  }



Future<void> _uploadProfileImage(File image, String type) async {
  // type: 'profile' | 'license' | 'id'
  final uri = Uri.parse('http://10.0.2.2:8000/renters/${widget.id}/image?type=$type');
  final req = http.MultipartRequest('POST', uri)
    ..files.add(await http.MultipartFile.fromPath(
      'file',
      image.path,
      contentType: MediaType('image', 'jpeg'),
    ));

  final resp = await req.send();
  final body = await resp.stream.bytesToString();
  if (resp.statusCode == 200 || resp.statusCode == 201) {
    await getUserData(); // refresh UI with new image path
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image updated')),
    );
  } else {
    throw Exception('Upload failed: ${resp.statusCode} $body');
  }
}
  void _showChangePictureOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> logOut() async {
    try {
      // Clear tokens or call logout endpoint if you have one
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged Out')),
      );
    } catch (e) {
      debugPrint('Error logging out: $e');
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
              logOut();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account'),
        backgroundColor: Colors.blueAccent,
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (userData == null)
              ? const Center(child: Text('Failed to load data'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ===== Profile Header =====
                      Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                              radius: 40,
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : NetworkImage(_profileImageUrl(userData!)) as ImageProvider,
                            ),

                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: InkWell(
                                  onTap: _showChangePictureOptions,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.add,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
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

                      // ===== Quick Stats =====
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statItem('Rentals',
                              userData!['rentals']?.toString() ?? '0'),
                          _statItem('Rating',
                              "${userData!['rating'] ?? '0'} ⭐"),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ===== Settings / Options =====
                      Column(
                        children: [
                          _settingItem(Icons.person, 'Edit Profile', () {
                            final userId = userData!["_id"];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditProfilePage(id: userId),
                              ),
                            );
                          }),
                          _settingItem(Icons.favorite_border, 'My Wishlist', () {
                            final userId = userData!["_id"];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    WishlistPage(renterId: userId),
                              ),
                            );
                          }),
                          _settingItem(Icons.currency_exchange,
                              'Change Currency', () {
                            final userId = userData!["_id"];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CurrencySelectorPage(id: userId),
                              ),
                            );
                          }),
                          _settingItem(Icons.help_outline, 'Help & Support', () {
                            // TODO: navigate to help
                          }),
                          _settingItem(Icons.settings, 'Settings', () {
                            final userId = userData!["_id"];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsPage(id: userId),
                              ),
                            );
                          }),
                          _settingItem(Icons.logout, 'Log Out', () {
                            showLogOutDialog();
                          }),
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
