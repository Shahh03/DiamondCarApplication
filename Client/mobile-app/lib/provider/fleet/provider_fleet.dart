import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/provider_fleet_api.dart';
import '../provider_data_scope.dart';
import '../provider_ui.dart';
import 'provider_car_details.dart';

const _surface = Colors.white;
const _softBlue = Color(0xFFEFF6FF);
const _success = Color(0xFF059669);
const _orange = Color(0xFFEA580C);

class ProviderFleetPage extends StatefulWidget {
  final String providerId;

  const ProviderFleetPage({
    super.key,
    required this.providerId,
  });

  @override
  State<ProviderFleetPage> createState() => _ProviderFleetPageState();
}

class _ProviderFleetPageState extends State<ProviderFleetPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _variants = <Map<String, dynamic>>[];
  String _availabilityFilter = 'All';
  String? _categoryFilter;
  String? _transmissionFilter;
  String? _fuelTypeFilter;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadFleet();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  int get _availableCount =>
      _variants.where((variant) => variant['isAvailable'] == true).length;

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
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _filteredVariants {
    final query = _searchController.text.trim().toLowerCase();

    return _variants.where((variant) {
      final available = variant['isAvailable'] == true;
      if (_availabilityFilter == 'Available' && !available) return false;
      if (_availabilityFilter == 'Unavailable' && available) return false;

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
      final searchable = [
        car['brand'],
        car['model'],
        car['year'],
        car['category'],
        car['transmission'],
        car['fuelType'],
        variant['registrationNumber'],
        variant['color'],
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
      return searchable.contains(query);
    }).toList();
  }

  void _clearAll() {
    _searchController.clear();
    setState(() {
      _availabilityFilter = 'All';
      _categoryFilter = null;
      _transmissionFilter = null;
      _fuelTypeFilter = null;
    });
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
        builder: (context, updateSheet) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.viewPaddingOf(context).bottom,
          ),
          decoration: const BoxDecoration(
            color: _surface,
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
                    'Refine vehicles by status and specifications.',
                    style: TextStyle(color: providerMuted),
                  ),
                  const SizedBox(height: 22),
                  const _FieldLabel('Availability'),
                  const SizedBox(height: 9),
                  Row(
                    children: ['All', 'Available', 'Unavailable']
                        .map(
                          (value) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: value == 'Unavailable' ? 0 : 8,
                              ),
                              child: _ChoiceButton(
                                label: value,
                                selected: availability == value,
                                onTap: () => updateSheet(
                                  () => availability = value,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  _FilterDropdown(
                    label: 'Category',
                    value: category,
                    options: _carOptions('category'),
                    onChanged: (value) =>
                        updateSheet(() => category = value),
                  ),
                  const SizedBox(height: 14),
                  _FilterDropdown(
                    label: 'Transmission',
                    value: transmission,
                    options: _carOptions('transmission'),
                    onChanged: (value) =>
                        updateSheet(() => transmission = value),
                  ),
                  const SizedBox(height: 14),
                  _FilterDropdown(
                    label: 'Fuel type',
                    value: fuelType,
                    options: _carOptions('fuelType'),
                    onChanged: (value) =>
                        updateSheet(() => fuelType = value),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => updateSheet(() {
                            availability = 'All';
                            category = null;
                            transmission = null;
                            fuelType = null;
                          }),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Reset'),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Show results'),
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

  void _openDetails(Map<String, dynamic> variant) {
    final scope = ProviderDataScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderDataScope(
          provider: scope.provider,
          refresh: scope.refresh,
          child: ProviderCarDetailsPage(variant: variant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = ProviderDataScope.of(context).currency;
    final filtered = _filteredVariants;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadFleet,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              sliver: SliverToBoxAdapter(
                child: _FleetHeader(
                  total: _variants.length,
                  available: _availableCount,
                  isRefreshing: _isLoading && _variants.isNotEmpty,
                  onRefresh: _loadFleet,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: _SearchBar(
                  controller: _searchController,
                  activeFilterCount: _activeFilterCount,
                  onFilter: _showFilters,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverToBoxAdapter(
                child: _AvailabilitySelector(
                  selected: _availabilityFilter,
                  onSelected: (value) =>
                      setState(() => _availabilityFilter = value),
                ),
              ),
            ),
            if (_categoryFilter != null ||
                _transmissionFilter != null ||
                _fuelTypeFilter != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: _ActiveFilters(
                    category: _categoryFilter,
                    transmission: _transmissionFilter,
                    fuelType: _fuelTypeFilter,
                    onRemoveCategory: () =>
                        setState(() => _categoryFilter = null),
                    onRemoveTransmission: () =>
                        setState(() => _transmissionFilter = null),
                    onRemoveFuelType: () =>
                        setState(() => _fuelTypeFilter = null),
                    onClear: _clearAll,
                  ),
                ),
              ),
            if (!_isLoading && _variants.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${filtered.length} vehicle${filtered.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: providerMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ..._buildContent(filtered, currency),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(
    List<Map<String, dynamic>> filtered,
    String currency,
  ) {
    if (_isLoading && _variants.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(
            children: const [
              _FleetSkeleton(),
              SizedBox(height: 10),
              _FleetSkeleton(),
              SizedBox(height: 10),
              _FleetSkeleton(),
            ],
          ),
        ),
      ];
    }

    if (_error != null && _variants.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          sliver: SliverToBoxAdapter(
            child: ProviderEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Fleet unavailable',
              message: _error!,
              actionLabel: 'Try again',
              onAction: _loadFleet,
            ),
          ),
        ),
      ];
    }

    if (_variants.isEmpty) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
          sliver: SliverToBoxAdapter(
            child: ProviderEmptyState(
              icon: Icons.directions_car_outlined,
              title: 'Your fleet is empty',
              message:
                  'Vehicles added through the management portal appear here.',
            ),
          ),
        ),
      ];
    }

    if (filtered.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          sliver: SliverToBoxAdapter(
            child: ProviderEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching vehicles',
              message: 'Try changing your search or active filters.',
              actionLabel: 'Clear filters',
              onAction: _clearAll,
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(
              bottom: index == filtered.length - 1 ? 0 : 10,
            ),
            child: _FleetRow(
              variant: filtered[index],
              currency: currency,
              onTap: () => _openDetails(filtered[index]),
            ),
          ),
        ),
      ),
    ];
  }

  static Map<String, dynamic> _asMap(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};
}

