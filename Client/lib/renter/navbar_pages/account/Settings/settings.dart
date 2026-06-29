import 'package:flutter/material.dart';
import 'changeUsername.dart';
import 'changePassword.dart';

class SettingsPage extends StatelessWidget {
  final String id;

  const SettingsPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text('Settings'),
      ),
      body: Padding(
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
                    builder: (_) => ChangeUsernamePage(userId: id),
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
                    builder: (_) => ChangePasswordPage(userId: id),
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