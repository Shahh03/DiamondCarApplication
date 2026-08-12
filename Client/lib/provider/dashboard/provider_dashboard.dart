import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../provider_data_scope.dart';
import '../provider_ui.dart';

class ProviderDashboardPage extends StatelessWidget {
  final String providerId;
  final VoidCallback onOpenFleet;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenEarnings;

  const ProviderDashboardPage({
    super.key,
    required this.providerId,
    required this.onOpenFleet,
    required this.onOpenBookings,
    required this.onOpenEarnings,
  });

  @override
  Widget build(BuildContext context) {
    final providerScope = ProviderDataScope.of(context);
    final companyName = providerScope.companyName;
    final currency = providerScope.currency;
    final profilePicture = providerScope.profilePicture;
    final money = '$currency ${NumberFormat.decimalPattern().format(0)}';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: providerScope.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [providerPrimaryDark, Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Provider dashboard',
                            style: TextStyle(
                              color: Color(0xFFBFDBFE),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            companyName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Manage your cars, bookings and earnings.',
                            style: TextStyle(
                              color: Color(0xFFDBEAFE),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ProviderAvatar(imageUrl: profilePicture),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: SliverList.list(
                children: [
                  const ProviderPageHeader(
                    title: 'Overview',
                    subtitle: 'Live business data will appear here.',
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.32,
                    children: [
                      _MetricCard(
                        icon: Icons.directions_car_rounded,
                        label: 'Total cars',
                        value: '—',
                        color: providerPrimary,
                        onTap: onOpenFleet,
                      ),
                      _MetricCard(
                        icon: Icons.event_available_rounded,
                        label: 'Active bookings',
                        value: '—',
                        color: const Color(0xFF059669),
                        onTap: onOpenBookings,
                      ),
                      _MetricCard(
                        icon: Icons.payments_outlined,
                        label: 'Monthly revenue',
                        value: money,
                        color: const Color(0xFF7C3AED),
                        onTap: onOpenEarnings,
                      ),
                      _MetricCard(
                        icon: Icons.schedule_rounded,
                        label: 'Upcoming rentals',
                        value: '—',
                        color: const Color(0xFFEA580C),
                        onTap: onOpenBookings,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Quick actions',
                    style: TextStyle(
                      color: providerInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ProviderSectionCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: Icons.add_circle_outline_rounded,
                          title: 'Add a car',
                          subtitle: 'Create a new vehicle listing',
                          onTap: onOpenFleet,
                        ),
                        const Divider(height: 1, color: providerBorder),
                        _ActionTile(
                          icon: Icons.calendar_month_outlined,
                          title: 'View bookings',
                          subtitle: 'See confirmed and upcoming rentals',
                          onTap: onOpenBookings,
                        ),
                        const Divider(height: 1, color: providerBorder),
                        _ActionTile(
                          icon: Icons.insights_outlined,
                          title: 'View earnings',
                          subtitle: 'Review revenue and refunds',
                          onTap: onOpenEarnings,
                        ),
                      ],
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

class _ProviderAvatar extends StatelessWidget {
  final String imageUrl;

  const _ProviderAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: 56,
        height: 56,
        color: Colors.white.withOpacity(0.14),
        child: imageUrl.isEmpty
            ? const Icon(Icons.storefront_rounded, color: Colors.white, size: 29)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: providerBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: providerInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: providerMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: providerPrimary),
      ),
      title: Text(
        title,
        style: const TextStyle(color: providerInk, fontWeight: FontWeight.w800),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: providerMuted)),
      trailing: const Icon(Icons.chevron_right_rounded, color: providerMuted),
    );
  }
}