class _FleetHeader extends StatelessWidget {
  final int total;
  final int available;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  const _FleetHeader({
    required this.total,
    required this.available,
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
                  'Fleet',
                  style: TextStyle(
                    color: providerInk,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total vehicle${total == 1 ? '' : 's'} · $available available',
                  style: const TextStyle(color: providerMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: isRefreshing ? null : onRefresh,
            tooltip: 'Refresh fleet',
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

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final int activeFilterCount;
  final VoidCallback onFilter;

  const _SearchBar({
    required this.controller,
    required this.activeFilterCount,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search vehicles or registration',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: controller.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: _surface,
                border: _searchBorder(providerBorder),
                enabledBorder: _searchBorder(providerBorder),
                focusedBorder: _searchBorder(providerPrimary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FilterButton(count: activeFilterCount, onTap: onFilter),
        ],
      );

  static OutlineInputBorder _searchBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
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
            color: count > 0 ? _softBlue : _surface,
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: providerPrimary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _surface, width: 2),
                ),
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

class _AvailabilitySelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _AvailabilitySelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: ['All', 'Available', 'Unavailable']
              .map(
                (value) => Expanded(
                  child: _Segment(
                    label: value,
                    selected: selected == value,
                    onTap: () => onSelected(value),
                  ),
                ),
              )
              .toList(),
        ),
      );
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _surface : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? providerInk : providerMuted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ),
      );
}

class _ActiveFilters extends StatelessWidget {
  final String? category;
  final String? transmission;
  final String? fuelType;
  final VoidCallback onRemoveCategory;
  final VoidCallback onRemoveTransmission;
  final VoidCallback onRemoveFuelType;
  final VoidCallback onClear;

