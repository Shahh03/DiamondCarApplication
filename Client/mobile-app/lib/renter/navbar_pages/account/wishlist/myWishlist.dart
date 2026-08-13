import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../api/renter_api.dart';
import 'bookCarVariant.dart';

const _primary = Color(0xFF1D4ED8);
const _primaryDark = Color(0xFF1E40AF);
const _surface = Color(0xFFF5F7FB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class WishlistPage extends StatefulWidget {
  final String renterId;

  const WishlistPage({super.key, required this.renterId});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  List<dynamic> _wishlist = [];
  Map<String, dynamic>? _userData;
  final Set<String> _removingIds = {};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPage();
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
        RenterApi.getUserById(widget.renterId),
        RenterApi.getWishlist(widget.renterId),
      ]);

      if (!mounted) return;
      setState(() {
        _userData = results[0] is Map
            ? Map<String, dynamic>.from(results[0] as Map)
            : null;
        _wishlist = results[1] is List ? List<dynamic>.from(results[1]) : [];
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Wishlist load error: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load your wishlist. Please try again.';
      });
    }
  }

  Future<void> _removeFromWishlist(String carVariantId) async {
    if (carVariantId.isEmpty || _removingIds.contains(carVariantId)) return;

    setState(() => _removingIds.add(carVariantId));
    try {
      final ok = await RenterApi.removeFromWishlist(
        widget.renterId,
        carVariantId,
      );
      if (!mounted) return;

      if (!ok) throw Exception('The car could not be removed.');

      setState(() {
        _wishlist.removeWhere(
          (item) => item is Map && item['_id']?.toString() == carVariantId,
        );
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Car removed from your wishlist'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF166534),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Could not remove this car. Try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFB91C1C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _removingIds.remove(carVariantId));
    }
  }

  Future<void> _confirmRemoval(String carVariantId, String carName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.heart_broken_outlined,
                  color: Color(0xFFDC2626)),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Remove this car?',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          carName.isEmpty
              ? 'This car will be removed from your saved vehicles.'
              : '$carName will be removed from your saved vehicles.',
          style: const TextStyle(color: _muted, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: _ink,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
            child: const Text('Keep car',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Remove',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) await _removeFromWishlist(carVariantId);
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

  String _moneyFromAED(num amount, {String? to}) {
    final code = (to ?? _preferredCurrency).toUpperCase();
    final egpPerAED = _egpPerUnit['AED'] ?? 13.6;
    final egpPerTarget = _egpPerUnit[code] ?? 1.0;
    final value = code == 'AED'
        ? amount.toDouble()
        : amount.toDouble() * (egpPerAED / egpPerTarget);
    return '${_currencySymbol(code)} ${NumberFormat.decimalPattern().format(value.round())}';
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
        value.contains('gray')) {
      return Colors.grey;
    }
    if (value.contains('gold')) return const Color(0xFFFFD700);
    if (value.contains('beige')) return const Color(0xFFF5F5DC);
    if (value.contains('brown')) return Colors.brown;
    return Colors.grey.shade600;
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

  String _seatLabel(dynamic value) {
    final text = (value ?? '').toString();
    final number = int.tryParse(text);
    if (number == null) return text.isEmpty ? '' : '$text seats';
    return number == 1 ? '1 seat' : '$number seats';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _WishlistHeader(
            itemCount: _wishlist.length,
            onBack: () => Navigator.maybePop(context),
            onRefresh: _isLoading ? null : _loadPage,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _WishlistLoading();
    if (_errorMessage != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        iconColor: const Color(0xFFDC2626),
        title: 'Something went wrong',
        message: _errorMessage!,
        buttonLabel: 'Try again',
        onPressed: _loadPage,
      );
    }
    if (_wishlist.isEmpty) {
      return _MessageState(
        icon: Icons.favorite_border_rounded,
        iconColor: _primary,
        title: 'Your wishlist is waiting',
        message:
            'Save the cars you love and compare them here when you are ready to book.',
        buttonLabel: 'Refresh wishlist',
        onPressed: _loadPage,
      );
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadPage,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        itemCount: _wishlist.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _WishlistSummary(count: _wishlist.length),
                ),
              ),
            );
          }

          final item = _asMap(_wishlist[index - 1]);
          final car = _asMap(item['car']);
          final images = item['images'] is List
              ? List<dynamic>.from(item['images'] as List)
              : <dynamic>[];
          final variantId = (item['_id'] ?? '').toString();
          final brand = (car['brand'] ?? '').toString().trim();
          final model = (car['model'] ?? '').toString().trim();
          final year = (car['year'] ?? '').toString().trim();
          final title = [brand, model]
              .where((part) => part.isNotEmpty)
              .join(' ');
          final color = (item['color'] ?? '').toString();
          final fuel = (car['fuelType'] ?? '').toString();
          final transmission = (car['transmission'] ?? '').toString();
          final seats = (car['seats'] ?? '').toString();
          final category = (car['category'] ?? '').toString();
          final price = item['rentalPricePerDay'] is num
              ? item['rentalPricePerDay'] as num
              : num.tryParse(item['rentalPricePerDay']?.toString() ?? '') ?? 0;
          final deposit = item['depositAmount'] is num
              ? item['depositAmount'] as num
              : num.tryParse(item['depositAmount']?.toString() ?? '') ?? 0;
          final available = item['isAvailable'] == true;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _WishlistCarCard(
                  key: ValueKey(variantId),
                  title: title.isEmpty ? 'Car details' : title,
                  year: year,
                  images: images,
                  imageUrl: _imageUrl,
                  price: price > 0 ? _moneyFromAED(price) : null,
                  deposit: deposit > 0 ? _moneyFromAED(deposit) : null,
                  available: available,
                  isRemoving: _removingIds.contains(variantId),
                  specs: [
                    if (category.isNotEmpty)
                      _CarSpec(Icons.category_outlined, category),
                    if (color.isNotEmpty)
                      _CarSpec(Icons.circle, color,
                          accent: _colorFromName(color)),
                    if (fuel.isNotEmpty) _CarSpec(_fuelIcon(fuel), fuel),
                    if (transmission.isNotEmpty)
                      _CarSpec(_transmissionIcon(transmission), transmission),
                    if (seats.isNotEmpty)
                      _CarSpec(Icons.airline_seat_recline_normal_rounded,
                          _seatLabel(seats)),
                  ],
                  onBook: available ? () => _bookCar(variantId) : null,
                  onRemove: variantId.isEmpty
                      ? null
                      : () => _confirmRemoval(
                            variantId,
                            title.isEmpty ? 'This car' : title,
                          ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WishlistHeader extends StatelessWidget {
  final int itemCount;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;

  const _WishlistHeader({
    required this.itemCount,
    required this.onBack,
    required this.onRefresh,
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
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 22),
          child: Row(
            children: [
              _HeaderButton(icon: Icons.arrow_back_rounded, onTap: onBack),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Wishlist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      itemCount == 0
                          ? 'Your saved cars'
                          : '$itemCount saved ${itemCount == 1 ? 'car' : 'cars'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderButton(
                icon: Icons.refresh_rounded,
                onTap: onRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
        fixedSize: const Size(44, 44),
      ),
    );
  }
}

class _WishlistSummary extends StatelessWidget {
  final int count;

  const _WishlistSummary({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: _primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'vehicle' : 'vehicles'} ready to compare and book',
              style: const TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.swipe_rounded, color: _primary, size: 19),
        ],
      ),
    );
  }
}

