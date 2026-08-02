import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

import 'api/auth_api.dart';

const _primary = Color(0xFF1D4ED8);
const _primaryDark = Color(0xFF1E40AF);
const _background = Color(0xFFF5F7FB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);
const _danger = Color(0xFFB91C1C);

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _stepKeys = List.generate(3, (_) => GlobalKey<FormState>());

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _occupationController = TextEditingController();
  final _locationController = TextEditingController();
  final _idCardController = TextEditingController();
  final _licenseController = TextEditingController();

  static const _stepTitles = ['Account', 'About you', 'Verification'];
  static const _nationalities = [
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

  int _currentStep = 0;
  DateTime? _selectedBirthDate;
  String? _selectedGender;
  String? _selectedNationality;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isLoading = false;

  @override
  void dispose() {
    for (final controller in [
      _usernameController,
      _emailController,
      _passwordController,
      _confirmPasswordController,
      _firstNameController,
      _middleNameController,
      _lastNameController,
      _phoneController,
      _occupationController,
      _locationController,
      _idCardController,
      _licenseController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_stepKeys[_currentStep].currentState?.validate() ?? false)) return;

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      return;
    }

    _submitSignup();
  }

  void _goBack() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _submitSignup() async {
    if (_isLoading) return;

    if (!_acceptedTerms) {
      _showMessage('Please accept the terms to continue.');
      return;
    }

    if (_selectedBirthDate == null ||
        _selectedGender == null ||
        _selectedNationality == null) {
      _showMessage('Some personal information is missing.');
      setState(() => _currentStep = 1);
      return;
    }

    final fullName = [
      _firstNameController.text.trim(),
      _middleNameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');

    setState(() => _isLoading = true);

    try {
      final message = await AuthApi.signup(
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        name: fullName,
        phoneNumber: _phoneController.text,
        birthDate: _selectedBirthDate!,
        gender: _selectedGender!,
        nationality: _selectedNationality!,
        idCardNumber: _idCardController.text,
        drivingLicenseNumber: _licenseController.text,
        occupation: _occupationController.text,
        location: _locationController.text,
        hasAcceptedTerms: _acceptedTerms,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(message, isError: false);
      Navigator.pushReplacementNamed(context, '/login');
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Something went wrong. Please try again.');
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: isError ? _danger : const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(now.year - 21),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select birth date',
    );

    if (picked != null && mounted) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          Container(
            height: 270,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryDark, _primary, Color(0xFF3B82F6)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopBar(onBack: _goBack),
                      const SizedBox(height: 22),
                      const Text(
                        'Create your account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A few details and you are ready to drive.',
                        style: TextStyle(
                          color: Color(0xFFDBEAFE),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SignupCard(
                        currentStep: _currentStep,
                        stepTitles: _stepTitles,
                        content: _buildCurrentStep(),
                        isLoading: _isLoading,
                        onBack: _goBack,
                        onContinue: _continue,
                        onLogin: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return Form(
          key: _stepKeys[0],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(
                controller: _usernameController,
                label: 'Username',
                hint: 'Choose a username',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
              ),
              _field(
                controller: _emailController,
                label: 'Email address',
                hint: 'name@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Enter your email address';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              _field(
                controller: _passwordController,
                label: 'Password',
                hint: 'Create a password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                suffix: _visibilityButton(
                  hidden: _obscurePassword,
                  onTap: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter a password';
                  if (value.length < 8) return 'Use at least 8 characters';
                  return null;
                },
              ),
              _field(
                controller: _confirmPasswordController,
                label: 'Confirm password',
                hint: 'Enter your password again',
                icon: Icons.verified_user_outlined,
                obscureText: _obscureConfirmation,
                textInputAction: TextInputAction.done,
                suffix: _visibilityButton(
                  hidden: _obscureConfirmation,
                  onTap: () => setState(
                    () => _obscureConfirmation = !_obscureConfirmation,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        );
      case 1:
        return Form(
          key: _stepKeys[1],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      controller: _firstNameController,
                      label: 'First name',
                      hint: 'First name',
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _lastNameController,
                      label: 'Last name',
                      hint: 'Last name',
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              _field(
                controller: _middleNameController,
                label: 'Middle name (optional)',
                hint: 'Middle name',
                icon: Icons.person_outline_rounded,
                isRequired: false,
                textInputAction: TextInputAction.next,
              ),
              _dateField(),
              _dropdownField(
                label: 'Gender',
                hint: 'Select gender',
                icon: Icons.people_outline_rounded,
                value: _selectedGender,
                items: const ['Male', 'Female'],
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              _nationalityField(),
              _field(
                controller: _phoneController,
                label: 'Phone number',
                hint: 'Enter your phone number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              _field(
                controller: _occupationController,
                label: 'Occupation',
                hint: 'What do you do?',
                icon: Icons.work_outline_rounded,
                textInputAction: TextInputAction.next,
              ),
              _field(
                controller: _locationController,
                label: 'Location',
                hint: 'City or area',
                icon: Icons.location_on_outlined,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        );
      default:
        return Form(
          key: _stepKeys[2],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: _primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter the details exactly as shown on your documents.',
                        style: TextStyle(
                          color: _primaryDark,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _field(
                controller: _idCardController,
                label: 'ID card number',
                hint: 'Enter your ID number',
                icon: Icons.credit_card_outlined,
                textInputAction: TextInputAction.next,
              ),
              _field(
                controller: _licenseController,
                label: 'Driving licence number',
                hint: 'Enter your licence number',
                icon: Icons.directions_car_outlined,
                textInputAction: TextInputAction.done,
              ),
              InkWell(
                onTap: _isLoading
                    ? null
                    : () => setState(() => _acceptedTerms = !_acceptedTerms),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: _acceptedTerms
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _acceptedTerms ? _primary : _border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        activeColor: _primary,
                        onChanged: _isLoading
                            ? null
                            : (value) => setState(
                                  () => _acceptedTerms = value ?? false,
                                ),
                      ),
                      const Expanded(
                        child: Text(
                          'I agree to the Terms and Conditions',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = true,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: !_isLoading,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: _inputDecoration(hint: hint, icon: icon, suffix: suffix),
            validator: validator ??
                (value) {
                  if (isRequired && (value == null || value.trim().isEmpty)) {
                    return '$label is required';
                  }
                  return null;
                },
          ),
        ],
      ),
    );
  }

  Widget _dateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Birth date',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          FormField<DateTime>(
            initialValue: _selectedBirthDate,
            validator: (_) =>
                _selectedBirthDate == null ? 'Select your birth date' : null,
            builder: (field) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _isLoading ? null : _pickBirthDate,
                    borderRadius: BorderRadius.circular(15),
                    child: InputDecorator(
                      decoration: _inputDecoration(
                        hint: '',
                        icon: Icons.calendar_month_outlined,
                        hasError: field.hasError,
                      ),
                      child: Text(
                        _selectedBirthDate == null
                            ? 'Select your birth date'
                            : _formatDate(_selectedBirthDate!),
                        style: TextStyle(
                          color: _selectedBirthDate == null
                              ? const Color(0xFF94A3B8)
                              : _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 6),
                      child: Text(
                        field.errorText!,
                        style: const TextStyle(
                          color: _danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            decoration: _inputDecoration(hint: hint, icon: icon),
            hint: Text(hint),
            items: items
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: _isLoading ? null : onChanged,
            validator: (selected) => selected == null ? 'Select $label' : null,
          ),
        ],
      ),
    );
  }

  Widget _nationalityField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nationality',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          DropdownSearch<String>(
            popupProps: const PopupProps.menu(
              showSearchBox: true,
              searchFieldProps: TextFieldProps(
                decoration: InputDecoration(
                  hintText: 'Search nationality',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            items: _nationalities,
            enabled: !_isLoading,
            selectedItem: _selectedNationality,
            dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: _inputDecoration(
                hint: 'Select nationality',
                icon: Icons.flag_outlined,
              ),
            ),
            onChanged: (value) => setState(() => _selectedNationality = value),
            validator: (value) =>
                value == null ? 'Select your nationality' : null,
          ),
        ],
      ),
    );
  }

  Widget _visibilityButton({
    required bool hidden,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      tooltip: hidden ? 'Show password' : 'Hide password',
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: _muted,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
    bool hasError = false,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: _primary, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      enabledBorder: border(hasError ? _danger : _border),
      disabledBorder: border(_border),
      focusedBorder: border(_primary, 1.5),
      errorBorder: border(_danger),
      focusedErrorBorder: border(_danger, 1.5),
      errorStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Material(
          color: Colors.white.withOpacity(0.14),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
        ),
        const Row(
          children: [
            Icon(Icons.directions_car_filled_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'DiamondCar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignupCard extends StatelessWidget {
  final int currentStep;
  final List<String> stepTitles;
  final Widget content;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onLogin;

  const _SignupCard({
    required this.currentStep,
    required this.stepTitles,
    required this.content,
    required this.isLoading,
    required this.onBack,
    required this.onContinue,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepProgress(currentStep: currentStep, titles: stepTitles),
          const SizedBox(height: 25),
          Text(
            stepTitles[currentStep],
            style: const TextStyle(
              color: _ink,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(currentStep),
              child: content,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (currentStep > 0) ...[
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: isLoading ? null : onBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ink,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: currentStep > 0 ? 2 : 1,
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: isLoading ? null : onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      disabledBackgroundColor: _primary.withOpacity(0.65),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                currentStep == 2 ? 'Create account' : 'Continue',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Already registered?',
                style: TextStyle(
                  color: _muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: isLoading ? null : onLogin,
                child: const Text(
                  'Log in',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  final int currentStep;
  final List<String> titles;

  const _StepProgress({required this.currentStep, required this.titles});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(titles.length, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == titles.length - 1 ? 0 : 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 5,
                  decoration: BoxDecoration(
                    color: active ? _primary : _border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  titles[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: index == currentStep ? _ink : _muted,
                    fontSize: 12,
                    fontWeight: index == currentStep
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
