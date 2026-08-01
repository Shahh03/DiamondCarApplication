import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/activity_api.dart';
import '../../api/car_variant_api.dart';
import '../../api/renter_api.dart';

const _primary = Color(0xFF1D4ED8);
const _primaryDark = Color(0xFF1E40AF);
const _background = Color(0xFFF5F7FB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

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
  Map<String, dynamic>? _variant;
  Map<String, dynamic>? _userData;

  bool _isLoading = true;
  bool _isWishlisted = false;
  bool _wishBusy = false;
  bool _viewTracked = false;
  String? _errorMessage;
  int _imageIndex = 0;

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
        CarVariantApi.getCarVariantById(widget.variantId),
        _getUserSafely(),
        _getWishlistSafely(),
      ]);
      if (!mounted) return;

      setState(() {
        _variant = results[0] is Map
            ? Map<String, dynamic>.from(results[0] as Map)
            : <String, dynamic>{};
        _userData = results[1] is Map
            ? Map<String, dynamic>.from(results[1] as Map)
            : null;
        final wishlistIds = results[2] is List
            ? List<dynamic>.from(results[2] as List)
            : <dynamic>[];
        _isWishlisted = wishlistIds
            .map((id) => id.toString())
            .contains(widget.variantId);
        _imageIndex = 0;
        _isLoading = false;
      });

      unawaited(_trackViewOnce());
    } catch (error) {
      debugPrint('Car details load error: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load this car. Please try again.';
      });
    }
  }

  Future<void> _trackViewOnce() async {
    if (_viewTracked ||
        widget.userId.trim().isEmpty ||
        widget.variantId.trim().isEmpty) {
      return;
    }

    _viewTracked = true;

    try {
      await ActivityApi.trackView(
        renterId: widget.userId,
        carVariantId: widget.variantId,
      );
    } catch (error) {
      _viewTracked = false;
      debugPrint('Car view tracking error: $error');
    }
  }

  Future<dynamic> _getUserSafely() async {
    try {
      return await RenterApi.getUserById(widget.userId);
    } catch (error) {
      debugPrint('User load error: $error');
      return null;
    }
  }

  Future<List<dynamic>> _getWishlistSafely() async {
    try {
      final result = await RenterApi.getWishlistVariantIds(widget.userId);
      return result is List ? List<dynamic>.from(result) : <dynamic>[];
    } catch (error) {
      debugPrint('Wishlist load error: $error');
      return <dynamic>[];
    }
  }

  Future<void> _toggleWishlist() async {
    if (_wishBusy) return;
    setState(() => _wishBusy = true);

    try {
      final wasWishlisted = _isWishlisted;
      final success = wasWishlisted
          ? await RenterApi.removeFromWishlist(widget.userId, widget.variantId)
          : await RenterApi.addToWishlist(widget.userId, widget.variantId);
      if (!mounted) return;

      if (!success) throw Exception('Wishlist update failed');
      setState(() => _isWishlisted = !wasWishlisted);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              wasWishlisted
                  ? 'Removed from your wishlist'
                  : 'Saved to your wishlist',
            ),
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
            content: const Text('Could not update your wishlist. Try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFB91C1C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _wishBusy = false);
    }
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

  String _formatMoneyFromAED(num amount, {String? to}) {
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
        value.contains('gray')) return Colors.grey;
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
    final number = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    if (number == null) return value?.toString() ?? '';
    return number == 1 ? '1 seat' : '$number seats';
  }

  void _bookNow() {
    // Keep this callback ready for the project's booking route.
  }

  @override
  Widget build(BuildContext context) {
    final available = _variant?['isAvailable'] != false;
    final price = _variant?['rentalPricePerDay'] is num
        ? _variant!['rentalPricePerDay'] as num
        : num.tryParse(_variant?['rentalPricePerDay']?.toString() ?? '') ?? 0;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: const Text(
          'Car details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              tooltip: 'Refresh car details',
              onPressed: _loadPage,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryDark, Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const _DetailsLoadingState()
          : _errorMessage != null
              ? _DetailsErrorState(
                  message: _errorMessage!,
                  onRetry: _loadPage,
                )
              : _CarDetailsContent(
                  variant: _variant ?? <String, dynamic>{},
                  imageIndex: _imageIndex,
                  onImageChanged: (index) =>
                      setState(() => _imageIndex = index),
                  imageUrl: _imageUrl,
                  money: _formatMoneyFromAED,
                  colorFromName: _colorFromName,
                  fuelIcon: _fuelIcon,
                  transmissionIcon: _transmissionIcon,
                  seatLabel: _seatLabel,
                  isWishlisted: _isWishlisted,
                  wishBusy: _wishBusy,
                  onToggleWishlist: _toggleWishlist,
                  onRefresh: _loadPage,
                ),
      bottomNavigationBar: !_isLoading && _errorMessage == null
          ? _BookingBar(
              price: price > 0 ? _formatMoneyFromAED(price) : null,
              available: available,
              onBook: available ? _bookNow : null,
            )
          : null,
    );
  }
}

