import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'tasks/tasks_page.dart';

/// Top-level router. Add routes here as new screens are built.
final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const TasksPage(),
    ),
  ],
);

/// Root widget of the Nexax web client.
class NexaxApp extends StatelessWidget {
  const NexaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Nexax Workspace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
