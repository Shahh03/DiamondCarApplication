import 'package:flutter/material.dart';
import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';

import '../../api/booking_api.dart';
import '../../api/renter_api.dart';
import '../../bookingDetails.dart';

class RenterMyRentals extends StatefulWidget {
  final String id;

  const RenterMyRentals({super.key, required this.id});

  @override
  State<RenterMyRentals> createState() => _RenterMyRentalsState();
}

class _RenterMyRentalsState extends State<RenterMyRentals> {
  static const _primary = Color(0xFF1D4ED8);
  static const _background = Color(0xFFF5F7FB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  Map<String, dynamic>? userData;
  List<dynamic> renterBookings = [];

  bool isUserLoading = true;
  bool isBookingsLoading = true;
  String? bookingsError;

  bool get isLoading => isUserLoading || isBookingsLoading;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    await Future.wait([getUserData(), getRenterBookings()]);
  }

  Future<void> getUserData() async {
    try {
      final data = await RenterApi.getUserById(widget.id);
      if (!mounted) return;

      setState(() {
        userData = data;
        isUserLoading = false;
      });
    } catch (error) {
      debugPrint('Error fetching user: $error');
      if (!mounted) return;

      setState(() => isUserLoading = false);
    }
  }

  Future<void> getRenterBookings() async {
    try {
      final bookings = await BookingApi.getRenterBookings(widget.id);
      if (!mounted) return;

      setState(() {
        renterBookings = bookings;
        bookingsError = null;
        isBookingsLoading = false;
      });
    } catch (error) {
      debugPrint('Error fetching bookings: $error');
      if (!mounted) return;

      setState(() {
        bookingsError = 'We could not load your rentals. Please try again.';
        isBookingsLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      isUserLoading = true;
      isBookingsLoading = true;
      bookingsError = null;
    });
    await _loadPage();
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Not available';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getCarImageUrl(dynamic image) {
    if (image is String) return image;
    if (image is Map && image['filepath'] != null) {
      return image['filepath'].toString();
    }
    return '';
  }

  List<String> _getValidImages(dynamic value) {
    if (value is! List) return [];
    return value
        .map(_getCarImageUrl)
        .where((url) => url.trim().isNotEmpty)
        .toList();
  }

  String get _firstName {
    final rawName = userData?['name'] ?? userData?['username'];
    final name = rawName?.toString().trim() ?? '';
    if (name.isEmpty) return '';
    return name.split(RegExp(r'\s+')).first;
  }

  Future<void> _openBookingDetails(dynamic bookingId) async {
    if (bookingId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailsPage(
          bookingId: bookingId.toString(),
        ),
      ),
    );
    if (mounted) await getRenterBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildBody(),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        userId: widget.id,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      toolbarHeight: 88,
      titleSpacing: 20,
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _firstName.isEmpty ? 'My Rentals' : 'Hello, $_firstName',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your trips, all in one place',
            style: TextStyle(
              color: Color(0xFFDCEBFF),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton.filled(
            tooltip: 'Refresh rentals',
            onPressed: isLoading ? null : _refresh,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const _RentalsLoadingView(key: ValueKey('loading'));
    }

    if (bookingsError != null) {
      return _StateView(
        key: const ValueKey('error'),
        icon: Icons.cloud_off_rounded,
        title: 'Couldn’t load rentals',
        message: bookingsError!,
        actionLabel: 'Try again',
        onAction: _refresh,
      );
    }

    if (renterBookings.isEmpty) {
      return _StateView(
        key: const ValueKey('empty'),
        icon: Icons.key_rounded,
        title: 'No rentals yet',
        message:
            'Once you book a car, you’ll be able to manage the trip from here.',
        actionLabel: 'Refresh',
        onAction: _refresh,
      );
    }

    return RefreshIndicator(
      key: const ValueKey('content'),
      color: _primary,
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 700 ? 32.0 : 16.0;

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              28,
            ),
            itemCount: renterBookings.length + 1,
            separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 16 : 18),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _RentalsSummary(count: renterBookings.length);
              }

              final booking = renterBookings[index - 1];
              final variant = booking is Map ? booking['carVariant'] : null;
              final car = variant is Map ? variant['car'] : null;
              final images = variant is Map
                  ? _getValidImages(variant['images'])
                  : <String>[];