class _WishlistCarCard extends StatelessWidget {
  final String title;
  final String year;
  final List<dynamic> images;
  final String Function(dynamic) imageUrl;
  final String? price;
  final String? deposit;
  final bool available;
  final bool isRemoving;
  final List<_CarSpec> specs;
  final VoidCallback? onBook;
  final VoidCallback? onRemove;

  const _WishlistCarCard({
    super.key,
    required this.title,
    required this.year,
    required this.images,
    required this.imageUrl,
    required this.price,
    required this.deposit,
    required this.available,
    required this.isRemoving,
    required this.specs,
    required this.onBook,
    required this.onRemove,
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
          _CarGallery(
            images: images,
            imageUrl: imageUrl,
            available: available,
            isRemoving: isRemoving,
            onRemove: onRemove,
          ),
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
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                          if (year.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              'Model year $year',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
                              letterSpacing: -0.25,
                            ),
                          ),
                          const Text(
                            'per day',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11,
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
                    children: specs.map((spec) => _SpecPill(spec: spec)).toList(),
                  ),
                ],
                if (deposit != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 19, color: _muted),
                        const SizedBox(width: 9),
                        const Text(
                          'Refundable deposit',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          deposit!,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onBook,
                    icon: Icon(
                      available
                          ? Icons.calendar_month_rounded
                          : Icons.event_busy_outlined,
                      size: 20,
                    ),
                    label: Text(available ? 'Book this car' : 'Currently unavailable'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: _muted,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 15,
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
  final bool available;
  final bool isRemoving;
  final VoidCallback? onRemove;

  const _CarGallery({
    required this.images,
    required this.imageUrl,
    required this.available,
    required this.isRemoving,
    required this.onRemove,
  });

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
    final validImages = widget.images
        .map(widget.imageUrl)
        .where((url) => url.trim().isNotEmpty)
        .toList();
    final count = validImages.isEmpty ? 1 : validImages.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            (constraints.maxWidth * 0.62).clamp(225.0, 320.0).toDouble();
        return SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: count,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) {
                  if (validImages.isEmpty) return const _ImagePlaceholder();
                  return Image.network(
                    validImages[index],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const _ImagePlaceholder(showLoader: true);
                    },
                    errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                  );
                },
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color(0x99000000)],
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        stops: [0.52, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: _AvailabilityBadge(available: widget.available),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: Material(
                  color: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.isRemoving ? null : widget.onRemove,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: widget.isRemoving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: Color(0xFFDC2626),
                                ),
                              )
                            : const Icon(
                                Icons.favorite_rounded,
                                color: Color(0xFFDC2626),
                                size: 23,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              if (validImages.length > 1)
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_outlined,
                            color: Colors.white, size: 15),
                        const SizedBox(width: 5),
                        Text(
                          '${_page + 1}/${validImages.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (validImages.length > 1)
                Positioned(
                  left: 16,
                  bottom: 19,
                  child: Row(
                    children: List.generate(
                      validImages.length > 7 ? 7 : validImages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: index == _page ? 20 : 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: index == _page
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.48),
                          borderRadius: BorderRadius.circular(10),
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

class _AvailabilityBadge extends StatelessWidget {
  final bool available;

  const _AvailabilityBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    final color = available ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            available ? 'Available' : 'Unavailable',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car_filled_outlined,
                      size: 52, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text('Image unavailable',
                      style: TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
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
            size: spec.icon == Icons.circle ? 13 : 16,
            color: spec.accent ?? _primary,
          ),
          const SizedBox(width: 6),
          Text(
            spec.label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _MessageState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 38),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                      label: Text(buttonLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WishlistLoading extends StatelessWidget {
  const _WishlistLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
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
                  height: 230,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8EDF5),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonLine(width: index == 0 ? 210 : 165, height: 20),
                      const SizedBox(height: 12),
                      const _SkeletonLine(width: 115, height: 12),
                      const SizedBox(height: 22),
                      const _SkeletonLine(width: double.infinity, height: 48),
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

class _SkeletonLine extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF5),
        borderRadius: BorderRadius.circular(9),
      ),
    );
  }
}
