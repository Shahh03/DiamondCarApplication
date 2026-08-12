import 'package:flutter/material.dart';

import '../provider_ui.dart';

class ProviderFleetPage extends StatefulWidget {
  final String providerId;

  const ProviderFleetPage({super.key, required this.providerId});

  @override
  State<ProviderFleetPage> createState() => _ProviderFleetPageState();
}

class _ProviderFleetPageState extends State<ProviderFleetPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddCar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The Add Car form is the next screen.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            ProviderPageHeader(
              title: 'My fleet',
              subtitle: 'Manage your cars, pricing and availability.',
              action: IconButton.filled(
                onPressed: _openAddCar,
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(backgroundColor: providerPrimary),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by brand, model or registration',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: providerBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: providerBorder),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ProviderEmptyState(
              icon: Icons.directions_car_outlined,
              title: 'No cars loaded yet',
              message:
                  'Your provider-owned CarVariant records will appear here.',
              actionLabel: 'Add your first car',
              onAction: _openAddCar,
            ),
          ],
        ),
      ),
    );
  }
}

