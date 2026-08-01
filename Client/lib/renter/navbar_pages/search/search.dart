import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';

import '../../api/activity_api.dart';
import '../../api/car_variant_api.dart';
import '../../api/renter_api.dart';
import 'carVariantDetails.dart';

const _primary = Color(0xFF1D4ED8);
const _primaryDark = Color(0xFF1E40AF);
const _background = Color(0xFFF5F7FB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class RenterSearch extends StatefulWidget {
  final String id;

  const RenterSearch({super.key, required this.id});

  @override
  State<RenterSearch> createState() => _RenterSearchState();
}

class _RenterSearchState extends State<RenterSearch> {
  static const String _baseCurrency = 'AED';

  final _searchController = TextEditingController();

  Map<String, dynamic>? _userData;
  List<dynamic> _carVariants = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _query = '';

  String? _selectedBrand;
  String? _selectedCategory;
  String? _selectedTransmission;
  String? _selectedFuel;
  int? _selectedSeats;
  RangeValues? _selectedPrice;
  RangeValues? _selectedYear;

  List<String> _brands = [];
  List<String> _categories = [];
  List<String> _transmissions = [];
  List<String> _fuels = [];
  List<int> _seatOptions = [];

  double _priceMin = 0;
  double _priceMax = 0;
  double _yearMin = 0;
  double _yearMax = 0;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPage() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        RenterApi.getUserById(widget.id),
        CarVariantApi.getAllAvailableCarVariants(),
      ]);
      if (!mounted) return;

      _userData = results[0] is Map
          ? Map<String, dynamic>.from(results[0] as Map)
          : null;
      _carVariants = results[1] is List
          ? List<dynamic>.from(results[1] as List)
          : <dynamic>[];
      _deriveFilterOptions();

      setState(() => _isLoading = false);
    } catch (error) {
      debugPrint('Search page load error: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load available cars. Please try again.';
      });
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  void _deriveFilterOptions() {
    final brands = <String>{};
    final categories = <String>{};
    final transmissions = <String>{};
    final fuels = <String>{};
    final seats = <int>{};
    double? minimumPrice;
    double? maximumPrice;
    int? minimumYear;
    int? maximumYear;

    for (final rawVariant in _carVariants) {
      final variant = _asMap(rawVariant);
      final car = _asMap(variant['car']);
      final brand = (car['brand'] ?? '').toString().trim();
      final category = (car['category'] ?? '').toString().trim();
      final transmission = (car['transmission'] ?? '').toString().trim();
      final fuel = (car['fuelType'] ?? '').toString().trim();
      final seatCount = car['seats'] is num
          ? (car['seats'] as num).toInt()
          : int.tryParse(car['seats']?.toString() ?? '');
      final year = car['year'] is num
          ? (car['year'] as num).toInt()
          : int.tryParse(car['year']?.toString() ?? '');
      final price = variant['rentalPricePerDay'] is num
          ? (variant['rentalPricePerDay'] as num).toDouble()
          : double.tryParse(variant['rentalPricePerDay']?.toString() ?? '');

      if (brand.isNotEmpty) brands.add(brand);
      if (category.isNotEmpty) categories.add(category);
      if (transmission.isNotEmpty) transmissions.add(transmission);
      if (fuel.isNotEmpty) fuels.add(fuel);
      if (seatCount != null) seats.add(seatCount);

      if (price != null) {
        minimumPrice = minimumPrice == null || price < minimumPrice
            ? price
            : minimumPrice;
        maximumPrice = maximumPrice == null || price > maximumPrice
            ? price
            : maximumPrice;
      }
      if (year != null) {
        minimumYear = minimumYear == null || year < minimumYear
            ? year
            : minimumYear;
        maximumYear = maximumYear == null || year > maximumYear
            ? year
            : maximumYear;
      }
    }

    _brands = brands.toList()..sort();
    _categories = categories.toList()..sort();
    _transmissions = transmissions.toList()..sort();
    _fuels = fuels.toList()..sort();
    _seatOptions = seats.toList()..sort();
    _priceMin = minimumPrice ?? 0;
    _priceMax = maximumPrice ?? 0;
    _yearMin = (minimumYear ?? 0).toDouble();
    _yearMax = (maximumYear ?? 0).toDouble();
  }

  String get _preferredCurrency {
    final currency =
        _userData?['currency'] ??
        _userData?['preferredCurrency'] ??
        _userData?['settings']?['currency'] ??
        'EGP';
    return currency.toString().toUpperCase();
  }

  Map<String, double> get _egpPerUnit {
    final rates = <String, double>{'EGP': 1};
    final fx = _userData?['fxRates'];
    if (fx is Map) {
      for (final entry in fx.entries) {
        final value = entry.value is num
            ? (entry.value as num).toDouble()
            : double.tryParse(entry.value.toString());
        if (value != null && value > 0) {
          rates[entry.key.toString().toUpperCase()] = value;
        }
      }
    }
    rates.putIfAbsent('USD', () => 50.0);
    rates.putIfAbsent('EUR', () => 54.0);
    rates.putIfAbsent('GBP', () => 64.0);
    rates.putIfAbsent('SAR', () => 13.3);
    rates.putIfAbsent('AED', () => 13.6);
    return rates;
  }

  double _egpPer(String code) =>
      _egpPerUnit[code.toUpperCase()] ?? 1.0;

  String _currencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'SAR':
        return '﷼';
      case 'AED':
        return 'د.إ';
      default:
        return 'EGP';
    }
  }

  String _formatMoneyFromBase(num amount, {String? to}) {
    final target = (to ?? _preferredCurrency).toUpperCase();
    final double converted;
    if (target == _baseCurrency) {
      converted = amount.toDouble();
    } else if (target == 'EGP') {
      converted = amount.toDouble() * _egpPer(_baseCurrency);
    } else {
      converted = amount.toDouble() *
          _egpPer(_baseCurrency) /
          _egpPer(target);
    }
    final value = NumberFormat.decimalPattern().format(converted.round());
    return '${_currencySymbol(target)} $value';
  }

  String _imageUrl(dynamic image) {
    if (image is String) return image;
    if (image is Map && image['filepath'] != null) {
      return image['filepath'].toString();
    }
    if (image is Map && image['url'] != null) {
      return image['url'].toString();
    }
    return '';
  }

  bool _isFullPriceRange(RangeValues? range) {
    if (range == null || _priceMax <= _priceMin) return true;
    return (range.start - _priceMin).abs() < 0.01 &&
        (range.end - _priceMax).abs() < 0.01;
  }

  bool _isFullYearRange(RangeValues? range) {
    if (range == null || _yearMax <= _yearMin) return true;
    return range.start.round() == _yearMin.round() &&
        range.end.round() == _yearMax.round();
  }

  int get _activeFilterCount {
    var count = 0;
    if (_selectedBrand != null) count++;
    if (_selectedCategory != null) count++;
    if (_selectedTransmission != null) count++;
    if (_selectedFuel != null) count++;
    if (_selectedSeats != null) count++;
    if (!_isFullPriceRange(_selectedPrice)) count++;
    if (!_isFullYearRange(_selectedYear)) count++;
    return count;
  }

  _FilterDraft get _currentFilters => _FilterDraft(
        brand: _selectedBrand,
        category: _selectedCategory,
        transmission: _selectedTransmission,
        fuel: _selectedFuel,
        seats: _selectedSeats,
        price: _selectedPrice,
        year: _selectedYear,
      );

  List<dynamic> _applyFilters([_FilterDraft? draft]) {
    final filters = draft ?? _currentFilters;
    final search = _query.trim().toLowerCase();

    return _carVariants.where((rawVariant) {
      final variant = _asMap(rawVariant);
      final car = _asMap(variant['car']);
      final provider = _asMap(variant['provider']);

      if (search.isNotEmpty) {
        final searchable = [
          car['brand'],
          car['model'],
          car['year'],
          car['category'],
          provider['companyName'],
          variant['color'],
          car['fuelType'],
          car['transmission'],
        ].where((value) => value != null).join(' ').toLowerCase();
        if (!searchable.contains(search)) return false;
      }

      if (filters.brand != null &&
          car['brand']?.toString() != filters.brand) return false;
      if (filters.category != null &&
          car['category']?.toString() != filters.category) return false;
      if (filters.transmission != null &&
          car['transmission']?.toString() != filters.transmission) return false;
      if (filters.fuel != null &&
          car['fuelType']?.toString() != filters.fuel) return false;

      if (filters.seats != null) {
        final seats = car['seats'] is num
            ? (car['seats'] as num).toInt()
            : int.tryParse(car['seats']?.toString() ?? '');
        if (seats != filters.seats) return false;
      }

      if (!_isFullPriceRange(filters.price)) {
        final price = variant['rentalPricePerDay'] is num
            ? (variant['rentalPricePerDay'] as num).toDouble()
            : double.tryParse(
                variant['rentalPricePerDay']?.toString() ?? '',
              );
        if (price == null ||
            price < filters.price!.start ||
            price > filters.price!.end) return false;
      }

      if (!_isFullYearRange(filters.year)) {
        final year = car['year'] is num
            ? (car['year'] as num).toDouble()
            : double.tryParse(car['year']?.toString() ?? '');
        if (year == null ||
            year < filters.year!.start ||
            year > filters.year!.end) return false;
      }

      return true;
    }).toList();
  }

  void _clearFilters({bool clearSearch = false}) {
    setState(() {
      _selectedBrand = null;
      _selectedCategory = null;
      _selectedTransmission = null;
      _selectedFuel = null;
      _selectedSeats = null;
      _selectedPrice = null;
      _selectedYear = null;
      if (clearSearch) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  Future<void> _trackSubmittedSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;

    try {
      await ActivityApi.trackSearch(
        renterId: widget.id,
        query: query,
        brand: _selectedBrand,
        category: _selectedCategory,
        transmission: _selectedTransmission,
        fuelType: _selectedFuel,
        seats: _selectedSeats,
        minPrice: _isFullPriceRange(_selectedPrice)
            ? null
            : _selectedPrice?.start,
        maxPrice: _isFullPriceRange(_selectedPrice)
            ? null
            : _selectedPrice?.end,
      );
    } catch (error) {
      debugPrint('Search tracking error: $error');
    }
  }

  Future<void> _trackFilterActivity(_FilterDraft filters) async {
    final hasMeaningfulFilter = filters.brand != null ||
        filters.category != null ||
        filters.transmission != null ||
        filters.fuel != null ||
        filters.seats != null ||
        !_isFullPriceRange(filters.price);
    if (!hasMeaningfulFilter) return;

    try {
      await ActivityApi.trackFilters(
        renterId: widget.id,
        brand: filters.brand,
        category: filters.category,
        transmission: filters.transmission,
        fuelType: filters.fuel,
        seats: filters.seats,
        minPrice:
            _isFullPriceRange(filters.price) ? null : filters.price?.start,
        maxPrice:
            _isFullPriceRange(filters.price) ? null : filters.price?.end,
      );
    } catch (error) {
      debugPrint('Filter tracking error: $error');
    }
  }

  void _selectQuickCategory(String? category) {
    final nextCategory = category == null
        ? null
        : (_selectedCategory == category ? null : category);

    setState(() => _selectedCategory = nextCategory);

    if (nextCategory != null) {
      unawaited(_trackFilterActivity(_currentFilters));
    }
  }

  Future<void> _openFilters() async {
    String? brand = _selectedBrand;
    String? category = _selectedCategory;
    String? transmission = _selectedTransmission;
    String? fuel = _selectedFuel;
    int? seats = _selectedSeats;
    RangeValues price = _selectedPrice ?? RangeValues(_priceMin, _priceMax);
    RangeValues year = _selectedYear ?? RangeValues(_yearMin, _yearMax);
    bool priceEnabled = !_isFullPriceRange(_selectedPrice);
    bool yearEnabled = !_isFullYearRange(_selectedYear);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final draft = _FilterDraft(
              brand: brand,
              category: category,
              transmission: transmission,
              fuel: fuel,
              seats: seats,
              price: priceEnabled ? price : null,
              year: yearEnabled ? year : null,
            );
            final matchCount = _applyFilters(draft).length;

            void resetDraft() {
              setSheetState(() {
                brand = null;
                category = null;
                transmission = null;
                fuel = null;
                seats = null;
                price = RangeValues(_priceMin, _priceMax);
                year = RangeValues(_yearMin, _yearMax);
                priceEnabled = false;
                yearEnabled = false;
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.58,
              maxChildSize: 0.96,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Filter cars',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.35,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: resetDraft,
                              child: const Text(
                                'Reset',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: _border),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                          children: [
                            if (_categories.isNotEmpty)
                              _ChoiceFilterSection<String>(
                                title: 'Category',
                                icon: Icons.category_outlined,
                                options: _categories,
                                selected: category,
                                labelFor: (value) => value,
                                onSelected: (value) => setSheetState(() {
                                  category = category == value ? null : value;
                                }),
                              ),
                            if (_brands.isNotEmpty)
                              _ChoiceFilterSection<String>(
                                title: 'Brand',
                                icon: Icons.directions_car_outlined,
                                options: _brands,
                                selected: brand,
                                labelFor: (value) => value,
                                onSelected: (value) => setSheetState(() {
                                  brand = brand == value ? null : value;
                                }),
                              ),
                            if (_priceMax > _priceMin)
                              _RangeFilterSection(
                                title: 'Daily price',
                                icon: Icons.payments_outlined,
                                enabled: priceEnabled,
                                values: price,
                                min: _priceMin,
                                max: _priceMax,
                                divisions: 30,
                                startLabel:
                                    _formatMoneyFromBase(price.start),
                                endLabel: _formatMoneyFromBase(price.end),
                                onChanged: (values) => setSheetState(() {
                                  price = values;
                                  priceEnabled = true;
                                }),
                                onReset: () => setSheetState(() {
                                  price = RangeValues(_priceMin, _priceMax);
                                  priceEnabled = false;
                                }),
                              ),
                            if (_yearMax > _yearMin)
                              _RangeFilterSection(
                                title: 'Model year',
                                icon: Icons.calendar_month_outlined,
                                enabled: yearEnabled,
                                values: year,
                                min: _yearMin,
                                max: _yearMax,
                                divisions: (_yearMax - _yearMin).round(),
                                startLabel: year.start.round().toString(),
                                endLabel: year.end.round().toString(),
                                onChanged: (values) => setSheetState(() {
                                  year = values;
                                  yearEnabled = true;
                                }),
                                onReset: () => setSheetState(() {
                                  year = RangeValues(_yearMin, _yearMax);
                                  yearEnabled = false;
                                }),
                              ),
                            if (_seatOptions.isNotEmpty)
                              _ChoiceFilterSection<int>(
                                title: 'Seats',
                                icon: Icons.airline_seat_recline_normal_rounded,
                                options: _seatOptions,
                                selected: seats,
                                labelFor: (value) => '$value seats',
                                onSelected: (value) => setSheetState(() {
                                  seats = seats == value ? null : value;
                                }),
                              ),
                            if (_transmissions.isNotEmpty)
                              _ChoiceFilterSection<String>(
                                title: 'Transmission',
                                icon: Icons.settings_suggest_outlined,
                                options: _transmissions,
                                selected: transmission,
                                labelFor: (value) => value,
                                onSelected: (value) => setSheetState(() {
                                  transmission =
                                      transmission == value ? null : value;
                                }),
                              ),
                            if (_fuels.isNotEmpty)
                              _ChoiceFilterSection<String>(
                                title: 'Fuel type',
                                icon: Icons.local_gas_station_outlined,
                                options: _fuels,
                                selected: fuel,
                                labelFor: (value) => value,
                                onSelected: (value) => setSheetState(() {
                                  fuel = fuel == value ? null : value;
                                }),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          14,
                          20,
                          14 + MediaQuery.paddingOf(context).bottom,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: _border)),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x0F0F172A),
                              blurRadius: 16,
                              offset: Offset(0, -4),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: () {
                              setState(() {
                                _selectedBrand = brand;
                                _selectedCategory = category;
                                _selectedTransmission = transmission;
                                _selectedFuel = fuel;
                                _selectedSeats = seats;
                                _selectedPrice = priceEnabled ? price : null;
                                _selectedYear = yearEnabled ? year : null;
                              });
                              unawaited(_trackFilterActivity(draft));
                              Navigator.pop(sheetContext);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              'Show $matchCount ${matchCount == 1 ? 'car' : 'cars'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<_ActiveFilter> _activeFilters() {
    return [
      if (_selectedBrand != null)
        _ActiveFilter(
          label: _selectedBrand!,
          onRemove: () => setState(() => _selectedBrand = null),
        ),
      if (_selectedCategory != null)
        _ActiveFilter(
          label: _selectedCategory!,
          onRemove: () => setState(() => _selectedCategory = null),
        ),
      if (!_isFullPriceRange(_selectedPrice))
        _ActiveFilter(
          label:
              '${_formatMoneyFromBase(_selectedPrice!.start)}–${_formatMoneyFromBase(_selectedPrice!.end)}',
          onRemove: () => setState(() => _selectedPrice = null),
        ),
      if (!_isFullYearRange(_selectedYear))
        _ActiveFilter(
          label:
              '${_selectedYear!.start.round()}–${_selectedYear!.end.round()}',
          onRemove: () => setState(() => _selectedYear = null),
        ),
      if (_selectedSeats != null)
        _ActiveFilter(
          label: '$_selectedSeats seats',
          onRemove: () => setState(() => _selectedSeats = null),
        ),
      if (_selectedTransmission != null)
        _ActiveFilter(
          label: _selectedTransmission!,
          onRemove: () => setState(() => _selectedTransmission = null),
        ),
      if (_selectedFuel != null)
        _ActiveFilter(
          label: _selectedFuel!,
          onRemove: () => setState(() => _selectedFuel = null),
        ),
    ];
  }

  String _seatLabel(dynamic value) {
    final number = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    if (number == null) return value?.toString() ?? '';
    return number == 1 ? '1 seat' : '$number seats';
  }

  IconData _fuelIcon(String fuel) {
    final value = fuel.toLowerCase();
    if (value.contains('electric')) return Icons.electric_bolt_rounded;
    if (value.contains('hybrid')) return Icons.energy_savings_leaf_outlined;
    return Icons.local_gas_station_outlined;
  }

  IconData _transmissionIcon(String transmission) {
    return transmission.toLowerCase().contains('auto')
        ? Icons.settings_suggest_outlined
        : Icons.settings_outlined;
  }

  Color _colorFromName(String name) {
    final value = name.toLowerCase();
    if (value.contains('black')) return Colors.black;
    if (value.contains('white')) return Colors.white;
    if (value.contains('red')) return Colors.red;
    if (value.contains('blue')) return Colors.blue;
    if (value.contains('green')) return Colors.green;
    if (value.contains('yellow')) return Colors.yellow;
    if (value.contains('orange')) return Colors.orange;
    if (value.contains('purple')) return Colors.purple;
    if (value.contains('silver') ||
        value.contains('grey') ||
        value.contains('gray')) return Colors.grey;
    if (value.contains('gold')) return const Color(0xFFFFD700);
    if (value.contains('beige')) return const Color(0xFFF5F5DC);
    if (value.contains('brown')) return Colors.brown;
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final filteredCars = _applyFilters();

    return Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          _SearchHeader(
            controller: _searchController,
            query: _query,
            activeFilterCount: _activeFilterCount,
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: (value) {
              setState(() => _query = value.trim());
              unawaited(_trackSubmittedSearch(value));
            },
            onClearSearch: () {
              _searchController.clear();
              setState(() => _query = '');
            },
            onOpenFilters: _openFilters,
          ),
          Expanded(child: _buildBody(filteredCars)),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1,
        userId: widget.id,
      ),
    );
  }

  Widget _buildBody(List<dynamic> filteredCars) {
    if (_isLoading) return const _SearchLoadingState();
    if (_errorMessage != null) {
      return _SearchMessageState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load cars',
        message: _errorMessage!,
        actionLabel: 'Try again',
        onAction: _loadPage,
      );
    }
    if (_carVariants.isEmpty) {
      return _SearchMessageState(
        icon: Icons.directions_car_outlined,
        title: 'No cars available',
        message: 'Check again soon for newly available vehicles.',
        actionLabel: 'Refresh',
        onAction: _loadPage,
      );
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadPage,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        itemCount: filteredCars.isEmpty ? 2 : filteredCars.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return _buildFilterControls();
          if (index == 1) {
            if (filteredCars.isEmpty) {
              return _NoSearchResults(
                onClear: () => _clearFilters(clearSearch: true),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(2, 20, 2, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${filteredCars.length} ${filteredCars.length == 1 ? 'car' : 'cars'} found',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                  Text(
                    _preferredCurrency,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }

          final variant = _asMap(filteredCars[index - 2]);
          final car = _asMap(variant['car']);
          final provider = _asMap(variant['provider']);
          final images = variant['images'] is List
              ? List<dynamic>.from(variant['images'] as List)
              : <dynamic>[];
          final price = variant['rentalPricePerDay'] is num
              ? variant['rentalPricePerDay'] as num
              : num.tryParse(
                    variant['rentalPricePerDay']?.toString() ?? '',
                  ) ??
                  0;
          final deposit = variant['depositAmount'] is num
              ? variant['depositAmount'] as num
              : num.tryParse(variant['depositAmount']?.toString() ?? '') ?? 0;
          final brand = (car['brand'] ?? 'Unknown').toString();
          final model = (car['model'] ?? '').toString();
          final year = (car['year'] ?? '').toString();
          final providerName =
              (provider['companyName'] ?? 'Provider').toString();
          final color = (variant['color'] ?? '').toString();
          final fuel = (car['fuelType'] ?? '').toString();
          final transmission = (car['transmission'] ?? '').toString();
          final seats = (car['seats'] ?? '').toString();
          final category = (car['category'] ?? '').toString();
          final variantId = (variant['_id'] ?? '').toString();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _SearchCarCard(
                  title: [brand, model]
                      .where((part) => part.trim().isNotEmpty)
                      .join(' '),
                  year: year,
                  provider: providerName,
                  images: images,
                  imageUrl: _imageUrl,
                  price: price > 0 ? _formatMoneyFromBase(price) : null,
                  deposit:
                      deposit > 0 ? _formatMoneyFromBase(deposit) : null,
                  specs: [
                    if (category.isNotEmpty)
                      _CarSpec(Icons.category_outlined, category),
                    if (color.isNotEmpty)
                      _CarSpec(Icons.circle, color,
                          accent: _colorFromName(color)),
                    if (fuel.isNotEmpty) _CarSpec(_fuelIcon(fuel), fuel),
                    if (transmission.isNotEmpty)
                      _CarSpec(
                          _transmissionIcon(transmission), transmission),
                    if (seats.isNotEmpty)
                      _CarSpec(
                        Icons.airline_seat_recline_normal_rounded,
                        _seatLabel(seats),
                      ),
                  ],
                  onViewDetails: variantId.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CarVariantDetails(
                                variantId: variantId,
                                userId: widget.id,
                              ),
                            ),
                          ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterControls() {
    final active = _activeFilters();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _QuickCategoryChip(
                          label: 'All',
                          selected: _selectedCategory == null,
                          onTap: () => _selectQuickCategory(null),
                        ),
                        ..._categories.map(
                          (category) => _QuickCategoryChip(
                            label: category,
                            selected: _selectedCategory == category,
                            onTap: () => _selectQuickCategory(category),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _MainFilterButton(
                  count: _activeFilterCount,
                  onTap: _openFilters,
                ),
              ],
            ),
            if (active.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Active',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _clearFilters(),
                    child: const Text(
                      'Clear all',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: active
                      .map(
                        (filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Text(filter.label),
                            onDeleted: filter.onRemove,
                            deleteIcon: const Icon(Icons.close_rounded, size: 17),
                            backgroundColor: const Color(0xFFEFF6FF),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            labelStyle: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterDraft {
  final String? brand;
  final String? category;
  final String? transmission;
  final String? fuel;
  final int? seats;
  final RangeValues? price;
  final RangeValues? year;

  const _FilterDraft({
    this.brand,
    this.category,
    this.transmission,
    this.fuel,
    this.seats,
    this.price,
    this.year,
  });
}

class _ActiveFilter {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilter({required this.label, required this.onRemove});
}

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final int activeFilterCount;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenFilters;

  const _SearchHeader({
    required this.controller,
    required this.query,
    required this.activeFilterCount,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClearSearch,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryDark, Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x331D4ED8),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Find your car',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.45,
                          ),
                        ),
                      ),
                      Icon(Icons.directions_car_filled_outlined,
                          color: Colors.white, size: 28),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          onChanged: onChanged,
                          onSubmitted: onSubmitted,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Brand, model, provider…',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 15,
                            ),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: _primary, size: 23),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: onClearSearch,
                                    icon: const Icon(Icons.close_rounded,
                                        color: _muted),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 17,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: onOpenFilters,
                            icon: const Icon(Icons.tune_rounded,
                                color: _primary, size: 24),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              fixedSize: const Size(54, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          if (activeFilterCount > 0)
                            Positioned(
                              right: -4,
                              top: -5,
                              child: Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDC2626),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$activeFilterCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
}

class _QuickCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: _primary,
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? _primary : _border),
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF334155),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),
    );
  }
}

class _MainFilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _MainFilterButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.tune_rounded, size: 19),
      label: Text(count == 0 ? 'Filters' : 'Filters $count'),
      style: FilledButton.styleFrom(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(104, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ChoiceFilterSection<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<T> options;
  final T? selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelected;

  const _ChoiceFilterSection({
    required this.title,
    required this.icon,
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterSectionTitle(icon: icon, title: title),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: options.map((option) {
              final isSelected = option == selected;
              return ChoiceChip(
                label: Text(labelFor(option)),
                selected: isSelected,
                onSelected: (_) => onSelected(option),
                selectedColor: const Color(0xFFDBEAFE),
                backgroundColor: const Color(0xFFF8FAFC),
                side: BorderSide(
                  color: isSelected ? _primary : _border,
                  width: isSelected ? 1.4 : 1,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? _primaryDark : const Color(0xFF334155),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RangeFilterSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool enabled;
  final RangeValues values;
  final double min;
  final double max;
  final int divisions;
  final String startLabel;
  final String endLabel;
  final ValueChanged<RangeValues> onChanged;
  final VoidCallback onReset;

  const _RangeFilterSection({
    required this.title,
    required this.icon,
    required this.enabled,
    required this.values,
    required this.min,
    required this.max,
    required this.divisions,
    required this.startLabel,
    required this.endLabel,
    required this.onChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _FilterSectionTitle(icon: icon, title: title)),
              if (enabled)
                TextButton(onPressed: onReset, child: const Text('Any')),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _RangeValue(label: startLabel),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Divider(color: _border),
                ),
              ),
              _RangeValue(label: endLabel),
            ],
          ),
          RangeSlider(
            values: values,
            min: min,
            max: max,
            divisions: divisions > 0 ? divisions : null,
            activeColor: _primary,
            inactiveColor: const Color(0xFFDBEAFE),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FilterSectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _primary, size: 21),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RangeValue extends StatelessWidget {
  final String label;

  const _RangeValue({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SearchCarCard extends StatelessWidget {
  final String title;
  final String year;
  final String provider;
  final List<dynamic> images;
  final String Function(dynamic) imageUrl;
  final String? price;
  final String? deposit;
  final List<_CarSpec> specs;
  final VoidCallback? onViewDetails;

  const _SearchCarCard({
    required this.title,
    required this.year,
    required this.provider,
    required this.images,
    required this.imageUrl,
    required this.price,
    required this.deposit,
    required this.specs,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CarGallery(images: images, imageUrl: imageUrl),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 21,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined,
                                  color: _muted, size: 17),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  provider,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (year.isNotEmpty) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('•',
                                      style: TextStyle(color: _muted)),
                                ),
                                Text(
                                  year,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (price != null) ...[
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            price!,
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'per day',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                if (specs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        specs.map((spec) => _SpecPill(spec: spec)).toList(),
                  ),
                ],
                if (deposit != null) ...[
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: _muted, size: 18),
                      const SizedBox(width: 7),
                      Text(
                        'Deposit $deposit',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: const Text('View details'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
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

class _CarGallery extends StatefulWidget {
  final List<dynamic> images;
  final String Function(dynamic) imageUrl;

  const _CarGallery({required this.images, required this.imageUrl});

  @override
  State<_CarGallery> createState() => _CarGalleryState();
}

class _CarGalleryState extends State<_CarGallery> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images
        .map(widget.imageUrl)
        .where((url) => url.trim().isNotEmpty)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            (constraints.maxWidth * 0.6).clamp(220.0, 310.0).toDouble();
        return SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: images.isEmpty ? 1 : images.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) {
                  if (images.isEmpty) return const _ImagePlaceholder();
                  return Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const _ImagePlaceholder(showLoader: true),
                    errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                  );
                },
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color(0x88000000)],
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        stops: [0.58, 1],
                      ),
                    ),
                  ),
                ),
              ),
              if (images.length > 1)
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_page + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (images.length > 1)
                Positioned(
                  left: 16,
                  bottom: 18,
                  child: Row(
                    children: List.generate(
                      images.length > 7 ? 7 : images.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _page == index ? 20 : 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: _page == index
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final bool showLoader;

  const _ImagePlaceholder({this.showLoader = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EDF5),
      child: Center(
        child: showLoader
            ? const CircularProgressIndicator(strokeWidth: 2.4, color: _primary)
            : const Icon(Icons.directions_car_filled_outlined,
                color: Color(0xFF94A3B8), size: 54),
      ),
    );
  }
}

class _CarSpec {
  final IconData icon;
  final String label;
  final Color? accent;

  const _CarSpec(this.icon, this.label, {this.accent});
}

class _SpecPill extends StatelessWidget {
  final _CarSpec spec;

  const _SpecPill({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            spec.icon,
            color: spec.accent ?? _primary,
            size: spec.icon == Icons.circle ? 13 : 16,
          ),
          const SizedBox(width: 6),
          Text(
            spec.label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  final VoidCallback onClear;

  const _NoSearchResults({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                color: _primary, size: 38),
          ),
          const SizedBox(height: 20),
          const Text(
            'No matching cars',
            style: TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try removing a filter or using a different search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 14),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Clear search and filters'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _SearchMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _primary, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchLoadingState extends StatelessWidget {
  const _SearchLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
      itemCount: 2,
      itemBuilder: (context, index) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            height: 410,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 235,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8EDF5),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: index == 0 ? 210 : 170,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EDF5),
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ],
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
