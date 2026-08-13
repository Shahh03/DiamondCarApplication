import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/provider_earnings_api.dart';
import '../provider_ui.dart';

enum _EarningsPeriod { thisMonth, lastMonth, lastSixMonths, custom }

class ProviderEarningsPage extends StatefulWidget {
  final String providerId;

  const ProviderEarningsPage({
    super.key,
    required this.providerId,
  });

  @override
  State<ProviderEarningsPage> createState() => _ProviderEarningsPageState();
}

class _ProviderEarningsPageState extends State<ProviderEarningsPage> {
  _EarningsPeriod _period = _EarningsPeriod.thisMonth;
  DateTimeRange? _customRange;
  Map<String, dynamic>? _earnings;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  DateTimeRange get _selectedRange {
    final now = DateTime.now();
    switch (_period) {
      case _EarningsPeriod.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month),
          end: now,
        );
      case _EarningsPeriod.lastMonth:
        final start = DateTime(now.year, now.month - 1);
        return DateTimeRange(
          start: start,
          end: DateTime(now.year, now.month).subtract(
            const Duration(milliseconds: 1),
          ),
        );
      case _EarningsPeriod.lastSixMonths:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 5),
          end: now,
        );
      case _EarningsPeriod.custom:
        return _customRange ?? DateTimeRange(start: now, end: now);
    }
  }

  DateTime _endOfDay(DateTime value) => DateTime(
        value.year,
        value.month,
        value.day,
        23,
        59,
        59,
        999,
      );

  Future<void> _loadEarnings() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final range = _selectedRange;
      final earnings = await ProviderEarningsApi.getEarnings(
        providerId: widget.providerId,
        from: range.start,
        to: _endOfDay(range.end),
      );
      if (!mounted) return;
      setState(() {
        _earnings = earnings;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _changePeriod(_EarningsPeriod value) async {
    if (value == _EarningsPeriod.custom) {
      final now = DateTime.now();
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 1, now.month, now.day),
        lastDate: now,
        initialDateRange: _customRange,
        helpText: 'Select earnings period',
      );
      if (selected == null || !mounted) return;
      _customRange = selected;
    }

    setState(() => _period = value);
    await _loadEarnings();
  }

  String get _periodLabel {
    switch (_period) {
      case _EarningsPeriod.thisMonth:
        return 'This month';
      case _EarningsPeriod.lastMonth:
        return 'Last month';
      case _EarningsPeriod.lastSixMonths:
        return 'Last 6 months';
      case _EarningsPeriod.custom:
        final range = _customRange;
        if (range == null) return 'Custom range';
        final formatter = DateFormat('d MMM');
        return '${formatter.format(range.start)} – ${formatter.format(range.end)}';
    }
  }

  Map<String, dynamic> get _summary => _asMap(_earnings?['summary']);

  List<Map<String, dynamic>> get _chart => _mapList(_earnings?['chart']);

  List<Map<String, dynamic>> get _transactions =>
      _mapList(_earnings?['transactions']);

  String get _currency {
    final value = _earnings?['currency']?.toString().trim().toUpperCase();
    return value?.isNotEmpty == true ? value! : 'AED';
  }

  String _money(dynamic value) {
    final amount = value is num ? value : num.tryParse('$value') ?? 0;
    return '$_currency ${NumberFormat('#,##0.00').format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadEarnings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            ProviderPageHeader(
              title: 'Earnings',
              subtitle: 'Track collections, deposits and refunds.',
              action: PopupMenuButton<_EarningsPeriod>(
                tooltip: 'Change period',
                initialValue: _period,
                onSelected: _changePeriod,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _EarningsPeriod.thisMonth,
                    child: Text('This month'),
                  ),
                  PopupMenuItem(
                    value: _EarningsPeriod.lastMonth,
                    child: Text('Last month'),
                  ),
                  PopupMenuItem(
                    value: _EarningsPeriod.lastSixMonths,
                    child: Text('Last 6 months'),
                  ),
                  PopupMenuItem(
                    value: _EarningsPeriod.custom,
                    child: Text('Custom range'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: providerBorder),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: providerPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _periodLabel,
                        style: const TextStyle(
                          color: providerInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_isLoading && _earnings == null)
              const _EarningsSkeleton()
            else if (_error != null && _earnings == null)
              ProviderEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load earnings',
                message: _error!,
                actionLabel: 'Try again',
                onAction: _loadEarnings,
              )
            else ...[
              _NetEarningsCard(
                value: _money(_summary['netEarnings']),
                period: _periodLabel,
                currency: _currency,
                paymentCount: (_summary['paymentCount'] as num?)?.toInt() ?? 0,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _EarningStat(
                      label: 'Rental revenue',
                      value: _money(_summary['rentalRevenue']),
                      icon: Icons.payments_outlined,
                      color: const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EarningStat(
                      label: 'Deposits collected',
                      value: _money(_summary['depositsCollected']),
                      icon: Icons.savings_outlined,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _EarningStat(
                      label: 'Gross collected',
                      value: _money(_summary['grossCollected']),
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _EarningStat(
                      label: 'Refunds',
                      value: _money(_summary['refunds']),
                      icon: Icons.undo_rounded,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ChartCard(
                points: _chart,
                currency: _currency,
                periodLabel: _periodLabel,
              ),
              const SizedBox(height: 18),
              _TransactionsSection(
                transactions: _transactions,
                money: _money,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _InlineError(message: _error!, onRetry: _loadEarnings),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _NetEarningsCard extends StatelessWidget {
  final String value;
  final String period;
  final String currency;
  final int paymentCount;

  const _NetEarningsCard({
    required this.value,
    required this.period,
    required this.currency,
    required this.paymentCount,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [providerPrimaryDark, providerPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x242563EB),
              blurRadius: 22,
              offset: Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Net collected',
                    style: TextStyle(
                      color: Color(0xFFDBEAFE),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x24FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    period,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$paymentCount payment${paymentCount == 1 ? '' : 's'} · $currency',
              style: const TextStyle(color: Color(0xFFBFDBFE)),
            ),
          ],
        ),
      );
}

class _EarningStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _EarningStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => ProviderSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 13),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: providerInk,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: providerMuted, fontSize: 11),
            ),
          ],
        ),
      );
}

