import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';
import 'package:intl/intl.dart';
import 'carVariantDetails.dart';

class RenterSearch extends StatefulWidget {
  final String id;

  const RenterSearch({super.key, required this.id});

  @override
  State<RenterSearch> createState() => _RenterSearchState();
}

class _RenterSearchState extends State<RenterSearch> {
  Map<String, dynamic>? userData;
  List<dynamic> carVariants = [];

  bool isUserLoading = true;
  bool isCarsLoading = true;
  String query = '';

  // ====== Filters (selected) ======
  String? selectedBrand;
  String? selectedCategory;
  String? selectedTransmission;
  String? selectedFuel;
  int? selectedSeats;

  // NOTE: Range slider values are kept in the DB's base currency (AED).
  RangeValues? selectedPrice; // AED  <<< CHANGED: clarified base unit
  RangeValues? selectedYear;  // model year

  // ====== Filter options / bounds (derived from data) ======
  List<String> brands = [];
  List<String> categories = [];
  List<String> transmissions = [];
  List<String> fuels = [];
  List<int> seatsOptions = [];

  double priceMin = 0, priceMax = 0; // AED  <<< CHANGED: clarified base unit
  double yearMin = 0, yearMax = 0;

  bool get isLoading => isUserLoading || isCarsLoading;

  // --- NEW: declare base currency code used in your DB ---
  static const String _BASE_CCY = 'AED'; // <<< CHANGED: AED is the stored unit

  @override
  void initState() {
    super.initState();
    getUserData();
    getAllAvailableCarVariants();
  }

