import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/utils/feedback.dart';
import '../../providers/auth_provider.dart';
import 'widgets/auth_bits.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_field.dart';

/// Email/password sign-in. On success the router redirects to the app.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.notice});

  /// Optional success notice (e.g. after verifying email / resetting password).
  final String? notice;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _twoFactorEmail;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            email: _email.text.trim(),
            password: _password.text,
          );
      // The router redirect navigates to the app once authenticated.
    } on TwoFactorRequiredException catch (e) {
      setState(() => _twoFactorEmail = e.email);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_code.text.trim().isEmpty) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verifyLoginOtp(
            email: _twoFactorEmail!,
            code: _code.text.trim(),
          );
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resendCode() async {
    try {
      await ref.read(authServiceProvider).resendOtp(
            email: _twoFactorEmail!,
            purpose: 'login',
          );
      if (mounted) {
        context.showSuccess('A new code is on its way.');
      }
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_twoFactorEmail != null) {
      return AuthScaffold(
        title: 'Two-factor verification',
        subtitle: 'Enter the 6-digit code we emailed to $_twoFactorEmail',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verifyCode(),
              decoration: const InputDecoration(
                labelText: 'Verification code',
                prefixIcon: Icon(Icons.shield_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) AuthError(_error!),
            const SizedBox(height: 12),
            SubmitButton(label: 'Verify', busy: _busy, onPressed: _verifyCode),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                TextButton(
                  onPressed: _busy ? null : _resendCode,
                  child: const Text('Resend code'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _twoFactorEmail = null;
                          _error = null;
                          _code.clear();
                        }),
                  child: const Text('Back'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to your Revah account',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.notice != null) AuthNotice(widget.notice!),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _password,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (String? v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),
            if (_error != null) AuthError(_error!),
            const SizedBox(height: 8),
            SubmitButton(label: 'Sign in', busy: _busy, onPressed: _submit),
            const SizedBox(height: 14),
            const OrDivider(),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.g_mobiledata, size: 28),
              label: const Text('Continue with Google (soon)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Text("Don't have an account?"),
                TextButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text('Sign up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
