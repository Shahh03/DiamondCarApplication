import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../provider_data_scope.dart';
import '../provider_ui.dart';

const _surface = Colors.white;
const _softBlue = Color(0xFFEFF6FF);
const _success = Color(0xFF059669);
const _orange = Color(0xFFEA580C);
const _danger = Color(0xFFDC2626);

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

  void _openGallery(List<String> images) {
    if (images.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          images: images,
          initialIndex: _photoIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.variant;
    final car = _asMap(variant['car']);
    final insurance = _asMap(variant['insuranceDetails']);
    final images = _images(variant['images']);
    final currency = ProviderDataScope.of(context).currency;
    final available = variant['isAvailable'] == true;
    final name = [_raw(car['brand']), _raw(car['model'])]
        .where((value) => value.isNotEmpty)
        .join(' ');
    final subtitle = [
      _raw(car['year']),
      _raw(car['category']),
      _raw(variant['registrationNumber']),
    ].where((value) => value.isNotEmpty).join(' · ');

    return Scaffold(
      backgroundColor: providerBackground,
      appBar: AppBar(
        title: const Text(
          'Vehicle details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        backgroundColor: providerBackground,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _PhotoGallery(
            images: images,
            index: _photoIndex,
            available: available,
            onChanged: (index) => setState(() => _photoIndex = index),
            onTap: () => _openGallery(images),
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
                      name.isEmpty ? 'Unnamed vehicle' : name,
                      style: const TextStyle(
                        color: providerInk,
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: providerMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(available: available),
            ],
          ),
          const SizedBox(height: 18),
          _PricingPanel(
            dailyRate: _money(currency, variant['rentalPricePerDay']),
            deposit: _money(currency, variant['depositAmount']),
          ),
          const SizedBox(height: 22),
          const _SectionHeading(
            eyebrow: 'SPECIFICATIONS',
            title: 'Vehicle information',
          ),
          const SizedBox(height: 11),
          _SpecificationsGrid(
            items: [
              _Specification(
                icon: Icons.palette_outlined,
                label: 'Color',
                value: _display(variant['color']),
              ),
              _Specification(
                icon: Icons.settings_outlined,
                label: 'Transmission',
                value: _display(car['transmission']),
              ),
              _Specification(
                icon: Icons.local_gas_station_outlined,
                label: 'Fuel type',
                value: _display(car['fuelType']),
              ),
              _Specification(
                icon: Icons.airline_seat_recline_normal_rounded,
                label: 'Seats',
                value: _display(car['seats']),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionHeading(
            eyebrow: 'PROTECTION',
            title: 'Insurance',
          ),
          const SizedBox(height: 11),
          _InsurancePanel(insurance: insurance),
          const SizedBox(height: 18),
          const _PortalNotice(),
        ],
      ),
    );
  }
}

class _PhotoGallery extends StatelessWidget {
  final List<String> images;
  final int index;
  final bool available;
  final ValueChanged<int> onChanged;
  final VoidCallback onTap;

  const _PhotoGallery({
    required this.images,
    required this.index,
    required this.available,
    required this.onChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                GestureDetector(
                  onTap: onTap,
                  child: PageView.builder(
                    itemCount: images.length,
                    onPageChanged: onChanged,
                    itemBuilder: (_, imageIndex) => Image.network(
                      images[imageIndex],
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
                  ),
                ),
              Positioned(
                left: 12,
                top: 12,
                child: _StatusBadge(available: available, onDark: true),
              ),
              if (images.isNotEmpty)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.58),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${index + 1}/${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (images.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      images.length > 8 ? 8 : images.length,
                      (dotIndex) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: dotIndex == index ? 17 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: dotIndex == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  final bool available;
  final bool onDark;

  const _StatusBadge({required this.available, this.onDark = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: available
              ? const Color(0xFFECFDF5)
              : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(20),
          boxShadow: onDark
              ? const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: available ? _success : _orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              available ? 'Available' : 'Unavailable',
              style: TextStyle(
                color: available ? _success : _orange,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _PricingPanel extends StatelessWidget {
  final String dailyRate;
  final String deposit;

  const _PricingPanel({required this.dailyRate, required this.deposit});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F2D68), providerPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x202563EB),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily rental rate',
                    style: TextStyle(
                      color: Color(0xFFBFDBFE),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      dailyRate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Text(
                    'per day',
                    style: TextStyle(color: Color(0xFF93C5FD), fontSize: 10),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 55,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white.withOpacity(0.18),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Refundable deposit',
                    style: TextStyle(
                      color: Color(0xFFBFDBFE),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      deposit,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Text(
                    'held during rental',
                    style: TextStyle(color: Color(0xFF93C5FD), fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;

  const _SectionHeading({required this.eyebrow, required this.title});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: providerPrimary,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
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
      );
}

class _Specification {
  final IconData icon;
  final String label;
  final String value;

  const _Specification({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _SpecificationsGrid extends StatelessWidget {
  final List<_Specification> items;

  const _SpecificationsGrid({required this.items});

  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.35,
        ),
        itemBuilder: (_, index) {
          final item = items[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: providerBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: _softBlue,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(item.icon, color: providerPrimary, size: 18),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        style: const TextStyle(
                          color: providerMuted,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: providerInk,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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

class _InsurancePanel extends StatelessWidget {
  final Map<String, dynamic> insurance;

  const _InsurancePanel({required this.insurance});

  @override
  Widget build(BuildContext context) {
    final expiry = DateTime.tryParse(insurance['expiryDate']?.toString() ?? '');
    final expired = expiry != null && expiry.isBefore(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: expired ? const Color(0xFFFCA5A5) : providerBorder,
        ),
      ),
      child: Column(
        children: [
          _InsuranceRow(
            icon: Icons.business_outlined,
            label: 'Insurance company',
            value: _display(insurance['insuranceCompany']),
          ),
          const Divider(height: 1, indent: 56, color: providerBorder),
          _InsuranceRow(
            icon: Icons.description_outlined,
            label: 'Policy number',
            value: _display(insurance['policyNumber']),
          ),
          const Divider(height: 1, indent: 56, color: providerBorder),
          _InsuranceRow(
            icon: Icons.event_outlined,
            label: 'Expiry date',
            value: _date(insurance['expiryDate']),
            warning: expired,
          ),
        ],
      ),
    );
  }
}

class _InsuranceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool warning;

  const _InsuranceRow({
    required this.icon,
    required this.label,
    required this.value,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: warning ? const Color(0xFFFEF2F2) : _softBlue,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 18,
                color: warning ? _danger : providerPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: providerMuted,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: warning ? _danger : providerInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (warning)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Expired',
                  style: TextStyle(
                    color: _danger,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _PortalNotice extends StatelessWidget {
  const _PortalNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _softBlue,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.admin_panel_settings_outlined, color: providerPrimary),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Managed in the web portal',
                    style: TextStyle(
                      color: providerPrimaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Use the DiamondCar management portal to change pricing, photos, insurance or availability.',
                    style: TextStyle(
                      color: providerPrimaryDark,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_index + 1} of ${widget.images.length}'),
        ),
        body: PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (_, index) => InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 60,
                ),
              ),
            ),
          ),
        ),
      );
}

Map<String, dynamic> _asMap(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

String _raw(dynamic value) => value?.toString().trim() ?? '';

String _display(dynamic value) {
  final text = _raw(value);
  return text.isEmpty ? 'Not provided' : text;
}

List<String> _images(dynamic value) => value is List
    ? value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList()
    : <String>[];

String _money(String currency, dynamic value) {
  final number = value is num
      ? value
      : num.tryParse(value?.toString() ?? '') ?? 0;
  return '$currency ${NumberFormat('#,##0.##').format(number)}';
}

String _date(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null
      ? 'Not provided'
      : DateFormat.yMMMd().format(parsed.toLocal());
}
