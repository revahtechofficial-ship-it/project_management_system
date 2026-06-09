import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';

/// Login screen: starts the Keycloak OIDC flow (AGENTS.md §1 feature page).
class AuthPage extends ConsumerWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AuthState> auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: Center(
        child: auth.isLoading
            ? const CircularProgressIndicator()
            : _SignIn(error: auth.hasError ? '${auth.error}' : null),
      ),
    );
  }
}

class _SignIn extends ConsumerWidget {
  const _SignIn({this.error});

  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Nexax Workspace',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => ref.read(authControllerProvider.notifier).login(),
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Keycloak'),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 16),
          Text('Sign-in error: $error'),
        ],
      ],
    );
  }
}
