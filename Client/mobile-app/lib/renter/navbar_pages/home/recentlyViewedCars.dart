import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/activity_api.dart';
import '../search/carVariantDetails.dart';

const _primary = Color(0xFF1D4ED8);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class RecentlyViewedCars extends StatefulWidget {
  final String renterId;
  final String currency;
  final Map<String, dynamic>? fxRates;

  const RecentlyViewedCars({
    super.key,
    required this.renterId,
    required this.currency,
    this.fxRates,
  });

  @override
  State<RecentlyViewedCars> createState() => RecentlyViewedCarsState();
}

class RecentlyViewedCarsState extends State<RecentlyViewedCars> {
  static const _baseCurrency = 'AED';

  List<dynamic> _cars = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  @override
  void didUpdateWidget(covariant RecentlyViewedCars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.renterId != widget.renterId) _loadCars();
  }

  Future<void> refresh() => _loadCars();

  Future<void> _loadCars() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final cars = await ActivityApi.getRecentlyViewed(
        renterId: widget.renterId,
        limit: 10,
      );
      if (!mounted) return;

      setState(() {
        _cars = List<dynamic>.from(cars);
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Recently viewed error: $error');
      if (!mounted) return;

      setState(() {
        _cars = [];
        _isLoading = false;
        _errorMessage = 'We could not load your recently viewed cars.';
      });
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  String _imageUrl(dynamic image) {
    String url = '';
    if (image is String) url = image.trim();
    if (image is Map && image['filepath'] != null) {
      url = image['filepath'].toString().trim();
    }
    if (image is Map && image['url'] != null) {
      url = image['url'].toString().trim();
    }

    if (url.contains('res.cloudinary.com') && url.contains('/upload/')) {
      return url.replaceFirst(
        '/upload/',
        '/upload/f_auto,q_auto,w_600,c_fill/',
      );
    }
    return url;
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
    return '${_symbol(target)} '
        '${NumberFormat.decimalPattern().format(converted.round())}';
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
    ).then((_) => refresh());
  }

  Widget _section(Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recently viewed',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Continue exploring cars you opened',
          style: TextStyle(
            color: _muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        content,
        const SizedBox(height: 26),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _section(
        const SizedBox(
          height: 232,
          child: Row(
            children: [
              Expanded(child: _RecentlyViewedSkeleton()),
              SizedBox(width: 12),
              Expanded(child: _RecentlyViewedSkeleton()),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _section(
        _RecentlyViewedMessage(
          message: _errorMessage!,
          onRetry: _loadCars,
        ),
      );
    }

    // A new user should not see an empty section taking up home-page space.
    if (_cars.isEmpty) return const SizedBox.shrink();

    return _section(
      SizedBox(
        height: 232,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _cars.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final variant = _asMap(_cars[index]);
            return _RecentlyViewedCard(
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
      ),
    );
  }
}

class _RecentlyViewedCard extends StatelessWidget {
  final Map<String, dynamic> variant;
  final String Function(dynamic image) imageUrl;
  final String Function(num amount) money;
  final VoidCallback onTap;

  const _RecentlyViewedCard({
    required this.variant,
    required this.imageUrl,
    required this.money,
    required this.onTap,
  });

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  String _viewedLabel(dynamic rawDate) {
    final date = DateTime.tryParse(rawDate?.toString() ?? '')?.toLocal();
    if (date == null) return 'Viewed recently';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final viewedDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(viewedDay).inDays;

    if (difference == 0) return 'Viewed today';
    if (difference == 1) return 'Viewed yesterday';
    return 'Viewed ${DateFormat('MMM d').format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final car = _asMap(variant['car']);
    final images = variant['images'] is List
        ? List<dynamic>.from(variant['images'] as List)
        : <dynamic>[];
    final image = images.isEmpty ? '' : imageUrl(images.first);
    final title = [car['brand'], car['model']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .map((value) => value.toString().trim())
        .join(' ');
    final detail = [car['category'], car['transmission']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' · ');
    final rawPrice = variant['rentalPricePerDay'];
    final price = rawPrice is num ? rawPrice : num.tryParse('$rawPrice');

    return SizedBox(
      width: 218,
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
                    height: 118,
                    child: image.isEmpty
                        ? const _CarImagePlaceholder()
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _CarImagePlaceholder(),
                          ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? 'Available car' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detail.isEmpty ? 'Available to rent' : detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (price != null)
                              Expanded(
                                child: Text(
                                  '${money(price)} / day',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            Text(
                              _viewedLabel(variant['viewedAt']),
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
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
        size: 42,
      ),
    );
  }
}

class _RecentlyViewedMessage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RecentlyViewedMessage({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_toggle_off_rounded, color: _muted),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _RecentlyViewedSkeleton extends StatelessWidget {
  const _RecentlyViewedSkeleton();

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
            height: 118,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EDF5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(width: 120, height: 15),
                SizedBox(height: 9),
                _SkeletonLine(width: 86, height: 10),
                SizedBox(height: 20),
                _SkeletonLine(width: 138, height: 11),
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
