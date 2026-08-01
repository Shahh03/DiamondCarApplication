import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project/renter/navbar_pages/bottom_nav_bar.dart';

import '../../api/renter_api.dart';
import 'Settings/settings.dart';
import 'currencySelector.dart';
import 'editProfile.dart';
import 'wishlist/myWishlist.dart';

class RenterProfile extends StatefulWidget {
  final String id;

  const RenterProfile({super.key, required this.id});

  @override
  State<RenterProfile> createState() => _RenterProfileState();
}

class _RenterProfileState extends State<RenterProfile> {
  static const _primary = Color(0xFF1D4ED8);
  static const _background = Color(0xFFF5F7FB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? userData;
  File? _imageFile;
  bool isLoading = true;
  bool isUploadingImage = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    getUserData();
  }

  Future<void> getUserData() async {
    try {
      final data = await RenterApi.getUserById(widget.id);
      if (!mounted) return;

      setState(() {
        userData = data;
        isLoading = false;
        loadError = null;
      });
    } catch (error) {
      debugPrint('Error loading profile: $error');
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'We could not load your account. Please try again.';
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    await getUserData();
  }

  String _profileImageUrl(Map<String, dynamic> user) {
    final picture = user['profilePicture'];
    if (picture is String && picture.trim().isNotEmpty) {
      return picture.trim();
    }
    return '';
  }

  String _displayValue(dynamic value, {String fallback = 'Not provided'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String get _userId {
    final id = userData?['_id']?.toString().trim() ?? '';
    return id.isEmpty ? widget.id : id;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (pickedFile == null || !mounted) return;

      final file = File(pickedFile.path);
      setState(() => _imageFile = file);
      await _uploadProfileImage(file);
    } catch (error) {
      debugPrint('pickImage error: $error');
      if (!mounted) return;

      _showMessage('Could not select that image.', isError: true);
    }
  }

  Future<void> _uploadProfileImage(File image) async {
    setState(() => isUploadingImage = true);

    try {
      await RenterApi.uploadRenterImage(
        renterId: widget.id,
        image: image,
      );
      await getUserData();

      if (!mounted) return;
      setState(() {
        _imageFile = null;
        isUploadingImage = false;
      });
      _showMessage('Profile photo updated.');
    } catch (error) {
      debugPrint('Upload error: $error');
      if (!mounted) return;

      setState(() {
        _imageFile = null;
        isUploadingImage = false;
      });
      _showMessage('Image upload failed. Please try again.', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor:
              isError ? const Color(0xFFB91C1C) : const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showChangePictureOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Update profile photo',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Choose how you want to add your new photo.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 18),
                _PhotoSourceTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Take a photo',
                  subtitle: 'Use your device camera',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                _PhotoSourceTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from gallery',
                  subtitle: 'Select an existing photo',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(id: _userId)),
    );

    if (mounted) await getUserData();
  }

  Future<void> logOut() async {
    try {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (error) {
      debugPrint('Error logging out: $error');
      if (mounted) {
        _showMessage('Could not log out. Please try again.', isError: true);
      }
    }
  }

  Future<void> showLogOutDialog() async {
    final shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFB91C1C),
              size: 28,
            ),
          ),
          title: const Text(
            'Log out?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'You’ll need to sign in again to access your bookings.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, height: 1.4),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
              ),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (shouldLogOut == true) await logOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        toolbarHeight: 76,
        titleSpacing: 20,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'My Account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Profile, preferences and support',
              style: TextStyle(
                color: Color(0xFFDCEBFF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton.filled(
              tooltip: 'Refresh account',
              onPressed: isLoading ? null : _refresh,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
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
      body: SafeArea(top: false, child: _buildBody()),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        userId: widget.id,
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) return const _ProfileLoadingView();

    if (loadError != null || userData == null) {
      return _ProfileErrorView(onRetry: _refresh);
    }

    final user = userData!;
    final username = _displayValue(user['username'], fallback: 'DiamondCar user');
    final email = _displayValue(user['email']);
    final fullName = _displayValue(user['name'], fallback: username);
    final rentals = _displayValue(user['rentals'], fallback: '0');
    final rating = _displayValue(user['rating'], fallback: '0');
    final currency = _displayValue(user['currency'], fallback: 'Select');

    return RefreshIndicator(
      color: _primary,
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 720 ? 28.0 : 16.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    _ProfileHero(
                      fullName: fullName,
                      username: username,
                      email: email,
                      imageFile: _imageFile,
                      imageUrl: _profileImageUrl(user),
                      isUploading: isUploadingImage,
                      onChangePhoto: isUploadingImage
                          ? null
                          : _showChangePictureOptions,
                    ),
                    const SizedBox(height: 16),
                    _StatsCard(rentals: rentals, rating: rating),
                    const SizedBox(height: 20),
                    _MenuSection(
                      title: 'Account',
                      children: [
                        _AccountMenuTile(
                          icon: Icons.person_outline_rounded,
                          title: 'Edit profile',
                          subtitle: 'Personal details and contact information',
                          onTap: _openEditProfile,
                        ),
                        const _MenuDivider(),
                        _AccountMenuTile(
                          icon: Icons.favorite_border_rounded,
                          title: 'My wishlist',
                          subtitle: 'Cars you saved for later',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WishlistPage(renterId: _userId),
                              ),
                            );
                          },
                        ),
                        const _MenuDivider(),
                        _AccountMenuTile(
                          icon: Icons.currency_exchange_rounded,
                          title: 'Currency',
                          subtitle: 'Choose how prices are displayed',
                          trailingLabel: currency,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CurrencySelectorPage(id: _userId),
                              ),
                            );
                            if (mounted) await getUserData();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _MenuSection(
                      title: 'Preferences & support',
                      children: [
                        _AccountMenuTile(
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          subtitle: 'Security and account preferences',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SettingsPage(id: _userId),
                              ),
                            );
                          },
                        ),
                        const _MenuDivider(),
                        _AccountMenuTile(
                          icon: Icons.help_outline_rounded,
                          title: 'Help & support',
                          subtitle: 'Get help with your DiamondCar account',
                          onTap: () {
                            _showMessage('Help & support will be available soon.');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _LogoutButton(onPressed: showLogOutDialog),
                    const SizedBox(height: 8),
                    const Text(
                      'DiamondCar mobile',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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
}

class _ProfileHero extends StatelessWidget {
  final String fullName;
  final String username;
  final String email;
  final File? imageFile;
  final String imageUrl;
  final bool isUploading;
  final VoidCallback? onChangePhoto;

  const _ProfileHero({
    required this.fullName,
    required this.username,
    required this.email,
    required this.imageFile,
    required this.imageUrl,
    required this.isUploading,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _RenterProfileState._border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Container(
                    color: const Color(0xFFEFF6FF),
                    child: imageFile != null
                        ? Image.file(imageFile!, fit: BoxFit.cover)
                        : imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const _AvatarPlaceholder(showLoader: true);
                                },
                                errorBuilder: (_, __, ___) =>
                                    const _AvatarPlaceholder(),
                              )
                            : const _AvatarPlaceholder(),
                  ),
                ),
              ),
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0x80000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Material(
                  color: _RenterProfileState._primary,
                  shape: const CircleBorder(
                    side: BorderSide(color: Colors.white, width: 3),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onChangePhoto,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _RenterProfileState._ink,
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _RenterProfileState._primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _RenterProfileState._muted,
                    fontSize: 12,
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

class _StatsCard extends StatelessWidget {
  final String rentals;
  final String rating;

  const _StatsCard({required this.rentals, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 17),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.key_rounded,
              value: rentals,
              label: 'Rentals',
            ),
          ),
          Container(width: 1, height: 42, color: const Color(0xFFBFDBFE)),
          Expanded(
            child: _StatItem(
              icon: Icons.star_rounded,
              value: rating,
              label: 'Rating',
              iconColor: Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor = _RenterProfileState._primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: _RenterProfileState._ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: _RenterProfileState._muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _MenuSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _RenterProfileState._border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback onTap;

  const _AccountMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: _RenterProfileState._primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _RenterProfileState._ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _RenterProfileState._muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingLabel != null) ...[
                Container(
                  constraints: const BoxConstraints(maxWidth: 72),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    trailingLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _LogoutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text(
          'Log out',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFB91C1C),
          backgroundColor: const Color(0xFFFFFBFB),
          side: const BorderSide(color: Color(0xFFFECACA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}

class _PhotoSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PhotoSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: _RenterProfileState._primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _RenterProfileState._ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _RenterProfileState._muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  final bool showLoader;

  const _AvatarPlaceholder({this.showLoader = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF6FF),
      child: Center(
        child: showLoader
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : const Icon(
                Icons.person_rounded,
                size: 50,
                color: Color(0xFF93C5FD),
              ),
      ),
    );
  }
}

class _ProfileErrorView extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ProfileErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_off_outlined,
                size: 42,
                color: _RenterProfileState._primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Couldn’t load your account',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _RenterProfileState._ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _RenterProfileState._muted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: _RenterProfileState._primary,
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

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 138,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _RenterProfileState._border),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 82,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(
          2,
          (_) => Container(
            height: 190,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _RenterProfileState._border),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 69,
      endIndent: 14,
      color: _RenterProfileState._border,
    );
  }
}
