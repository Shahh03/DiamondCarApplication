import 'package:flutter/material.dart';

import '../../authentication/api/auth_api.dart';
import '../api/provider_api.dart';
import '../bookings/provider_bookings.dart';
import '../dashboard/provider_dashboard.dart';
import '../earnings/provider_earnings.dart';
import '../fleet/provider_fleet.dart';
import '../profile/provider_profile.dart';
import '../provider_data_scope.dart';
import '../provider_ui.dart';

class ProviderNavbar extends StatefulWidget {
  final String providerId;

  const ProviderNavbar({
    super.key,
    required this.providerId,
  });

  @override
  State<ProviderNavbar> createState() => _ProviderNavbarState();
}

class _ProviderNavbarState extends State<ProviderNavbar> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _provider;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProvider();
  }

  Future<void> _loadProvider() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final provider = await ProviderApi.getProviderById(widget.providerId);
      if (!mounted) return;
      setState(() {
        _provider = provider;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _selectPage(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    await AuthApi.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _provider == null) {
      return const Scaffold(
        backgroundColor: providerBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _provider == null) {
      return Scaffold(
        backgroundColor: providerBackground,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ProviderEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load provider account',
                message: _error!,
                actionLabel: 'Try again',
                onAction: _loadProvider,
              ),
            ),
          ),
        ),
      );
    }

    final pages = <Widget>[
      ProviderDashboardPage(
        providerId: widget.providerId,
        onOpenFleet: () => _selectPage(1),
        onOpenBookings: () => _selectPage(2),
        onOpenEarnings: () => _selectPage(3),
      ),
      ProviderFleetPage(providerId: widget.providerId),
      ProviderBookingsPage(providerId: widget.providerId),
      ProviderEarningsPage(providerId: widget.providerId),
      ProviderProfilePage(
        providerId: widget.providerId,
        onLogout: _logout,
      ),
    ];

    return ProviderDataScope(
      provider: _provider!,
      refresh: _loadProvider,
      child: Scaffold(
        backgroundColor: providerBackground,
        body: IndexedStack(index: _selectedIndex, children: pages),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 72,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFDBEAFE),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected ? providerPrimary : providerMuted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectPage,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_car_outlined),
                selectedIcon: Icon(Icons.directions_car_rounded),
                label: 'Fleet',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: 'Bookings',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Earnings',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
