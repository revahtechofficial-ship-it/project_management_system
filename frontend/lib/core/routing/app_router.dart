import 'package:go_router/go_router.dart';

import '../../features/tasks/tasks_page.dart';

/// Declarative app router (AGENTS.md §9). Add routes here as features grow;
/// use `redirect` for auth flows once SSO lands.
final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const TasksPage(),
    ),
  ],
);
