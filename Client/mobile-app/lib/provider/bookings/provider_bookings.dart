import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/provider_booking_api.dart';
import '../provider_data_scope.dart';
import '../provider_ui.dart';
import 'provider_booking_details.dart';

const _surface = Colors.white;
const _success = Color(0xFF059669);
const _danger = Color(0xFFDC2626);
const _orange = Color(0xFFF97316);
const _active = providerPrimary;

class ProviderBookingsPage extends StatefulWidget {
  final String providerId;

  const ProviderBookingsPage({super.key, required this.providerId});

  @override
  State<ProviderBookingsPage> createState() =>
      _ProviderBookingsPageState();
}

class _ProviderBookingsPageState extends State<ProviderBookingsPage> {
  static const _tabs = ['Upcoming', 'Active', 'Completed', 'Cancelled'];

  final _searchController = TextEditingController();
  String _selectedStatus = 'Upcoming';
  List<Map<String, dynamic>> _bookings = <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshSearch);
    _loadBookings();
  }

  @override
  void dispose() {
    _searchController.removeListener(_refreshSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _refreshSearch() => setState(() {});

  Future<void> _loadBookings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final bookings = await ProviderBookingApi.getProviderBookings(
        providerId: widget.providerId,
      );
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<void> _openDetails(Map<String, dynamic> booking) async {
    final scope = ProviderDataScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderDataScope(
          provider: scope.provider,
          refresh: scope.refresh,
          child: ProviderBookingDetailsPage(booking: booking),
        ),
      ),
    );
    if (mounted) await _loadBookings();
  }

  List<Map<String, dynamic>> _forTab(String tab) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _bookings.where((booking) {
      if (_displayStatus(booking) != tab) return false;
      if (query.isEmpty) return true;

      final renter = _map(booking['renter']);
      final variant = _map(booking['carVariant']);
      final car = _map(variant['car']);
      return [
        renter['name'],
        renter['phoneNumber'],
        car['brand'],
        car['model'],
        variant['registrationNumber'],
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ')
          .contains(query);
    }).toList();

    filtered.sort((left, right) {
      final leftDate = DateTime.tryParse(_raw(left['startDate']));
      final rightDate = DateTime.tryParse(_raw(right['startDate']));
      if (leftDate == null || rightDate == null) return 0;
      return tab == 'Completed' || tab == 'Cancelled'
          ? rightDate.compareTo(leftDate)
          : leftDate.compareTo(rightDate);
    });
    return filtered;
  }

  int _countForStatus(String status) =>
      _bookings.where((booking) => _displayStatus(booking) == status).length;

  @override
  Widget build(BuildContext context) {
    final currency = ProviderDataScope.of(context).currency;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: _BookingsHeader(
              upcoming: _countForStatus('Upcoming'),
              active: _countForStatus('Active'),
              isRefreshing: _isLoading && _bookings.isNotEmpty,
              onRefresh: _loadBookings,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search renter, car or registration',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: providerBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: providerBorder),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final status = _tabs[index];
                return _StatusFilter(
                  status: status,
                  count: _countForStatus(status),
                  selected: _selectedStatus == status,
                  onTap: () => setState(() => _selectedStatus = status),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _BookingList(
                key: ValueKey(_selectedStatus),
                status: _selectedStatus,
                bookings: _forTab(_selectedStatus),
                currency: currency,
                isLoading: _isLoading && _bookings.isEmpty,
                error: _bookings.isEmpty ? _error : null,
                onRefresh: _loadBookings,
                onOpen: _openDetails,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsHeader extends StatelessWidget {
  final int upcoming;
  final int active;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const _BookingsHeader({
    required this.upcoming,
    required this.active,
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
                const Text(
                  'Bookings',
                  style: TextStyle(
                    color: providerInk,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$upcoming upcoming · $active active now',
                  style: const TextStyle(
                    color: providerMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isRefreshing ? null : onRefresh,
            tooltip: 'Refresh bookings',
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
        ],
      );
}

class _StatusFilter extends StatelessWidget {
  final String status;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _StatusFilter({
    required this.status,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Material(
      color: selected ? color : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? color : providerBorder),
          ),
          child: Row(
            children: [
              Text(
                status,
                style: TextStyle(
                  color: selected ? Colors.white : providerInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.20)
                      : color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : color,
                    fontSize: 11,
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

class _BookingList extends StatelessWidget {
  final String status;
  final List<Map<String, dynamic>> bookings;
  final String currency;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _BookingList({
    super.key,
    required this.status,
    required this.bookings,
    required this.currency,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (isLoading)
            for (var index = 0; index < 3; index++) ...[
              const _BookingSkeleton(),
              if (index != 2) const SizedBox(height: 12),
            ]
          else if (error != null)
            ProviderEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load bookings',
              message: error!,
              actionLabel: 'Try again',
              onAction: onRefresh,
            )
          else if (bookings.isEmpty)
            ProviderEmptyState(
              icon: Icons.event_note_outlined,
              title: 'No ${status.toLowerCase()} bookings',
              message: 'Bookings in this category will appear here.',
            )
          else
            for (var index = 0; index < bookings.length; index++) ...[
              _BookingCard(
                booking: bookings[index],
                currency: currency,
                displayStatus: status,
                onTap: () => onOpen(bookings[index]),
              ),
              if (index != bookings.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final String currency;
  final String displayStatus;
  final VoidCallback onTap;

  const _BookingCard({
    required this.booking,
    required this.currency,
    required this.displayStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final renter = _map(booking['renter']);
    final variant = _map(booking['carVariant']);
    final car = _map(variant['car']);
    final payment = _map(booking['payment']);
    final images = _stringList(variant['images']);
    final name = [_raw(car['brand']), _raw(car['model'])]
        .where((value) => value.isNotEmpty)
        .join(' ');
    final paymentCurrency = _raw(payment['currency']).toUpperCase();

    final amount = _money(
      paymentCurrency.isEmpty ? currency : paymentCurrency,
      payment['amount'] ?? booking['totalPrice'],
    );

    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: providerBorder),
          ),
          child: SizedBox(
            height: 154,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BookingThumbnail(
                  imageUrl: images.isEmpty ? '' : images.first,
                  status: displayStatus,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 13, 11, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name.isEmpty ? 'Vehicle' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: providerInk,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: providerMuted,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _value(
                            variant['registrationNumber'],
                            'No registration',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: providerMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _CompactRow(
                          icon: Icons.person_outline_rounded,
                          text: _value(renter['name'], 'Renter'),
                        ),
                        const SizedBox(height: 7),
                        _CompactRow(
                          icon: Icons.date_range_outlined,
                          text:
                              '${_shortDate(booking['startDate'])} – ${_shortDate(booking['endDate'])}',
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                amount,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: providerPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            _BookingStatusBadge(status: displayStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingThumbnail extends StatelessWidget {
  final String imageUrl;
  final String status;

  const _BookingThumbnail({required this.imageUrl, required this.status});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 112,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(19),
              ),
              child: imageUrl.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFF1F5F9),
                      child: Icon(
                        Icons.directions_car_rounded,
                        size: 38,
                        color: providerMuted,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const ColoredBox(
                              color: Color(0xFFF1F5F9),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFF1F5F9),
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: providerMuted,
                        ),
                      ),
                    ),
            ),
            Positioned(
              left: 9,
              bottom: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _statusColor(status),
                  shape: BoxShape.circle,
                  border: Border.all(color: _surface, width: 2),
                ),
              ),
            ),
          ],
        ),
      );
}

class _BookingSkeleton extends StatelessWidget {
  const _BookingSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 154,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: providerBorder),
        ),
        child: Row(
          children: [
            _block(width: 112, height: double.infinity, radius: 19),
            const SizedBox(width: 13),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 13, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _block(width: double.infinity, height: 15),
                    const SizedBox(height: 8),
                    _block(width: 90, height: 10),
                    const SizedBox(height: 15),
                    _block(width: 130, height: 11),
                    const SizedBox(height: 9),
                    _block(width: 160, height: 11),
                    const Spacer(),
                    _block(width: 105, height: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  static Widget _block({
    required double width,
    required double height,
    double radius = 6,
  }) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3F8),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class _CompactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CompactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: providerPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: providerInk,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}

class _BookingStatusBadge extends StatelessWidget {
  final String status;

  const _BookingStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

Color _statusColor(String status) => switch (status) {
      'Upcoming' => _active,
      'Active' => _orange,
      'Completed' => _success,
      'Cancelled' => _danger,
      _ => providerPrimary,
    };

String _displayStatus(Map<String, dynamic> booking) {
  final stored = _raw(booking['status']);
  if (stored == 'Cancelled') return 'Cancelled';
  if (stored == 'Completed') return 'Completed';
  if (stored == 'InProgress') return 'Active';
  if (stored == 'Confirmed') return 'Upcoming';

  final start = DateTime.tryParse(_raw(booking['startDate']))?.toLocal();
  final end = DateTime.tryParse(_raw(booking['endDate']))?.toLocal();
  if (start == null || end == null) return 'Upcoming';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  if (startDay.isAfter(today)) return 'Upcoming';
  if (endDay.isBefore(today)) return 'Completed';
  return 'Active';
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

List<String> _stringList(dynamic value) => value is List
    ? value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList()
    : <String>[];

String _raw(dynamic value) => value?.toString().trim() ?? '';

String _value(dynamic value, String fallback) {
  final text = _raw(value);
  return text.isEmpty ? fallback : text;
}

String _shortDate(dynamic value) {
  final date = DateTime.tryParse(_raw(value))?.toLocal();
  return date == null ? 'Unknown' : DateFormat('d MMM').format(date);
}

String _money(String currency, dynamic value) {
  final number = value is num
      ? value
      : num.tryParse(value?.toString() ?? '') ?? 0;
  return '$currency ${NumberFormat.decimalPattern().format(number)}';
}

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
