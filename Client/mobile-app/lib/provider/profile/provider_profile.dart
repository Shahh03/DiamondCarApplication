import 'package:flutter/material.dart';

import '../provider_data_scope.dart';
import '../provider_ui.dart';

const _surface = Colors.white;
const _softBlue = Color(0xFFEFF6FF);
const _success = Color(0xFF059669);
const _orange = Color(0xFFEA580C);
const _danger = Color(0xFFDC2626);

class ProviderProfilePage extends StatelessWidget {
  final String providerId;
  final Future<void> Function() onLogout;

  const ProviderProfilePage({
    super.key,
    required this.providerId,
    required this.onLogout,
  });

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          20 + MediaQuery.viewPaddingOf(sheetContext).bottom,
        ),
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: providerBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: _danger),
              ),
              const SizedBox(height: 14),
              const Text(
                'Log out of DiamondCar?',
                style: TextStyle(
                  color: providerInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'You will need to sign in again to manage your provider account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: providerMuted, height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Keep me signed in'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: _danger,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Log out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) await onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ProviderDataScope.of(context);
    final provider = scope.provider;
    final contact = _map(provider['contactPerson']);
    final address = _map(provider['address']);
    final bank = _map(provider['bankDetails']);
    final documents = _map(provider['verificationDocuments']);
    final license = _map(documents['license']);
    final idCard = _map(documents['idCard']);

    final companyName = scope.companyName;
    final currency = scope.currency;
    final accountStatus = _value(provider['status'], 'Pending');
    final isVerified = provider['isVerified'] == true;
    final contactName = _value(contact['name']);
    final contactEmail = _firstValue([
      contact['email'],
      provider['email'],
    ]);
    final contactPhone = _value(contact['phoneNumber']);
    final location = _address(address);
    final bankConfigured = _hasValues(
      bank,
      const ['accountHolderName', 'accountNumber', 'bankName'],
    );
    final documentsReady =
        _raw(license['filepath']).isNotEmpty &&
        _raw(idCard['filepath']).isNotEmpty;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: scope.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
          children: [
            _ProfileHeader(onRefresh: scope.refresh),
            const SizedBox(height: 18),
            _ProfileHero(
              companyName: companyName,
              profilePicture: scope.profilePicture,
              status: accountStatus,
              verified: isVerified,
              location: location,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ReadinessCard(
                    icon: Icons.account_balance_outlined,
                    label: 'Payout account',
                    value: bankConfigured ? 'Configured' : 'Action required',
                    ready: bankConfigured,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReadinessCard(
                    icon: Icons.verified_user_outlined,
                    label: 'Documents',
                    value: documentsReady ? 'Submitted' : 'Incomplete',
                    ready: documentsReady,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle(
              eyebrow: 'BUSINESS',
              title: 'Company information',
            ),
            const SizedBox(height: 11),
            _DetailsCard(
              children: [
                _DetailRow(
                  icon: Icons.storefront_outlined,
                  label: 'Company name',
                  value: companyName,
                ),
                _DetailRow(
                  icon: Icons.badge_outlined,
                  label: 'Registration number',
                  value: _value(provider['registrationNumber']),
                ),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Business address',
                  value: location,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle(
              eyebrow: 'PRIMARY CONTACT',
              title: 'Contact person',
            ),
            const SizedBox(height: 11),
            _ContactCard(
              name: contactName,
              email: contactEmail,
              phone: contactPhone,
            ),
            const SizedBox(height: 24),
            const _SectionTitle(
              eyebrow: 'ACCOUNT',
              title: 'Preferences and access',
            ),
            const SizedBox(height: 11),
            _DetailsCard(
              children: [
                _DetailRow(
                  icon: Icons.alternate_email_rounded,
                  label: 'Username',
                  value: _value(provider['username']),
                ),
                _DetailRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Sign-in email',
                  value: _value(provider['email']),
                ),
                _DetailRow(
                  icon: Icons.currency_exchange_rounded,
                  label: 'Operating currency',
                  value: currency,
                ),
                _DetailRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'Provider reference',
                  value: _shortReference(providerId),
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _PortalNotice(),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _danger,
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _ProfileHeader({required this.onRefresh});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile',
                  style: TextStyle(
                    color: providerInk,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your provider account at a glance',
                  style: TextStyle(color: providerMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Refresh profile',
            style: IconButton.styleFrom(
              backgroundColor: _surface,
              side: const BorderSide(color: providerBorder),
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      );
}

class _ProfileHero extends StatelessWidget {
  final String companyName;
  final String profilePicture;
  final String status;
  final bool verified;
  final String location;

  const _ProfileHero({
    required this.companyName,
    required this.profilePicture,
    required this.status,
    required this.verified,
    required this.location,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [providerPrimaryDark, providerPrimary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x242563EB),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProviderAvatar(imageUrl: profilePicture),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companyName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (location != 'Not provided')
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFFDBEAFE),
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFDBEAFE),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _HeroBadge(
                        label: status,
                        color: _accountStatusColor(status),
                      ),
                      _HeroBadge(
                        label: verified ? 'Verified' : 'Not verified',
                        color: verified ? _success : _orange,
                        icon: verified
                            ? Icons.verified_rounded
                            : Icons.shield_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ProviderAvatar extends StatelessWidget {
  final String imageUrl;

  const _ProviderAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        height: 72,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.24),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: imageUrl.isEmpty
              ? const ColoredBox(
                  color: _softBlue,
                  child: Icon(
                    Icons.storefront_rounded,
                    color: providerPrimary,
                    size: 34,
                  ),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const ColoredBox(
                          color: _softBlue,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: _softBlue,
                    child: Icon(
                      Icons.storefront_rounded,
                      color: providerPrimary,
                      size: 34,
                    ),
                  ),
                ),
        ),
      );
}

class _HeroBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _HeroBadge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
            ] else ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _ReadinessCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool ready;

  const _ReadinessCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    final color = ready ? _success : _orange;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: providerBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ready
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: providerMuted,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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

class _SectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;

  const _SectionTitle({required this.eyebrow, required this.title});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: providerPrimary,
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              color: providerInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
}

class _DetailsCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailsCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: providerBorder),
        ),
        child: Column(children: children),
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _softBlue,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: providerPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: providerMuted,
                          fontSize: 9,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: providerInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
            const Divider(height: 1, indent: 58, color: providerBorder),
        ],
      );
}

class _ContactCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;

  const _ContactCard({
    required this.name,
    required this.email,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name == 'Not provided' || name.isEmpty
        ? 'P'
        : name.substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: providerBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _softBlue,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: providerPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: providerInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                _ContactLine(icon: Icons.mail_outline_rounded, text: email),
                const SizedBox(height: 4),
                _ContactLine(icon: Icons.phone_outlined, text: phone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: providerMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: providerMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}

class _PortalNotice extends StatelessWidget {
  const _PortalNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _softBlue,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.admin_panel_settings_outlined, color: providerPrimary),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sensitive changes use the web portal',
                    style: TextStyle(
                      color: providerPrimaryDark,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Update company registration, bank details, verification documents and account settings in the private management portal.',
                    style: TextStyle(
                      color: providerPrimaryDark,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

Map<String, dynamic> _map(dynamic value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

String _raw(dynamic value) => value?.toString().trim() ?? '';

String _value(dynamic value, [String fallback = 'Not provided']) {
  final text = _raw(value);
  return text.isEmpty ? fallback : text;
}

String _firstValue(List<dynamic> values) {
  for (final value in values) {
    final text = _raw(value);
    if (text.isNotEmpty) return text;
  }
  return 'Not provided';
}

String _address(Map<String, dynamic> address) {
  final parts = [
    address['street'],
    address['city'],
    address['state'],
    address['country'],
    address['postalCode'],
  ].map(_raw).where((value) => value.isNotEmpty).toList();
  return parts.isEmpty ? 'Not provided' : parts.join(', ');
}

bool _hasValues(Map<String, dynamic> value, List<String> fields) =>
    fields.every((field) => _raw(value[field]).isNotEmpty);

Color _accountStatusColor(String status) => switch (status.toLowerCase()) {
      'accepted' => _success,
      'rejected' => _danger,
      _ => _orange,
    };

String _shortReference(String value) {
  if (value.isEmpty) return 'Not provided';
  return value.length <= 8
      ? value.toUpperCase()
      : value.substring(value.length - 8).toUpperCase();
}
