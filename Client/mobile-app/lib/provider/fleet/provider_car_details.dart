import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../provider_data_scope.dart';
import '../provider_ui.dart';

class ProviderCarDetailsPage extends StatefulWidget {
  final Map<String, dynamic> variant;

  const ProviderCarDetailsPage({
    super.key,
    required this.variant,
  });

  @override
  State<ProviderCarDetailsPage> createState() =>
      _ProviderCarDetailsPageState();
}

class _ProviderCarDetailsPageState extends State<ProviderCarDetailsPage> {
  int _photoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final variant = widget.variant;
    final car = _map(variant['car']);
    final insurance = _map(variant['insuranceDetails']);
    final images = _images(variant['images']);
    final currency = ProviderDataScope.of(context).currency;
    final isAvailable = variant['isAvailable'] == true;
    final name = [_raw(car['brand']), _raw(car['model'])]
        .where((value) => value.isNotEmpty)
        .join(' ');

    return Scaffold(
      backgroundColor: providerBackground,
      appBar: AppBar(
        title: const Text('Vehicle details'),
        backgroundColor: providerBackground,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _PhotoGallery(
            images: images,
            index: _photoIndex,
            onChanged: (index) => setState(() => _photoIndex = index),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Unnamed vehicle' : name,
                      style: const TextStyle(
                        color: providerInk,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [_raw(car['year']), _raw(car['category'])]
                          .where((value) => value.isNotEmpty)
                          .join(' • '),
                      style: const TextStyle(
                        color: providerMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(isAvailable: isAvailable),
            ],
          ),
          const SizedBox(height: 18),
          ProviderSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Pricing'),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Price(
                        label: 'Per day',
                        value: _money(
                          currency,
                          variant['rentalPricePerDay'],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Price(
                        label: 'Deposit',
                        value: _money(currency, variant['depositAmount']),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ProviderSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Vehicle information'),
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.pin_outlined,
                  label: 'Registration',
                  value: _text(variant['registrationNumber']),
                ),
                _DetailRow(
                  icon: Icons.palette_outlined,
                  label: 'Color',
                  value: _text(variant['color']),
                ),
                _DetailRow(
                  icon: Icons.settings_outlined,
                  label: 'Transmission',
                  value: _text(car['transmission']),
                ),
                _DetailRow(
                  icon: Icons.local_gas_station_outlined,
                  label: 'Fuel type',
                  value: _text(car['fuelType']),
                ),
                _DetailRow(
                  icon: Icons.airline_seat_recline_normal_rounded,
                  label: 'Seats',
                  value: _text(car['seats']),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ProviderSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Insurance'),
                const SizedBox(height: 8),
                _DetailRow(
                  icon: Icons.business_outlined,
                  label: 'Company',
                  value: _text(insurance['insuranceCompany']),
                ),
                _DetailRow(
                  icon: Icons.description_outlined,
                  label: 'Policy number',
                  value: _text(insurance['policyNumber']),
                ),
                _DetailRow(
                  icon: Icons.event_outlined,
                  label: 'Expiry date',
                  value: _date(insurance['expiryDate']),
                  showDivider: false,
                ),
              ],
            ),
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
                    'To edit pricing, photos, insurance or availability, use the DiamondCar management portal.',
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

  static Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};

  static String _text(dynamic value) {
    final text = _raw(value);
    return text.isEmpty ? 'Not provided' : text;
  }

  static String _raw(dynamic value) => value?.toString().trim() ?? '';

  static List<String> _images(dynamic value) => value is List
      ? value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList()
      : <String>[];

  static String _money(String currency, dynamic value) {
    final number = value is num
        ? value
        : num.tryParse(value?.toString() ?? '') ?? 0;
    return '$currency ${NumberFormat.decimalPattern().format(number)}';
  }

  static String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? 'Not provided' : DateFormat.yMMMd().format(parsed);
  }
}

class _PhotoGallery extends StatelessWidget {
  final List<String> images;
  final int index;
  final ValueChanged<int> onChanged;

  const _PhotoGallery({
    required this.images,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (images.isEmpty)
              const ColoredBox(
                color: Color(0xFFE2E8F0),
                child: Icon(
                  Icons.directions_car_rounded,
                  size: 72,
                  color: providerMuted,
                ),
              )
            else
              PageView.builder(
                itemCount: images.length,
                onPageChanged: onChanged,
                itemBuilder: (_, imageIndex) => Image.network(
                  images[imageIndex],
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const ColoredBox(
                          color: Color(0xFFE2E8F0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFFE2E8F0),
                    child: Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
              ),
            if (images.length > 1)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${index + 1}/${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isAvailable;

  const _StatusBadge({required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAvailable
            ? const Color(0xFFD1FAE5)
            : const Color(0xFFFFEDD5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAvailable ? 'Available' : 'Unavailable',
        style: TextStyle(
          color: isAvailable
              ? const Color(0xFF047857)
              : const Color(0xFFC2410C),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: providerInk,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      );
}

class _Price extends StatelessWidget {
  final String label;
  final String value;

  const _Price({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: providerBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: providerMuted)),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: providerInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
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
                  child: Text(
                    label,
                    style: const TextStyle(color: providerMuted),
                  ),
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
          if (showDivider) const Divider(height: 1, color: providerBorder),
        ],
      );
}
