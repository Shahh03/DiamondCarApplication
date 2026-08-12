import 'package:flutter/material.dart';

import '../provider_ui.dart';

class ProviderBookingsPage extends StatefulWidget {
  final String providerId;

  const ProviderBookingsPage({super.key, required this.providerId});

  @override
  State<ProviderBookingsPage> createState() =>
      _ProviderBookingsPageState();
}

class _ProviderBookingsPageState extends State<ProviderBookingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: ProviderPageHeader(
              title: 'Bookings',
              subtitle: 'Paid bookings are confirmed automatically.',
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: providerPrimary,
            unselectedLabelColor: providerMuted,
            indicatorColor: providerPrimary,
            dividerColor: providerBorder,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _BookingEmpty(label: 'No upcoming bookings'),
                _BookingEmpty(label: 'No active rentals'),
                _BookingEmpty(label: 'No completed bookings'),
                _BookingEmpty(label: 'No cancelled bookings'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingEmpty extends StatelessWidget {
  final String label;

  const _BookingEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          ProviderEmptyState(
            icon: Icons.event_note_outlined,
            title: label,
            message: 'Bookings in this status will appear here.',
          ),
        ],
      ),
    );
  }
}

