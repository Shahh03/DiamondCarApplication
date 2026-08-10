import 'package:flutter/material.dart';
import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';

import '../../api/user_api.dart';
import '../account/account.dart';
import '../myRentals/myRentals.dart';
import '../search/search.dart';
import 'browseCars.dart';
import 'recentlyViewedCars.dart';
import 'recommendedCars.dart';
import 'upcomingRentals.dart';

const _primary = Color(0xFF1D4ED8);
const _primaryDark = Color(0xFF1E40AF);
const _background = Color(0xFFF5F7FB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class RenterHome extends StatefulWidget {
  final String renterId;

  const RenterHome({super.key, required this.renterId});

  @override
  State<RenterHome> createState() => _RenterHomeState();
}

class _RenterHomeState extends State<RenterHome> {
  final _upcomingKey = GlobalKey<UpcomingRentalsState>();
  final _recommendedKey = GlobalKey<RecommendedCarsState>();
  final _recentlyViewedKey = GlobalKey<RecentlyViewedCarsState>();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (mounted) {
      setState(() => _errorMessage = null);
    }

    try {
      final data = await UserApi.getUserById(widget.renterId);
      if (!mounted) return;

      setState(() {
        _userData = data;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Home user load error: $error');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load your account. Please try again.';
      });
    }
  }

  Future<void> _refreshHome() async {
    final tasks = <Future<void>>[
      _loadUser(showLoading: false),
    ];

    final upcoming = _upcomingKey.currentState;
    final recommended = _recommendedKey.currentState;
    final recentlyViewed = _recentlyViewedKey.currentState;

    if (upcoming != null) tasks.add(upcoming.refresh());
    if (recommended != null) tasks.add(recommended.refresh());
    if (recentlyViewed != null) tasks.add(recentlyViewed.refresh());

    await Future.wait(tasks);
  }

  String get _name {
    final value = (_userData?['name'] ?? 'User').toString().trim();
    return value.isEmpty ? 'User' : value;
  }

  String get _firstName => _name.split(RegExp(r'\s+')).first;

  String get _currency =>
      (_userData?['currency'] ?? 'EGP').toString().toUpperCase();

  Map<String, dynamic>? get _fxRates {
    final rates = _userData?['fxRates'];
    return rates is Map ? Map<String, dynamic>.from(rates) : null;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RenterSearch(id: widget.renterId)),
    );
  }

  void _openRentals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RenterMyRentals(id: widget.renterId),
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RenterProfile(id: widget.renterId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        foregroundColor: Colors.white,
        titleSpacing: 18,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.diamond_outlined, size: 23),
            SizedBox(width: 8),
            Text(
              'DiamondCar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              button: true,
              label: 'Open account',
              child: InkWell(
                onTap: _openProfile,
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white.withOpacity(0.18),
                  child: Text(
                    _name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryDark, Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _refreshHome,
        child: _buildBody(),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        userId: widget.renterId,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _HomeLoading();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 800 ? 28.0 : 16.0;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            30,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WelcomeHero(
                      greeting: _greeting,
                      name: _firstName,
                      onSearch: _openSearch,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      _HomeError(
                        message: _errorMessage!,
                        onRetry: () => _loadUser(showLoading: false),
                      ),
                    ],
                    const SizedBox(height: 25),
                    _SectionHeader(
                      title: 'Upcoming rentals',
                      subtitle: 'Your next confirmed bookings',
                      actionLabel: 'See all',
                      onAction: _openRentals,
                    ),
                    const SizedBox(height: 12),
                    UpcomingRentals(
                      key: _upcomingKey,
                      renterId: widget.renterId,
                    ),
                    const SizedBox(height: 26),
                    _SectionHeader(
                      title: 'Recommended for you',
                      subtitle: 'Based on your activity and preferences',
                      actionLabel: 'View all',
                      onAction: _openSearch,
                    ),
                    const SizedBox(height: 12),
                    RecommendedCars(
                      key: _recommendedKey,
                      renterId: widget.renterId,
                      currency: _currency,
                      fxRates: _fxRates,
                    ),
                    const SizedBox(height: 26),
                    RecentlyViewedCars(
                      key: _recentlyViewedKey,
                      renterId: widget.renterId,
                      currency: _currency,
                      fxRates: _fxRates,
                    ),
                    _SectionHeader(
                      title: 'Browse by type',
                      subtitle: 'Find a car that fits your journey',
                      actionLabel: 'View all',
                      onAction: _openSearch,
                    ),
                    const SizedBox(height: 12),
                    BrowseCars(renterId: widget.renterId),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  final String greeting;
  final String name;
  final VoidCallback onSearch;

  const _WelcomeHero({
    required this.greeting,
    required this.name,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryDark, Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331D4ED8),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -45,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Where do you want to drive today?',
                  style: TextStyle(
                    color: Color(0xFFDCEAFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: onSearch,
                    borderRadius: BorderRadius.circular(15),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: _primary,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search by brand or model',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.tune_rounded,
                            color: _primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class _HomeError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _HomeError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Account details unavailable',
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 14),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                const _LoadingBlock(height: 178, radius: 24),
                const SizedBox(height: 24),
                const _LoadingBlock(height: 122, radius: 20),
                const SizedBox(height: 12),
                const _LoadingBlock(height: 122, radius: 20),
                const SizedBox(height: 24),
                const _LoadingBlock(height: 286, radius: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  final double height;
  final double radius;

  const _LoadingBlock({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
