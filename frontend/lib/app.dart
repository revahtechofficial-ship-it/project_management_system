import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_theme.dart';
import 'core/routing/app_router.dart';
import 'features/settings/providers/settings_providers.dart';
import 'providers/theme_provider.dart';

/// Root widget: applies routing, theme, and global appearance preferences
/// (AGENTS.md §1). Theme mode, accent, density, motion and text scale are all
/// user-controlled via Settings and persisted.
class RevahApp extends ConsumerWidget {
  const RevahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsState settings = ref.watch(settingsControllerProvider);
    final Color seed = Color(settings.accent);

    return MaterialApp.router(
      title: 'Revah Management System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        seed: seed,
        compact: settings.compactMode,
        reduceMotion: settings.reduceMotion,
      ),
      darkTheme: AppTheme.dark(
        seed: seed,
        compact: settings.compactMode,
        reduceMotion: settings.reduceMotion,
      ),
      themeMode: _effectiveMode(ref.watch(themeModeProvider), settings.autoDark),
      routerConfig: ref.watch(goRouterProvider),
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(settings.textScale),
            disableAnimations: settings.reduceMotion || mq.disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// When "auto dark" is on, follow the clock (dark in the evening/early
  /// morning) and ignore the manual selector; otherwise use the selector.
  ThemeMode _effectiveMode(ThemeMode mode, bool autoDark) {
    if (!autoDark) {
      return mode;
    }
    final int hour = DateTime.now().hour;
    final bool night = hour >= 19 || hour < 7;
    return night ? ThemeMode.dark : ThemeMode.light;
  }
}
