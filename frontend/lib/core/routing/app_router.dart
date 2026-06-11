import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/forgot_password_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/reset_password_page.dart';
import '../../features/auth/signup_page.dart';
import '../../features/auth/verify_otp_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/projects/projects_page.dart';
import '../../features/reports/reports_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/tasks/tasks_page.dart';
import '../../features/team/team_page.dart';
import '../../features/vikunja/vikunja_projects_page.dart';
import '../../providers/auth_provider.dart';
import '../widgets/app_shell.dart';

const Set<String> _authPaths = <String>{
  '/login',
  '/signup',
  '/verify-otp',
  '/forgot-password',
  '/reset-password',
};

/// Declarative router with an auth gate (AGENTS.md §9). Unauthenticated users
/// are limited to the auth pages; the router refreshes when the session changes.
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
      final bool onAuthPage = _authPaths.contains(state.matchedLocation);
      if (!authed) {
        return onAuthPage ? null : '/login';
      }
      if (onAuthPage) {
        return '/';
      }
      return null;
    },
    routes: <RouteBase>[
      ShellRoute(
        builder: (c, s, Widget child) => AppShell(child: child),
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (c, s) => const DashboardPage()),
          GoRoute(path: '/tasks', builder: (c, s) => const TasksPage()),
          GoRoute(path: '/projects', builder: (c, s) => const ProjectsPage()),
          GoRoute(path: '/team', builder: (c, s) => const TeamPage()),
          GoRoute(path: '/reports', builder: (c, s) => const ReportsPage()),
          GoRoute(path: '/settings', builder: (c, s) => const SettingsPage()),
          GoRoute(
            path: '/notifications',
            builder: (c, s) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/vikunja',
            builder: (c, s) => const VikunjaProjectsPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (c, s) =>
            LoginPage(notice: s.uri.queryParameters['notice']),
      ),
      GoRoute(path: '/signup', builder: (c, s) => const SignupPage()),
      GoRoute(
        path: '/verify-otp',
        builder: (c, s) =>
            VerifyOtpPage(email: s.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (c, s) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (c, s) =>
            ResetPasswordPage(email: s.uri.queryParameters['email'] ?? ''),
      ),
    ],
  );

  ref.listen(authControllerProvider, (_, _) => router.refresh());
  return router;
});
