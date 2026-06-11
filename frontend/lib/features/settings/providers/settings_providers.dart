import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User notification/display preferences (feature-scoped app state).
class SettingsState {
  const SettingsState({
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.weeklyDigest = false,
    this.compactMode = false,
  });

  final bool emailNotifications;
  final bool pushNotifications;
  final bool weeklyDigest;
  final bool compactMode;

  SettingsState copyWith({
    bool? emailNotifications,
    bool? pushNotifications,
    bool? weeklyDigest,
    bool? compactMode,
  }) =>
      SettingsState(
        emailNotifications: emailNotifications ?? this.emailNotifications,
        pushNotifications: pushNotifications ?? this.pushNotifications,
        weeklyDigest: weeklyDigest ?? this.weeklyDigest,
        compactMode: compactMode ?? this.compactMode,
      );
}

/// Holds preferences and persists each toggle to `SharedPreferences`
/// (AGENTS.md §1 feature providers; §9 Riverpod-only state).
class SettingsController extends Notifier<SettingsState> {
  static const String _email = 'pref_email_notifications';
  static const String _push = 'pref_push_notifications';
  static const String _digest = 'pref_weekly_digest';
  static const String _compact = 'pref_compact_mode';

  @override
  SettingsState build() {
    _restore();
    return const SettingsState();
  }

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      emailNotifications: prefs.getBool(_email) ?? true,
      pushNotifications: prefs.getBool(_push) ?? true,
      weeklyDigest: prefs.getBool(_digest) ?? false,
      compactMode: prefs.getBool(_compact) ?? false,
    );
  }

  Future<void> _save(String key, bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> setEmailNotifications(bool value) async {
    state = state.copyWith(emailNotifications: value);
    await _save(_email, value);
  }

  Future<void> setPushNotifications(bool value) async {
    state = state.copyWith(pushNotifications: value);
    await _save(_push, value);
  }

  Future<void> setWeeklyDigest(bool value) async {
    state = state.copyWith(weeklyDigest: value);
    await _save(_digest, value);
  }

  Future<void> setCompactMode(bool value) async {
    state = state.copyWith(compactMode: value);
    await _save(_compact, value);
  }
}

final NotifierProvider<SettingsController, SettingsState>
    settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(
        SettingsController.new);