  Future<void> getUserData() async {
    try {
      final url = Uri.parse('http://10.0.2.2:8000/user/${widget.id}');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          userData = data;
          isUserLoading = false;
        });
        print("User Data: $userData");
      } else {
        throw Exception('Failed to load user');
      }
    } catch (e) {
      print('Error fetching user: $e');
      setState(() => isUserLoading = false);
    }
  }

  // ===== Currency helpers =====

  // Read the user’s preferred currency from the loaded user object.
  String get _preferredCurrency {
    final c =
        userData?['currency'] ??
        userData?['preferredCurrency'] ??
        userData?['settings']?['currency'] ??
        'EGP';
    return c.toString().toUpperCase();
  }

  // We expect fxRates as **EGP per 1 unit** of the currency, e.g.:
  // { "USD": 50.0, "EUR": 54.0, "GBP": 64.0, "SAR": 13.3, "AED": 13.6, "EGP": 1 }
  Map<String, double> get _egpPerUnit {
    final m = <String, double>{'EGP': 1};
    final fx = userData?['fxRates'];
    if (fx is Map) {
      for (final e in fx.entries) {
        final k = e.key.toString().toUpperCase();
        final v = (e.value is num) ? (e.value as num).toDouble() : null;
        if (v != null && v > 0) m[k] = v;
      }
    }
    // Fallbacks
    m.putIfAbsent('USD', () => 50.0);
    m.putIfAbsent('EUR', () => 54.0);
    m.putIfAbsent('GBP', () => 64.0);
    m.putIfAbsent('SAR', () => 13.3);
    m.putIfAbsent('AED', () => 13.6);
    return m;
  }

  double _egpPer(String code) => _egpPerUnit[code.toUpperCase()] ?? 1.0;

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
      case 'EGP':
      default:
        return 'EGP';
    }
  }

  // Convert an amount stored in **AED** (DB base) to the user's preferred currency,
  // formatting as a label (no decimals).
  // Math: amount[AED] -> EGP via egpPer(AED) -> Target via divide egpPer(Target).
  String _formatMoneyFromBase(num baseAmount, {String? to}) { // <<< CHANGED: new converter
    final target = (to ?? _preferredCurrency).toUpperCase();
    final sym = _currencySymbol(target);

    double value;
    if (target == _BASE_CCY) {
      value = baseAmount.toDouble();
    } else if (target == 'EGP') {
      value = baseAmount.toDouble() * _egpPer(_BASE_CCY);
    } else {
      // Convert AED -> EGP -> target
      final egpPerBase = _egpPer(_BASE_CCY);
      final egpPerTarget = _egpPer(target);
      value = baseAmount.toDouble() * egpPerBase / egpPerTarget;
    }

    final s = NumberFormat.decimalPattern().format(value.round());
    return (target == 'EGP') ? '$sym $s' : '$sym $s';
  }

  Future<void> getAllAvailableCarVariants() async {
    try {
      final url = Uri.parse('http://10.0.2.2:8000/carVariant/getAllAvailable'); // change casing if needed
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        List<dynamic> list;
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        } else {
          list = [];
        }

        setState(() {
          carVariants = list;
          isCarsLoading = false;
        });
        _deriveFilterOptions();
        print("Variants: ${carVariants.length}");
      } else {
        throw Exception('Failed to load variants');
      }
    } catch (e) {
      print('Error fetching variants: $e');
      setState(() => isCarsLoading = false);
    }
  }

  // ====== Derive options & bounds from data ======
  void _deriveFilterOptions() {
    final brandSet = <String>{};
    final categorySet = <String>{};
    final transmissionSet = <String>{};
    final fuelSet = <String>{};
    final seatsSet = <int>{};
    double? pMin, pMax; // in AED (DB base)  <<< CHANGED: comment
    int? yMin, yMax;

    for (final v in carVariants) {
      final car = (v['car'] ?? {}) as Map;
      final b = (car['brand'] ?? '').toString().trim();
      final c = (car['category'] ?? '').toString().trim();
      final tr = (car['transmission'] ?? '').toString().trim();
      final fu = (car['fuelType'] ?? '').toString().trim();
      final st = car['seats'];
      final y = car['year'];
      final price = v['rentalPricePerDay']; // AED

      if (b.isNotEmpty) brandSet.add(b);
      if (c.isNotEmpty) categorySet.add(c);
      if (tr.isNotEmpty) transmissionSet.add(tr);
      if (fu.isNotEmpty) fuelSet.add(fu);
      if (st is int) seatsSet.add(st);

      if (price is num) {
        final d = price.toDouble(); // AED
        pMin = (pMin == null) ? d : (d < pMin! ? d : pMin);
        pMax = (pMax == null) ? d : (d > pMax! ? d : pMax);
      }
      if (y is int) {
        yMin = (yMin == null) ? y : (y < yMin! ? y : yMin);
        yMax = (yMax == null) ? y : (y > yMax! ? y : yMax);
      }
    }

    final br = brandSet.toList()..sort();
    final ct = categorySet.toList()..sort();
    final trL = transmissionSet.toList()..sort();
    final fuL = fuelSet.toList()..sort();
    final se = seatsSet.toList()..sort();

    setState(() {
      brands = br;
      categories = ct;
      transmissions = trL;
      fuels = fuL;
      seatsOptions = se;

      priceMin = (pMin ?? 0); // AED
      priceMax = (pMax ?? 0); // AED
      yearMin = (yMin ?? 0).toDouble();
      yearMax = (yMax ?? 0).toDouble();

      // default ranges cover all values (means "no filter")
      if (priceMin <= priceMax) selectedPrice = RangeValues(priceMin, priceMax); // AED
      if (yearMin <= yearMax) selectedYear = RangeValues(yearMin, yearMax);
    });
  }

  // ====== Filtering logic ======
  List<dynamic> _applyFilters() {
    final q = query.trim().toLowerCase();

    return carVariants.where((v) {
      final car = (v['car'] ?? {}) as Map;

      // Search string (brand/model/provider/color/etc.)
      if (q.isNotEmpty) {
        final provider = (v['provider'] ?? {}) as Map;
        final hay = [
          car['brand'],
          car['model'],
          car['year']?.toString(),
          provider['companyName'],
          v['color'],
          car['fuelType'],
          car['transmission'],
          v['rentalPricePerDay']?.toString(), // AED raw
        ].where((x) => x != null).join(' ').toString().toLowerCase();

        if (!hay.contains(q)) return false;
      }

      // Brand
      if (selectedBrand != null && (car['brand']?.toString() ?? '') != selectedBrand) {
        return false;
      }

      // Category
      if (selectedCategory != null && (car['category']?.toString() ?? '') != selectedCategory) {
        return false;
      }

      // Transmission
      if (selectedTransmission != null &&
          (car['transmission']?.toString() ?? '') != selectedTransmission) {
        return false;
      }

      // Fuel
      if (selectedFuel != null && (car['fuelType']?.toString() ?? '') != selectedFuel) {
        return false;
      }

      // Seats (exact match)
      if (selectedSeats != null) {
        final st = car['seats'];
        if (st is! int || st != selectedSeats) return false;
      }

      // Price range (values stored & compared in AED)
      if (selectedPrice != null && priceMin < priceMax) {
        final price = v['rentalPricePerDay'];
        final p = (price is num) ? price.toDouble() : null; // AED
        if (p == null) return false;
        if (p < selectedPrice!.start || p > selectedPrice!.end) return false;
      }

      // Year range
      if (selectedYear != null && yearMin < yearMax) {
        final y = car['year'];
        if (y is! int) return false;
        final yy = y.toDouble();
        if (yy < selectedYear!.start || yy > selectedYear!.end) return false;
      }

      return true;
    }).toList();
  }

  // ====== Helpers (icons/labels/colors) ======
  String _seatLabel(dynamic value) {
    final s = (value ?? '').toString();
    final n = int.tryParse(s);
    if (n == null) return s.isEmpty ? '' : '$s seats';
    return n == 1 ? '1 seat' : '$n seats';
  }

  IconData _fuelIcon(String fuel) {
    final f = fuel.toLowerCase();
    if (f.contains('electric')) return Icons.electric_bolt;
    if (f.contains('hybrid')) return Icons.energy_savings_leaf;
    return Icons.local_gas_station_outlined;
  }

  IconData _transmissionIcon(String tr) {
    final t = tr.toLowerCase();
    if (t.contains('auto')) return Icons.settings_suggest; // automatic
    return Icons.settings_outlined;                         // manual/other
  }

  Color _colorFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('black')) return Colors.black;
    if (n.contains('white')) return Colors.white;
    if (n.contains('red')) return Colors.red;
    if (n.contains('blue')) return Colors.blue;
    if (n.contains('green')) return Colors.green;
    if (n.contains('yellow')) return Colors.yellow;
    if (n.contains('orange')) return Colors.orange;
    if (n.contains('purple')) return Colors.purple;
    if (n.contains('silver') || n.contains('grey') || n.contains('gray')) return Colors.grey;
    if (n.contains('gold')) return const Color(0xFFFFD700);
    if (n.contains('beige')) return const Color(0xFFF5F5DC);
    if (n.contains('brown')) return Colors.brown;
    return Colors.grey.shade600;
  }

  // ====== Filter sheets ======

  Future<void> _openChoiceSheet({
    required String title,
    required List<String> options,
    required String? current,
    required ValueChanged<String?> onSelected,
  }) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        String? temp = current;
        return StatefulBuilder(builder: (context, setModalState) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.clear),
                  title: const Text('All'),
                  onTap: () {
                    onSelected(null);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final opt = options[i];
                      return RadioListTile<String>(
                        title: Text(opt),
                        value: opt,
                        groupValue: temp,
                        onChanged: (val) {
                          setModalState(() => temp = val);
                          onSelected(val);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    setState(() {}); // refresh labels
  }

  Future<void> _openSeatsSheet() async {
    final opts = seatsOptions.map((e) => e.toString()).toList();
    await _openChoiceSheet(
      title: 'Number of seats',
      options: opts,
      current: selectedSeats?.toString(),
      onSelected: (val) {
        setState(() => selectedSeats = (val == null) ? null : int.tryParse(val));
      },
    );
  }

  Future<void> _openRangeSheet({
    required String title,
    required double min,
    required double max,
    required RangeValues current,
    required ValueChanged<RangeValues> onApplied,
    String Function(double v)? formatValue,
  }) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        RangeValues tmp = current;
        return StatefulBuilder(builder: (context, setModalState) {
          String fmt(double v) => formatValue != null ? formatValue(v) : v.toStringAsFixed(0);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(fmt(tmp.start)),
                      Text(fmt(tmp.end)),
                    ],
                  ),
                  RangeSlider(
                    min: min,
                    max: max,
                    values: tmp,
                    divisions: (max > min) ? (max - min).round() : null,
                    onChanged: (val) => setModalState(() => tmp = val),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setModalState(() => tmp = RangeValues(min, max)),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          onApplied(tmp);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
    setState(() {}); // refresh labels
  }

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilters();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Colors.blueAccent,
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : carVariants.isEmpty
              ? const Center(child: Text('No cars available.'))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() => query = v),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText: 'Search brand, model, provider, color…',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Clear filters + search
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                query = '';
                                _searchCtrl.clear();

                                selectedBrand = null;
                                selectedCategory = null;
                                selectedTransmission = null;
                                selectedFuel = null;
                                selectedSeats = null;
                                if (priceMax > priceMin) {
                                  selectedPrice = RangeValues(priceMin, priceMax); // AED
                                }
                                if (yearMax > yearMin) {
                                  selectedYear = RangeValues(yearMin, yearMax);
                                }
                              });
                            },
                            icon: const Icon(Icons.filter_alt_off_rounded),
                            label: const Text('Clear'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ===== Filter boxes =====
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterButton(
                              label: selectedBrand ?? 'Brand',
                              icon: Icons.directions_car,
                              onTap: () => _openChoiceSheet(
                                title: 'Brand',
                                options: brands,
                                current: selectedBrand,
                                onSelected: (val) => setState(() => selectedBrand = val),
                              ),
                            ),
                            _FilterButton(
                              label: selectedCategory ?? 'Category',
                              icon: Icons.category_outlined,
                              onTap: () => _openChoiceSheet(
                                title: 'Category',
                                options: categories,
                                current: selectedCategory,
                                onSelected: (val) => setState(() => selectedCategory = val),
                              ),
                            ),
                            _FilterButton(
                              // Display preferred currency, but slider values are AED
                              label: (selectedPrice != null && priceMax > priceMin)
                                  ? '${_formatMoneyFromBase(selectedPrice!.start)} - ${_formatMoneyFromBase(selectedPrice!.end)}' // <<< CHANGED
                                  : 'Price range',
                              icon: Icons.price_change_outlined,
                              onTap: () {
                                if (priceMax <= priceMin) return;
                                _openRangeSheet(
                                  title: 'Price per day (${_preferredCurrency})',
                                  min: priceMin, // AED
                                  max: priceMax, // AED
                                  current: selectedPrice ?? RangeValues(priceMin, priceMax),
                                  onApplied: (val) => setState(() => selectedPrice = val),
                                  // `v` is AED internally; only change how it’s displayed
                                  formatValue: (v) => _formatMoneyFromBase(v), // <<< CHANGED
                                );
                              },
                            ),
                            _FilterButton(
                              label: (selectedYear != null && yearMax > yearMin)
                                  ? '${selectedYear!.start.round()} - ${selectedYear!.end.round()}'
                                  : 'Model year',
                              icon: Icons.calendar_today_outlined,
                              onTap: () {
                                if (yearMax <= yearMin) return;
                                _openRangeSheet(
                                  title: 'Model year',
                                  min: yearMin,
                                  max: yearMax,
                                  current: selectedYear ?? RangeValues(yearMin, yearMax),
                                  onApplied: (val) => setState(() => selectedYear = val),
                                );
                              },
                            ),
                            _FilterButton(
                              label: selectedSeats != null ? '${selectedSeats!} seats' : 'No. of seats',
                              icon: Icons.event_seat,
                              onTap: _openSeatsSheet,
                            ),
                            _FilterButton(
                              label: selectedTransmission ?? 'Transmission',
                              icon: Icons.settings_suggest,
                              onTap: () => _openChoiceSheet(
                                title: 'Transmission',
                                options: transmissions,
                                current: selectedTransmission,
                                onSelected: (val) => setState(() => selectedTransmission = val),
                              ),
                            ),
                            _FilterButton(
                              label: selectedFuel ?? 'Fuel type',
                              icon: Icons.ev_station,
                              onTap: () => _openChoiceSheet(
                                title: 'Fuel type',
                                options: fuels,
                                current: selectedFuel,
                                onSelected: (val) => setState(() => selectedFuel = val),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Showing ${filtered.length} cars',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // ===== Results list =====
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final v = filtered[index];

                            final car = v['car'] ?? {};
                            final provider = v['provider'] ?? {};
                            final List images = (v['images'] ?? []) as List;

                            final brand = car['brand'] ?? 'Unknown';
                            final model = car['model'] ?? '';
                            final year = car['year']?.toString() ?? '';

                            final providerName = provider['companyName'] ?? 'Provider';
                            final color = (v['color'] ?? '').toString();
                            final fuel = (car['fuelType'] ?? '').toString();
                            final transmission = (car['transmission'] ?? '').toString();
                            final seats = (car['seats'] ?? '').toString();
                            final priceStr = v['rentalPricePerDay']?.toString() ?? ''; // AED
                            final depositStr = v['depositAmount']?.toString() ?? '';  // AED (assumed)

                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ---- Image carousel ----
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    child: SizedBox(
                                      height: 250,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: images.length,
                                        itemBuilder: (context, i) {
                                          final imgPath = images[i]?['filepath'] ?? '';
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 8.0),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(
                                                "$imgPath",
                                                width: 400,
                                                height: 250,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  width: 400,
                                                  height: 250,
                                                  color: Colors.grey.shade200,
                                                  child: const Center(
                                                    child: Icon(Icons.directions_car_filled_outlined),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                  // ---- Details ----
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$brand $model ${year.isNotEmpty ? year : ''}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),

                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // LEFT: framed spec badges
                                            Expanded(
                                              child: Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  if (providerName.isNotEmpty)
                                                    FramedInfo(
                                                      leading: const Icon(Icons.store_mall_directory, size: 16),
                                                      label: providerName,
                                                    ),
                                                  if (color.isNotEmpty)
                                                    FramedInfo(
                                                      leading: Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: _colorFromName(color),
                                                          border: Border.all(color: Colors.black12),
                                                        ),
                                                      ),
                                                      label: color,
                                                    ),
                                                  if (fuel.isNotEmpty)
                                                    FramedInfo(
                                                      leading: Icon(_fuelIcon(fuel), size: 16),
                                                      label: fuel,
                                                    ),
                                                  if (transmission.isNotEmpty)
                                                    FramedInfo(
                                                      leading: Icon(_transmissionIcon(transmission), size: 16),
                                                      label: transmission,
                                                    ),
                                                  if (seats.isNotEmpty)
                                                    FramedInfo(
                                                      leading: const Icon(Icons.event_seat, size: 16),
                                                      label: _seatLabel(seats),
                                                    ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            // RIGHT: price/deposit (convert from AED to preferred)
                                            Builder(builder: (_) {
                                              final priceNum   = num.tryParse(priceStr) ?? 0;
                                              final depositNum = num.tryParse(depositStr) ?? 0;

                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  if (priceNum > 0)
                                                    Text(
                                                      '${_formatMoneyFromBase(priceNum)}/day', // <<< CHANGED
                                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                                    ),
                                                  if (depositNum > 0) const SizedBox(height: 2),
                                                  if (depositNum > 0)
                                                    Text(
                                                      'Deposit: ${_formatMoneyFromBase(depositNum)}', // <<< CHANGED
                                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                                    ),
                                                ],
                                              );
                                            }),
                                          ],
                                        ),

                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.center,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              final variantId = (v['_id'] ?? '').toString();
                                              if (variantId.isEmpty) return;

                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => CarVariantDetails(
                                                    variantId: variantId,
                                                    userId: widget.id,
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              elevation: 4,
                                              backgroundColor: Colors.blueAccent,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                            ),
                                            child: const Text('View Details'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1,
        userId: widget.id,
      ),
    );
  }
}

// ===== Filter button (small outlined pill) =====
class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _FilterButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          side: BorderSide(color: Theme.of(context).dividerColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ===== simple framed-badge widget like a "frame with logo" =====
class FramedInfo extends StatelessWidget {
  final Widget leading;
  final String label;

  const FramedInfo({super.key, required this.leading, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          if (!(leading is SizedBox)) const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
