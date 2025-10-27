import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CarVariantDetails extends StatefulWidget {
  final String variantId;
  final String userId;

  const CarVariantDetails({
    super.key,
    required this.variantId,
    required this.userId,
  });

  @override
  State<CarVariantDetails> createState() => _CarVariantDetailsState();
}

class _CarVariantDetailsState extends State<CarVariantDetails> {
  Map<String, dynamic>? carVariantData;
  Map<String, dynamic>? userData;
  bool isVariantLoading = true;
  bool isUserLoading = true;
  String? _variantError;
  String? _userError;
  int _imgIndex = 0;

  bool _isWishlisted = false;
  bool _wishBusy = false;

  bool get _isLoading => isVariantLoading || isUserLoading;

  @override
  void initState() {
    super.initState();
    getUserData();
    getVariantData();
    getUserWishlist(); // load saved items → ensures heart is filled if already wishlisted
  }

  // ---------------- User & Currency helpers ----------------

  Future<void> getUserData() async {
    try {
      final url = Uri.parse('http://10.0.2.2:8000/user/${widget.userId}');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          userData = data;
          isUserLoading = false;
        });
        //debugPrint("User Data: $userData");
      } else {
        throw Exception('Failed to load user');
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
      setState(() => isUserLoading = false);
      _userError = 'Failed to load user';
    }
  }

 Future<void> getUserWishlist() async {
  try {
    final uri = Uri.parse('http://10.0.2.2:8000/renter/getWishlist/${widget.userId}');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final ids = extractVariantIdsFromWishlistResponse(res.body); // works with raw JSON
      if (!mounted) return;
      setState(() => _isWishlisted = ids.contains(widget.variantId));
      // If you also need the array for anything else:
      // final List<String> idList = ids.toList(growable: false);
    } else {
      debugPrint('Wishlist load failed: ${res.statusCode} ${res.body}');
    }
  } catch (e) {
    debugPrint('Wishlist load error: $e');
  }
}


  // Normalize common shapes to Set<String> of variant ids
