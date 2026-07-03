import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activity/activity_page.dart';
import '../../features/admin/admin_page.dart';
import '../../features/approvals/approvals_page.dart';
import '../../features/ai/assistant_page.dart';
import '../../features/auth/forgot_password_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/reset_password_page.dart';
import '../../features/auth/signup_page.dart';
import '../../features/auth/verify_otp_page.dart';
import '../../features/automation/automation_page.dart';
import '../../features/chat/chat_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/dashboard/dashboards_page.dart';
import '../../features/focus/focus_page.dart';
import '../../features/goals/goals_page.dart';
import '../../features/integrations/integrations_page.dart';
import '../../features/leave/leave_page.dart';
import '../../features/one_on_ones/one_on_ones_page.dart';
import '../../features/landing/landing_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/pages/pages_page.dart';
import '../../features/planning/planning_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/projects/projects_page.dart';
import '../../features/projects/shared_project_page.dart';
import '../../features/releases/releases_page.dart';
import '../../features/reports/reports_page.dart';
import '../../features/resources/resources_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/sprints/sprints_page.dart';
import '../../features/tasks/tasks_page.dart';
import '../../features/team/team_page.dart';
import '../../features/time/time_page.dart';
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
      final bool authed =
          ref.read(authControllerProvider).asData?.value.isAuthenticated ??
          false;
      final String loc = state.matchedLocation;
      final bool isAuthPage = loc == '/welcome' || _authPaths.contains(loc);
      // Public read-only share links are open to everyone, signed in or not.
      final bool isShare = loc.startsWith('/share/');
      if (!authed) {
        // Signed-out visitors get the landing page as the front door, but may
        // still open a share link.
        return (isAuthPage || isShare) ? null : '/welcome';
      }
      // Signed-in users never see the landing or auth pages (but share links
      // stay reachable).
      if (isAuthPage) {
        return '/';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/welcome', builder: (c, s) => const LandingPage()),
      GoRoute(
        path: '/share/project/:token',
        builder: (c, s) =>
            SharedProjectPage(token: s.pathParameters['token'] ?? ''),
      ),
      ShellRoute(
        builder: (c, s, Widget child) => AppShell(child: child),
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (c, s) => const DashboardPage()),
          GoRoute(path: '/focus', builder: (c, s) => const FocusPage()),
          GoRoute(path: '/tasks', builder: (c, s) => const TasksPage()),
          GoRoute(path: '/sprints', builder: (c, s) => const SprintsPage()),
          GoRoute(path: '/releases', builder: (c, s) => const ReleasesPage()),
          GoRoute(path: '/chat', builder: (c, s) => const ChatPage()),
          GoRoute(path: '/projects', builder: (c, s) => const ProjectsPage()),
          GoRoute(path: '/pages', builder: (c, s) => const PagesPage()),
          GoRoute(
            path: '/dashboards',
            builder: (c, s) => const DashboardsPage(),
          ),
          GoRoute(path: '/planning', builder: (c, s) => const PlanningPage()),
          GoRoute(
            path: '/resources',
            builder: (c, s) => const ResourcesPage(),
          ),
          GoRoute(path: '/time', builder: (c, s) => const TimePage()),
          GoRoute(path: '/goals', builder: (c, s) => const GoalsPage()),
          GoRoute(path: '/team', builder: (c, s) => const TeamPage()),
          GoRoute(
            path: '/one-on-ones',
            builder: (c, s) => const OneOnOnesPage(),
          ),
          GoRoute(path: '/leave', builder: (c, s) => const LeavePage()),
          GoRoute(
            path: '/approvals',
            builder: (c, s) => const ApprovalsPage(),
          ),
          GoRoute(path: '/reports', builder: (c, s) => const ReportsPage()),
          GoRoute(path: '/activity', builder: (c, s) => const ActivityPage()),
          GoRoute(
            path: '/integrations',
            builder: (c, s) => const IntegrationsPage(),
          ),
          GoRoute(path: '/admin', builder: (c, s) => const AdminPage()),
          GoRoute(path: '/ai', builder: (c, s) => const AssistantPage()),
          GoRoute(
            path: '/automation',
            builder: (c, s) => const AutomationPage(),
          ),
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
        builder: (c, s) => LoginPage(notice: s.uri.queryParameters['notice']),
      ),
      GoRoute(path: '/profile', builder: (c, s) => const ProfilePage()),
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
