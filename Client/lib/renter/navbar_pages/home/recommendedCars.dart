import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/car_variant_api.dart';
import '../search/carVariantDetails.dart';

const _primary = Color(0xFF1D4ED8);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class RecommendedCars extends StatefulWidget {
  final String renterId;
  final String currency;
  final Map<String, dynamic>? fxRates;

  const RecommendedCars({
    super.key,
    required this.renterId,
    required this.currency,
    this.fxRates,
  });

  @override
  State<RecommendedCars> createState() => RecommendedCarsState();
}

class RecommendedCarsState extends State<RecommendedCars> {
  static const _baseCurrency = 'AED';

  List<dynamic> _recommendations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> refresh() => _loadRecommendations();

  Future<void> _loadRecommendations() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final cars = await CarVariantApi.getRecommendedCarVariants(
        widget.renterId,
        limit: 8,
      );
      if (!mounted) return;

      setState(() {
        _recommendations = List<dynamic>.from(cars);
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Recommended cars error: $error');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'We could not load recommendations.';
      });
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  String _imageUrl(dynamic image) {
    if (image is String) return image.trim();
    if (image is Map && image['filepath'] != null) {
      return image['filepath'].toString();
    }
    if (image is Map && image['url'] != null) {
      return image['url'].toString();
    }
    return '';
  }

  Map<String, double> get _egpPerUnit {
    final rates = <String, double>{'EGP': 1};
    final fx = widget.fxRates;

    if (fx != null) {
      for (final entry in fx.entries) {
        final value = entry.value is num
            ? (entry.value as num).toDouble()
            : double.tryParse(entry.value.toString());
        if (value != null && value > 0) {
          rates[entry.key.toUpperCase()] = value;
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

  String _symbol(String currency) {
    switch (currency) {
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

  String _money(num amount) {
    final target = widget.currency.toUpperCase();
    final rates = _egpPerUnit;

    if (target != _baseCurrency &&
        target != 'EGP' &&
        !rates.containsKey(target)) {
      return 'AED ${NumberFormat.decimalPattern().format(amount.round())}';
    }

    final converted = target == _baseCurrency
        ? amount.toDouble()
        : target == 'EGP'
            ? amount.toDouble() * rates[_baseCurrency]!
            : amount.toDouble() * rates[_baseCurrency]! / rates[target]!;
    final value = NumberFormat.decimalPattern().format(converted.round());
    return '${_symbol(target)} $value';
  }

  void _openDetails(String variantId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarVariantDetails(
          variantId: variantId,
          userId: widget.renterId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 286,
        child: Row(
          children: [
            Expanded(child: _RecommendationSkeleton()),
            SizedBox(width: 12),
            Expanded(child: _RecommendationSkeleton()),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _RecommendationMessage(
        icon: Icons.auto_awesome_outlined,
        title: 'Recommendations unavailable',
        message: _errorMessage!,
        actionLabel: 'Try again',
        onAction: _loadRecommendations,
      );
    }

    if (_recommendations.isEmpty) {
      return const _RecommendationMessage(
        icon: Icons.directions_car_outlined,
        title: 'No recommendations yet',
        message: 'Browse a few cars and your suggestions will improve.',
      );
    }

    return SizedBox(
      height: 286,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _recommendations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final variant = _asMap(_recommendations[index]);
          return _RecommendedCarCard(
            variant: variant,
            imageUrl: _imageUrl,
            money: _money,
            onTap: () {
              final id = (variant['_id'] ?? '').toString();
              if (id.isNotEmpty) _openDetails(id);
            },
          );
        },
      ),
    );
  }
}

class _RecommendedCarCard extends StatelessWidget {
  final Map<String, dynamic> variant;
  final String Function(dynamic image) imageUrl;
  final String Function(num amount) money;
  final VoidCallback onTap;

  const _RecommendedCarCard({
    required this.variant,
    required this.imageUrl,
    required this.money,
    required this.onTap,
  });

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final car = _asMap(variant['car']);
    final provider = _asMap(variant['provider']);
    final address = _asMap(provider['address']);
    final images = variant['images'] is List
        ? List<dynamic>.from(variant['images'] as List)
        : <dynamic>[];
    final firstImage = images.isEmpty ? '' : imageUrl(images.first);
    final title = [car['brand'], car['model']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .map((value) => value.toString().trim())
        .join(' ');
    final providerName = (provider['companyName'] ?? 'Rental provider').toString();
    final city = (address['city'] ?? '').toString();
    final reason = (variant['recommendationReason'] ??
            'Available for your next trip')
        .toString();
    final price = variant['rentalPricePerDay'] is num
        ? variant['rentalPricePerDay'] as num
        : num.tryParse(variant['rentalPricePerDay']?.toString() ?? '');

    return SizedBox(
      width: 248,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(19),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 138,
                    child: firstImage.isEmpty
                        ? const _CarImagePlaceholder()
                        : Image.network(
                            firstImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _CarImagePlaceholder(),
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? 'Available car' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          city.isEmpty ? providerName : '$providerName · $city',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: _primary,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                reason,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (price != null)
                          Text.rich(
                            TextSpan(
                              text: money(price),
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                              children: const [
                                TextSpan(
                                  text: ' / day',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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
}

class _CarImagePlaceholder extends StatelessWidget {
  const _CarImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF6FF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.directions_car_filled_outlined,
        color: _primary,
        size: 46,
      ),
    );
  }
}

class _RecommendationMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _RecommendationMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _primary, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _RecommendationSkeleton extends StatelessWidget {
  const _RecommendationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 138,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EDF5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(width: 130, height: 16),
                SizedBox(height: 10),
                _SkeletonLine(width: 90, height: 11),
                SizedBox(height: 12),
                _SkeletonLine(width: 150, height: 11),
              ],
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
