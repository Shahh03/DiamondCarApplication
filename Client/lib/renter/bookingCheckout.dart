import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'api/booking_api.dart';
import 'bookingDetails.dart';

const _primary = Color(0xFF1D4ED8);
const _primaryDark = Color(0xFF1E40AF);
const _background = Color(0xFFF5F7FB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);
const _success = Color(0xFF047857);
const _danger = Color(0xFFDC2626);

class BookingCheckoutPage extends StatefulWidget {
  final String renterId;
  final Map<String, dynamic> variant;

  const BookingCheckoutPage({
    super.key,
    required this.renterId,
    required this.variant,
  });

  @override
  State<BookingCheckoutPage> createState() => _BookingCheckoutPageState();
}

class _BookingCheckoutPageState extends State<BookingCheckoutPage> {
  DateTimeRange? _dates;
  final Set<DateTime> _bookedDays = <DateTime>{};

  bool _isLoadingDates = true;
  bool _isChecking = false;
  bool _isAvailable = false;
  bool _isSubmitting = false;
  bool _saveCard = false;
  String? _datesError;
  String? _availabilityMessage;

  @override
  void initState() {
    super.initState();
    _loadUnavailableDates();
  }

  Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};

  num _number(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get _variantId => widget.variant['_id']?.toString() ?? '';
  Map<String, dynamic> get _car => _map(widget.variant['car']);

  String get _carName {
    final name = [
      _car['brand']?.toString().trim() ?? '',
      _car['model']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? 'Car rental' : name;
  }

  String get _imageUrl {
    final images = widget.variant['images'];
    if (images is! List || images.isEmpty) return '';

    final first = images.first;
    if (first is String) return first;
    if (first is Map) {
      return (first['url'] ?? first['filepath'] ?? '').toString();
    }
    return '';
  }

  num get _dailyRate => _number(widget.variant['rentalPricePerDay']);
  num get _deposit => _number(widget.variant['depositAmount']);
  int get _days => _dates == null ? 0 : _dates!.duration.inDays;
  num get _rentalSubtotal => _dailyRate * _days;
  num get _totalDue => _rentalSubtotal + _deposit;

  bool get _isAndroid =>
      Theme.of(context).platform == TargetPlatform.android;
  bool get _isIOS => Theme.of(context).platform == TargetPlatform.iOS;

  String _money(num amount) =>
      'AED ${NumberFormat.decimalPattern().format(amount)}';

  DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _utcDay(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  DateTime? _parseApiDay(dynamic value) {
    final text = value?.toString();
    if (text == null || text.length < 10) return null;

    final parts = text.substring(0, 10).split('-');
    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    return DateTime(year, month, day);
  }

  Future<void> _loadUnavailableDates() async {
    if (_variantId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingDates = false;
          _datesError = 'Car information is incomplete.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingDates = true;
        _datesError = null;
      });
    }

    try {
      final ranges =
          await BookingApi.getUnavailableDateRanges(_variantId);
      final loadedDays = <DateTime>{};

      for (final range in ranges) {
        final start = _parseApiDay(range['startDate']);
        final end = _parseApiDay(range['endDate']);
        if (start == null || end == null) continue;

        var current = start;
        while (!current.isAfter(end)) {
          loadedDays.add(_day(current));
          current = current.add(const Duration(days: 1));
        }
      }

      if (!mounted) return;
      setState(() {
        _bookedDays
          ..clear()
          ..addAll(loadedDays);
        _isLoadingDates = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingDates = false;
        _datesError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _selectDates() async {
    if (_isSubmitting) return;

    if (_isLoadingDates) {
      _showMessage('The availability calendar is still loading.');
      return;
    }

    if (_datesError != null) {
      await _loadUnavailableDates();
      if (!mounted || _datesError != null) return;
    }

    final selected = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.94,
        child: _RentalDatePicker(
          bookedDays: _bookedDays,
          initialRange: _dates,
        ),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _dates = selected;
      _isAvailable = false;
      _availabilityMessage = null;
    });

    await _checkAvailability();
  }

  Future<bool> _checkAvailability() async {
    if (_dates == null || _variantId.isEmpty) return false;

    setState(() {
      _isChecking = true;
      _availabilityMessage = null;
    });

    try {
      final result = await BookingApi.checkAvailability(
        carVariantId: _variantId,
        startDate: _utcDay(_dates!.start),
        endDate: _utcDay(_dates!.end),
      );

      if (!mounted) return false;
      final available = result['available'] == true;

      setState(() {
        _isAvailable = available;
        _availabilityMessage = result['message']?.toString() ??
            (available
                ? 'Available for your selected dates.'
                : 'This car is already booked for those dates.');
      });

      if (!available) await _loadUnavailableDates();
      return available;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _isAvailable = false;
        _availabilityMessage =
            error.toString().replaceFirst('Exception: ', '');
      });
      return false;
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _confirmBooking() async {
    if (_dates == null) {
      await _selectDates();
      return;
    }

    final available = await _checkAvailability();
    if (!available || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await BookingApi.createStripePaymentIntent(
        renterId: widget.renterId,
        carVariantId: _variantId,
        startDate: _utcDay(_dates!.start),
        endDate: _utcDay(_dates!.end),
        savePaymentMethod: _saveCard,
      );

      if (!mounted) return;

      final paymentIntentId =
          result['paymentIntentId']?.toString() ?? '';
      final clientSecret = result['clientSecret']?.toString() ?? '';
      final customerId = result['customerId']?.toString() ?? '';
      final customerSessionSecret =
          result['customerSessionClientSecret']?.toString() ?? '';

      if (paymentIntentId.isEmpty ||
          clientSecret.isEmpty ||
          customerId.isEmpty ||
          customerSessionSecret.isEmpty) {
        throw Exception(
          'The server returned incomplete payment information.',
        );
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          customerSessionClientSecret: customerSessionSecret,
          merchantDisplayName: 'DiamondCar',
          style: ThemeMode.system,
          returnURL: 'diamondcar://stripe-redirect',
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
            name: CollectionMode.never,
            email: CollectionMode.never,
            phone: CollectionMode.never,
            address: AddressCollectionMode.never,
          ),
          googlePay: _isAndroid
              ? const PaymentSheetGooglePay(
                  merchantCountryCode: 'AE',
                  currencyCode: 'AED',
                  testEnv: true,
                )
              : null,
          applePay: _isIOS
              ? const PaymentSheetApplePay(
                  merchantCountryCode: 'AE',
                )
              : null,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      if (!mounted) return;

      final status = await _waitForPaymentConfirmation(paymentIntentId);
      if (!mounted) return;

      if (status == null) {
        _showMessage(
          'Payment was received. Booking confirmation is still processing.',
        );
        return;
      }

      if (status['refunded'] == true) {
        throw Exception(
          status['message']?.toString() ??
              'The dates became unavailable and your payment was refunded.',
        );
      }

      final bookingId = status['bookingId']?.toString() ?? '';
      if (status['confirmed'] != true || bookingId.isEmpty) {
        throw Exception('The booking could not be confirmed.');
      }

      await _showSuccessDialog(bookingId);
    } on StripeException catch (error) {
      if (!mounted) return;
      final message = error.error.localizedMessage?.trim();
      if (message != null && message.isNotEmpty) _showMessage(message);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<Map<String, dynamic>?> _waitForPaymentConfirmation(
    String paymentIntentId,
  ) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final status =
          await BookingApi.getStripePaymentStatus(paymentIntentId);

      if (status['confirmed'] == true || status['refunded'] == true) {
        return status;
      }

      final paymentStatus = status['paymentStatus']?.toString();
      if (paymentStatus == 'Failed' || paymentStatus == 'canceled') {
        return status;
      }

      await Future<void>.delayed(const Duration(milliseconds: 750));
    }

    return null;
  }

  Future<void> _showSuccessDialog(String bookingId) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: const Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFD1FAE5),
              child: Icon(Icons.check_rounded, color: _success, size: 32),
            ),
            SizedBox(height: 14),
            Text(
              'Booking confirmed',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          'Your $_carName booking is confirmed and paid.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BookingDetailsPage(bookingId: bookingId),
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: _primary),
              child: const Text('View booking'),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _danger,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('EEE, d MMM yyyy');

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'Complete booking',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
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
      body: RefreshIndicator(
        onRefresh: _loadUnavailableDates,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  _CarHeader(
                    name: _carName,
                    imageUrl: _imageUrl,
                    dailyRate: _money(_dailyRate),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    icon: Icons.calendar_month_outlined,
                    title: 'Rental dates',
                    child: Column(
                      children: [
                        InkWell(
                          onTap: _selectDates,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _border),
                            ),
                            child: _isLoadingDates
                                ? const Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: _primary,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Loading availability...',
                                        style: TextStyle(
                                          color: _ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  )
                                : _dates == null
                                    ? const Row(
                                        children: [
                                          Icon(
                                            Icons.date_range_rounded,
                                            color: _primary,
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Choose pickup and return dates',
                                              style: TextStyle(
                                                color: _ink,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: _muted,
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: _DateValue(
                                              label: 'Pickup',
                                              value: formatter
                                                  .format(_dates!.start),
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            child: Icon(
                                              Icons.arrow_forward_rounded,
                                              color: _muted,
                                              size: 19,
                                            ),
                                          ),
                                          Expanded(
                                            child: _DateValue(
                                              label: 'Return',
                                              value:
                                                  formatter.format(_dates!.end),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.edit_calendar_outlined,
                                            color: _primary,
                                            size: 21,
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                        if (_datesError != null) ...[
                          const SizedBox(height: 12),
                          _StatusMessage(
                            message: _datesError!,
                            successful: false,
                          ),
                        ] else if (_isChecking) ...[
                          const SizedBox(height: 14),
                          const LinearProgressIndicator(color: _primary),
                        ] else if (_availabilityMessage != null) ...[
                          const SizedBox(height: 12),
                          _StatusMessage(
                            message: _availabilityMessage!,
                            successful: _isAvailable,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    icon: Icons.lock_outline_rounded,
                    title: 'Secure payment',
                    child: Column(
                      children: [
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: _success,
                              size: 22,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Stripe will show saved cards, Link and any wallet supported by this device.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                          ),
                          child: CheckboxListTile(
                            value: _saveCard,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: _primary,
                            title: const Text(
                              'Save a new card',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: const Text(
                              'Only save it when you want faster checkout next time.',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                height: 1.25,
                              ),
                            ),
                            onChanged: _isSubmitting
                                ? null
                                : (value) => setState(
                                      () => _saveCard = value ?? false,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Price summary',
                    child: Column(
                      children: [
                        _PriceRow(
                          label: _days == 0
                              ? 'Rental subtotal'
                              : '${_money(_dailyRate)} × $_days ${_days == 1 ? 'day' : 'days'}',
                          value: _money(_rentalSubtotal),
                        ),
                        const Divider(height: 25, color: _border),
                        _PriceRow(
                          label: 'Refundable deposit',
                          value: _money(_deposit),
                        ),
                        const Divider(height: 25, color: _border),
                        _PriceRow(
                          label: 'Total due',
                          value: _money(_totalDue),
                          emphasized: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isSubmitting || _isChecking
                  ? null
                  : _confirmBooking,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: _primary.withOpacity(0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSubmitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.3,
                          ),
                        ),
                        SizedBox(width: 11),
                        Text('Opening secure checkout...'),
                      ],
                    )
                  : Text(
                      _days == 0
                          ? 'Choose rental dates'
                          : 'Continue • ${_money(_totalDue)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RentalDatePicker extends StatefulWidget {
  final Set<DateTime> bookedDays;
  final DateTimeRange? initialRange;

  const _RentalDatePicker({
    required this.bookedDays,
    required this.initialRange,
  });

  @override
  State<_RentalDatePicker> createState() => _RentalDatePickerState();
}

class _RentalDatePickerState extends State<_RentalDatePicker> {
  late final DateTime _today;
  late final DateTime _lastDay;
  late DateTime _focusedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  RangeSelectionMode _rangeMode = RangeSelectionMode.toggledOn;
  String? _selectionError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _lastDay = DateTime(_today.year + 2, _today.month, _today.day);
    _rangeStart = widget.initialRange?.start;
    _rangeEnd = widget.initialRange?.end;
    _focusedDay = _rangeStart ?? _today;
  }

  DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isBooked(DateTime value) => widget.bookedDays.contains(_day(value));

  bool _rangeContainsBookedDay(DateTime start, DateTime end) {
    var current = _day(start);
    final finalDay = _day(end);

    while (!current.isAfter(finalDay)) {
      if (_isBooked(current)) return true;
      current = current.add(const Duration(days: 1));
    }
    return false;
  }

  void _onRangeSelected(
    DateTime? start,
    DateTime? end,
    DateTime focusedDay,
  ) {
    setState(() {
      _focusedDay = focusedDay;
      _selectionError = null;

      if (start != null && end != null && _rangeContainsBookedDay(start, end)) {
        _rangeStart = start;
        _rangeEnd = null;
        _rangeMode = RangeSelectionMode.toggledOn;
        _selectionError =
            'That range includes booked dates. Choose an earlier return date.';
        return;
      }

      _rangeStart = start;
      _rangeEnd = end;
      _rangeMode = RangeSelectionMode.toggledOn;
    });
  }

  void _applyDuration(int days) {
    final start = _rangeStart ?? _today;
    final end = start.add(Duration(days: days));

    if (end.isAfter(_lastDay) || _rangeContainsBookedDay(start, end)) {
      setState(() {
        _selectionError =
            'This duration overlaps booked dates. Choose another pickup date.';
      });
      return;
    }

    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _focusedDay = start;
      _selectionError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final compactDate = DateFormat('d MMM yyyy');

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose rental dates',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Select pickup first, then return',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: _PickerDateCard(
                    label: 'PICKUP',
                    value: _rangeStart == null
                        ? 'Select date'
                        : compactDate.format(_rangeStart!),
                    active: _rangeStart == null || _rangeEnd != null,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 9),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: _muted,
                    size: 19,
                  ),
                ),
                Expanded(
                  child: _PickerDateCard(
                    label: 'RETURN',
                    value: _rangeEnd == null
                        ? 'Select date'
                        : compactDate.format(_rangeEnd!),
                    active: _rangeStart != null && _rangeEnd == null,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _LegendDot(color: _primary, label: 'Selected'),
                const SizedBox(width: 18),
                const _LegendDot(color: Color(0xFFFEE2E2), label: 'Booked'),
                const SizedBox(width: 18),
                const _LegendDot(color: Color(0xFFE2E8F0), label: 'Past'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TableCalendar<void>(
                firstDay: _today,
                lastDay: _lastDay,
                focusedDay: _focusedDay,
                currentDay: _today,
                rangeStartDay: _rangeStart,
                rangeEndDay: _rangeEnd,
                rangeSelectionMode: _rangeMode,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                sixWeekMonthsEnforced: true,
                shouldFillViewport: false,
                enabledDayPredicate: (day) =>
                    !day.isBefore(_today) && !_isBooked(day),
                onRangeSelected: _onRangeSelected,
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: _ink,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: _ink,
                  ),
                  titleTextStyle: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                  weekendStyle: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  cellMargin: const EdgeInsets.all(5),
                  rangeHighlightColor: _primary.withOpacity(0.14),
                  rangeStartDecoration: const BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                  ),
                  rangeEndDecoration: const BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                  ),
                  withinRangeTextStyle: const TextStyle(
                    color: _primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _primary),
                  ),
                  todayTextStyle: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w800,
                  ),
                  disabledTextStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                  ),
                ),
                calendarBuilders: CalendarBuilders<void>(
                    disabledBuilder: (context, day, focusedDay) {
                    if (!_isBooked(day)) return null;

                    return Container(
                      margin: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(
                          color: _danger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Quick duration',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _DurationChip(label: '1 day', onTap: () => _applyDuration(1)),
                      const SizedBox(width: 7),
                      _DurationChip(label: '3 days', onTap: () => _applyDuration(3)),
                      const SizedBox(width: 7),
                      _DurationChip(label: '7 days', onTap: () => _applyDuration(7)),
                    ],
                  ),
                  if (_selectionError != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: _danger,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _selectionError!,
                            style: const TextStyle(
                              color: _danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _rangeStart != null && _rangeEnd != null
                          ? () => Navigator.pop(
                                context,
                                DateTimeRange(
                                  start: _rangeStart!,
                                  end: _rangeEnd!,
                                ),
                              )
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        _rangeEnd == null
                            ? 'Select a return date'
                            : 'Use these dates',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarHeader extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String dailyRate;

  const _CarHeader({
    required this.name,
    required this.imageUrl,
    required this.dailyRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 105,
              height: 82,
              child: imageUrl.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFEFF6FF),
                      child: Icon(
                        Icons.directions_car_rounded,
                        color: _primary,
                        size: 42,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFEFF6FF),
                        child: Icon(
                          Icons.directions_car_rounded,
                          color: _primary,
                          size: 42,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$dailyRate / day',
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              Icon(icon, color: _primary, size: 22),
              const SizedBox(width: 10),
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
          const SizedBox(height: 17),
          child,
        ],
      ),
    );
  }
}

class _DateValue extends StatelessWidget {
  final String label;
  final String value;

  const _DateValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          style: const TextStyle(
            color: _ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String message;
  final bool successful;

  const _StatusMessage({
    required this.message,
    required this.successful,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          successful
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          color: successful ? _success : _danger,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: successful ? _success : _danger,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasized ? _ink : _muted,
              fontSize: emphasized ? 16 : 14,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: emphasized ? _primary : _ink,
            fontSize: emphasized ? 18 : 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PickerDateCard extends StatelessWidget {
  final String label;
  final String value;
  final bool active;

  const _PickerDateCard({
    required this.label,
    required this.value,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: active ? _primary : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? _primary : _muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DurationChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
