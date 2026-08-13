import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/provider_fleet_api.dart';
import '../provider_data_scope.dart';
import '../provider_ui.dart';
import 'provider_edit_car.dart';

class ProviderFleetPage extends StatefulWidget {
  final String providerId;

  const ProviderFleetPage({
    super.key,
    required this.providerId,
  });

  @override
  State<ProviderFleetPage> createState() =>
      _ProviderFleetPageState();
}

class _ProviderFleetPageState extends State<ProviderFleetPage> {
  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, dynamic>> _variants = <Map<String, dynamic>>[];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_handleSearchChanged);
    _loadFleet();
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadFleet() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final variants = await ProviderFleetApi.getProviderCars(
        providerId: widget.providerId,
      );

      if (!mounted) return;

      setState(() {
        _variants = variants;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _filteredVariants {
    final query =
        _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _variants;
    }

    return _variants.where((variant) {
      final car = _asMap(variant['car']);

      final searchableValues = [
        car['brand'],
        car['model'],
        car['year'],
        car['category'],
        car['transmission'],
        car['fuelType'],
        variant['registrationNumber'],
        variant['color'],
      ];

      final searchableText = searchableValues
          .map(
            (value) =>
                value?.toString().trim().toLowerCase() ?? '',
          )
          .join(' ');

      return searchableText.contains(query);
    }).toList();
  }

  void _openAddCar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The Add Car screen will be implemented next.',
        ),
      ),
    );
  }

  Future<void> _openEditCar(Map<String, dynamic> variant) async {
    final providerScope = ProviderDataScope.of(context);
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProviderDataScope(
          provider: providerScope.provider,
          refresh: providerScope.refresh,
          child: ProviderEditCarPage(
            providerId: widget.providerId,
            variant: variant,
          ),
        ),
      ),
    );

    if (changed == true) {
      await _loadFleet();
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        ProviderDataScope.of(context).currency;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadFleet,
        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(16, 18, 16, 12),
              sliver: SliverToBoxAdapter(
                child: ProviderPageHeader(
                  title: 'My fleet',
                  subtitle:
                      '${_variants.length} vehicle${_variants.length == 1 ? '' : 's'} in your fleet',
                  action: IconButton.filled(
                    onPressed: _openAddCar,
                    tooltip: 'Add car',
                    icon: const Icon(Icons.add_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: providerPrimary,
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText:
                        'Search brand, model or registration',
                    prefixIcon:
                        const Icon(Icons.search_rounded),
                    suffixIcon:
                        _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed:
                                    _searchController.clear,
                                icon: const Icon(
                                  Icons.close_rounded,
                                ),
                              ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: providerBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: providerBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: providerPrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ..._buildContent(currency),
            const SliverToBoxAdapter(
              child: SizedBox(height: 28),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(String currency) {
    if (_isLoading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ];
    }

    if (_error != null) {
      return [
        SliverPadding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: ProviderEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your fleet',
              message: _error!,
              actionLabel: 'Try again',
              onAction: _loadFleet,
            ),
          ),
        ),
      ];
    }

    if (_variants.isEmpty) {
      return [
        SliverPadding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: ProviderEmptyState(
              icon: Icons.directions_car_outlined,
              title: 'Your fleet is empty',
              message:
                  'Add your first vehicle to begin receiving bookings.',
              actionLabel: 'Add your first car',
              onAction: _openAddCar,
            ),
          ),
        ),
      ];
    }

    final filteredVariants = _filteredVariants;

    if (filteredVariants.isEmpty) {
      return const [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: ProviderEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching vehicles',
              message:
                  'Try another brand, model, color or registration number.',
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final variant = filteredVariants[index];

              return Padding(
                padding: EdgeInsets.only(
                  bottom:
                      index == filteredVariants.length - 1
                          ? 0
                          : 12,
                ),
                child: _FleetCard(
                  variant: variant,
                  currency: currency,
                  onEdit: () => _openEditCar(variant),
                ),
              );
            },
            childCount: filteredVariants.length,
          ),
        ),
      ),
    ];
  }
}

