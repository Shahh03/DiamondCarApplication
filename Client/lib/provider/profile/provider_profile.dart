import 'package:flutter/material.dart';

import '../provider_data_scope.dart';
import '../provider_ui.dart';

class ProviderProfilePage extends StatelessWidget {
  final String providerId;
  final Future<void> Function() onLogout;

  const ProviderProfilePage({
    super.key,
    required this.providerId,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final providerScope = ProviderDataScope.of(context);
    final provider = providerScope.provider;

    final companyName = providerScope.companyName;
    final currency = providerScope.currency;
    final profilePicture = providerScope.profilePicture;

    final contactPerson = _asMap(provider['contactPerson']);
    final address = _asMap(provider['address']);

    final contactName =
        contactPerson['name']?.toString().trim() ?? '';

    final location = [
      address['city']?.toString().trim() ?? '',
      address['country']?.toString().trim() ?? '',
    ].where((value) => value.isNotEmpty).join(', ');

    final status =
        provider['status']?.toString().trim() ?? 'Provider account';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: providerScope.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            const ProviderPageHeader(
              title: 'Profile',
              subtitle:
                  'Manage your company and provider account.',
            ),
            const SizedBox(height: 18),
            ProviderSectionCard(
              child: Row(
                children: [
                  _ProviderProfilePicture(
                    imageUrl: profilePicture,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: providerInk,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: const TextStyle(
                            color: providerMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ProviderSectionCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ProfileTile(
                    icon: Icons.business_outlined,
                    title: 'Company information',
                    trailingText: companyName,
                  ),
                  const Divider(
                    height: 1,
                    color: providerBorder,
                  ),
                  _ProfileTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Contact person',
                    trailingText:
                        contactName.isEmpty ? null : contactName,
                  ),
                  const Divider(
                    height: 1,
                    color: providerBorder,
                  ),
                  _ProfileTile(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    trailingText:
                        location.isEmpty ? null : location,
                  ),
                  const Divider(
                    height: 1,
                    color: providerBorder,
                  ),
                  const _ProfileTile(
                    icon: Icons.account_balance_outlined,
                    title: 'Bank and payout details',
                  ),
                  const Divider(
                    height: 1,
                    color: providerBorder,
                  ),
                  const _ProfileTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Verification documents',
                  ),
                  const Divider(
                    height: 1,
                    color: providerBorder,
                  ),
                  _ProfileTile(
                    icon: Icons.currency_exchange_rounded,
                    title: 'Currency',
                    trailingText: currency,
                  ),
                  const Divider(
                    height: 1,
                    color: providerBorder,
                  ),
                  const _ProfileTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(
                  color: Color(0xFFFCA5A5),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }
}

class _ProviderProfilePicture extends StatelessWidget {
  final String imageUrl;

  const _ProviderProfilePicture({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Container(
        width: 62,
        height: 62,
        color: const Color(0xFFEFF6FF),
        child: imageUrl.isEmpty
            ? const Icon(
                Icons.storefront_rounded,
                color: providerPrimary,
                size: 31,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const Icon(
                    Icons.storefront_rounded,
                    color: providerPrimary,
                    size: 31,
                  );
                },
              ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailingText;

  const _ProfileTile({
    required this.icon,
    required this.title,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: providerPrimary,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: providerInk,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null &&
              trailingText!.trim().isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 125,
              ),
              child: Text(
                trailingText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: providerMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: providerMuted,
          ),
        ],
      ),
    );
  }
}