Set<String> extractVariantIdsFromWishlistResponse(dynamic raw) {
  final data = (raw is String) ? jsonDecode(raw) : raw;

  // Normalize to a List
  final list = data is List
      ? data
      : (data is Map && data['wishlist'] is List)
          ? data['wishlist']
          : (data is Map && data['data'] is List)
              ? data['data']
              : const [];

  // Each item is a carVariant; its ID is the top-level "_id"
  return list
      .whereType<Map>()
      .map((m) => m['_id']?.toString())
      .whereType<String>()
      .toSet();
}

  Future<void> _toggleWishlist() async {
    if (_wishBusy) return;
    setState(() => _wishBusy = true);

    try {
      final wantRemove = _isWishlisted;
      final ok = wantRemove ? await _removeFromWishlist() : await _addToWishlist();

      if (!mounted) return;
      if (ok) {
        setState(() => _isWishlisted = !_isWishlisted);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wantRemove ? 'Failed to remove from wishlist' : 'Failed to add to wishlist',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wishlist error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _wishBusy = false);
    }
  }

  Future<bool> _addToWishlist() async {
    final uri = Uri.parse(
      'http://10.0.2.2:8000/renter/addToWishlist/${widget.userId}/${widget.variantId}',
    );
    final res = await http.post(uri); // POST
    final ok = (res.statusCode >= 200 && res.statusCode < 300) || res.statusCode == 409; // already added
    if (!ok) debugPrint('ADD wishlist failed: ${res.statusCode} ${res.body}');
    return ok;
  }

  Future<bool> _removeFromWishlist() async {
    final uri = Uri.parse(
      'http://10.0.2.2:8000/renter/removeFromWishlist/${widget.userId}/${widget.variantId}',
    );
    final res = await http.post(uri); // POST
    final ok = (res.statusCode >= 200 && res.statusCode < 300) || res.statusCode == 404; // already removed
    if (!ok) debugPrint('REMOVE wishlist failed: ${res.statusCode} ${res.body}');
    return ok;
  }

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
        if (v != null && v > 0) m[k] = v;
      }
    }
    // sensible fallbacks
    m.putIfAbsent('USD', () => 50.0);
    m.putIfAbsent('EUR', () => 54.0);
    m.putIfAbsent('GBP', () => 64.0);
    m.putIfAbsent('SAR', () => 13.3);
    m.putIfAbsent('AED', () => 13.6);
    return m;
  }

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

  // Convert amount stored in **AED** → preferred currency.
  // fx map is "EGP per 1 unit". Cross-rate:
  // value_in_target = amount_in_AED * (EGP_per_AED / EGP_per_target)
  String _formatMoneyFromAED(num aedAmount, {String? to}) {
    final code = (to ?? _preferredCurrency).toUpperCase();

    final egpPer = _egpPerUnit;                // EGP per 1 unit
    final egpPerAED = egpPer['AED'] ?? 13.6;   // fallback if backend didn't send
    final egpPerTarget = egpPer[code] ?? 1.0;

    final double value =
        (code == 'AED') ? aedAmount.toDouble() : aedAmount.toDouble() * (egpPerAED / egpPerTarget);

    final sym = _currencySymbol(code);
    final s = NumberFormat.decimalPattern().format(value.round());
    return '$sym $s';
  }

  // ---------------- Variant fetch ----------------

  Future<void> getVariantData() async {
    try {
      final url = Uri.parse('http://10.0.2.2:8000/carVariant/${widget.variantId}');
      final response = await http.get(url);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          carVariantData = data;
          isVariantLoading = false;
        });
        //debugPrint("Car Variant Data: $carVariantData"); // fixed: was printing userData
      } else {
        throw Exception('Failed to load Car Variant');
      }
    } catch (e) {
      debugPrint('Error fetching Car Variant: $e');
      setState(() => isVariantLoading = false);
      _variantError = 'Failed to load car variant';
    }
  }

  // ---------------- UI helpers ----------------

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

  String _seatLabel(dynamic value) {
    final s = (value ?? '').toString();
    final n = int.tryParse(s);
    if (n == null) return s.isEmpty ? '' : '$s seats';
    return n == 1 ? '1 seat' : '$n seats';
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : (_variantError != null)
            ? _ErrorView(message: _variantError!, onRetry: getVariantData)
            : _DetailsView(
                variant: carVariantData!,
                imgIndex: _imgIndex,
                onImgChanged: (i) => setState(() => _imgIndex = i), // ← updates dots
                money: _formatMoneyFromAED,
                colorFromName: _colorFromName,
                fuelIcon: _fuelIcon,
                transmissionIcon: _transmissionIcon,
                seatLabel: _seatLabel,
                onBookNow: () {},
                onContact: () {},
                isWishlisted: _isWishlisted,
                wishBusy: _wishBusy,
                onToggleWishlist: _toggleWishlist,
              );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Car details'),
      ),
      body: body,
    );
  }
}

// ------------------ PRESENTATION WIDGET ------------------

class _DetailsView extends StatelessWidget {
  final Map<String, dynamic> variant;
  final int imgIndex;
  final ValueChanged<int> onImgChanged;

  final String Function(num aed, {String? to}) money;
  final Color Function(String name) colorFromName;
  final IconData Function(String fuel) fuelIcon;
  final IconData Function(String tr) transmissionIcon;
  final String Function(dynamic seats) seatLabel;

  final bool isWishlisted;
  final bool wishBusy;
  final VoidCallback onToggleWishlist;

  final VoidCallback onBookNow;
  final VoidCallback onContact;