class _FleetCard extends StatelessWidget {
  final Map<String, dynamic> variant;
  final String currency;
  final VoidCallback onEdit;

  const _FleetCard({
    required this.variant,
    required this.currency,
    required this.onEdit,
  });

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  static num _asNumber(dynamic value) {
    if (value is num) return value;

    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _text(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  String get _imageUrl {
    final images = variant['images'];

    if (images is! List || images.isEmpty) {
      return '';
    }

    final firstImage = images.first;

    if (firstImage is String) {
      return firstImage.trim();
    }

    if (firstImage is Map) {
      return _text(
        firstImage['url'] ??
            firstImage['secure_url'] ??
            firstImage['filepath'],
      );
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final car = _asMap(variant['car']);

    final brand = _text(car['brand']);
    final model = _text(car['model']);
    final year = _text(car['year']);
    final category = _text(car['category']);
    final transmission = _text(car['transmission']);
    final fuelType = _text(car['fuelType']);

    final carName = [brand, model]
        .where((value) => value.isNotEmpty)
        .join(' ');

    final registration =
        _text(variant['registrationNumber']);

    final color = _text(variant['color']);

    final dailyPrice =
        _asNumber(variant['rentalPricePerDay']);

    final deposit =
        _asNumber(variant['depositAmount']);

    final isAvailable =
        variant['isAvailable'] == true;

    return ProviderSectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VehicleImage(
            imageUrl: _imageUrl,
            isAvailable: isAvailable,
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        carName.isEmpty
                            ? 'Unnamed vehicle'
                            : carName,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: providerInk,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AvailabilityBadge(
                      isAvailable: isAvailable,
                    ),
                  ],
                ),
                if (year.isNotEmpty ||
                    category.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [year, category]
                        .where(
                          (value) => value.isNotEmpty,
                        )
                        .join(' • '),
                    style: const TextStyle(
                      color: providerMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: _PriceItem(
                        label: 'Price per day',
                        value:
                            '$currency ${NumberFormat.decimalPattern().format(dailyPrice)}',
                        color: providerPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PriceItem(
                        label: 'Deposit',
                        value:
                            '$currency ${NumberFormat.decimalPattern().format(deposit)}',
                        color: providerInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (registration.isNotEmpty)
                      _InformationChip(
                        icon: Icons.pin_outlined,
                        text: registration,
                      ),
                    if (color.isNotEmpty)
                      _InformationChip(
                        icon: Icons.palette_outlined,
                        text: color,
                      ),
                    if (transmission.isNotEmpty)
                      _InformationChip(
                        icon:
                            Icons.settings_outlined,
                        text: transmission,
                      ),
                    if (fuelType.isNotEmpty)
                      _InformationChip(
                        icon:
                            Icons.local_gas_station_outlined,
                        text: fuelType,
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Manage vehicle'),
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

class _VehicleImage extends StatelessWidget {
  final String imageUrl;
  final bool isAvailable;

  const _VehicleImage({
    required this.imageUrl,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(20),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 8.2,
        child: Container(
          width: double.infinity,
          color: const Color(0xFFF1F5F9),
          child: imageUrl.isEmpty
              ? const Center(
                  child: Icon(
                    Icons.directions_car_rounded,
                    size: 58,
                    color: providerMuted,
                  ),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (
                    context,
                    child,
                    progress,
                  ) {
                    if (progress == null) return child;

                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 45,
                        color: providerMuted,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final bool isAvailable;

  const _AvailabilityBadge({
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isAvailable
        ? const Color(0xFFD1FAE5)
        : const Color(0xFFFFEDD5);

    final foregroundColor = isAvailable
        ? const Color(0xFF047857)
        : const Color(0xFFC2410C);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAvailable ? 'Available' : 'Unavailable',
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PriceItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PriceItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: providerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: providerMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InformationChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: providerBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: providerMuted,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: providerMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
