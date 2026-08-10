import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/password_reset_api.dart';

const _primary = Color(0xFF1D4ED8);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF5F7FB);

enum _ResetStep { email, otp, password }

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _isLoading = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  String? _resetToken;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canResend => _resendSeconds == 0 && !_isLoading;

  String get _email => _emailController.text.trim().toLowerCase();

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _requestCode({bool resend = false}) async {
    final validEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!validEmail.hasMatch(_email)) {
      _showMessage('Enter a valid email address.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final message = await PasswordResetApi.requestOtp(_email);
      if (!mounted) return;

      _otpController.clear();
      setState(() {
        _step = _ResetStep.otp;
        _resetToken = null;
      });
      _startResendTimer();
      _showMessage(resend ? 'A new code was sent.' : message);
    } on PasswordResetApiException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final otp = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showMessage('Enter the 6-digit code.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await PasswordResetApi.verifyOtp(
        email: _email,
        otp: otp,
      );
      if (!mounted) return;

      _resendTimer?.cancel();
      setState(() {
        _resetToken = token;
        _step = _ResetStep.password;
      });
    } on PasswordResetApiException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirmation = _confirmPasswordController.text;

    if (password.length < 8) {
      _showMessage('Password must be at least 8 characters.', isError: true);
      return;
    }
    if (password != confirmation) {
      _showMessage('Passwords do not match.', isError: true);
      return;
    }
    if (_resetToken == null || _resetToken!.isEmpty) {
      _showMessage('Your reset session expired. Request a new code.', isError: true);
      setState(() => _step = _ResetStep.email);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await PasswordResetApi.resetPassword(
        resetToken: _resetToken!,
        newPassword: password,
      );
      if (!mounted) return;
      await _showSuccessDialog();
    } on PasswordResetApiException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
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
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in using your new password.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 15),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (_) => false,
                  );
                },
                style: FilledButton.styleFrom(backgroundColor: _primary),
                child: const Text(
                  'Back to login',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? const Color(0xFFB91C1C) : const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _goBack() {
    if (_isLoading) return;
    switch (_step) {
      case _ResetStep.email:
        Navigator.maybePop(context);
        return;
      case _ResetStep.otp:
        _resendTimer?.cancel();
        setState(() => _step = _ResetStep.email);
        return;
      case _ResetStep.password:
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _resetToken = null;
          _step = _ResetStep.email;
        });
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: _background,
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Reset password',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Progress(step: _step.index),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (_step) {
                      _ResetStep.email => _emailStep(),
                      _ResetStep.otp => _otpStep(),
                      _ResetStep.password => _passwordStep(),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailStep() {
    return _Card(
      key: const ValueKey('email'),
      icon: Icons.mark_email_unread_outlined,
      title: 'Find your account',
      subtitle: 'Enter the email connected to your DiamondCar account.',
      children: [
        _label('Email address'),
        const SizedBox(height: 9),
        TextField(
          controller: _emailController,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _requestCode(),
          decoration: _decoration(
            hint: 'name@example.com',
            icon: Icons.email_outlined,
          ),
        ),
        const SizedBox(height: 22),
        _button('Send verification code', () => _requestCode()),
      ],
    );
  }

  Widget _otpStep() {
    return _Card(
      key: const ValueKey('otp'),
      icon: Icons.password_rounded,
      title: 'Enter verification code',
      subtitle: 'We sent a 6-digit code to $_email.',
      children: [
        TextField(
          controller: _otpController,
          enabled: !_isLoading,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _verifyCode(),
          style: const TextStyle(
            color: _ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
          ),
          decoration: _decoration(hint: '000000').copyWith(counterText: ''),
        ),
        const SizedBox(height: 22),
        _button('Verify code', _verifyCode),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _canResend ? () => _requestCode(resend: true) : null,
            child: Text(
              _resendSeconds > 0
                  ? 'Resend code in ${_resendSeconds}s'
                  : 'Resend code',
            ),
          ),
        ),
      ],
    );
  }

  Widget _passwordStep() {
    return _Card(
      key: const ValueKey('password'),
      icon: Icons.lock_reset_rounded,
      title: 'Create a new password',
      subtitle: 'Use at least 8 characters and choose something unique.',
      children: [
        _label('New password'),
        const SizedBox(height: 9),
        TextField(
          controller: _passwordController,
          enabled: !_isLoading,
          obscureText: _hidePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          decoration: _passwordDecoration(
            hint: 'Enter a new password',
            hidden: _hidePassword,
            toggle: () => setState(() => _hidePassword = !_hidePassword),
          ),
        ),
        const SizedBox(height: 18),
        _label('Confirm password'),
        const SizedBox(height: 9),
        TextField(
          controller: _confirmPasswordController,
          enabled: !_isLoading,
          obscureText: _hideConfirmation,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => _resetPassword(),
          decoration: _passwordDecoration(
            hint: 'Repeat the new password',
            hidden: _hideConfirmation,
            toggle: () => setState(
              () => _hideConfirmation = !_hideConfirmation,
            ),
          ),
        ),
        const SizedBox(height: 22),
        _button('Update password', _resetPassword),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _button(String text, Future<void> Function() action) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: _isLoading ? null : action,
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  InputDecoration _decoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: _primary),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: _borderStyle(_border),
      enabledBorder: _borderStyle(_border),
      focusedBorder: _borderStyle(_primary, width: 1.6),
    );
  }

  InputDecoration _passwordDecoration({
    required String hint,
    required bool hidden,
    required VoidCallback toggle,
  }) {
    return _decoration(hint: hint, icon: Icons.lock_outline_rounded).copyWith(
      suffixIcon: IconButton(
        onPressed: toggle,
        icon: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    );
  }

  OutlineInputBorder _borderStyle(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _Progress extends StatelessWidget {
  final int step;

  const _Progress({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        final active = index <= step;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
            decoration: BoxDecoration(
              color: active ? _primary : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _Card({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _primary, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 26),
          ...children,
        ],
      ),
    );
  }
}
