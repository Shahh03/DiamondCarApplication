import 'package:flutter/material.dart';

import '../../api/renter_api.dart';

class EditProfilePage extends StatefulWidget {
  final String id;

  const EditProfilePage({
    super.key,
    required this.id,
  });

  @override
  State<EditProfilePage> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfilePage> {
  static const _primary = Color(0xFF1D4ED8);
  static const _background = Color(0xFFF5F7FB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController firstNameController;
  late final TextEditingController lastNameController;
  late final TextEditingController nationalityController;
  late final TextEditingController occupationController;
  late final TextEditingController locationController;

  DateTime? birthDate;
  String? gender;

  bool isLoading = true;
  bool isSaving = false;
  String? loadError;

  final List<String> genderOptions = const ['Male', 'Female'];

  final List<String> nationalityOptions = [
    'Argentina',
    'Australia',
    'Brazil',
    'Canada',
    'China',
    'Egypt',
    'France',
    'Germany',
    'India',
    'Italy',
    'Japan',
    'Mexico',
    'Netherlands',
    'Saudi Arabia',
    'South Africa',
    'Spain',
    'Turkey',
    'UAE',
    'United Kingdom',
    'United States',
  ];

  @override
  void initState() {
    super.initState();
    firstNameController = TextEditingController();
    lastNameController = TextEditingController();
    nationalityController = TextEditingController();
    occupationController = TextEditingController();
    locationController = TextEditingController();
    getUserData();
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    nationalityController.dispose();
    occupationController.dispose();
    locationController.dispose();
    super.dispose();
  }

  Future<void> getUserData() async {
    try {
      final data = await RenterApi.getUserById(widget.id);
      if (!mounted) return;

      final fullName = (data['name'] ?? '').toString().trim();
      final nameParts = fullName.isEmpty
          ? <String>[]
          : fullName.split(RegExp(r'\s+'));
      final dbNationality = data['nationality']?.toString().trim() ?? '';
      final dbGender = data['gender']?.toString().trim().toLowerCase();

      if (dbNationality.isNotEmpty &&
          !nationalityOptions.contains(dbNationality)) {
        nationalityOptions.add(dbNationality);
        nationalityOptions.sort();
      }

      setState(() {
        firstNameController.text = nameParts.isEmpty ? '' : nameParts.first;
        lastNameController.text =
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        nationalityController.text = dbNationality;
        occupationController.text = data['occupation']?.toString() ?? '';
        locationController.text = data['location']?.toString() ?? '';

        if (dbGender == 'male') {
          gender = 'Male';
        } else if (dbGender == 'female') {
          gender = 'Female';
        } else {
          gender = null;
        }

        birthDate = data['birthDate'] == null
            ? null
            : DateTime.tryParse(data['birthDate'].toString());
        isLoading = false;
        loadError = null;
      });
    } catch (error) {
      debugPrint('Error loading profile: $error');
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = 'We could not load your profile. Please try again.';
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });
    await getUserData();
  }

  Future<void> saveChanges() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (birthDate == null) {
      _showMessage('Please select your birth date.', isError: true);
      return;
    }

    setState(() => isSaving = true);

    try {
      await RenterApi.updateRenterProfile(
        renterId: widget.id,
        name:
            '${firstNameController.text.trim()} ${lastNameController.text.trim()}',
        nationality: nationalityController.text.trim(),
        occupation: occupationController.text.trim(),
        location: locationController.text.trim(),
        gender: gender,
        birthDate: birthDate,
      );

      if (!mounted) return;
      _showMessage('Profile updated successfully.');
      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('Error updating profile: $error');
      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
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
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
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

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(now.year - 22),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'SELECT BIRTH DATE',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => birthDate = picked);
    }
  }

  String _formatDate(DateTime date) {
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

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Keep your account information up to date',
              style: TextStyle(
                color: Color(0xFFDCEBFF),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
    );
  }

  Widget _buildBody() {
    if (isLoading) return const _EditProfileLoading();
    if (loadError != null) return _EditProfileError(onRetry: _retry);

    final nationalityValue =
        nationalityOptions.contains(nationalityController.text)
            ? nationalityController.text
            : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 720 ? 28.0 : 16.0;

        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FormIntro(),
                    const SizedBox(height: 18),
                    _FormSection(
                      icon: Icons.badge_outlined,
                      title: 'Personal information',
                      subtitle: 'Your basic identity details',
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, fieldConstraints) {
                              if (fieldConstraints.maxWidth >= 520) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        controller: firstNameController,
                                        label: 'First name',
                                        icon: Icons.person_outline_rounded,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.givenName,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextField(
                                        controller: lastNameController,
                                        label: 'Last name',
                                        icon: Icons.person_outline_rounded,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.familyName,
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _buildTextField(
                                    controller: firstNameController,
                                    label: 'First name',
                                    icon: Icons.person_outline_rounded,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.givenName,
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  _buildTextField(
                                    controller: lastNameController,
                                    label: 'Last name',
                                    icon: Icons.person_outline_rounded,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.familyName,
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildDropdown(
                            label: 'Nationality',
                            value: nationalityValue,
                            items: nationalityOptions,
                            icon: Icons.flag_outlined,
                            onChanged: (value) {
                              setState(() {
                                nationalityController.text = value ?? '';
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildDropdown(
                            label: 'Gender',
                            value: gender,
                            items: genderOptions,
                            icon: Icons.wc_outlined,
                            onChanged: (value) => setState(() => gender = value),
                          ),
                          const SizedBox(height: 14),
                          _BirthDateField(
                            value: birthDate == null
                                ? null
                                : _formatDate(birthDate!),
                            onTap: isSaving ? null : _pickBirthDate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _FormSection(
                      icon: Icons.work_outline_rounded,
                      title: 'Additional details',
                      subtitle: 'Information that helps personalize your account',
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: occupationController,
                            label: 'Occupation',
                            icon: Icons.work_outline_rounded,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: locationController,
                            label: 'Location',
                            icon: Icons.location_on_outlined,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.addressCity],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: isSaving ? null : saveChanges,
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          disabledBackgroundColor: const Color(0xFF93C5FD),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        icon: isSaving
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.3,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 21),
                        label: Text(
                          isSaving ? 'Saving changes…' : 'Save changes',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'Your information is used to manage your rentals.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputAction? textInputAction,
    List<String>? autofillHints,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !isSaving,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(
        color: _ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(label, icon),
      validator: (value) => _requiredValidator(value, label),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    final safeValue = items.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      isExpanded: true,
      menuMaxHeight: 340,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: isSaving ? null : onChanged,
      decoration: _inputDecoration(label, icon),
      validator: (selected) => _requiredValidator(selected, label),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: _muted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, size: 20, color: _primary),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }
}

class _FormIntro extends StatelessWidget {
  const _FormIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _EditProfileState._primary),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Make sure these details match your identification documents.',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _FormSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _EditProfileState._border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: _EditProfileState._primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _EditProfileState._ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _EditProfileState._muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _BirthDateField extends StatelessWidget {
  final String? value;
  final VoidCallback? onTap;

  const _BirthDateField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: ValueKey(value),
      initialValue: value,
      validator: (_) => value == null ? 'Birth date is required' : null,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: field.hasError
                          ? const Color(0xFFDC2626)
                          : _EditProfileState._border,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: _EditProfileState._primary,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Birth date',
                              style: TextStyle(
                                color: _EditProfileState._muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              value ?? 'Select your birth date',
                              style: TextStyle(
                                color: value == null
                                    ? const Color(0xFF94A3B8)
                                    : _EditProfileState._ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
            ),
            if (field.hasError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 13),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _EditProfileError extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _EditProfileError({required this.onRetry});

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
                color: _EditProfileState._primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Couldn’t load your profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _EditProfileState._ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _EditProfileState._muted),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: _EditProfileState._primary,
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

class _EditProfileLoading extends StatelessWidget {
  const _EditProfileLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 74,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        const SizedBox(height: 18),
        ...List.generate(
          2,
          (_) => Container(
            height: 270,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _EditProfileState._border),
            ),
          ),
        ),
      ],
    );
  }
}
