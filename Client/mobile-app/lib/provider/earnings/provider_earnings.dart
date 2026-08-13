import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../provider_data_scope.dart';
import '../provider_ui.dart';

class ProviderEarningsPage extends StatelessWidget {
  final String providerId;

  const ProviderEarningsPage({
    super.key,
    required this.providerId,
  });

  @override
  Widget build(BuildContext context) {
    final scope = ProviderDataScope.of(context);
    final currency = scope.currency;

    String money(num value) {
      return '$currency ${NumberFormat.decimalPattern().format(value)}';
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: scope.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            const ProviderPageHeader(
              title: 'Earnings',
              subtitle:
                  'Track revenue, deposits, refunds and net earnings.',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    providerPrimaryDark,
                    providerPrimary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Net earnings this month',
                    style: TextStyle(
                      color: Color(0xFFDBEAFE),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    money(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All amounts shown in $currency',
                    style: const TextStyle(
                      color: Color(0xFFBFDBFE),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _EarningStat(
                    label: 'Rental revenue',
                    value: money(0),
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _EarningStat(
                    label: 'Refunds',
                    value: money(0),
                    icon: Icons.undo_rounded,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const ProviderEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              message:
                  'Completed payments and refunds will appear here.',
            ),
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return ProviderSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: providerInk,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: providerMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}