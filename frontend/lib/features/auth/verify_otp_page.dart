import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import 'widgets/auth_bits.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/otp_field.dart';

/// Confirms a signup OTP. On success it sends the user to sign in (no auto
/// login).
class VerifyOtpPage extends ConsumerStatefulWidget {
  const VerifyOtpPage({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends ConsumerState<VerifyOtpPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .verifyEmail(email: widget.email, code: _code.text.trim());
      if (mounted) {
        const String notice = 'Email verified! Please sign in.';
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
          .resendOtp(email: widget.email, purpose: 'signup');
      setState(() => _info = 'A new code is on its way.');
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verify your email',
      subtitle: 'Enter the 6-digit code we sent to ${widget.email}',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_info != null) AuthNotice(_info!),
            OtpField(controller: _code, onSubmitted: (_) => _verify()),
            if (_error != null) AuthError(_error!),
            const SizedBox(height: 8),
            SubmitButton(label: 'Verify', busy: _busy, onPressed: _verify),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Text("Didn't get it?"),
                TextButton(
                  onPressed: _resend,
                  child: const Text('Resend code'),
                ),
              ],
            ),
            Center(
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
