import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which language the calendar reads in (AGENTS.md §1 `providers`).
///
/// Global and persisted, rather than local to the page. It was page state
/// before, which meant the choice was forgotten on every refresh — someone who
/// reads in English had to switch back to English each time they opened the
/// calendar, which is the sort of thing that makes a feature feel broken even
/// though every part of it works.
///
/// Nepali is the default, because this is a Nepali patro.
class LanguageController extends Notifier<bool> {
  static const String _key = 'calendar_nepali';

  @override
  bool build() {
    _restore();
    return true;
  }

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? saved = prefs.getBool(_key);
    if (saved != null) {
      state = saved;
    }
  }

  /// Switches the language and remembers it.
  Future<void> setNepali(bool nepali) async {
    state = nepali;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, nepali);
  }
}

/// True when the calendar should read in Nepali.
final NotifierProvider<LanguageController, bool> nepaliProvider =
    NotifierProvider<LanguageController, bool>(LanguageController.new);
