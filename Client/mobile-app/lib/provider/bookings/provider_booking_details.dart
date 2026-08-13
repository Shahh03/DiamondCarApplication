import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../provider_data_scope.dart';
import '../provider_ui.dart';

class ProviderBookingDetailsPage extends StatelessWidget {
  final Map<String, dynamic> booking;

  const ProviderBookingDetailsPage({
    super.key,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    final renter = _map(booking['renter']);
    final variant = _map(booking['carVariant']);
    final car = _map(variant['car']);
    final payment = _map(booking['payment']);
    final images = _strings(variant['images']);
    final fallbackCurrency = ProviderDataScope.of(context).currency;
    final paymentCurrency = _raw(payment['currency']).toUpperCase();
    final currency = paymentCurrency.isEmpty ? fallbackCurrency : paymentCurrency;
    final carName = [_raw(car['brand']), _raw(car['model'])]
        .where((value) => value.isNotEmpty)
        .join(' ');

    return Scaffold(
      backgroundColor: providerBackground,
      appBar: AppBar(
        title: const Text('Booking details'),
        backgroundColor: providerBackground,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: const Color(0xFFE2E8F0),
                child: images.isEmpty
                    ? const Icon(
                        Icons.directions_car_rounded,
                        size: 64,
                        color: providerMuted,
                      )
                    : Image.network(
                        images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: providerMuted,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  carName.isEmpty ? 'Vehicle' : carName,
                  style: const TextStyle(
                    color: providerInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _Status(status: _displayStatus(booking)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _value(variant['registrationNumber']),
            style: const TextStyle(color: providerMuted),
          ),
          const SizedBox(height: 18),
          _Section(
            title: 'Rental period',
            children: [
              _Row(
                icon: Icons.login_rounded,
                label: 'Pickup',
                value: _date(booking['startDate']),
              ),
              _Row(
                icon: Icons.logout_rounded,
                label: 'Return',
                value: _date(booking['endDate']),
                divider: false,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Renter',
            children: [
              _Row(
                icon: Icons.person_outline_rounded,
                label: 'Name',
                value: _value(renter['name']),
              ),
              _Row(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: _value(renter['phoneNumber']),
                divider: false,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Payment',
            children: [
              _Row(
                icon: Icons.payments_outlined,
                label: 'Amount',
                value: _money(
                  currency,
                  payment['amount'] ?? booking['totalPrice'],
                ),
              ),
              _Row(
                icon: Icons.verified_outlined,
                label: 'Payment status',
                value: _value(payment['paymentStatus']),
              ),
              _Row(
                icon: Icons.credit_card_outlined,
                label: 'Payment method',
                value: _value(payment['paymentMethod']),
              ),
              _Row(
                icon: Icons.event_available_outlined,
                label: 'Payment date',
                value: _date(payment['paymentDate']),
                divider: false,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: providerPrimary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bookings are confirmed automatically after successful payment. Booking management and refunds remain in the private management portal.',
                    style: TextStyle(
                      color: providerPrimaryDark,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
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

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => ProviderSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: providerInk,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool divider;

  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: providerPrimary, size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: const TextStyle(color: providerMuted)),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: providerInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (divider) const Divider(height: 1, color: providerBorder),
        ],
      );
}

class _Status extends StatelessWidget {
  final String status;

  const _Status({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Active' => const Color(0xFF059669),
      'Upcoming' => providerPrimary,
      'Completed' => providerMuted,
      _ => const Color(0xFFDC2626),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

String _displayStatus(Map<String, dynamic> booking) {
  final stored = _raw(booking['status']);
  if (stored == 'Cancelled') return 'Cancelled';
  if (stored == 'Completed') return 'Completed';
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

String _date(dynamic value) {
  final date = DateTime.tryParse(_raw(value))?.toLocal();
  return date == null ? 'Not provided' : DateFormat.yMMMd().format(date);
}

String _money(String currency, dynamic value) {
  final amount = value is num
      ? value
      : num.tryParse(value?.toString() ?? '') ?? 0;
  return '$currency ${NumberFormat.decimalPattern().format(amount)}';
}
