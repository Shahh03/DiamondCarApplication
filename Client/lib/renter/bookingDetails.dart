
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api/booking_api.dart';

class BookingDetailsPage extends StatefulWidget {
  final String bookingId;

  const BookingDetailsPage({super.key, required this.bookingId});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  static const _primary = Color(0xFF1D4ED8);
  static const _background = Color(0xFFF5F7FB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  late Future<Map<String, dynamic>> _bookingFuture;
  late final PageController _imageController;
  int _activeImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
    _bookingFuture = fetchBookingDetails();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> fetchBookingDetails() async {
  return BookingApi.getBookingById(widget.bookingId);
}

  Future<void> _reload() async {
    if (_imageController.hasClients) {
      _imageController.jumpToPage(0);
    }

    setState(() {
      _activeImageIndex = 0;
      _bookingFuture = fetchBookingDetails();
    });

    try {
      await _bookingFuture;
    } catch (_) {
      // FutureBuilder renders the dedicated retry state.
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  String _getCarImageUrl(dynamic image) {
    if (image is String) return image.trim();
    if (image is Map && image['filepath'] != null) {
      return image['filepath'].toString().trim();
    }
    return '';
  }

  List<String> _getValidImages(dynamic value) {
    if (value is! List) return [];
    return value
        .map(_getCarImageUrl)
        .where((url) => url.isNotEmpty)
        .toList();
  }

  String _displayValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'Not provided' : text;
  }

  String _capitalize(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return 'Unknown';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Not available';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _joinAvailable(List<dynamic> parts, {String separator = ' '}) {
    return parts
        .map((part) => part?.toString().trim() ?? '')
        .where((part) => part.isNotEmpty)
        .join(separator);
  }

  String _paymentAmount(Map<String, dynamic> payment) {
    final amount = payment['amount']?.toString().trim() ?? '';
    final currency = payment['currency']?.toString().trim() ?? '';
    final result = [amount, currency].where((part) => part.isNotEmpty).join(' ');
    return result.isEmpty ? 'Not provided' : result;
  }

  void _copyBookingId(String id) {
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Booking ID copied'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: const Text(
          'Booking details',
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
              tooltip: 'Refresh booking',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _bookingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _BookingDetailsLoading();
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return _BookingErrorState(onRetry: _reload);
            }

            return _buildContent(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> booking) {
    final carVariant = _asMap(booking['carVariant']);
    final car = _asMap(carVariant['car']);
    final provider = _asMap(carVariant['provider']);
    final payment = _asMap(booking['payment']);
    final providerAddress = _asMap(provider['address']);
    final contactPerson = _asMap(provider['contactPerson']);

    final images = _getValidImages(carVariant['images']);
    final status = _displayValue(booking['status']);
    final statusStyle = _statusStyle(status);
    final carName = _joinAvailable([car['brand'], car['model']]);
    final location = _joinAvailable(
      [providerAddress['state'], providerAddress['country']],
      separator: ', ',
    );
    final bookingId = _displayValue(booking['_id']);

    return RefreshIndicator(
      color: _primary,
      onRefresh: _reload,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 760 ? 28.0 : 16.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGallery(images),
                    const SizedBox(height: 18),
                    _VehicleHeader(
                      carName: carName.isEmpty ? 'Your rental car' : carName,
                      year: _displayValue(car['year']),
                      company: _displayValue(provider['companyName']),
                      location: location.isEmpty ? 'Location not provided' : location,
                      status: _capitalize(status),
                      statusStyle: statusStyle,
                    ),
                    const SizedBox(height: 18),
                    _BookingTimeline(
                      startDate: _formatDate(booking['startDate']),
                      endDate: _formatDate(booking['endDate']),
                    ),
                    const SizedBox(height: 18),
                    _DetailsSection(
                      icon: Icons.receipt_long_outlined,
                      title: 'Booking information',
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Booking ID',
                            value: bookingId,
                            trailing: IconButton(
                              tooltip: 'Copy booking ID',
                              visualDensity: VisualDensity.compact,
                              onPressed: bookingId == 'Not provided'
                                  ? null
                                  : () => _copyBookingId(bookingId),
                              icon: const Icon(Icons.copy_rounded, size: 18),
                            ),
                          ),
                          const _SectionDivider(),
                          _DetailRow(
                            icon: Icons.info_outline_rounded,
                            label: 'Status',
                            value: _capitalize(status),
                            valueColor: statusStyle.foreground,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DetailsSection(
                      icon: Icons.directions_car_outlined,
                      title: 'Vehicle specifications',
                      child: _SpecsGrid(
                        specs: [
                          _SpecData(
                            Icons.category_outlined,
                            'Category',
                            _displayValue(car['category']),
                          ),
                          _SpecData(
                            Icons.palette_outlined,
                            'Color',
                            _displayValue(carVariant['color']),
                          ),
                          _SpecData(
                            Icons.local_gas_station_outlined,
                            'Fuel type',
                            _displayValue(car['fuelType']),
                          ),
                          _SpecData(
                            Icons.settings_outlined,
                            'Transmission',
                            _displayValue(car['transmission']),
                          ),
                          _SpecData(
                            Icons.airline_seat_recline_normal_rounded,
                            'Seats',
                            car['seats'] == null
                                ? 'Not provided'
                                : '${car['seats']} passengers',
                          ),
                          _SpecData(
                            Icons.pin_outlined,
                            'Registration',
                            _displayValue(carVariant['registrationNumber']),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DetailsSection(
                      icon: Icons.storefront_outlined,
                      title: 'Rental provider',
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.business_outlined,
                            label: 'Company',
                            value: _displayValue(provider['companyName']),
                          ),
                          const _SectionDivider(),
                          _DetailRow(
                            icon: Icons.mail_outline_rounded,
                            label: 'Email',
                            value: _displayValue(contactPerson['email']),
                          ),
                          const _SectionDivider(),
                          _DetailRow(
                            icon: Icons.location_on_outlined,
                            label: 'Location',
                            value: location.isEmpty
                                ? 'Not provided'
                                : location,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PaymentCard(
                      amount: _paymentAmount(payment),
                      method: _displayValue(payment['paymentMethod']),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGallery(List<String> images) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final galleryHeight =
            (constraints.maxWidth * 0.68).clamp(250.0, 390.0).toDouble();

        return Container(
          height: galleryHeight,
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
                const _GalleryPlaceholder()
              else
                PageView.builder(
                  controller: _imageController,
                  itemCount: images.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _activeImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const _GalleryPlaceholder(showLoader: true);
                      },
                      errorBuilder: (_, __, ___) => const _GalleryPlaceholder(),
                    );
                  },
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
              if (images.length > 1) ...[
                Positioned(
                  top: 14,
                  right: 14,
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
                        const Icon(
                          Icons.photo_library_outlined,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_activeImageIndex + 1} / ${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (images.length <= 8)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (index) {
                          final isActive = _activeImageIndex == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: isActive ? 20 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: isActive
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
            ],
          ),
        );
      },
    );
  }

  static _StatusStyle _statusStyle(String value) {
    switch (value.toLowerCase()) {
      case 'confirmed':
        return const _StatusStyle(Color(0xFF047857), Color(0xFFD1FAE5));
      case 'active':
      case 'ongoing':
        return const _StatusStyle(Color(0xFF1D4ED8), Color(0xFFDBEAFE));
      case 'completed':
        return const _StatusStyle(Color(0xFF475569), Color(0xFFE2E8F0));
      case 'cancelled':
      case 'rejected':
        return const _StatusStyle(Color(0xFFB91C1C), Color(0xFFFEE2E2));
      case 'pending':
        return const _StatusStyle(Color(0xFFB45309), Color(0xFFFEF3C7));
      default:
        return const _StatusStyle(Color(0xFF475569), Color(0xFFF1F5F9));
    }
  }
}

class _VehicleHeader extends StatelessWidget {
  final String carName;
  final String year;
  final String company;
  final String location;
  final String status;
  final _StatusStyle statusStyle;

  const _VehicleHeader({
    required this.carName,
    required this.year,
    required this.company,
    required this.location,
    required this.status,
    required this.statusStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _BookingDetailsPageState._border),
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
                      carName,
                      style: const TextStyle(
                        color: _BookingDetailsPageState._ink,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      year == 'Not provided' ? 'Model year unavailable' : year,
                      style: const TextStyle(
                        color: _BookingDetailsPageState._muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: statusStyle.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusStyle.foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusStyle.foreground,
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
              const Icon(
                Icons.storefront_outlined,
                size: 18,
                color: _BookingDetailsPageState._primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  company,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BookingDetailsPageState._ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: _BookingDetailsPageState._primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BookingDetailsPageState._muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingTimeline extends StatelessWidget {
  final String startDate;
  final String endDate;

  const _BookingTimeline({required this.startDate, required this.endDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimelinePoint(
              label: 'PICK-UP',
              value: startDate,
              icon: Icons.trip_origin_rounded,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: List.generate(
                3,
                (_) => Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF93C5FD),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _TimelinePoint(
              label: 'RETURN',
              value: endDate,
              icon: Icons.location_on_rounded,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePoint extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool alignEnd;

  const _TimelinePoint({
    required this.label,
    required this.value,
    required this.icon,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _BookingDetailsPageState._primary),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF60A5FA),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            color: _BookingDetailsPageState._ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DetailsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DetailsSection({
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
        border: Border.all(color: _BookingDetailsPageState._border),
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
                child: Icon(
                  icon,
                  color: _BookingDetailsPageState._primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: const TextStyle(
                  color: _BookingDetailsPageState._ink,
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: _BookingDetailsPageState._muted),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _BookingDetailsPageState._muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              SelectableText(
                value,
                style: TextStyle(
                  color: valueColor ?? _BookingDetailsPageState._ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SpecsGrid extends StatelessWidget {
  final List<_SpecData> specs;

  const _SpecsGrid({required this.specs});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        const gap = 10.0;
        final tileWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: specs.map((spec) {
            return SizedBox(
              width: tileWidth,
              child: Container(
                padding: const EdgeInsets.all(13),
                constraints: const BoxConstraints(minHeight: 96),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFEDF1F5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      spec.icon,
                      size: 20,
                      color: _BookingDetailsPageState._primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      spec.label,
                      style: const TextStyle(
                        color: _BookingDetailsPageState._muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      spec.value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _BookingDetailsPageState._ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final String amount;
  final String method;

  const _PaymentCard({required this.amount, required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172554), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x241E40AF),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAYMENT',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  method,
                  style: const TextStyle(
                    color: Color(0xFFDCEBFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.credit_card_rounded, color: Color(0xFF93C5FD)),
        ],
      ),
    );
  }
}

class _GalleryPlaceholder extends StatelessWidget {
  final bool showLoader;

  const _GalleryPlaceholder({this.showLoader = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE9EEF5),
      child: Center(
        child: showLoader
            ? const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(
                Icons.directions_car_filled_rounded,
                size: 68,
                color: Color(0xFF94A3B8),
              ),
      ),
    );
  }
}

class _BookingErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _BookingErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: _BookingDetailsPageState._primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Couldn’t load this booking',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _BookingDetailsPageState._ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _BookingDetailsPageState._muted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: _BookingDetailsPageState._primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingDetailsLoading extends StatelessWidget {
  const _BookingDetailsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF5),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 18),
        ...List.generate(
          3,
          (_) => Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _BookingDetailsPageState._border),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 13),
      child: Divider(height: 1, color: _BookingDetailsPageState._border),
    );
  }
}

class _SpecData {
  final IconData icon;
  final String label;
  final String value;

  const _SpecData(this.icon, this.label, this.value);
}

class _StatusStyle {
  final Color foreground;
  final Color background;

  const _StatusStyle(this.foreground, this.background);
}
