import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/provider_dashboard_api.dart';
import '../provider_data_scope.dart';
import '../provider_ui.dart';

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
    final providerRefresh = ProviderDataScope.of(context).refresh;
    await Future.wait([providerRefresh(), _loadDashboard()]);
  }

  Map<String, dynamic> get _fleet => _map(_dashboard?['fleet']);
  Map<String, dynamic> get _bookings => _map(_dashboard?['bookings']);
  Map<String, dynamic> get _earnings => _map(_dashboard?['earnings']);
  Map<String, dynamic>? get _nextRental {
    final value = _dashboard?['nextRental'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  List<Map<String, dynamic>> get _recentBookings =>
      _mapList(_dashboard?['recentBookings']);

  int _number(Map<String, dynamic> source, String key) =>
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
    final provider = ProviderDataScope.of(context);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _DashboardHero(
                greeting: _greeting,
                companyName: provider.companyName,
                imageUrl: provider.profilePicture,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.list(
                children: [
                  if (_isLoading && _dashboard == null)
                    const _DashboardSkeleton()
                  else if (_error != null && _dashboard == null)
                    ProviderEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load dashboard',
                      message: _error!,
                      actionLabel: 'Try again',
                      onAction: _loadDashboard,
                    )
                  else ...[
                    ProviderPageHeader(
                      title: 'Business overview',
                      subtitle: 'Your operation at a glance',
                      action: IconButton(
                        onPressed: _isLoading ? null : _loadDashboard,
                        tooltip: 'Refresh dashboard',
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.28,
                      children: [
                        _MetricCard(
                          icon: Icons.directions_car_rounded,
                          label: 'Total vehicles',
                          value: '${_number(_fleet, 'total')}',
                          detail: '${_number(_fleet, 'available')} available',
                          color: providerPrimary,
                          onTap: widget.onOpenFleet,
                        ),
                        _MetricCard(
                          icon: Icons.key_rounded,
                          label: 'Active rentals',
                          value: '${_number(_bookings, 'active')}',
                          detail: 'Currently on rent',
                          color: const Color(0xFF059669),
                          onTap: widget.onOpenBookings,
                        ),
                        _MetricCard(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Net this month',
                          value: _money(_earnings['monthNet']),
                          detail: '${_number(_earnings, 'paymentCount')} payments',
                          color: const Color(0xFF7C3AED),
                          onTap: widget.onOpenEarnings,
                        ),
                        _MetricCard(
                          icon: Icons.upcoming_rounded,
                          label: 'Upcoming rentals',
                          value: '${_number(_bookings, 'upcoming')}',
                          detail: 'Confirmed bookings',
                          color: const Color(0xFFEA580C),
                          onTap: widget.onOpenBookings,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _FleetHealthCard(
                      total: _number(_fleet, 'total'),
                      available: _number(_fleet, 'available'),
                      unavailable: _number(_fleet, 'unavailable'),
                      availabilityRate: _number(_fleet, 'availabilityRate'),
                      onTap: widget.onOpenFleet,
                    ),
                    const SizedBox(height: 18),
                    _SectionTitle(
                      title: 'Next rental',
                      actionLabel: 'All bookings',
                      onAction: widget.onOpenBookings,
                    ),
                    const SizedBox(height: 10),
                    if (_nextRental == null)
                      const _CompactEmptyCard(
                        icon: Icons.event_available_outlined,
                        title: 'No upcoming rentals',
                        message: 'Your next confirmed rental will appear here.',
                      )
                    else
                      _NextRentalCard(
                        booking: _nextRental!,
                        money: _money,
                        onTap: widget.onOpenBookings,
                      ),
                    const SizedBox(height: 22),
                    _SectionTitle(
                      title: 'Recent booking activity',
                      actionLabel: 'View all',
                      onAction: widget.onOpenBookings,
                    ),
                    const SizedBox(height: 10),
                    if (_recentBookings.isEmpty)
                      const _CompactEmptyCard(
                        icon: Icons.history_rounded,
                        title: 'No booking activity yet',
                        message: 'New and updated bookings will appear here.',
                      )
                    else
                      ProviderSectionCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var index = 0;
                                index < _recentBookings.length;
                                index++) ...[
                              _RecentBookingRow(
                                booking: _recentBookings[index],
                                onTap: widget.onOpenBookings,
                              ),
                              if (index < _recentBookings.length - 1)
                                const Divider(
                                  height: 1,
                                  color: providerBorder,
                                ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 22),
                    const Text(
                      'Quick actions',
                      style: TextStyle(
                        color: providerInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.directions_car_outlined,
                            label: 'Fleet',
                            onTap: widget.onOpenFleet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.calendar_month_outlined,
                            label: 'Bookings',
                            onTap: widget.onOpenBookings,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.insights_outlined,
                            label: 'Earnings',
                            onTap: widget.onOpenEarnings,
                          ),
                        ),
                      ],
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _InlineError(message: _error!, onRetry: _loadDashboard),
                    ],
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

class _DashboardHero extends StatelessWidget {
  final String greeting;
  final String companyName;
  final String imageUrl;

  const _DashboardHero({
    required this.greeting,
    required this.companyName,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [providerPrimaryDark, Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x242563EB),
              blurRadius: 22,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      color: Color(0xFFBFDBFE),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    companyName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Here’s what’s happening with your business.',
                    style: TextStyle(
                      color: Color(0xFFDBEAFE),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _ProviderAvatar(imageUrl: imageUrl),
          ],
        ),
      );
}

class _ProviderAvatar extends StatelessWidget {
  final String imageUrl;

  const _ProviderAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) => ClipOval(
        child: Container(
          width: 58,
          height: 58,
          color: Colors.white.withOpacity(0.14),
          child: imageUrl.isEmpty
              ? const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 29,
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
        ),
      );
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: providerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: providerInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: providerInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: providerMuted, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      );
}

class _FleetHealthCard extends StatelessWidget {
  final int total;
  final int available;
  final int unavailable;
  final int availabilityRate;
  final VoidCallback onTap;

  const _FleetHealthCard({
    required this.total,
    required this.available,
    required this.unavailable,
    required this.availabilityRate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ProviderSectionCard(
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
                    color: Color(0xFF059669),
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
                      Text(
                        'Vehicles ready to be booked',
                        style: TextStyle(color: providerMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$availabilityRate%',
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: total == 0 ? 0 : available / total,
                color: const Color(0xFF10B981),
                backgroundColor: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Text(
                  '$available available',
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(' · ', style: TextStyle(color: providerMuted)),
                Text(
                  '$unavailable unavailable',
                  style: const TextStyle(color: providerMuted, fontSize: 11),
                ),
                const Spacer(),
                TextButton(onPressed: onTap, child: const Text('View fleet')),
              ],
            ),
          ],
        ),
      );
}

class _NextRentalCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String Function(dynamic) money;
  final VoidCallback onTap;

  const _NextRentalCard({
    required this.booking,
    required this.money,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final vehicle = _map(booking['vehicle']);
    final renter = _map(booking['renter']);
    final start = DateTime.tryParse(booking['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(booking['endDate']?.toString() ?? '');
    final image = vehicle['image']?.toString() ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: providerBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 82,
                      height: 68,
                      color: const Color(0xFFEFF6FF),
                      child: image.isEmpty
                          ? const Icon(
                              Icons.directions_car_rounded,
                              color: providerPrimary,
                            )
                          : Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.directions_car_rounded,
                                color: providerPrimary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          vehicle['registrationNumber']?.toString() ?? '',
                          style: const TextStyle(
                            color: providerMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          renter['name']?.toString() ?? 'Renter',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: providerInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: providerMuted),
                ],
              ),
              const Divider(height: 24, color: providerBorder),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 17,
                    color: providerPrimary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      start == null || end == null
                          ? 'Rental dates unavailable'
                          : '${DateFormat('d MMM').format(start.toLocal())} – ${DateFormat('d MMM y').format(end.toLocal())}',
                      style: const TextStyle(
                        color: providerInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    money(booking['totalPrice']),
                    style: const TextStyle(
                      color: providerPrimary,
                      fontWeight: FontWeight.w900,
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
}

class _RecentBookingRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  const _RecentBookingRow({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final vehicle = _map(booking['vehicle']);
    final renter = _map(booking['renter']);
    final status = booking['status']?.toString() ?? 'Confirmed';
    final start = DateTime.tryParse(booking['startDate']?.toString() ?? '');
    final statusColor = _statusColor(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEFF6FF),
                backgroundImage: (renter['profilePicture']?.toString() ?? '')
                        .isNotEmpty
                    ? NetworkImage(renter['profilePicture'].toString())
                    : null,
                child: (renter['profilePicture']?.toString() ?? '').isEmpty
                    ? const Icon(Icons.person_outline, color: providerPrimary)
                    : null,
              ),
              const SizedBox(width: 11),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${renter['name'] ?? 'Renter'}${start == null ? '' : ' · ${DateFormat('d MMM').format(start.toLocal())}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: providerMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: providerInk,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: providerBorder),
            ),
            child: Column(
              children: [
                Icon(icon, color: providerPrimary),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: providerInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CompactEmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _CompactEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => ProviderSectionCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
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
                    style: const TextStyle(color: providerMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
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
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
            const SizedBox(width: 9),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.28,
            children: List.generate(4, (_) => const _SkeletonBlock()),
          ),
          const SizedBox(height: 14),
          const _SkeletonBlock(height: 145),
          const SizedBox(height: 14),
          const _SkeletonBlock(height: 115),
        ],
      );
}

class _SkeletonBlock extends StatelessWidget {
  final double? height;

  const _SkeletonBlock({this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: providerBorder),
        ),
      );
}

Color _statusColor(String status) {
  switch (status) {
    case 'Completed':
      return const Color(0xFF2563EB);
    case 'Cancelled':
      return const Color(0xFFDC2626);
    case 'Confirmed':
    default:
      return const Color(0xFF059669);
  }
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : <Map<String, dynamic>>[];
