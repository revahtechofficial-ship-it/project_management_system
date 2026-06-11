import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/password_policy.dart';
import '../../providers/auth_provider.dart';
import 'widgets/auth_bits.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/otp_field.dart';
import 'widgets/password_field.dart';
import 'widgets/password_requirements.dart';

/// Sets a new password using the reset OTP, then sends the user to sign in.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
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
      await ref.read(authServiceProvider).resetPassword(
            email: widget.email,
            code: _code.text.trim(),
            newPassword: _password.text,
          );
      if (mounted) {
        const String notice = 'Password updated! Please sign in.';
        context.go('/login?notice=${Uri.encodeComponent(notice)}');
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .resendOtp(email: widget.email, purpose: 'reset');
      setState(() => _info = 'A new code is on its way.');
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset password',
      subtitle: 'Enter the code sent to ${widget.email} and a new password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_info != null) AuthNotice(_info!),
            OtpField(controller: _code),
            const SizedBox(height: 16),
            PasswordField(
              controller: _password,
              label: 'New password',
              onChanged: (_) => setState(() {}),
              validator: (String? v) => PasswordPolicy.isValid(v ?? '')
                  ? null
                  : 'Password does not meet the requirements',
            ),
            const SizedBox(height: 12),
            PasswordRequirements(password: _password.text),
            const SizedBox(height: 16),
            PasswordField(
              controller: _confirm,
              label: 'Confirm new password',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (String? v) =>
                  v != _password.text ? 'Passwords do not match' : null,
            ),
            if (_error != null) AuthError(_error!),
            const SizedBox(height: 16),
            SubmitButton(
                label: 'Reset password', busy: _busy, onPressed: _submit),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Text("Didn't get a code?"),
                TextButton(onPressed: _resend, child: const Text('Resend')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
