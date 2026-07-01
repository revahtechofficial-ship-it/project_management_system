import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the first-run tour has been shown. `null` means "not yet restored"
/// so the dashboard doesn't flash the tour for returning users before the
/// stored flag loads (AGENTS.md §1 `providers`).
class OnboardingController extends Notifier<bool?> {
  static const String _key = 'onboarding_seen';

  @override
  bool? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  /// Marks the tour as seen so it never auto-opens again.
  Future<void> markSeen() async {
    state = true;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

final NotifierProvider<OnboardingController, bool?> onboardingProvider =
    NotifierProvider<OnboardingController, bool?>(OnboardingController.new);
