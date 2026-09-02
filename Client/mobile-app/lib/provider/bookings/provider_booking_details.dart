import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/provider_booking_api.dart';
import '../provider_data_scope.dart';
import '../provider_ui.dart';

const _surface = Colors.white;
const _softBlue = Color(0xFFEFF6FF);
const _success = Color(0xFF059669);
const _danger = Color(0xFFDC2626);
const _orange = Color(0xFFEA580C);

class ProviderBookingDetailsPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const ProviderBookingDetailsPage({
    super.key,
    required this.booking,
  });

  @override
  State<ProviderBookingDetailsPage> createState() =>
      _ProviderBookingDetailsPageState();
}

class _ProviderBookingDetailsPageState
    extends State<ProviderBookingDetailsPage> {
  late Map<String, dynamic> _booking;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _booking = Map<String, dynamic>.from(widget.booking);
  }

  Future<void> _copyReference(BuildContext context, String reference) async {
    if (reference.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: reference));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking reference copied')),
    );
  }

  Future<void> _changeStatus({required bool start}) async {
    final bookingId = _raw(_booking['_id']);
    if (bookingId.isEmpty || _isUpdating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(start ? 'Start this rental?' : 'Complete this rental?'),
        content: Text(
          start
              ? 'Confirm that the renter has collected the vehicle.'
              : 'Confirm that the vehicle has been returned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: start ? providerPrimary : _success,
            ),
            child: Text(start ? 'Start rental' : 'Complete rental'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isUpdating = true);
    try {
      final result = start
          ? await ProviderBookingApi.startBooking(bookingId: bookingId)
          : await ProviderBookingApi.completeBooking(bookingId: bookingId);
      if (!mounted) return;

      final updated = _map(result['booking']);
      setState(() {
        _booking = <String, dynamic>{..._booking, ...updated};
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _valueOr(
              result['message'],
              start
                  ? 'Rental started successfully.'
                  : 'Rental completed successfully.',
            ),
          ),
          backgroundColor: _success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(error)),
          backgroundColor: _danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    final renter = _map(booking['renter']);
    final variant = _map(booking['carVariant']);
    final car = _map(variant['car']);
    final payment = _map(booking['payment']);
    final images = _strings(variant['images']);
    final fallbackCurrency = ProviderDataScope.of(context).currency;
    final paymentCurrency = _raw(payment['currency']).toUpperCase();
    final currency = paymentCurrency.isEmpty
        ? fallbackCurrency
        : paymentCurrency;
    final status = _displayStatus(booking);
    final carName = [_raw(car['brand']), _raw(car['model'])]
        .where((value) => value.isNotEmpty)
        .join(' ');
    final reference = _raw(booking['_id']);

    return Scaffold(
      backgroundColor: providerBackground,
      appBar: AppBar(
        title: const Text(
          'Booking details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: providerBackground,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _BookingHero(
            imageUrl: images.isEmpty ? '' : images.first,
            status: status,
          ),
          const SizedBox(height: 17),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      carName.isEmpty ? 'Vehicle' : carName,
                      style: const TextStyle(
                        color: providerInk,
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        _raw(car['year']),
                        _raw(car['category']),
                        _raw(variant['registrationNumber']),
                      ].where((value) => value.isNotEmpty).join(' · '),
                      style: const TextStyle(
                        color: providerMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (reference.isNotEmpty) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => _copyReference(context, reference),
                  tooltip: 'Copy booking reference',
                  style: IconButton.styleFrom(
                    backgroundColor: _surface,
                    side: const BorderSide(color: providerBorder),
                  ),
                  icon: const Icon(Icons.content_copy_rounded, size: 19),
                ),
              ],
            ],
          ),
          if (reference.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Booking #${_shortReference(reference)}',
              style: const TextStyle(
                color: providerMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 22),
          const _SectionTitle(
            eyebrow: 'SCHEDULE',
            title: 'Rental period',
          ),
          const SizedBox(height: 11),
          _TripTimeline(
            startDate: booking['startDate'],
            endDate: booking['endDate'],
          ),
          const SizedBox(height: 22),
          const _SectionTitle(
            eyebrow: 'CUSTOMER',
            title: 'Renter details',
          ),
          const SizedBox(height: 11),
          _RenterCard(renter: renter),
          const SizedBox(height: 22),
          const _SectionTitle(
            eyebrow: 'TRANSACTION',
            title: 'Payment',
          ),
          const SizedBox(height: 11),
          _PaymentPanel(
            currency: currency,
            amount: payment['amount'] ?? booking['totalPrice'],
            payment: payment,
          ),
          const SizedBox(height: 18),
          _BookingLifecyclePanel(
            status: status,
            isUpdating: _isUpdating,
            onStart: () => _changeStatus(start: true),
            onComplete: () => _changeStatus(start: false),
          ),
        ],
      ),
    );
  }
}

