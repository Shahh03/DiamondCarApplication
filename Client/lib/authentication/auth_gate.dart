import 'package:flutter/material.dart';

import '../admin/dashboard.dart';
import '../provider/dashboard.dart';
import '../renter/navbar_pages/home/home.dart';
import 'api/auth_api.dart';
import 'welcome.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final user = await AuthApi.restoreSession();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1D4ED8)),
        ),
      );
    }

    final user = _user;
    if (user == null) return const WelcomePage();

    final id = user['_id']?.toString() ?? '';
    switch (user['type']?.toString()) {
      case 'Renter':
        return RenterHome(renterId: id);
      case 'Provider':
        return ProviderDashboard(id: id);
      case 'Admin':
        return AdminDashboard(id: id);
      default:
        return const WelcomePage();
    }
  }
}
