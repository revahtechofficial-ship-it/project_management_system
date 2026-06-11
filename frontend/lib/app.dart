import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_theme.dart';
import 'core/routing/app_router.dart';
import 'providers/theme_provider.dart';

/// Root widget: applies routing, theme, and global settings (AGENTS.md §1).
/// The active [ThemeMode] is user-controlled via Settings and persisted.
class RevahApp extends ConsumerWidget {
  const RevahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Revah Management System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