class _BookingHero extends StatelessWidget {
  final String imageUrl;
  final String status;

  const _BookingHero({required this.imageUrl, required this.status});

  @override
  Widget build(BuildContext context) {
    final caption = switch (status) {
      'Cancelled' => 'This booking has been cancelled',
      'Completed' => 'Rental completed',
      'Active' => 'Rental currently in progress',
      _ => 'Paid booking confirmed',
    };

    return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isEmpty)
                const ColoredBox(
                  color: Color(0xFFE2E8F0),
                  child: Icon(
                    Icons.directions_car_rounded,
                    size: 72,
                    color: providerMuted,
                  ),
                )
              else
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const ColoredBox(
                          color: Color(0xFFE2E8F0),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFFE2E8F0),
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: providerMuted,
                    ),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x66000000)],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _StatusBadge(status: status),
              ),
              Positioned(
                left: 14,
                bottom: 13,
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;

  const _SectionTitle({required this.eyebrow, required this.title});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: providerPrimary,
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              color: providerInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
}

class _TripTimeline extends StatelessWidget {
  final dynamic startDate;
  final dynamic endDate;

  const _TripTimeline({required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context) {
    final days = _rentalDays(startDate, endDate);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: providerBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DateStop(
              icon: Icons.key_rounded,
              label: 'PICKUP',
              date: _date(startDate),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: providerPrimary,
                  size: 19,
                ),
                const SizedBox(height: 4),
                Text(
                  '$days day${days == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: providerMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _DateStop(
              icon: Icons.flag_outlined,
              label: 'RETURN',
              date: _date(endDate),
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateStop extends StatelessWidget {
  final IconData icon;
  final String label;
  final String date;
  final bool alignEnd;

  const _DateStop({
    required this.icon,
    required this.label,
    required this.date,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _softBlue,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: providerPrimary, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: providerMuted,
              fontSize: 8,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            date,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: const TextStyle(
              color: providerInk,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
}

class _RenterCard extends StatelessWidget {
  final Map<String, dynamic> renter;

  const _RenterCard({required this.renter});

  @override
  Widget build(BuildContext context) {
    final name = _value(renter['name']);
    final phone = _value(renter['phoneNumber']);
    final initial = name == 'Not provided' || name.isEmpty
        ? 'R'
        : name.substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: providerBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _softBlue,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: providerPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: providerInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      color: providerMuted,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: providerMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
    );
  }
}

class _PaymentPanel extends StatelessWidget {
  final String currency;
  final dynamic amount;
  final Map<String, dynamic> payment;

  const _PaymentPanel({
    required this.currency,
    required this.amount,
    required this.payment,
  });

  @override
  Widget build(BuildContext context) {
    final paymentStatus = _value(payment['paymentStatus']);
    final statusColor = switch (paymentStatus) {
      'Completed' => _success,
      'Refunded' => _orange,
      'Failed' => _danger,
      _ => providerMuted,
    };

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: providerBorder),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [providerPrimaryDark, providerPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BOOKING TOTAL',
                  style: TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _money(currency, amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          _PaymentRow(
            icon: Icons.verified_outlined,
            label: 'Payment status',
            value: paymentStatus,
            valueColor: statusColor,
          ),
          const Divider(height: 1, indent: 52, color: providerBorder),
          _PaymentRow(
            icon: Icons.credit_card_outlined,
            label: 'Method',
            value: _value(payment['paymentMethod']),
          ),
          const Divider(height: 1, indent: 52, color: providerBorder),
          _PaymentRow(
            icon: Icons.event_available_outlined,
            label: 'Paid on',
            value: _date(payment['paymentDate']),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _PaymentRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: providerPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: providerMuted, fontSize: 11),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: valueColor ?? providerInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
}

class _BookingLifecyclePanel extends StatelessWidget {
  final String status;
  final bool isUpdating;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  const _BookingLifecyclePanel({
    required this.status,
    required this.isUpdating,
    required this.onStart,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _softBlue,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              status == 'Active'
                  ? Icons.key_rounded
                  : status == 'Completed'
                      ? Icons.check_circle_outline_rounded
                      : Icons.event_available_outlined,
              color: status == 'Active' ? _success : providerPrimary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    switch (status) {
                      'Upcoming' => 'Vehicle handover',
                      'Active' => 'Rental in progress',
                      'Completed' => 'Rental completed',
                      _ => 'No booking action available',
                    },
                    style: const TextStyle(
                      color: providerPrimaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    switch (status) {
                      'Upcoming' => 'Start the rental after the renter collects the vehicle.',
                      'Active' => 'Complete the rental after the vehicle is returned.',
                      'Completed' => 'No further lifecycle action is required.',
                      'Cancelled' => 'This booking was cancelled and cannot be started.',
                      _ => 'Refresh the booking before trying another action.',
                    },
                    style: const TextStyle(
                      color: providerPrimaryDark,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  if (status == 'Upcoming' || status == 'Active') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isUpdating
                            ? null
                            : status == 'Upcoming'
                                ? onStart
                                : onComplete,
                        icon: isUpdating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                status == 'Upcoming'
                                    ? Icons.key_rounded
                                    : Icons.check_circle_outline_rounded,
                              ),
                        label: Text(
                          isUpdating
                              ? 'Saving…'
                              : status == 'Upcoming'
                                  ? 'Start rental'
                                  : 'Complete rental',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: status == 'Upcoming'
                              ? providerPrimary
                              : _success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

Color _statusColor(String status) => switch (status) {
      'Active' => _orange,
      'Upcoming' => providerPrimary,
      'Completed' => _success,
      'Cancelled' => _danger,
      _ => _orange,
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

int _rentalDays(dynamic startValue, dynamic endValue) {
  final start = DateTime.tryParse(_raw(startValue));
  final end = DateTime.tryParse(_raw(endValue));
  if (start == null || end == null) return 0;
  final difference = end.difference(start).inDays;
  return difference < 1 ? 1 : difference;
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

List<String> _strings(dynamic value) => value is List
    ? value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList()
    : <String>[];

String _raw(dynamic value) => value?.toString().trim() ?? '';

String _value(dynamic value) {
  final text = _raw(value);
  return text.isEmpty ? 'Not provided' : text;
}

String _valueOr(dynamic value, String fallback) {
  final text = _raw(value);
  return text.isEmpty ? fallback : text;
}

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

String _shortReference(String value) =>
    value.length <= 8 ? value.toUpperCase() : value.substring(value.length - 8).toUpperCase();

String _date(dynamic value) {
  final date = DateTime.tryParse(_raw(value))?.toLocal();
  return date == null ? 'Not provided' : DateFormat.yMMMd().format(date);
}

String _money(String currency, dynamic value) {
  final amount = value is num
      ? value
      : num.tryParse(value?.toString() ?? '') ?? 0;
  return '$currency ${NumberFormat('#,##0.##').format(amount)}';
}
