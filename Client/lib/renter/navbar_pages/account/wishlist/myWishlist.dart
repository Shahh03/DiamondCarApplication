import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../api/renter_api.dart';
import 'bookCarVariant.dart';

class WishlistPage extends StatefulWidget {
  final String renterId;

  const WishlistPage({super.key, required this.renterId});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  List<dynamic> wishlist = [];
  Map<String, dynamic>? userData;

  bool isWishlistLoading = true;
  bool isUserLoading = true;
  bool hasError = false;

  bool get isLoading => isWishlistLoading || isUserLoading;

  @override
  void initState() {
    super.initState();
    _getUser();
    _fetchWishlist();
  }

  // ---------------- Data fetch ----------------

  Future<void> _getUser() async {
    try {
      final data = await RenterApi.getUserById(widget.renterId);

      if (!mounted) return;

      setState(() {
        userData = data;
        isUserLoading = false;
      });
    } catch (e) {
      debugPrint('User error: $e');

      if (!mounted) return;

      setState(() {
        isUserLoading = false;
      });
    }
  }

  Future<void> _fetchWishlist() async {
    try {
      final data = await RenterApi.getWishlist(widget.renterId);

      if (!mounted) return;

      setState(() {
        wishlist = data;
        isWishlistLoading = false;
        hasError = false;
      });
    } catch (e) {
      debugPrint('Wishlist error: $e');

      if (!mounted) return;

      setState(() {
        hasError = true;
        isWishlistLoading = false;
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

    // Extra fallback if some old API used url instead
    if (image is Map && image['url'] != null) {
      return image['url'].toString();
    }

    return '';
  }

  // ---------------- Wishlist actions ----------------

  Future<void> _removeFromWishlist(String carVariantId) async {
    try {
      final ok = await RenterApi.removeFromWishlist(
        widget.renterId,
        carVariantId,
      );

      if (!mounted) return;

      if (ok) {
        setState(() {
          wishlist.removeWhere(
            (e) => (e['_id']?.toString() ?? '') == carVariantId,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from wishlist'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to remove from wishlist');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _showConfirmationDialog(String carVariantId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Remove from Wishlist?',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove this car from your wishlist?',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _removeFromWishlist(carVariantId);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('Yes'),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              backgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('No'),
            ),
          ),
        ],
      ),
    );
  }

  void _bookCar(String carVariantId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RenterBookCarVariantPage(
          renterId: widget.renterId,
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

  String _moneyFromAED(num aedAmount, {String? to}) {
    final code = (to ?? _preferredCurrency).toUpperCase();

    final egpPerAED = _egpPerUnit['AED'] ?? 13.6;
    final egpPerTarget = _egpPerUnit[code] ?? 1.0;

    final double value = code == 'AED'
        ? aedAmount.toDouble()
        : aedAmount.toDouble() * (egpPerAED / egpPerTarget);

    final sym = _currencySymbol(code);
    final s = NumberFormat.decimalPattern().format(value.round());

    return '$sym $s';
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
    if (n.contains('silver') || n.contains('grey') || n.contains('gray')) {
      return Colors.grey;
    }
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

  Widget _emptyCarImagePlaceholder() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 400,
          height: 230,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(
              Icons.directions_car_filled_outlined,
              size: 48,
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
          height: 230,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 400,
              height: 230,
              color: Colors.grey[300],
              child: const Icon(
                Icons.image_not_supported,
                size: 50,
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageHeader(List images, String variantId) {
    return SizedBox(
      height: 230,
      child: Stack(
        children: [
          ListView.builder(
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

          Positioned(
            top: 14,
            right: 12,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  onPressed: () => _showConfirmationDialog(variantId),
                  icon: const Icon(
                    Icons.favorite,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Remove from wishlist',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Wishlist"),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? const Center(child: Text("Error loading wishlist"))
              : wishlist.isEmpty
                  ? const Center(child: Text("Your wishlist is empty."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: wishlist.length,
                      itemBuilder: (context, index) {
                        final item = wishlist[index];

                        final car = (item['car'] ?? {}) as Map;
                        final List images = item['images'] ?? [];

                        final variantId = (item['_id'] ?? '').toString();

                        final brand = (car['brand'] ?? '').toString();
                        final model = (car['model'] ?? '').toString();
                        final year = (car['year'] ?? '').toString();

                        final title = [brand, model, year]
                            .where((e) => e.toString().trim().isNotEmpty)
                            .join(' ');

                        final colorName = (item['color'] ?? '').toString();
                        final fuel = (car['fuelType'] ?? '').toString();
                        final transmission =
                            (car['transmission'] ?? '').toString();
                        final seats = (car['seats'] ?? '').toString();
                        final category = (car['category'] ?? '').toString();

                        final price = item['rentalPricePerDay'] is num
                            ? item['rentalPricePerDay'] as num
                            : 0;

                        final deposit = item['depositAmount'] is num
                            ? item['depositAmount'] as num
                            : 0;

                        final available = item['isAvailable'] == true;

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildImageHeader(images, variantId),

                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title.isEmpty
                                                ? 'Car details'
                                                : title,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            if (price > 0)
                                              Text(
                                                '${_moneyFromAED(price)}/day',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            if (deposit > 0)
                                              const SizedBox(height: 2),
                                            if (deposit > 0)
                                              Text(
                                                'Deposit: ${_moneyFromAED(deposit)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),

                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (category.isNotEmpty)
                                          _SpecChip(
                                            icon: Icons.category_outlined,
                                            label: category,
                                          ),
                                        if (colorName.isNotEmpty)
                                          _ColorChip(
                                            colorName: colorName,
                                            color: _colorFromName(colorName),
                                          ),
                                        if (fuel.isNotEmpty)
                                          _SpecChip(
                                            icon: _fuelIcon(fuel),
                                            label: fuel,
                                          ),
                                        if (transmission.isNotEmpty)
                                          _SpecChip(
                                            icon: _transmissionIcon(
                                              transmission,
                                            ),
                                            label: transmission,
                                          ),
                                        if (seats.isNotEmpty)
                                          _SpecChip(
                                            icon: Icons.event_seat,
                                            label: _seatLabel(seats),
                                          ),
                                        if (year.isNotEmpty)
                                          _SpecChip(
                                            icon:
                                                Icons.calendar_month_outlined,
                                            label: 'Model $year',
                                          ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: available
                                            ? Colors.green[100]
                                            : Colors.red[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        available
                                            ? "Available"
                                            : "Not Available",
                                        style: TextStyle(
                                          color: available
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (available)
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _bookCar(variantId),
                                            style: ElevatedButton.styleFrom(
                                              elevation: 3,
                                              backgroundColor:
                                                  Colors.blueAccent,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.calendar_month,
                                            ),
                                            label: const Text(
                                              "Book Now",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),

                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _showConfirmationDialog(
                                            variantId,
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: Colors.redAccent,
                                              width: 1.5,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          label: const Text(
                                            "Remove",
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

// ---------- UI atoms ----------

class _SpecChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SpecChip({
    required this.icon,
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
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String colorName;
  final Color color;

  const _ColorChip({
    required this.colorName,
    required this.color,
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
          Text(
            colorName,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}