import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/provider_dashboard_api.dart';
import '../provider_data_scope.dart';
import '../provider_ui.dart';

const _surface = Colors.white;
const _softBlue = Color(0xFFEFF6FF);
const _success = Color(0xFF059669);
const _danger = Color(0xFFDC2626);
const _orange = Color(0xFFEA580C);

class ProviderDashboardPage extends StatefulWidget {
  final String providerId;
  final VoidCallback onOpenFleet;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenEarnings;

  const ProviderDashboardPage({
    super.key,
    required this.providerId,
    required this.onOpenFleet,
    required this.onOpenBookings,
    required this.onOpenEarnings,
  });

  @override
  State<ProviderDashboardPage> createState() =>
      _ProviderDashboardPageState();
}

class _ProviderDashboardPageState extends State<ProviderDashboardPage> {
  Map<String, dynamic>? _dashboard;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final dashboard = await ProviderDashboardApi.getDashboard(
        widget.providerId,
      );
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
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

  Future<void> _refreshAll() async {
    final refreshProvider = ProviderDataScope.of(context).refresh;
    await Future.wait([refreshProvider(), _loadDashboard()]);
  }

  Map<String, dynamic> get _fleet => _asMap(_dashboard?['fleet']);
  Map<String, dynamic> get _bookings => _asMap(_dashboard?['bookings']);
  Map<String, dynamic> get _earnings => _asMap(_dashboard?['earnings']);

