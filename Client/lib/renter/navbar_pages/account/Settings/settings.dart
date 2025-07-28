import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'changeUsername.dart';
import 'changePassword.dart';

class SettingsPage extends StatefulWidget {
  final String id;

  const SettingsPage({super.key, required this.id});

  @override
  State<SettingsPage> createState() => _SettingsPagePageState();
}

class _SettingsPagePageState extends State<SettingsPage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getUserData();
  }

  Future<void> getUserData() async {
    try {
      final url = Uri.parse('http://10.0.2.2:8000/user/${widget.id}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userData = data;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      print('Error: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
                backgroundColor: Colors.blueAccent,

        title: const Text('Settings'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _settingItem(
                    Icons.person,
                    'Change Username',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeUsernamePage(userId: widget.id),
                        ),
                      );
                    },
                  ),
                  _settingItem(
                    Icons.lock,
                    'Change Password',
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangePasswordPage(userId: widget.id),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _settingItem(IconData icon, String label, VoidCallback onTap) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