class _CarDetailsContent extends StatelessWidget {
  final Map<String, dynamic> variant;
  final int imageIndex;
  final ValueChanged<int> onImageChanged;
  final String Function(dynamic) imageUrl;
  final String Function(num amount, {String? to}) money;
  final Color Function(String name) colorFromName;
  final IconData Function(String fuel) fuelIcon;
  final IconData Function(String transmission) transmissionIcon;
  final String Function(dynamic seats) seatLabel;
  final bool isWishlisted;
  final bool wishBusy;
  final VoidCallback onToggleWishlist;
  final Future<void> Function() onRefresh;

  const _CarDetailsContent({
    required this.variant,
    required this.imageIndex,
    required this.onImageChanged,
    required this.imageUrl,
    required this.money,
    required this.colorFromName,
    required this.fuelIcon,
    required this.transmissionIcon,
    required this.seatLabel,
    required this.isWishlisted,
    required this.wishBusy,
    required this.onToggleWishlist,
    required this.onRefresh,
  });

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final car = _asMap(variant['car']);
    final provider = _asMap(variant['provider']);
    final images = variant['images'] is List
        ? List<dynamic>.from(variant['images'] as List)
        : <dynamic>[];
    final validImages = images
        .map(imageUrl)
        .where((url) => url.trim().isNotEmpty)
        .toList();

    final brand = (car['brand'] ?? '').toString().trim();
    final model = (car['model'] ?? '').toString().trim();
    final year = (car['year'] ?? '').toString().trim();
    final title = [brand, model]
        .where((part) => part.isNotEmpty)
        .join(' ');
    final color = (variant['color'] ?? '').toString();
    final fuel = (car['fuelType'] ?? '').toString();
    final transmission = (car['transmission'] ?? '').toString();
    final seats = (car['seats'] ?? '').toString();
    final category = (car['category'] ?? '').toString();
    final providerName =
        (provider['companyName'] ?? 'Provider').toString();
    final providerPhone =
        (provider['phone'] ?? provider['mobile'] ?? '').toString();
    final providerCity = (provider['city'] ?? '').toString();
    final price = variant['rentalPricePerDay'] is num
        ? variant['rentalPricePerDay'] as num
        : num.tryParse(variant['rentalPricePerDay']?.toString() ?? '') ?? 0;
    final deposit = variant['depositAmount'] is num
        ? variant['depositAmount'] as num
        : num.tryParse(variant['depositAmount']?.toString() ?? '') ?? 0;
    final description =
        (variant['description'] ?? car['description'] ?? '').toString().trim();
    final available = variant['isAvailable'] != false;
    final features = car['features'] is List
        ? List<dynamic>.from(car['features'] as List)
            .map((feature) => feature.toString().trim())
            .where((feature) => feature.isNotEmpty)
            .toList()
        : <String>[];

    return _BookingStyleDetails(
      images: validImages,
      imageIndex: imageIndex,
      onImageChanged: onImageChanged,
      title: title.isEmpty ? 'Car details' : title,
      year: year,
      providerName: providerName,
      providerCity: providerCity,
      providerPhone: providerPhone,
      available: available,
      price: price > 0 ? money(price) : null,
      deposit: deposit > 0 ? money(deposit) : null,
      category: category,
      color: color,
      colorValue: color.isEmpty ? null : colorFromName(color),
      fuel: fuel,
      fuelIcon: fuel.isEmpty ? null : fuelIcon(fuel),
      transmission: transmission,
      transmissionIcon:
          transmission.isEmpty ? null : transmissionIcon(transmission),
      seats: seats.isEmpty ? '' : seatLabel(seats),
      description: description,
      features: features,
      isWishlisted: isWishlisted,
      wishBusy: wishBusy,
      onToggleWishlist: onToggleWishlist,
      onRefresh: onRefresh,
    );
  }
}

