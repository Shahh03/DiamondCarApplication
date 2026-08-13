import 'package:flutter/material.dart';
import 'package:project/renter/navbar_pages/account/account.dart';
import 'package:project/renter/navbar_pages/home/home.dart';
import 'package:project/renter/navbar_pages/myRentals/myRentals.dart';
import 'package:project/renter/navbar_pages/search/search.dart';

const _primary = Color(0xFF1D4ED8);
const _primaryDark = Color(0xFF1E40AF);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String userId;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.userId,
  });

  void _handleTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    final Widget destination;

    switch (index) {
      case 0:
        destination = RenterHome(renterId: userId);
        break;
      case 1:
        destination = RenterSearch(id: userId);
        break;
      case 2:
        destination = RenterMyRentals(id: userId);
        break;
      case 3:
        destination = RenterProfile(id: userId);
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 22,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 70,
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: const Color(0xFFE0EAFF),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);

              return IconThemeData(
                color: selected ? _primaryDark : _muted,
                size: selected ? 25 : 23,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);

              return TextStyle(
                color: selected ? _primaryDark : _muted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: -0.1,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) => _handleTap(context, index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.manage_search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_car_outlined),
                selectedIcon: Icon(Icons.directions_car_rounded),
                label: 'My Rentals',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
