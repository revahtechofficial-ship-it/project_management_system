import 'package:flutter/material.dart';

import 'core/routing/app_router.dart';

/// Root widget: applies routing, theme, and global settings (AGENTS.md §1).
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
      routerConfig: appRouter,
    );
  }
}
