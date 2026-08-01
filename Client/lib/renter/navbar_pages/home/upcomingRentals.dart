import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project/renter/api/booking_api.dart';

import '../../bookingDetails.dart';

const _primary = Color(0xFF1D4ED8);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class UpcomingRentals extends StatefulWidget {
  final String renterId;

  const UpcomingRentals({
    super.key,
    required this.renterId,
  });

  @override
  State<UpcomingRentals> createState() => _UpcomingRentalsState();
}

class _UpcomingRentalsState extends State<UpcomingRentals> {
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final bookings = await BookingApi.getUpcomingBookings(widget.renterId);
      if (!mounted) return;

      setState(() {
        _bookings = List<dynamic>.from(bookings);
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Upcoming rentals error: $error');
      if (!mounted) return;

      setState(() {
        _bookings = [];
        _isLoading = false;
        _errorMessage = 'We could not load your upcoming rentals.';
      });
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  DateTime _safeDate(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime(9999);
  }

  String _dateRange(dynamic start, dynamic end) {
    final startDate = DateTime.tryParse(start?.toString() ?? '');
    final endDate = DateTime.tryParse(end?.toString() ?? '');

    if (startDate == null || endDate == null) return 'Dates unavailable';

    return '${DateFormat('MMM d').format(startDate)} – '
        '${DateFormat('MMM d').format(endDate)}';
  }

  String _imageUrl(dynamic image) {
    if (image is String) return image.trim();
    if (image is Map && image['filepath'] != null) {
      return image['filepath'].toString();
    }
    if (image is Map && image['url'] != null) {
      return image['url'].toString();
    }
    return '';
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFEFF6FF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.directions_car_filled_outlined,
        color: _primary,
        size: 42,
      ),
    );
  }

  Widget _carImage(List<dynamic> images) {
    if (images.isEmpty) return _imagePlaceholder();

    final firstImage = images.first;
    final url = _imageUrl(firstImage);

    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _imagePlaceholder(),
      );
    }

    if (firstImage is Map && firstImage['filename'] != null) {
      try {
        final raw = firstImage['filename'].toString();
        final encoded = raw.contains(',') ? raw.split(',').last : raw;

        return Image.memory(
          base64Decode(encoded),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _imagePlaceholder(),
        );
      } catch (_) {
        return _imagePlaceholder();
      }
    }

    return _imagePlaceholder();
  }

  void _openBooking(dynamic rental) {
    final booking = _asMap(rental);
    final bookingId = (booking['_id'] ?? '').toString();
    if (bookingId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailsPage(bookingId: bookingId),
      ),
    );
  }

  Widget _rentalCard(dynamic rawRental) {
    final rental = _asMap(rawRental);
    final variant = _asMap(rental['carVariant']);
    final car = _asMap(variant['car']);
    final images = variant['images'] is List
        ? List<dynamic>.from(variant['images'] as List)
        : <dynamic>[];
    final name = [car['brand'], car['model']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .map((value) => value.toString().trim())
        .join(' ');
    final status = (rental['status'] ?? 'Upcoming').toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _openBooking(rental),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  width: 102,
                  height: 100,
                  child: _carImage(images),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name.isEmpty ? 'Car rental' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: _muted,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: _primary,
                          size: 17,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _dateRange(rental['startDate'], rental['endDate']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Column(
        children: [
          _RentalSkeleton(),
          SizedBox(height: 12),
          _RentalSkeleton(),
        ],
      );
    }

    if (_errorMessage != null) {
      return _HomeMessageCard(
        icon: Icons.cloud_off_outlined,
        title: 'Rentals unavailable',
        message: _errorMessage!,
        actionLabel: 'Try again',
        onAction: _loadBookings,
      );
    }

    if (_bookings.isEmpty) {
      return const _HomeMessageCard(
        icon: Icons.event_available_outlined,
        title: 'No upcoming rentals',
        message: 'Your next confirmed booking will appear here.',
      );
    }

    final sorted = List<dynamic>.from(_bookings)
      ..sort((a, b) {
        final first = _asMap(a);
        final second = _asMap(b);
        return _safeDate(first['startDate'])
            .compareTo(_safeDate(second['startDate']));
      });

    return Column(
      children: [
        for (var index = 0; index < sorted.take(2).length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _rentalCard(sorted[index]),
        ],
      ],
    );
  }
}

class _HomeMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _HomeMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _primary, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _RentalSkeleton extends StatelessWidget {
  const _RentalSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 122,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 102,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDF5),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(width: 150, height: 16),
                SizedBox(height: 12),
                _SkeletonLine(width: 120, height: 12),
                SizedBox(height: 12),
                _SkeletonLine(width: 72, height: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF5),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