  Map<String, dynamic>? get _nextRental {
    final value = _dashboard?['nextRental'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  List<Map<String, dynamic>> get _recentBookings =>
      _asMapList(_dashboard?['recentBookings']);

  int _integer(Map<String, dynamic> source, String key) =>
      (source[key] as num?)?.toInt() ?? 0;

  String get _currency {
    final value = _dashboard?['currency']?.toString().trim().toUpperCase();
    return value?.isNotEmpty == true ? value! : 'AED';
  }

  String _money(dynamic value) {
    final amount = value is num ? value : num.tryParse('$value') ?? 0;
    return '$_currency ${NumberFormat('#,##0.00').format(amount)}';
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final providerScope = ProviderDataScope.of(context);
    final provider = providerScope.provider;
    final isVerified = provider['isVerified'] == true ||
        provider['status']?.toString() == 'Accepted';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              sliver: SliverToBoxAdapter(
                child: _DashboardHeader(
                  greeting: _greeting,
                  companyName: providerScope.companyName,
                  profilePicture: providerScope.profilePicture,
                  isVerified: isVerified,
                  isRefreshing: _isLoading && _dashboard != null,
                  onRefresh: _loadDashboard,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              sliver: SliverList.list(
                children: [
                  if (_isLoading && _dashboard == null)
                    const _DashboardSkeleton()
                  else if (_error != null && _dashboard == null)
                    _FullErrorState(
                      message: _error!,
                      onRetry: _loadDashboard,
                    )
                  else ...[
                    _PerformanceCard(
                      net: _money(_earnings['monthNet']),
                      collected: _money(_earnings['monthCollected']),
                      refunds: _money(_earnings['monthRefunds']),
                      paymentCount: _integer(_earnings, 'paymentCount'),
                      refundCount: _integer(_earnings, 'refundCount'),
                      onTap: widget.onOpenEarnings,
                    ),
                    const SizedBox(height: 20),
                    const _SectionHeading(
                      eyebrow: 'OPERATIONS',
                      title: 'Today at a glance',
                    ),
                    const SizedBox(height: 11),
                    _OperationsStrip(
                      totalVehicles: _integer(_fleet, 'total'),
                      activeRentals: _integer(_bookings, 'active'),
                      upcomingRentals: _integer(_bookings, 'upcoming'),
                      onOpenFleet: widget.onOpenFleet,
                      onOpenBookings: widget.onOpenBookings,
                    ),
                    const SizedBox(height: 24),
                    _SectionHeading(
                      eyebrow: 'SCHEDULE',
                      title: 'Next rental',
                      actionLabel: 'View bookings',
                      onAction: widget.onOpenBookings,
                    ),
                    const SizedBox(height: 11),
                    if (_nextRental == null)
                      const _EmptyPanel(
                        icon: Icons.calendar_today_outlined,
                        title: 'No upcoming rentals',
                        message: 'Your next confirmed pickup will appear here.',
                      )
                    else
                      _NextRentalPanel(
                        booking: _nextRental!,
                        money: _money,
                        onTap: widget.onOpenBookings,
                      ),
                    const SizedBox(height: 22),
                    _FleetAvailabilityPanel(
                      total: _integer(_fleet, 'total'),
                      available: _integer(_fleet, 'available'),
                      unavailable: _integer(_fleet, 'unavailable'),
                      availabilityRate: _integer(
                        _fleet,
                        'availabilityRate',
                      ),
                      onTap: widget.onOpenFleet,
                    ),
                    const SizedBox(height: 24),
                    _SectionHeading(
                      eyebrow: 'LATEST',
                      title: 'Booking activity',
                      actionLabel: 'View all',
                      onAction: widget.onOpenBookings,
                    ),
                    const SizedBox(height: 11),
                    if (_recentBookings.isEmpty)
                      const _EmptyPanel(
                        icon: Icons.history_rounded,
                        title: 'No booking activity yet',
                        message: 'New bookings and status updates appear here.',
                      )
                    else
                      _RecentActivityPanel(
                        bookings: _recentBookings.take(4).toList(),
                        onTap: widget.onOpenBookings,
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _InlineError(message: _error!, onRetry: _loadDashboard),
                    ],
                    const SizedBox(height: 12),
                    _LastUpdatedLabel(value: _dashboard?['generatedAt']),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String greeting;
  final String companyName;
  final String profilePicture;
  final bool isVerified;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const _DashboardHeader({
    required this.greeting,
    required this.companyName,
    required this.profilePicture,
    required this.isVerified,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: const TextStyle(
                    color: providerMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: providerInk,
                          fontSize: 23,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: providerPrimary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  DateFormat('EEEE, d MMMM').format(DateTime.now()),
                  style: const TextStyle(
                    color: providerMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isRefreshing ? null : onRefresh,
            tooltip: 'Refresh dashboard',
            style: IconButton.styleFrom(
              backgroundColor: _surface,
              side: const BorderSide(color: providerBorder),
            ),
            icon: isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 9),
          _BusinessAvatar(imageUrl: profilePicture),
        ],
      );
}

class _BusinessAvatar extends StatelessWidget {
  final String imageUrl;

  const _BusinessAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) => Container(
        width: 50,
        height: 50,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _surface,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
        ),
        child: ClipOval(
          child: Container(
            color: _softBlue,
            child: imageUrl.isEmpty
                ? const Icon(Icons.storefront_rounded, color: providerPrimary)
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.storefront_rounded,
                      color: providerPrimary,
                    ),
                  ),
          ),
        ),
      );
}

class _PerformanceCard extends StatelessWidget {
  final String net;
  final String collected;
  final String refunds;
  final int paymentCount;
  final int refundCount;
  final VoidCallback onTap;

  const _PerformanceCard({
    required this.net,
    required this.collected,
    required this.refunds,
    required this.paymentCount,
    required this.refundCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Ink(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2D68), providerPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x262563EB),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly performance',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Net collected this month',
                            style: TextStyle(
                              color: Color(0xFFBFDBFE),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFFBFDBFE),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    net,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _PerformanceDetail(
                        label: 'Collected',
                        value: collected,
                        footnote:
                            '$paymentCount payment${paymentCount == 1 ? '' : 's'}',
                        positive: true,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: Colors.white.withOpacity(0.16),
                    ),
                    Expanded(
                      child: _PerformanceDetail(
                        label: 'Refunded',
                        value: refunds,
                        footnote:
                            '$refundCount refund${refundCount == 1 ? '' : 's'}',
                        positive: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _PerformanceDetail extends StatelessWidget {
  final String label;
  final String value;
  final String footnote;
  final bool positive;

  const _PerformanceDetail({
    required this.label,
    required this.value,
    required this.footnote,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          left: positive ? 0 : 16,
          right: positive ? 16 : 0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  positive
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: positive
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFDBEAFE),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              footnote,
              style: const TextStyle(
                color: Color(0xFF93C5FD),
                fontSize: 9,
              ),
            ),
          ],
        ),
      );
}

class _SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: providerPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: providerInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(actionLabel!),
            ),
        ],
      );
}

class _OperationsStrip extends StatelessWidget {
  final int totalVehicles;
  final int activeRentals;
  final int upcomingRentals;
  final VoidCallback onOpenFleet;
  final VoidCallback onOpenBookings;

  const _OperationsStrip({
    required this.totalVehicles,
    required this.activeRentals,
    required this.upcomingRentals,
    required this.onOpenFleet,
    required this.onOpenBookings,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: providerBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: _OperationMetric(
                icon: Icons.directions_car_outlined,
                value: '$totalVehicles',
                label: 'Vehicles',
                color: providerPrimary,
                onTap: onOpenFleet,
              ),
            ),
            const _VerticalDivider(),
            Expanded(
              child: _OperationMetric(
                icon: Icons.key_outlined,
                value: '$activeRentals',
                label: 'Active',
                color: _success,
                onTap: onOpenBookings,
              ),
            ),
            const _VerticalDivider(),
            Expanded(
              child: _OperationMetric(
                icon: Icons.calendar_month_outlined,
                value: '$upcomingRentals',
                label: 'Upcoming',
                color: _orange,
                onTap: onOpenBookings,
              ),
            ),
          ],
        ),
      );
}

