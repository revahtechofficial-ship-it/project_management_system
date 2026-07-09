import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/password_policy.dart';
import '../../providers/auth_provider.dart';
import 'widgets/auth_bits.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/password_field.dart';
import 'widgets/password_requirements.dart';

/// Create-account form. On success it sends the user to verify their email —
/// it does NOT sign them in.
class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
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
    final String email = _email.text.trim();
    try {
      await ref
          .read(authServiceProvider)
          .register(
            email: email,
            password: _password.text,
            fullName: _name.text.trim(),
          );
      if (mounted) {
        context.go('/verify-otp?email=${Uri.encodeComponent(email)}');
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Join Revah Management System',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
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
              label: 'Confirm password',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (String? v) =>
                  v != _password.text ? 'Passwords do not match' : null,
            ),
            if (_error != null) AuthError(_error!),
            const SizedBox(height: 16),
            SubmitButton(
              label: 'Create account',
              busy: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const Text('Already have an account?'),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
