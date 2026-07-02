import 'package:flutter/material.dart';
import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';
import 'package:intl/intl.dart';

import '../../api/renter_api.dart';
import '../../api/car_variant_api.dart';
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

  String? selectedBrand;
  String? selectedCategory;
  String? selectedTransmission;
  String? selectedFuel;
  int? selectedSeats;

  RangeValues? selectedPrice;
  RangeValues? selectedYear;

  List<String> brands = [];
  List<String> categories = [];
  List<String> transmissions = [];
  List<String> fuels = [];
  List<int> seatsOptions = [];

  double priceMin = 0, priceMax = 0;
  double yearMin = 0, yearMax = 0;

  bool get isLoading => isUserLoading || isCarsLoading;

  static const String _BASE_CCY = 'AED';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    getUserData();
    getAllAvailableCarVariants();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> getUserData() async {
    try {
      final data = await RenterApi.getUserById(widget.id);

      if (!mounted) return;

      setState(() {
        userData = data;
        isUserLoading = false;
      });

      debugPrint("User Data: $userData");
    } catch (e) {
      debugPrint('Error fetching user: $e');

      if (!mounted) return;

      setState(() {
        isUserLoading = false;
      });
    }
  }

  Future<void> getAllAvailableCarVariants() async {
    try {
      final list = await CarVariantApi.getAllAvailableCarVariants();

      if (!mounted) return;

      setState(() {
        carVariants = list;
        isCarsLoading = false;
      });

      _deriveFilterOptions();

      debugPrint("Variants: ${carVariants.length}");
    } catch (e) {
      debugPrint('Error fetching variants: $e');

      if (!mounted) return;

      setState(() {
        isCarsLoading = false;
      });
    }
  }

  // ---------------- Image helper ----------------

  String getCarImageUrl(dynamic image) {
    // New structure:
    // images: ["https://res.cloudinary.com/..."]
    if (image is String) {
      return image;
    }

    // Old structure fallback:
    // images: [{ filepath: "..." }]
    if (image is Map && image['filepath'] != null) {
      return image['filepath'].toString();
    }

    // Extra fallback
    if (image is Map && image['url'] != null) {
      return image['url'].toString();
    }

    return '';
  }

  Widget _emptyCarImagePlaceholder() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 400,
          height: 250,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(
              Icons.directions_car_filled_outlined,
              size: 50,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _carImage(String imgPath) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imgPath,
          width: 400,
          height: 250,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              width: 400,
              height: 250,
              color: Colors.grey.shade200,
              child: const Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCarImageCarousel(List images) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: SizedBox(
        height: 250,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: images.isEmpty ? 1 : images.length,
          itemBuilder: (context, i) {
            if (images.isEmpty) {
              return _emptyCarImagePlaceholder();
            }

            final imgPath = getCarImageUrl(images[i]);

            if (imgPath.isEmpty) {
              return _emptyCarImagePlaceholder();
            }

            return _carImage(imgPath);
          },
        ),
      ),
    );
  }

  // ---------------- Currency helpers ----------------

  String get _preferredCurrency {
    final c =
        userData?['currency'] ??
        userData?['preferredCurrency'] ??
        userData?['settings']?['currency'] ??
        'EGP';

    return c.toString().toUpperCase();
  }

  Map<String, double> get _egpPerUnit {
    final m = <String, double>{'EGP': 1};

    final fx = userData?['fxRates'];

    if (fx is Map) {
      for (final e in fx.entries) {
        final k = e.key.toString().toUpperCase();
        final v = (e.value is num) ? (e.value as num).toDouble() : null;

        if (v != null && v > 0) {
          m[k] = v;
        }
      }
    }

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

  String _formatMoneyFromBase(num baseAmount, {String? to}) {
    final target = (to ?? _preferredCurrency).toUpperCase();
    final sym = _currencySymbol(target);

    double value;

    if (target == _BASE_CCY) {
      value = baseAmount.toDouble();
    } else if (target == 'EGP') {
      value = baseAmount.toDouble() * _egpPer(_BASE_CCY);
    } else {
      final egpPerBase = _egpPer(_BASE_CCY);
      final egpPerTarget = _egpPer(target);
      value = baseAmount.toDouble() * egpPerBase / egpPerTarget;
    }

    final s = NumberFormat.decimalPattern().format(value.round());
    return '$sym $s';
  }

  // ---------------- Filter logic ----------------

  void _deriveFilterOptions() {
    final brandSet = <String>{};
    final categorySet = <String>{};
    final transmissionSet = <String>{};
    final fuelSet = <String>{};
    final seatsSet = <int>{};

    double? pMin, pMax;
    int? yMin, yMax;

    for (final v in carVariants) {
      final car = (v['car'] ?? {}) as Map;

      final b = (car['brand'] ?? '').toString().trim();
      final c = (car['category'] ?? '').toString().trim();
      final tr = (car['transmission'] ?? '').toString().trim();
      final fu = (car['fuelType'] ?? '').toString().trim();

      final st = car['seats'];
      final y = car['year'];
      final price = v['rentalPricePerDay'];

      if (b.isNotEmpty) brandSet.add(b);
      if (c.isNotEmpty) categorySet.add(c);
      if (tr.isNotEmpty) transmissionSet.add(tr);
      if (fu.isNotEmpty) fuelSet.add(fu);
      if (st is int) seatsSet.add(st);

      if (price is num) {
        final d = price.toDouble();
        pMin = (pMin == null) ? d : (d < pMin ? d : pMin);
        pMax = (pMax == null) ? d : (d > pMax ? d : pMax);
      }

      if (y is int) {
        yMin = (yMin == null) ? y : (y < yMin ? y : yMin);
        yMax = (yMax == null) ? y : (y > yMax ? y : yMax);
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

      priceMin = pMin ?? 0;
      priceMax = pMax ?? 0;
      yearMin = (yMin ?? 0).toDouble();
      yearMax = (yMax ?? 0).toDouble();

      if (priceMin <= priceMax) {
        selectedPrice = RangeValues(priceMin, priceMax);
      }

      if (yearMin <= yearMax) {
        selectedYear = RangeValues(yearMin, yearMax);
      }
    });
  }

  List<dynamic> _applyFilters() {
    final q = query.trim().toLowerCase();

    return carVariants.where((v) {
      final car = (v['car'] ?? {}) as Map;

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
          v['rentalPricePerDay']?.toString(),
        ].where((x) => x != null).join(' ').toString().toLowerCase();

        if (!hay.contains(q)) return false;
      }

      if (selectedBrand != null &&
          (car['brand']?.toString() ?? '') != selectedBrand) {
        return false;
      }

      if (selectedCategory != null &&
          (car['category']?.toString() ?? '') != selectedCategory) {
        return false;
      }

      if (selectedTransmission != null &&
          (car['transmission']?.toString() ?? '') != selectedTransmission) {
        return false;
      }

      if (selectedFuel != null &&
          (car['fuelType']?.toString() ?? '') != selectedFuel) {
        return false;
      }

      if (selectedSeats != null) {
        final st = car['seats'];
        if (st is! int || st != selectedSeats) return false;
      }

      if (selectedPrice != null && priceMin < priceMax) {
        final price = v['rentalPricePerDay'];
        final p = (price is num) ? price.toDouble() : null;

        if (p == null) return false;
        if (p < selectedPrice!.start || p > selectedPrice!.end) return false;
      }

      if (selectedYear != null && yearMin < yearMax) {
        final y = car['year'];

        if (y is! int) return false;

        final yy = y.toDouble();

        if (yy < selectedYear!.start || yy > selectedYear!.end) return false;
      }

      return true;
    }).toList();
  }

  // ---------------- UI helpers ----------------

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

    if (t.contains('auto')) return Icons.settings_suggest;

    return Icons.settings_outlined;
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

    if (n.contains('silver') || n.contains('grey') || n.contains('gray')) {
      return Colors.grey;
    }

    if (n.contains('gold')) return const Color(0xFFFFD700);
    if (n.contains('beige')) return const Color(0xFFF5F5DC);
    if (n.contains('brown')) return Colors.brown;

    return Colors.grey.shade600;
  }

  // ---------------- Filter sheets ----------------

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

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
          },
        );
      },
    );

    setState(() {});
  }

  Future<void> _openSeatsSheet() async {
    final opts = seatsOptions.map((e) => e.toString()).toList();

    await _openChoiceSheet(
      title: 'Number of seats',
      options: opts,
      current: selectedSeats?.toString(),
      onSelected: (val) {
        setState(() {
          selectedSeats = val == null ? null : int.tryParse(val);
        });
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

        return StatefulBuilder(
          builder: (context, setModalState) {
            String fmt(double v) {
              return formatValue != null ? formatValue(v) : v.toStringAsFixed(0);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                      onChanged: (val) {
                        setModalState(() {
                          tmp = val;
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setModalState(() {
                              tmp = RangeValues(min, max);
                            });
                          },
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
          },
        );
      },
    );

    setState(() {});
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilters();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Search',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2563EB),
                Color(0xFF60A5FA),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
                              onChanged: (v) {
                                setState(() {
                                  query = v;
                                });
                              },
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText:
                                    'Search brand, model, provider, color…',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                                  selectedPrice =
                                      RangeValues(priceMin, priceMax);
                                }

                                if (yearMax > yearMin) {
                                  selectedYear = RangeValues(yearMin, yearMax);
                                }
                              });
                            },
                            icon: const Icon(Icons.filter_alt_off_rounded),
                            label: const Text('Clear'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

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
                                onSelected: (val) {
                                  setState(() {
                                    selectedBrand = val;
                                  });
                                },
                              ),
                            ),
                            _FilterButton(
                              label: selectedCategory ?? 'Category',
                              icon: Icons.category_outlined,
                              onTap: () => _openChoiceSheet(
                                title: 'Category',
                                options: categories,
                                current: selectedCategory,
                                onSelected: (val) {
                                  setState(() {
                                    selectedCategory = val;
                                  });
                                },
                              ),
                            ),
                            _FilterButton(
                              label: (selectedPrice != null &&
                                      priceMax > priceMin)
                                  ? '${_formatMoneyFromBase(selectedPrice!.start)} - ${_formatMoneyFromBase(selectedPrice!.end)}'
                                  : 'Price range',
                              icon: Icons.price_change_outlined,
                              onTap: () {
                                if (priceMax <= priceMin) return;

                                _openRangeSheet(
                                  title: 'Price per day ($_preferredCurrency)',
                                  min: priceMin,
                                  max: priceMax,
                                  current: selectedPrice ??
                                      RangeValues(priceMin, priceMax),
                                  onApplied: (val) {
                                    setState(() {
                                      selectedPrice = val;
                                    });
                                  },
                                  formatValue: (v) => _formatMoneyFromBase(v),
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
                                  current: selectedYear ??
                                      RangeValues(yearMin, yearMax),
                                  onApplied: (val) {
                                    setState(() {
                                      selectedYear = val;
                                    });
                                  },
                                );
                              },
                            ),
                            _FilterButton(
                              label: selectedSeats != null
                                  ? '${selectedSeats!} seats'
                                  : 'No. of seats',
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
                                onSelected: (val) {
                                  setState(() {
                                    selectedTransmission = val;
                                  });
                                },
                              ),
                            ),
                            _FilterButton(
                              label: selectedFuel ?? 'Fuel type',
                              icon: Icons.ev_station,
                              onTap: () => _openChoiceSheet(
                                title: 'Fuel type',
                                options: fuels,
                                current: selectedFuel,
                                onSelected: (val) {
                                  setState(() {
                                    selectedFuel = val;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Showing ${filtered.length} cars',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final v = filtered[index];

                            final car = v['car'] ?? {};
                            final provider = v['provider'] ?? {};
                            final List images =
                                v['images'] is List ? v['images'] as List : [];

                            final brand = car['brand'] ?? 'Unknown';
                            final model = car['model'] ?? '';
                            final year = car['year']?.toString() ?? '';

                            final providerName =
                                provider['companyName'] ?? 'Provider';

                            final color = (v['color'] ?? '').toString();
                            final fuel = (car['fuelType'] ?? '').toString();
                            final transmission =
                                (car['transmission'] ?? '').toString();
                            final seats = (car['seats'] ?? '').toString();

                            final priceStr =
                                v['rentalPricePerDay']?.toString() ?? '';
                            final depositStr =
                                v['depositAmount']?.toString() ?? '';

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCarImageCarousel(images),

                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  if (providerName
                                                      .toString()
                                                      .isNotEmpty)
                                                    FramedInfo(
                                                      leading: const Icon(
                                                        Icons
                                                            .store_mall_directory,
                                                        size: 16,
                                                      ),
                                                      label: providerName,
                                                    ),
                                                  if (color.isNotEmpty)
                                                    FramedInfo(
                                                      leading: Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration:
                                                            BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color:
                                                              _colorFromName(
                                                                  color),
                                                          border: Border.all(
                                                            color:
                                                                Colors.black12,
                                                          ),
                                                        ),
                                                      ),
                                                      label: color,
                                                    ),
                                                  if (fuel.isNotEmpty)
                                                    FramedInfo(
                                                      leading: Icon(
                                                        _fuelIcon(fuel),
                                                        size: 16,
                                                      ),
                                                      label: fuel,
                                                    ),
                                                  if (transmission.isNotEmpty)
                                                    FramedInfo(
                                                      leading: Icon(
                                                        _transmissionIcon(
                                                          transmission,
                                                        ),
                                                        size: 16,
                                                      ),
                                                      label: transmission,
                                                    ),
                                                  if (seats.isNotEmpty)
                                                    FramedInfo(
                                                      leading: const Icon(
                                                        Icons.event_seat,
                                                        size: 16,
                                                      ),
                                                      label:
                                                          _seatLabel(seats),
                                                    ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(width: 8),

                                            Builder(
                                              builder: (_) {
                                                final priceNum =
                                                    num.tryParse(priceStr) ?? 0;
                                                final depositNum =
                                                    num.tryParse(depositStr) ??
                                                        0;

                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    if (priceNum > 0)
                                                      Text(
                                                        '${_formatMoneyFromBase(priceNum)}/day',
                                                        style:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    if (depositNum > 0)
                                                      const SizedBox(height: 2),
                                                    if (depositNum > 0)
                                                      Text(
                                                        'Deposit: ${_formatMoneyFromBase(depositNum)}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 8),

                                        Align(
                                          alignment: Alignment.center,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              final variantId =
                                                  (v['_id'] ?? '').toString();

                                              if (variantId.isEmpty) return;

                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      CarVariantDetails(
                                                    variantId: variantId,
                                                    userId: widget.id,
                                                  ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              elevation: 4,
                                              backgroundColor:
                                                  Colors.blueAccent,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 28,
                                                vertical: 12,
                                              ),
                                              textStyle: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
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

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class FramedInfo extends StatelessWidget {
  final Widget leading;
  final String label;

  const FramedInfo({
    super.key,
    required this.leading,
    required this.label,
  });

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
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}