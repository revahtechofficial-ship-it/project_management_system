import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the wide-screen sidebar is collapsed to an icon rail, persisted
/// across launches (AGENTS.md §1 `providers`). The shell's collapse toggle
/// drives this so the choice survives reloads. Defaults to collapsed so the
/// app opens with a compact menu; the user expands it with the toggle.
class SidebarController extends Notifier<bool> {
  static const String _key = 'sidebar_collapsed';

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

  /// Flips between the full sidebar and the icon rail, persisting the choice.
  Future<void> toggle() async {
    state = !state;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

final NotifierProvider<SidebarController, bool> sidebarCollapsedProvider =
    NotifierProvider<SidebarController, bool>(SidebarController.new);