class _ChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  final String currency;
  final String periodLabel;

  const _ChartCard({
    required this.points,
    required this.currency,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) => ProviderSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cash flow',
                    style: TextStyle(
                      color: providerInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  periodLabel,
                  style: const TextStyle(
                    color: providerMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Payments minus refunds · $currency',
              style: const TextStyle(color: providerMuted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            if (points.isEmpty)
              const SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    'No cash-flow activity in this period',
                    style: TextStyle(color: providerMuted),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 165,
                width: double.infinity,
                child: CustomPaint(
                  painter: _CashFlowPainter(points),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _LegendDot(
                    color: providerPrimary,
                    text: points.first['period']?.toString() ?? '',
                  ),
                  const Spacer(),
                  _LegendDot(
                    color: const Color(0xFF93C5FD),
                    text: points.last['period']?.toString() ?? '',
                  ),
                ],
              ),
            ],
          ],
        ),
      );
}

class _CashFlowPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;

  const _CashFlowPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final values = points
        .map((point) => (point['net'] as num?)?.toDouble() ?? 0)
        .toList();
    final maxValue = math.max(
      1.0,
      values.fold<double>(
        0,
        (largest, value) => math.max(largest, value.abs()).toDouble(),
      ),
    );
    final zeroY = values.any((value) => value < 0) ? size.height / 2 : size.height;
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = providerPrimary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x332563EB), Color(0x002563EB)],
      ).createShader(Offset.zero & size);

    for (var index = 0; index <= 3; index++) {
      final y = size.height * index / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), gridPaint);

    final path = Path();
    final fillPath = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final availableHeight = values.any((value) => value < 0)
          ? size.height / 2 - 8
          : size.height - 8;
      final y = zeroY - (values[index] / maxValue) * availableHeight;
      if (index == 0) {
        path.moveTo(x, y);
        fillPath
          ..moveTo(x, zeroY)
          ..lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = providerPrimary);
    }
    final lastX = values.length == 1 ? size.width / 2 : size.width;
    fillPath
      ..lineTo(lastX, zeroY)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(_CashFlowPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendDot({required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: providerMuted, fontSize: 10),
          ),
        ],
      );
}

class _TransactionsSection extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final String Function(dynamic) money;

  const _TransactionsSection({
    required this.transactions,
    required this.money,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent transactions',
            style: TextStyle(
              color: providerInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const ProviderEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              message: 'Completed payments and refunds will appear here.',
            )
          else
            ...transactions.map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionCard(
                  transaction: transaction,
                  money: money,
                ),
              ),
            ),
        ],
      );
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String Function(dynamic) money;

  const _TransactionCard({
    required this.transaction,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final isRefund = transaction['type'] == 'Refund';
    final date = DateTime.tryParse(transaction['date']?.toString() ?? '');
    final vehicle = transaction['vehicle']?.toString() ?? 'Vehicle';
    final renter = transaction['renterName']?.toString() ?? 'Renter';
    final method = transaction['paymentMethod']?.toString() ?? 'Card';

    return ProviderSectionCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isRefund
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isRefund ? Icons.undo_rounded : Icons.south_west_rounded,
              color: isRefund
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRefund ? 'Refund · $vehicle' : vehicle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: providerInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$renter · $method${date == null ? '' : ' · ${DateFormat('d MMM, h:mm a').format(date.toLocal())}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: providerMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            money(transaction['amount']),
            style: TextStyle(
              color: isRefund
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF059669),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _EarningsSkeleton extends StatelessWidget {
  const _EarningsSkeleton();

  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          4,
          (index) => Container(
            height: index == 0 ? 145 : 92,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: index == 0 ? const Color(0xFFDBEAFE) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: providerBorder),
            ),
          ),
        ),
      );
}

Map<String, dynamic> _asMap(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : <Map<String, dynamic>>[];
