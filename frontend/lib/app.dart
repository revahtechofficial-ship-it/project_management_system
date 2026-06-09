import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'providers/auth_provider.dart';

/// Root widget: applies routing, theme, and global settings (AGENTS.md §1).
class RevahApp extends ConsumerWidget {
  const RevahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Once signed in, run the second (silent) OIDC handshake to establish the
    // user's Vikunja session via the BFF. Loop-safe (an "attempted" flag).
    ref.listen<AsyncValue<AuthState>>(authControllerProvider, (_, next) {
      final AuthState? state = next.asData?.value;
      if (state != null && state.needsVikunjaLogin) {
        ref.read(authControllerProvider.notifier).connectVikunja();
      }
    });

    return MaterialApp.router(
      title: 'Revah Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