class _OperationMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OperationMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Column(
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: providerInk,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: providerMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 54,
        color: providerBorder,
      );
}

class _NextRentalPanel extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String Function(dynamic) money;
  final VoidCallback onTap;

  const _NextRentalPanel({
    required this.booking,
    required this.money,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vehicle = _asMap(booking['vehicle']);
    final renter = _asMap(booking['renter']);
    final start = DateTime.tryParse(booking['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(booking['endDate']?.toString() ?? '');
    final image = vehicle['image']?.toString() ?? '';

    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: providerBorder),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _VehicleThumbnail(imageUrl: image),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  vehicle['name']?.toString() ?? 'Vehicle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: providerInk,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _CountdownBadge(startDate: start),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            vehicle['registrationNumber']?.toString() ?? '',
                            style: const TextStyle(
                              color: providerMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                color: providerMuted,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  renter['name']?.toString() ?? 'Renter',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: providerInk,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(21),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: providerPrimary,
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        start == null || end == null
                            ? 'Rental dates unavailable'
                            : '${DateFormat('d MMM').format(start.toLocal())} – ${DateFormat('d MMM y').format(end.toLocal())}',
                        style: const TextStyle(
                          color: providerInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      money(booking['totalPrice']),
                      style: const TextStyle(
                        color: providerPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: providerMuted,
                      size: 20,
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

class _VehicleThumbnail extends StatelessWidget {
  final String imageUrl;

  const _VehicleThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 86,
          height: 76,
          color: _softBlue,
          child: imageUrl.isEmpty
              ? const Icon(
                  Icons.directions_car_rounded,
                  color: providerPrimary,
                  size: 34,
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.directions_car_rounded,
                    color: providerPrimary,
                    size: 34,
                  ),
                ),
        ),
      );
}

class _CountdownBadge extends StatelessWidget {
  final DateTime? startDate;

  const _CountdownBadge({required this.startDate});

  String get _label {
    if (startDate == null) return 'Upcoming';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final local = startDate!.toLocal();
    final start = DateTime(local.year, local.month, local.day);
    final days = start.difference(today).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _label,
          style: const TextStyle(
            color: _orange,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _FleetAvailabilityPanel extends StatelessWidget {
  final int total;
  final int available;
  final int unavailable;
  final int availabilityRate;
  final VoidCallback onTap;

  const _FleetAvailabilityPanel({
    required this.total,
    required this.available,
    required this.unavailable,
    required this.availabilityRate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: providerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.speed_rounded,
                        color: _success,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fleet availability',
                            style: TextStyle(
                              color: providerInk,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Vehicles ready for new bookings',
                            style: TextStyle(
                              color: providerMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$availabilityRate%',
                      style: const TextStyle(
                        color: _success,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: providerMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: total == 0 ? 0 : available / total,
                    color: const Color(0xFF10B981),
                    backgroundColor: const Color(0xFFE2E8F0),
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    _DotLabel(color: _success, label: '$available available'),
                    const SizedBox(width: 15),
                    _DotLabel(
                      color: providerMuted,
                      label: '$unavailable unavailable',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _DotLabel extends StatelessWidget {
  final Color color;
  final String label;

  const _DotLabel({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: providerMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _RecentActivityPanel extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final VoidCallback onTap;

  const _RecentActivityPanel({required this.bookings, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: providerBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Column(
            children: [
              for (var index = 0; index < bookings.length; index++) ...[
                _BookingActivityRow(
                  booking: bookings[index],
                  onTap: onTap,
                ),
                if (index < bookings.length - 1)
                  const Divider(
                    height: 1,
                    indent: 62,
                    color: providerBorder,
                  ),
              ],
            ],
          ),
        ),
      );
}

class _BookingActivityRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  const _BookingActivityRow({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final vehicle = _asMap(booking['vehicle']);
    final renter = _asMap(booking['renter']);
    final status = booking['status']?.toString() ?? 'Confirmed';
    final start = DateTime.tryParse(booking['startDate']?.toString() ?? '');
    final statusStyle = _bookingStatusStyle(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusStyle.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  statusStyle.icon,
                  color: statusStyle.color,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle['name']?.toString() ?? 'Vehicle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: providerInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${renter['name'] ?? 'Renter'}${start == null ? '' : ' · ${DateFormat('d MMM').format(start.toLocal())}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: providerMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusStyle.color.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusStyle.color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: providerBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _softBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: providerPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: providerInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: const TextStyle(
                      color: providerMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _FullErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FullErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: ProviderEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Dashboard unavailable',
          message: message,
          actionLabel: 'Try again',
          onAction: onRetry,
        ),
      );
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: _danger),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _LastUpdatedLabel extends StatelessWidget {
  final dynamic value;

  const _LastUpdatedLabel({required this.value});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return const SizedBox.shrink();
    return Center(
      child: Text(
        'Updated ${DateFormat('d MMM, h:mm a').format(date)}',
        style: const TextStyle(color: providerMuted, fontSize: 9),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          _SkeletonBlock(height: 220),
          SizedBox(height: 18),
          _SkeletonBlock(height: 105),
          SizedBox(height: 22),
          _SkeletonBlock(height: 150),
          SizedBox(height: 22),
          _SkeletonBlock(height: 125),
        ],
      );
}

class _SkeletonBlock extends StatelessWidget {
  final double height;

  const _SkeletonBlock({required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: providerBorder),
        ),
      );
}

class _StatusStyle {
  final Color color;
  final IconData icon;

  const _StatusStyle(this.color, this.icon);
}

_StatusStyle _bookingStatusStyle(String status) {
  switch (status) {
    case 'Completed':
      return const _StatusStyle(providerPrimary, Icons.check_rounded);
    case 'Cancelled':
      return const _StatusStyle(_danger, Icons.close_rounded);
    case 'Confirmed':
    default:
      return const _StatusStyle(_success, Icons.event_available_outlined);
  }
}

Map<String, dynamic> _asMap(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

List<Map<String, dynamic>> _asMapList(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : <Map<String, dynamic>>[];
