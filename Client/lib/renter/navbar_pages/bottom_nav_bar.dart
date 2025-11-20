import 'package:flutter/material.dart';
import 'package:project/renter/navbar_pages/home/home.dart';
import 'package:project/renter/navbar_pages/search/search.dart';
import 'package:project/renter/navbar_pages/myRentals/myRentals.dart';
import 'package:project/renter/navbar_pages/account/account.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String userId;

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.userId,
  }) : super(key: key);

  void _handleTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget destination;

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
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _handleTap(context, index),
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.directions_car),
          label: 'My Rentals',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Account',
        ),
      ],
    );
  }
}
