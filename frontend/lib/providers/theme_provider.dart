import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global theme-mode state, persisted across launches (AGENTS.md §1
/// `providers`). The Settings page drives this, so the whole app re-themes
/// live when the user switches between System / Light / Dark.
///
/// Light is the default. Following the operating system sounds accommodating,
/// but it means the app opens dark for anyone whose machine is dark, without
/// ever having asked for a dark app — and this one is designed light. System is
/// still there for whoever wants it; it is simply no longer assumed.
class ThemeController extends Notifier<ThemeMode> {
  static const String _key = 'theme_mode';

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.light;
  }

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_key);
    if (saved != null) {
      state = ThemeMode.values.firstWhere(
        (ThemeMode m) => m.name == saved,
        orElse: () => ThemeMode.light,
      );
    }
  }

  /// Switches the active theme mode and persists the choice.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}

final NotifierProvider<ThemeController, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