class _BookingStyleDetails extends StatelessWidget {
  final List<String> images;
  final int imageIndex;
  final ValueChanged<int> onImageChanged;
  final String title;
  final String year;
  final String providerName;
  final String providerCity;
  final String providerPhone;
  final bool available;
  final String? price;
  final String? deposit;
  final String category;
  final String color;
  final Color? colorValue;
  final String fuel;
  final IconData? fuelIcon;
  final String transmission;
  final IconData? transmissionIcon;
  final String seats;
  final String description;
  final List<String> features;
  final bool isWishlisted;
  final bool wishBusy;
  final VoidCallback onToggleWishlist;
  final Future<void> Function() onRefresh;

  const _BookingStyleDetails({
    required this.images,
    required this.imageIndex,
    required this.onImageChanged,
    required this.title,
    required this.year,
    required this.providerName,
    required this.providerCity,
    required this.providerPhone,
    required this.available,
    required this.price,
    required this.deposit,
    required this.category,
    required this.color,
    required this.colorValue,
    required this.fuel,
    required this.fuelIcon,
    required this.transmission,
    required this.transmissionIcon,
    required this.seats,
    required this.description,
    required this.features,
    required this.isWishlisted,
    required this.wishBusy,
    required this.onToggleWishlist,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _primary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 800 ? 28.0 : 16.0;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              32,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BookingGalleryCard(
                        images: images,
                        imageIndex: imageIndex,
                        onImageChanged: onImageChanged,
                        available: available,
                        isWishlisted: isWishlisted,
                        wishBusy: wishBusy,
                        onToggleWishlist: onToggleWishlist,
                      ),
                      const SizedBox(height: 18),
                      _CarSummaryCard(
                        title: title,
                        year: year,
                        provider: providerName,
                        city: providerCity,
                        available: available,
                        price: price,
                      ),
                      const SizedBox(height: 18),
                      _BookingDetailsSection(
                        icon: Icons.directions_car_outlined,
                        title: 'Vehicle specifications',
                        child: _BookingSpecsGrid(
                          specs: [
                            if (category.isNotEmpty)
                              _BookingSpecData(
                                Icons.category_outlined,
                                'Category',
                                category,
                              ),
                            if (color.isNotEmpty)
                              _BookingSpecData(
                                Icons.circle,
                                'Color',
                                color,
                                iconColor: colorValue,
                              ),
                            if (fuel.isNotEmpty)
                              _BookingSpecData(
                                fuelIcon ?? Icons.local_gas_station_outlined,
                                'Fuel',
                                fuel,
                              ),
                            if (transmission.isNotEmpty)
                              _BookingSpecData(
                                transmissionIcon ?? Icons.settings_outlined,
                                'Transmission',
                                transmission,
                              ),
                            if (seats.isNotEmpty)
                              _BookingSpecData(
                                Icons.airline_seat_recline_normal_rounded,
                                'Capacity',
                                seats,
                              ),
                          ],
                        ),
                      ),
                      if (price != null || deposit != null) ...[
                        const SizedBox(height: 18),
                        _BookingDetailsSection(
                          icon: Icons.payments_outlined,
                          title: 'Pricing',
                          child: Column(
                            children: [
                              if (price != null)
                                _BookingDetailRow(
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Daily rate',
                                  value: price!,
                                  valueColor: _primary,
                                ),
                              if (price != null && deposit != null)
                                const _BookingSectionDivider(),
                              if (deposit != null)
                                _BookingDetailRow(
                                  icon: Icons.shield_outlined,
                                  label: 'Refundable deposit',
                                  value: deposit!,
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _BookingDetailsSection(
                          icon: Icons.notes_rounded,
                          title: 'About this car',
                          child: Text(
                            description,
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 15,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                      if (features.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _BookingDetailsSection(
                          icon: Icons.auto_awesome_outlined,
                          title: 'Features',
                          child: Wrap(
                            spacing: 9,
                            runSpacing: 9,
                            children: features
                                .map((feature) => _FeatureChip(label: feature))
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _BookingDetailsSection(
                        icon: Icons.storefront_outlined,
                        title: 'Rental provider',
                        child: Column(
                          children: [
                            _BookingDetailRow(
                              icon: Icons.business_outlined,
                              label: 'Company',
                              value: providerName,
                            ),
                            if (providerCity.isNotEmpty) ...[
                              const _BookingSectionDivider(),
                              _BookingDetailRow(
                                icon: Icons.location_on_outlined,
                                label: 'Location',
                                value: providerCity,
                              ),
                            ],
                            if (providerPhone.isNotEmpty) ...[
                              const _BookingSectionDivider(),
                              _BookingDetailRow(
                                icon: Icons.phone_outlined,
                                label: 'Phone',
                                value: providerPhone,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookingGalleryCard extends StatelessWidget {
  final List<String> images;
  final int imageIndex;
  final ValueChanged<int> onImageChanged;
  final bool available;
  final bool isWishlisted;
  final bool wishBusy;
  final VoidCallback onToggleWishlist;

  const _BookingGalleryCard({
    required this.images,
    required this.imageIndex,
    required this.onImageChanged,
    required this.available,
    required this.isWishlisted,
    required this.wishBusy,
    required this.onToggleWishlist,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            (constraints.maxWidth * 0.68).clamp(250.0, 390.0).toDouble();

        return Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF5),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x160F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (images.isEmpty)
                const _ImagePlaceholder()
              else
                PageView.builder(
                  itemCount: images.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: onImageChanged,
                  itemBuilder: (context, index) => Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const _ImagePlaceholder(showLoader: true),
                    errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                  ),
                ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0x73000000)],
                      stops: [0.52, 1],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: _AvailabilityBadge(available: available),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: _WishlistButton(
                  isWishlisted: isWishlisted,
                  busy: wishBusy,
                  onTap: onToggleWishlist,
                ),
              ),
              if (images.length > 1)
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xA6000000),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_outlined,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '${imageIndex + 1} / ${images.length}',
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
              if (images.length > 1 && images.length <= 8)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 17,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (index) {
                        final active = imageIndex == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: active ? 20 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
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

class _CarSummaryCard extends StatelessWidget {
  final String title;
  final String year;
  final String provider;
  final String city;
  final bool available;
  final String? price;

  const _CarSummaryCard({
    required this.title,
    required this.year,
    required this.provider,
    required this.city,
    required this.available,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        available ? const Color(0xFF047857) : const Color(0xFFB91C1C);
    final statusBackground =
        available ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
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
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      year.isEmpty ? 'Model year unavailable' : 'Model $year',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      available ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.storefront_outlined,
                  color: _primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (price != null)
                Text(
                  '$price/day',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          if (city.isNotEmpty) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    color: _primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    city,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingDetailsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _BookingDetailsSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _primary, size: 20),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _BookingDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _BookingDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: _muted),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingSectionDivider extends StatelessWidget {
  const _BookingSectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, color: _border),
    );
  }
}

class _BookingSpecData {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const _BookingSpecData(
    this.icon,
    this.label,
    this.value, {
    this.iconColor,
  });
}

class _BookingSpecsGrid extends StatelessWidget {
  final List<_BookingSpecData> specs;

  const _BookingSpecsGrid({required this.specs});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        const gap = 10.0;
        final width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: specs
              .map((spec) => SizedBox(
                    width: width,
                    child: _BookingSpecTile(spec: spec),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _BookingSpecTile extends StatelessWidget {
  final _BookingSpecData spec;

  const _BookingSpecTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            spec.icon,
            size: spec.icon == Icons.circle ? 16 : 20,
            color: spec.iconColor ?? _primary,
          ),
          const SizedBox(height: 9),
          Text(
            spec.label,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            spec.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsGallery extends StatelessWidget {
  final List<String> images;
  final int imageIndex;
  final ValueChanged<int> onImageChanged;
  final bool isWishlisted;
  final bool wishBusy;
  final bool available;
  final VoidCallback onToggleWishlist;
  final VoidCallback onBack;

  const _DetailsGallery({
    required this.images,
    required this.imageIndex,
    required this.onImageChanged,
    required this.isWishlisted,
    required this.wishBusy,
    required this.available,
    required this.onToggleWishlist,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.74).clamp(300.0, 440.0).toDouble();

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: images.isEmpty ? 1 : images.length,
            onPageChanged: onImageChanged,
            itemBuilder: (context, index) {
              if (images.isEmpty) return const _ImagePlaceholder();
              return Image.network(
                images[index],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
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
                    colors: [Color(0x77000000), Colors.transparent, Color(0x99000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: _GalleryButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: _WishlistButton(
                isWishlisted: isWishlisted,
                busy: wishBusy,
                onTap: onToggleWishlist,
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 15,
            child: _AvailabilityBadge(available: available),
          ),
          if (images.length > 1)
            Positioned(
              right: 14,
              bottom: 15,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${imageIndex + 1}/${images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
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
              bottom: 19,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length > 7 ? 7 : images.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: imageIndex == index ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: imageIndex == index
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
  }
}

class _GalleryButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GalleryButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: _ink),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        fixedSize: const Size(46, 46),
        shadowColor: Colors.black26,
        elevation: 4,
      ),
    );
  }
}

class _WishlistButton extends StatelessWidget {
  final bool isWishlisted;
  final bool busy;
  final VoidCallback onTap;

  const _WishlistButton({
    required this.isWishlisted,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: busy ? null : onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: Color(0xFFDC2626),
                    ),
                  )
                : Icon(
                    isWishlisted
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: const Color(0xFFDC2626),
                    size: 24,
                  ),
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            available ? 'Available' : 'Unavailable',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;

  const _DetailCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B0F172A),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SpecificationTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;

  const _SpecificationTile({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width;
    final width = availableWidth >= 700
        ? 210.0
        : ((availableWidth - 74) / 2).clamp(132.0, 320.0).toDouble();

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: iconColor ?? _primary,
                size: icon == Icons.circle ? 15 : 19,
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
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepositCard extends StatelessWidget {
  final String amount;

  const _DepositCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, color: _primary, size: 22),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Text(
              'Refundable deposit',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              color: _primaryDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _primary, size: 22),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;

  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: Color(0xFF16A34A), size: 18),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String name;
  final String city;
  final String phone;

  const _ProviderCard({
    required this.name,
    required this.city,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primaryDark, Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 25),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (city.isNotEmpty || phone.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: _border),
            ),
            if (city.isNotEmpty)
              _ProviderInfo(
                icon: Icons.location_on_outlined,
                value: city,
              ),
            if (city.isNotEmpty && phone.isNotEmpty)
              const SizedBox(height: 12),
            if (phone.isNotEmpty)
              _ProviderInfo(
                icon: Icons.phone_outlined,
                value: phone,
              ),
          ],
        ],
      ),
    );
  }
}

class _ProviderInfo extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ProviderInfo({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingBar extends StatelessWidget {
  final String? price;
  final bool available;
  final VoidCallback? onBook;

  const _BookingBar({
    required this.price,
    required this.available,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        13,
        16,
        13 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Row(
            children: [
              if (price != null) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily rate',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      price!,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onBook,
                    icon: Icon(
                      available
                          ? Icons.calendar_month_rounded
                          : Icons.event_busy_outlined,
                      size: 20,
                    ),
                    label: Text(
                      available ? 'Book now' : 'Unavailable',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: _muted,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
            : const Icon(Icons.directions_car_filled_outlined,
                color: Color(0xFF94A3B8), size: 58),
      ),
    );
  }
}

class _DetailsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DetailsErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFDC2626), size: 38),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Unable to load car',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted, fontSize: 15),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _DetailsLoadingState extends StatelessWidget {
  const _DetailsLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EDF5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Skeleton(width: 230, height: 26),
                      SizedBox(height: 12),
                      _Skeleton(width: 120, height: 15),
                      SizedBox(height: 24),
                      _Skeleton(width: double.infinity, height: 54),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double width;
  final double height;

  const _Skeleton({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF5),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
