import 'package:flutter/material.dart';

import '../../../api/renter_api.dart';

const _primary = Color(0xFF1D4ED8);
const _primaryDark = Color(0xFF1E40AF);
const _background = Color(0xFFF5F7FB);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);

class ChangePasswordPage extends StatefulWidget {
  final String userId;

  const ChangePasswordPage({super.key, required this.userId});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _newPasswordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _isLoading = false;
  bool _hideOldPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_refreshPasswordStrength);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_refreshPasswordStrength);
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _refreshPasswordStrength() {
    if (mounted) setState(() {});
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await RenterApi.changePassword(
        userId: widget.userId,
        oldPassword: _oldPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );
      if (!mounted) return;
      await _showSuccessDialog();
    } catch (error) {
      if (!mounted) return;
      final message = error
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('Error: ', '');

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: const Color(0xFFB91C1C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

Future<void> _showSuccessDialog() async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF15803D),
              size: 38,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Password updated',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.25,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your password was changed successfully. For your security, '
            'please sign in again using your new password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Sign in again',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  String? _requiredPassword(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Confirm your new password';
    }
    if (value.trim() != _newPasswordController.text.trim()) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          _PasswordHeader(
            onBack: _isLoading ? null : () => Navigator.maybePop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: _border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0D0F172A),
                                blurRadius: 20,
                                offset: Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _FieldHeading(
                                title: 'Current password',
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _oldPasswordController,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                enabled: !_isLoading,
                                obscureText: _hideOldPassword,
                                validator: (value) => _requiredPassword(
                                  value,
                                  'Enter your current password',
                                ),
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) =>
                                    _newPasswordFocus.requestFocus(),
                                decoration: _passwordDecoration(
                                  hintText: 'Enter your current password',
                                  icon: Icons.lock_outline_rounded,
                                  isHidden: _hideOldPassword,
                                  onVisibilityPressed: () => setState(() {
                                    _hideOldPassword = !_hideOldPassword;
                                  }),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const _FieldHeading(
                                title: 'New password',
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _newPasswordController,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                focusNode: _newPasswordFocus,
                                enabled: !_isLoading,
                                obscureText: _hideNewPassword,
                                validator: (value) => _requiredPassword(
                                  value,
                                  'Enter a new password',
                                ),
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.newPassword],
                                onFieldSubmitted: (_) =>
                                    _confirmPasswordFocus.requestFocus(),
                                decoration: _passwordDecoration(
                                  hintText: 'Create a new password',
                                  icon: Icons.password_rounded,
                                  isHidden: _hideNewPassword,
                                  onVisibilityPressed: () => setState(() {
                                    _hideNewPassword = !_hideNewPassword;
                                  }),
                                ),
                              ),
                              if (_newPasswordController.text.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _PasswordStrength(
                                  password: _newPasswordController.text,
                                ),
                              ],
                              const SizedBox(height: 22),
                              const _FieldHeading(
                                title: 'Confirm new password',
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _confirmPasswordController,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                focusNode: _confirmPasswordFocus,
                                enabled: !_isLoading,
                                obscureText: _hideConfirmPassword,
                                validator: _validateConfirmation,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.newPassword],
                                onFieldSubmitted: (_) => _changePassword(),
                                decoration: _passwordDecoration(
                                  hintText: 'Repeat your new password',
                                  icon: Icons.verified_user_outlined,
                                  isHidden: _hideConfirmPassword,
                                  onVisibilityPressed: () => setState(() {
                                    _hideConfirmPassword =
                                        !_hideConfirmPassword;
                                  }),
                                ),
                              ),
                              const SizedBox(height: 25),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton.icon(
                                  onPressed:
                                      _isLoading ? null : _changePassword,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primary,
                                    disabledBackgroundColor:
                                        const Color(0xFF93C5FD),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.3,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.lock_reset_rounded,
                                          size: 21,
                                        ),
                                  label: Text(
                                    _isLoading
                                        ? 'Updating password...'
                                        : 'Change password',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _passwordDecoration({
    required String hintText,
    required IconData icon,
    required bool isHidden,
    required VoidCallback onVisibilityPressed,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
      prefixIcon: Icon(icon, color: _primary, size: 23),
      suffixIcon: IconButton(
        tooltip: isHidden ? 'Show password' : 'Hide password',
        onPressed: _isLoading ? null : onVisibilityPressed,
        icon: Icon(
          isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: _muted,
        ),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.6),
      ),
    );
  }
}

class _PasswordHeader extends StatelessWidget {
  final VoidCallback? onBack;

  const _PasswordHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryDark, Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x331D4ED8),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 22),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                  fixedSize: const Size(44, 44),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Change Password',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Protect your account access',
                      style: TextStyle(
                        color: Color(0xFFC7D7FE),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.enhanced_encryption_outlined,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldHeading extends StatelessWidget {
  final String title;

  const _FieldHeading({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  final String password;

  const _PasswordStrength({required this.password});

  int get _score {
    var value = 0;
    if (password.length >= 8) value++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) value++;
    if (RegExp(r'[0-9]').hasMatch(password)) value++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) value++;
    if (value < 1) return 1;
    if (value > 4) return 4;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    final color = switch (score) {
      1 => const Color(0xFFDC2626),
      2 => const Color(0xFFF59E0B),
      3 => const Color(0xFF2563EB),
      _ => const Color(0xFF16A34A),
    };
    final label = switch (score) {
      1 => 'Weak',
      2 => 'Fair',
      3 => 'Good',
      _ => 'Strong',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            4,
            (index) => Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 4,
                margin: EdgeInsets.only(right: index == 3 ? 0 : 5),
                decoration: BoxDecoration(
                  color: index < score ? color : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Password strength: $label',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
