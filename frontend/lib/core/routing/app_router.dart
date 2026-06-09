import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_page.dart';
import '../../features/tasks/tasks_page.dart';
import '../../features/vikunja/vikunja_projects_page.dart';
import '../../providers/auth_provider.dart';

/// Declarative router with an auth gate (AGENTS.md §9). Unauthenticated users
/// are redirected to `/login`; the router refreshes when auth state changes.
final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final bool authed = ref
              .read(authControllerProvider)
              .asData
              ?.value
              .isAuthenticated ??
          false;
      final bool atLogin = state.matchedLocation == '/login';
      // Treat "still loading" as not-authed -> show the login screen (which
      // renders a spinner while the session resolves).
      if (!authed) {
        return atLogin ? null : '/login';
      }
      if (atLogin) {
        return '/';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const TasksPage(),
      ),
      GoRoute(
        path: '/vikunja',
        builder: (context, state) => const VikunjaProjectsPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthPage(),
      ),
    ],
  );

  // Re-evaluate redirects whenever the session changes (go_router's own
  // refresh — no ChangeNotifier/ValueNotifier, per AGENTS.md §9).
  ref.listen(authControllerProvider, (_, _) => router.refresh());
  return router;
});