  const _DetailsView({
    required this.variant,
    required this.imgIndex,
    required this.onImgChanged,
    required this.money,
    required this.colorFromName,
    required this.fuelIcon,
    required this.transmissionIcon,
    required this.seatLabel,
    required this.onBookNow,
    required this.onContact,
    required this.isWishlisted,
    required this.wishBusy,
    required this.onToggleWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final car = (variant['car'] ?? {}) as Map;
    final provider = (variant['provider'] ?? {}) as Map;
    final List images = (variant['images'] ?? []) as List;

    final brand = (car['brand'] ?? '').toString();
    final model = (car['model'] ?? '').toString();
    final year = (car['year'] ?? '').toString();
    final title = [brand, model, year].where((e) => e.toString().trim().isNotEmpty).join(' ');

    final color = (variant['color'] ?? '').toString();
    final fuel = (car['fuelType'] ?? '').toString();
    final transmission = (car['transmission'] ?? '').toString();
    final seats = (car['seats'] ?? '').toString();
    final category = (car['category'] ?? '').toString();

    final providerName = (provider['companyName'] ?? 'Provider').toString();
    final providerPhone = (provider['phone'] ?? provider['mobile'] ?? '').toString();
    final providerCity = (provider['city'] ?? '').toString();

    final priceNum = (variant['rentalPricePerDay'] is num) ? (variant['rentalPricePerDay'] as num) : 0;
    final depositNum = (variant['depositAmount'] is num) ? (variant['depositAmount'] as num) : 0;
    final description = (variant['description'] ?? car['description'] ?? '').toString();

    return CustomScrollView(
      slivers: [
        // Image header without an AppBar
        SliverToBoxAdapter(
          child: SizedBox(
            height: 320,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.bottomCenter,
              children: [
                PageView.builder(
                  itemCount: images.isEmpty ? 1 : images.length,
                  onPageChanged: onImgChanged, // ← keep dots in sync
                  itemBuilder: (context, i) {
                    if (images.isEmpty) {
                      return Center(
                        child: SizedBox(
                          width: 410,
                          height: 280,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.directions_car_filled_outlined, size: 48),
                            ),
                          ),
                        ),
                      );
                    }
                    final src = images[i]?['filepath'] ?? '';
                    return Center(
                      child: SizedBox(
                        width: 410, // exact width
                        height: 280, // exact height
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            src,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.directions_car_filled_outlined, size: 48),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // dots
                if (images.length > 1)
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: imgIndex == i ? 10 : 6,
                          height: imgIndex == i ? 10 : 6,
                          decoration: BoxDecoration(
                            color: imgIndex == i ? Colors.white : Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Heart overlay (top-right of the image header)
                Positioned(
                  top: 20,
                  right: 12,
                  child: Material(
                    color: Colors.black45,
                    shape: const CircleBorder(),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: wishBusy
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            )
                          : IconButton(
                              onPressed: onToggleWishlist,
                              icon: Icon(
                                isWishlisted ? Icons.favorite : Icons.favorite_border,
                                color: isWishlisted ? Colors.redAccent : Colors.white,
                              ),
                              tooltip: isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // title + price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'Car details' : title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (priceNum > 0)
                          Text(
                            '${money(priceNum)}/day',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        if (depositNum > 0) const SizedBox(height: 2),
                        if (depositNum > 0)
                          Text(
                            'Deposit: ${money(depositNum)}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // spec chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (providerName.isNotEmpty)
                      _SpecChip(icon: Icons.store_mall_directory, label: providerName),
                    if (category.isNotEmpty) _SpecChip(icon: Icons.category_outlined, label: category),
                    if (color.isNotEmpty) _ColorChip(colorName: color, color: colorFromName(color)),
                    if (fuel.isNotEmpty) _SpecChip(icon: fuelIcon(fuel), label: fuel),
                    if (transmission.isNotEmpty)
                      _SpecChip(icon: transmissionIcon(transmission), label: transmission),
                    if (seats.isNotEmpty) _SpecChip(icon: Icons.event_seat, label: seatLabel(seats)),
                    if (year.isNotEmpty) _SpecChip(icon: Icons.calendar_month_outlined, label: 'Model $year'),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),

                const SizedBox(height: 16),
                const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  description.isEmpty ? 'No description provided.' : description,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),

                const SizedBox(height: 16),
                const Text('Provider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.store, title: 'Name', value: providerName),
                if (providerCity.isNotEmpty) _InfoRow(icon: Icons.location_on_outlined, title: 'City', value: providerCity),
                if (providerPhone.isNotEmpty) _InfoRow(icon: Icons.call, title: 'Phone', value: providerPhone),

                const SizedBox(height: 16),
                const Divider(height: 1),

                const SizedBox(height: 16),
                const Text('Rental details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const _Bullet(text: 'Daily price includes standard mileage unless stated otherwise.'),
                const _Bullet(text: 'Refundable deposit required on pickup.'),
                const _Bullet(text: 'Valid ID and driving license are required.'),
                const _Bullet(text: 'Fuel policy as per provider terms.'),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onBookNow,
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Book now'),
                      style: ElevatedButton.styleFrom(
                        elevation: 3,
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: onContact,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Icon(Icons.chat_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- small UI atoms ----------

class _SpecChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SpecChip({required this.icon, required this.label});

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
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String colorName;
  final Color color;
  const _ColorChip({required this.colorName, required this.color});

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
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.black12),
            ),
          ),
          const SizedBox(width: 6),
          Text(colorName, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 10),
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  '),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
