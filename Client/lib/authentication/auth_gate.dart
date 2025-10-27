import 'package:flutter/material.dart';
import 'auth_storage.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final ok = await AuthStorage.isLoggedIn();
    if (!mounted) return;

    if (!ok) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Logged in → pick home by role
    final role = await AuthStorage.readRole();
    if (!mounted) return;

    switch (role) {
      case UserRole.admin:
        Navigator.pushReplacementNamed(context, '/home/admin');
        break;
      case UserRole.provider:
        Navigator.pushReplacementNamed(context, '/home/provider');
        break;
      case UserRole.renter:
        Navigator.pushReplacementNamed(context, '/home/renter');
        break;
      default:
        // If role is missing, send to a small chooser or safe default
        Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
