import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/provider_fleet_api.dart';
import '../provider_data_scope.dart';
import '../provider_ui.dart';
import 'provider_car_details.dart';

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
  String _availabilityFilter = 'All';
  String? _categoryFilter;
  String? _transmissionFilter;
  String? _fuelTypeFilter;

  bool _isLoading = true;
  String? _error;

  int get _availableCount =>
      _variants.where((variant) => variant['isAvailable'] == true).length;

  int get _unavailableCount => _variants.length - _availableCount;

  int get _activeFilterCount =>
      (_availabilityFilter == 'All' ? 0 : 1) +
      (_categoryFilter == null ? 0 : 1) +
      (_transmissionFilter == null ? 0 : 1) +
      (_fuelTypeFilter == null ? 0 : 1);

  List<String> _carOptions(String field) {
    final values = _variants
        .map((variant) => _asMap(variant['car'])[field]?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

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

    return _variants.where((variant) {
      final isAvailable = variant['isAvailable'] == true;
      if (_availabilityFilter == 'Available' && !isAvailable) return false;
      if (_availabilityFilter == 'Unavailable' && isAvailable) return false;

      final car = _asMap(variant['car']);
      if (_categoryFilter != null &&
          car['category']?.toString() != _categoryFilter) {
        return false;
      }
      if (_transmissionFilter != null &&
          car['transmission']?.toString() != _transmissionFilter) {
        return false;
      }
      if (_fuelTypeFilter != null &&
          car['fuelType']?.toString() != _fuelTypeFilter) {
        return false;
      }

      if (query.isEmpty) return true;

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

  Future<void> _showFilters() async {
    var availability = _availabilityFilter;
    var category = _categoryFilter;
    var transmission = _transmissionFilter;
    var fuelType = _fuelTypeFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            20 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: providerBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Filter fleet',
                    style: TextStyle(
                      color: providerInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Narrow vehicles by availability and specifications.',
                    style: TextStyle(color: providerMuted),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Availability',
                    style: TextStyle(
                      color: providerInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: ['All', 'Available', 'Unavailable']
                        .map(
                          (value) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: value == 'Unavailable' ? 0 : 8,
                              ),
                              child: _FleetFilter(
                                label: value,
                                selected: availability == value,
                                onTap: () => setSheetState(
                                  () => availability = value,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _FilterDropdown(
                    label: 'Category',
                    value: category,
                    options: _carOptions('category'),
                    onChanged: (value) => setSheetState(() => category = value),
                  ),
                  const SizedBox(height: 14),
                  _FilterDropdown(
                    label: 'Transmission',
                    value: transmission,
                    options: _carOptions('transmission'),
                    onChanged: (value) =>
                        setSheetState(() => transmission = value),
                  ),
                  const SizedBox(height: 14),
                  _FilterDropdown(
                    label: 'Fuel type',
                    value: fuelType,
                    options: _carOptions('fuelType'),
                    onChanged: (value) => setSheetState(() => fuelType = value),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setSheetState(() {
                            availability = 'All';
                            category = null;
                            transmission = null;
                            fuelType = null;
                          }),
                          child: const Text('Clear all'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _availabilityFilter = availability;
                              _categoryFilter = category;
                              _transmissionFilter = transmission;
                              _fuelTypeFilter = fuelType;
                            });
                            Navigator.pop(sheetContext);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: providerPrimary,
                          ),
                          child: const Text('Apply filters'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openCarDetails(Map<String, dynamic> variant) {
    final providerScope = ProviderDataScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderDataScope(
          provider: providerScope.provider,
          refresh: providerScope.refresh,
          child: ProviderCarDetailsPage(
            variant: variant,
          ),
        ),
      ),
    );
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
                  action: IconButton(
                    onPressed: _isLoading ? null : _loadFleet,
                    tooltip: 'Refresh fleet',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: _FleetSummary(
                  total: _variants.length,
                  available: _availableCount,
                  unavailable: _unavailableCount,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search brand, model or registration',
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
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: providerPrimary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _FilterButton(
                      count: _activeFilterCount,
                      onTap: _showFilters,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: ['All', 'Available', 'Unavailable']
                      .map(
                        (filter) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: filter == 'Unavailable' ? 0 : 8,
                            ),
                            child: _FleetFilter(
                              label: filter,
                              selected: _availabilityFilter == filter,
                              onTap: () => setState(
                                () => _availabilityFilter = filter,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
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
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(
            children: const [
              _FleetSkeleton(),
              SizedBox(height: 12),
              _FleetSkeleton(),
            ],
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
                  'Vehicles added through the management portal will appear here.',
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
                  onView: () => _openCarDetails(variant),
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

class _FleetSummary extends StatelessWidget {
  final int total;
  final int available;
  final int unavailable;

  const _FleetSummary({
    required this.total,
    required this.available,
    required this.unavailable,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [providerPrimaryDark, Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x242563EB),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _SummaryItem(
              icon: Icons.directions_car_rounded,
              label: 'Total',
              value: total,
            ),
            const _SummaryDivider(),
            _SummaryItem(
              icon: Icons.check_circle_outline_rounded,
              label: 'Available',
              value: available,
            ),
            const _SummaryDivider(),
            _SummaryItem(
              icon: Icons.remove_circle_outline_rounded,
              label: 'Unavailable',
              value: unavailable,
            ),
          ],
        ),
      );
}

class _FilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FilterButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: count > 0 ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: count > 0 ? providerPrimary : providerBorder,
                  ),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: count > 0 ? providerPrimary : providerMuted,
                ),
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: providerPrimary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      );
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        value: options.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: providerBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: providerBorder),
          ),
        ),
        hint: Text('All ${label.toLowerCase()}'),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('All ${label.toLowerCase()}'),
          ),
          ...options.map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            ),
          ),
        ],
        onChanged: onChanged,
      );
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFBFDBFE), size: 21),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFDBEAFE),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 48,
        color: Colors.white.withOpacity(0.18),
      );
}

class _FleetFilter extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FleetFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? providerPrimary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? providerPrimary : providerBorder,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : providerMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
}

class _FleetSkeleton extends StatelessWidget {
  const _FleetSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: providerBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 170,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF3F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBlock(double.infinity, 17),
                  const SizedBox(height: 10),
                  _skeletonBlock(130, 12),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _skeletonBlock(double.infinity, 52)),
                      const SizedBox(width: 10),
                      Expanded(child: _skeletonBlock(double.infinity, 52)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _skeletonBlock(double.infinity, 38),
                ],
              ),
            ),
          ],
        ),
      );

  static Widget _skeletonBlock(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3F8),
          borderRadius: BorderRadius.circular(10),
        ),
      );
}

class _FleetCard extends StatelessWidget {
  final Map<String, dynamic> variant;
  final String currency;
  final VoidCallback onView;

  const _FleetCard({
    required this.variant,
    required this.currency,
    required this.onView,
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

  int get _imageCount {
    final images = variant['images'];
    return images is List ? images.length : 0;
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
            imageCount: _imageCount,
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
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View details'),
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
  final int imageCount;

  const _VehicleImage({
    required this.imageUrl,
    required this.isAvailable,
    required this.imageCount,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(20),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 8.2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
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
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 45,
                          color: providerMuted,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _AvailabilityBadge(isAvailable: isAvailable),
            ),
            if (imageCount > 0)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.62),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$imageCount',
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
          ],
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