              final brand = car is Map ? car['brand']?.toString() : null;
              final model = car is Map ? car['model']?.toString() : null;
              final year = car is Map ? car['year']?.toString() : null;
              final name = [brand, model]
                  .where((part) => part != null && part!.trim().isNotEmpty)
                  .join(' ');

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _RentalCard(
                    carName: name.isEmpty ? 'Your rental car' : name,
                    year: year ?? '',
                    status: booking is Map
                        ? booking['status']?.toString() ?? 'Unknown'
                        : 'Unknown',
                    startDate: _formatDate(
                      booking is Map ? booking['startDate'] : null,
                    ),
                    endDate: _formatDate(
                      booking is Map ? booking['endDate'] : null,
                    ),
                    images: images,
                    onTap: () => _openBookingDetails(
                      booking is Map ? booking['_id'] : null,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RentalsSummary extends StatelessWidget {
  final int count;

  const _RentalsSummary({required this.count});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDBEAFE)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: _RenterMyRentalsState._primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rental overview',
                      style: TextStyle(
                        color: _RenterMyRentalsState._ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? 'booking' : 'bookings'} in your account',
                      style: const TextStyle(
                        color: _RenterMyRentalsState._muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  final String carName;
  final String year;
  final String status;
  final String startDate;
  final String endDate;
  final List<String> images;
  final VoidCallback onTap;

  const _RentalCard({
    required this.carName,
    required this.year,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.images,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(status);
    final statusLabel = _statusLabel(status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RentalImage(
                images: images,
                status: statusLabel,
                statusStyle: statusStyle,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            carName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _RenterMyRentalsState._ink,
                              fontSize: 21,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                        ),
                        if (year.trim().isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              year,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DatePanel(startDate: startDate, endDate: endDate),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _RenterMyRentalsState._primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'View booking details',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 19),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _StatusStyle _statusStyle(String value) {
    switch (value.toLowerCase()) {
      case 'confirmed':
        return const _StatusStyle(Color(0xFF047857), Color(0xFFD1FAE5));
      case 'active':
      case 'ongoing':
      case 'inprogress':
        return const _StatusStyle(Color(0xFF1D4ED8), Color(0xFFDBEAFE));
      case 'completed':
        return const _StatusStyle(Color(0xFF475569), Color(0xFFE2E8F0));
      case 'cancelled':
      case 'rejected':
        return const _StatusStyle(Color(0xFFB91C1C), Color(0xFFFEE2E2));
      case 'pending':
        return const _StatusStyle(Color(0xFFB45309), Color(0xFFFEF3C7));
      default:
        return const _StatusStyle(Color(0xFF475569), Color(0xFFF1F5F9));
    }
  }

  static String _statusLabel(String value) {
    final status = value.trim();
    if (status.isEmpty) return 'Unknown';
    if (status.toLowerCase() == 'inprogress') return 'On Rent';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }
}

class _RentalImage extends StatefulWidget {
  final List<String> images;
  final String status;
  final _StatusStyle statusStyle;

  const _RentalImage({
    required this.images,
    required this.status,
    required this.statusStyle,
  });

  @override
  State<_RentalImage> createState() => _RentalImageState();
}

class _RentalImageState extends State<_RentalImage> {
  late final PageController _pageController;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _RentalImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.images.length != oldWidget.images.length &&
        _activeIndex >= widget.images.length) {
      _activeIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Taller on phones so the car remains the visual focus, but capped on
        // wider screens so the card never becomes excessively large.
        final imageHeight =
            (constraints.maxWidth * 0.62).clamp(225.0, 320.0).toDouble();

        return SizedBox(
          height: imageHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.images.isEmpty)
                const _ImagePlaceholder()
              else
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _activeIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return Image.network(
                      widget.images[index],
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const _ImagePlaceholder(showLoader: true);
                      },
                      errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                    );
                  },
                ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0x73000000)],
                      stops: [0.48, 1],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: widget.statusStyle.background,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: widget.statusStyle.foreground,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        widget.status,
                        style: TextStyle(
                          color: widget.statusStyle.foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.images.length > 1) ...[
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xA6000000),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_activeIndex + 1} / ${widget.images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.images.length <= 8)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.images.length, (index) {
                          final isActive = index == _activeIndex;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            width: isActive ? 20 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final bool showLoader;

  const _ImagePlaceholder({this.showLoader = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF3F8),
      child: Center(
        child: showLoader
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(
                Icons.directions_car_filled_rounded,
                size: 58,
                color: Color(0xFF94A3B8),
              ),
      ),
    );
  }
}

class _DatePanel extends StatelessWidget {
  final String startDate;
  final String endDate;

  const _DatePanel({required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DateItem(
              label: 'PICK-UP',
              value: startDate,
              icon: Icons.trip_origin_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFFE2E8F0),
          ),
          Expanded(
            child: _DateItem(
              label: 'RETURN',
              value: endDate,
              icon: Icons.location_on_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DateItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: _RenterMyRentalsState._primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _RenterMyRentalsState._ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _StateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _RenterMyRentalsState._primary,
      onRefresh: onAction,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32),
            children: [
              SizedBox(height: constraints.maxHeight * 0.17),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 42,
                    color: _RenterMyRentalsState._primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _RenterMyRentalsState._ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _RenterMyRentalsState._muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  label: Text(actionLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _RenterMyRentalsState._primary,
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RentalsLoadingView extends StatelessWidget {
  const _RentalsLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (_, __) {
        return Container(
          height: 330,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 185,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9EEF5),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 180,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EEF5),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusStyle {
  final Color foreground;
  final Color background;

  const _StatusStyle(this.foreground, this.background);
}
