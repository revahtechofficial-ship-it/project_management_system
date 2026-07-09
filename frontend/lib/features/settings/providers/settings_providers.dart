import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';

/// User notification/display preferences (feature-scoped app state).
class SettingsState {
  const SettingsState({
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.weeklyDigest = false,
    this.compactMode = false,
    this.accent = _defaultAccent,
    this.autoDark = false,
    this.reduceMotion = false,
    this.textScale = 1.0,
  });

  /// Default accent (indigo) as a packed ARGB int.
  static const int _defaultAccent = 0xFF4F46E5;

  final bool emailNotifications;
  final bool pushNotifications;
  final bool weeklyDigest;

  /// Denser spacing across the app (maps to a compact [VisualDensity]).
  final bool compactMode;

  /// The chosen brand accent, as a packed ARGB int (seeds the color scheme).
  final int accent;

  /// Switch to a dark theme automatically in the evening, overriding the
  /// System/Light/Dark selector while enabled.
  final bool autoDark;

  /// Minimise animations for users who prefer reduced motion.
  final bool reduceMotion;

  /// Global text scale factor (1.0 = default).
  final double textScale;

  SettingsState copyWith({
    bool? emailNotifications,
    bool? pushNotifications,
    bool? weeklyDigest,
    bool? compactMode,
    int? accent,
    bool? autoDark,
    bool? reduceMotion,
    double? textScale,
  }) => SettingsState(
    emailNotifications: emailNotifications ?? this.emailNotifications,
    pushNotifications: pushNotifications ?? this.pushNotifications,
    weeklyDigest: weeklyDigest ?? this.weeklyDigest,
    compactMode: compactMode ?? this.compactMode,
    accent: accent ?? this.accent,
    autoDark: autoDark ?? this.autoDark,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    textScale: textScale ?? this.textScale,
  );
}

/// Holds preferences and persists each setting to `SharedPreferences`
/// (AGENTS.md §1 feature providers; §9 Riverpod-only state).
class SettingsController extends Notifier<SettingsState> {
  static const String _email = 'pref_email_notifications';
  static const String _push = 'pref_push_notifications';
  static const String _digest = 'pref_weekly_digest';
  static const String _compact = 'pref_compact_mode';
  static const String _accentKey = 'pref_accent';
  static const String _autoDarkKey = 'pref_auto_dark';
  static const String _reduceMotionKey = 'pref_reduce_motion';
  static const String _textScaleKey = 'pref_text_scale';

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
      accent: prefs.getInt(_accentKey) ?? SettingsState._defaultAccent,
      autoDark: prefs.getBool(_autoDarkKey) ?? false,
      reduceMotion: prefs.getBool(_reduceMotionKey) ?? false,
      textScale: prefs.getDouble(_textScaleKey) ?? 1.0,
    );
  }

  Future<void> _saveBool(String key, bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> setEmailNotifications(bool value) async {
    state = state.copyWith(emailNotifications: value);
    await _saveBool(_email, value);
  }

  Future<void> setPushNotifications(bool value) async {
    state = state.copyWith(pushNotifications: value);
    await _saveBool(_push, value);
  }

  Future<void> setWeeklyDigest(bool value) async {
    state = state.copyWith(weeklyDigest: value);
    await _saveBool(_digest, value);
  }

  Future<void> setCompactMode(bool value) async {
    state = state.copyWith(compactMode: value);
    await _saveBool(_compact, value);
  }

  /// Sets the brand accent from a [color]; falls back to indigo when reset.
  Future<void> setAccent(int color) async {
    state = state.copyWith(accent: color);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color);
  }

  Future<void> resetAccent() => setAccent(AppColors.brand.toARGB32());

  Future<void> setAutoDark(bool value) async {
    state = state.copyWith(autoDark: value);
    await _saveBool(_autoDarkKey, value);
  }

  Future<void> setReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    await _saveBool(_reduceMotionKey, value);
  }

  Future<void> setTextScale(double value) async {
    state = state.copyWith(textScale: value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_textScaleKey, value);
  }
}

final NotifierProvider<SettingsController, SettingsState>
settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
