import 'package:flutter/material.dart';
import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';
import '../account/wishlist/myWishlist.dart';
import '../search/search.dart';
import '../myRentals/myRentals.dart';
import 'upcomingRentals.dart';
import 'quickActions.dart';
import 'browseCars.dart';
import '../account/account.dart';
import 'package:project/renter/api/user_api.dart';
import '../../api/user_api.dart';
class RenterHome extends StatefulWidget {
  final String renterId;

  const RenterHome({super.key, required this.renterId});

  @override
  State<RenterHome> createState() => _RenterHomeState();
}

class _RenterHomeState extends State<RenterHome> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? error;

  Future<void> getUserData() async {
  setState(() {
    isLoading = true;
    error = null;
  });

  try {
    final data = await UserApi.getUserById(widget.renterId);

    if (!mounted) return;

    setState(() {
      userData = data;
      isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      error = e.toString();
      isLoading = false;
    });
  }
}

  @override
  void initState() {
    super.initState();
    getUserData();
  }

  void handleQuickAction(String action) {
    if (action == 'favorites') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WishlistPage(renterId: widget.renterId),
        ),
      );
    } else if (action == 'browse') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RenterSearch(id: widget.renterId),
        ),
      );
    } else if (action == 'rentals') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RenterMyRentals(id: widget.renterId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (userData?['name'] ?? 'User').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Home',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RenterProfile(id: widget.renterId),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.25),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "U",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: getUserData,
        child: Builder(
          builder: (_) {
            if (isLoading) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: const [
                  _SkeletonHeader(),
                  SizedBox(height: 16),
                  _SkeletonCard(height: 90),
                  SizedBox(height: 16),
                  _SkeletonCard(height: 150),
                  SizedBox(height: 16),
                  _SkeletonCard(height: 210),
                ],
              );
            }

            if (error != null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Something went wrong",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: getUserData,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Try again"),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // WELCOME
                _WelcomeHeader(name: name),

                const SizedBox(height: 16),

                // QUICK ACTIONS
                _SectionTitle(
                  title: "Quick Actions",
                  subtitle: "Jump back in quickly",
                  icon: Icons.flash_on_rounded,
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  child: QuickActions(onAction: handleQuickAction),
                ),

                const SizedBox(height: 18),

                // UPCOMING RENTALS
                _SectionTitle(
                  title: "Upcoming Rentals",
                  subtitle: "Your next trips",
                  icon: Icons.event_available_rounded,
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  padding: const EdgeInsets.all(0),
                  child: UpcomingRentals(renterId: widget.renterId),
                ),

                const SizedBox(height: 18),

                // BROWSE CARS
                _SectionTitle(
                  title: "Looking for a ride?",
                  subtitle: "Recommended for you",
                  icon: Icons.directions_car_rounded,
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  padding: const EdgeInsets.all(0),
                  child: BrowseCars(renterId: widget.renterId),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        userId: widget.renterId,
      ),
    );
  }
}

/* ---------------- UI Helpers ---------------- */

class _WelcomeHeader extends StatelessWidget {
  final String name;
  const _WelcomeHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.waving_hand_rounded, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back,",
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF111827)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: child,
    );
  }
}

/* --------- Simple Skeletons (no packages) --------- */

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Container(
        margin: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _SkeletonHeader extends StatelessWidget {
  const _SkeletonHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 10, width: 110, color: const Color(0xFFE5E7EB)),
                const SizedBox(height: 8),
                Container(height: 14, width: 170, color: const Color(0xFFE5E7EB)),
              ],
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}