  const _ActiveFilters({
    required this.category,
    required this.transmission,
    required this.fuelType,
    required this.onRemoveCategory,
    required this.onRemoveTransmission,
    required this.onRemoveFuelType,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (category != null)
                    _FilterChip(label: category!, onDeleted: onRemoveCategory),
                  if (transmission != null)
                    _FilterChip(
                      label: transmission!,
                      onDeleted: onRemoveTransmission,
                    ),
                  if (fuelType != null)
                    _FilterChip(label: fuelType!, onDeleted: onRemoveFuelType),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Clear'),
          ),
        ],
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _FilterChip({required this.label, required this.onDeleted});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: InputChip(
          label: Text(label),
          onDeleted: onDeleted,
          deleteIcon: const Icon(Icons.close_rounded, size: 16),
          visualDensity: VisualDensity.compact,
          backgroundColor: _softBlue,
          side: const BorderSide(color: Color(0xFFBFDBFE)),
          labelStyle: const TextStyle(
            color: providerPrimaryDark,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _FleetRow extends StatelessWidget {
  final Map<String, dynamic> variant;
  final String currency;
  final VoidCallback onTap;

  const _FleetRow({
    required this.variant,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final car = _asMap(variant['car']);
    final images = _images(variant['images']);
    final name = [car['brand'], car['model']]
        .map((value) => value?.toString().trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' ');
    final available = variant['isAvailable'] == true;

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
            height: 142,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              _FleetThumbnail(
                imageUrl: images.isEmpty ? '' : images.first,
                imageCount: images.length,
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
                              name.isEmpty ? 'Unnamed vehicle' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: providerInk,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _StatusDot(available: available),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          car['year'],
                          variant['registrationNumber'],
                        ].map((value) => value?.toString().trim() ?? '')
                            .where((value) => value.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: providerMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          if (_text(car['category']).isNotEmpty)
                            _SpecTag(_text(car['category'])),
                          if (_text(car['transmission']).isNotEmpty)
                            _SpecTag(_text(car['transmission'])),
                          if (_text(car['fuelType']).isNotEmpty)
                            _SpecTag(_text(car['fuelType'])),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: _money(
                                      currency,
                                      variant['rentalPricePerDay'],
                                    ),
                                    style: const TextStyle(
                                      color: providerPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' / day',
                                    style: TextStyle(
                                      color: providerMuted,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: providerMuted,
                            size: 20,
                          ),
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

  static Map<String, dynamic> _asMap(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};

  static List<String> _images(dynamic value) => value is List
      ? value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList()
      : <String>[];

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static String _money(String currency, dynamic value) {
    final number = value is num
        ? value
        : num.tryParse(value?.toString() ?? '') ?? 0;
    return '$currency ${NumberFormat('#,##0.##').format(number)}';
  }
}

class _FleetThumbnail extends StatelessWidget {
  final String imageUrl;
  final int imageCount;

  const _FleetThumbnail({required this.imageUrl, required this.imageCount});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(19)),
        child: SizedBox(
          width: 116,
          height: 142,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: const Color(0xFFF1F5F9),
                child: imageUrl.isEmpty
                    ? const Icon(
                        Icons.directions_car_rounded,
                        size: 42,
                        color: providerMuted,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          size: 36,
                          color: providerMuted,
                        ),
                      ),
              ),
              if (imageCount > 0)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
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
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$imageCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
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

class _StatusDot extends StatelessWidget {
  final bool available;

  const _StatusDot({required this.available});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: available
              ? const Color(0xFFECFDF5)
              : const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: available ? _success : _orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              available ? 'Available' : 'Unavailable',
              style: TextStyle(
                color: available ? _success : _orange,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _SpecTag extends StatelessWidget {
  final String label;

  const _SpecTag(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: providerBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: providerMuted,
            fontSize: 8,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _FleetSkeleton extends StatelessWidget {
  const _FleetSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 142,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: providerBorder),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: providerInk,
          fontWeight: FontWeight.w800,
        ),
      );
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? _softBlue : _surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? providerPrimary : providerBorder,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? providerPrimary : providerMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
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
        value: value ?? '',
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
        items: [
          DropdownMenuItem<String>(
            value: '',
            child: Text('All ${label.toLowerCase()}'),
          ),
          ...options.map(
            (option) => DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            ),
          ),
        ],
        onChanged: (selected) =>
            onChanged(selected == null || selected.isEmpty ? null : selected),
      );
}
