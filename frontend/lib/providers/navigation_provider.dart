import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nav locations the user has pinned to the top of the sidebar, persisted
/// across launches (AGENTS.md §1 `providers`).
class PinnedNavController extends Notifier<List<String>> {
  static const String _key = 'nav_pinned';

  @override
  List<String> build() {
    _restore();
    return const <String>[];
  }

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key) ?? const <String>[];
  }

  bool isPinned(String location) => state.contains(location);

  Future<void> toggle(String location) async {
    final List<String> next = <String>[...state];
    if (!next.remove(location)) {
      next.add(location);
    }
    state = next;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next);
  }
}

final NotifierProvider<PinnedNavController, List<String>> pinnedNavProvider =
    NotifierProvider<PinnedNavController, List<String>>(
        PinnedNavController.new);

/// The most-recently visited routes (newest first, capped), for the command
/// palette's "Recent" quick-switcher. Persisted across launches.
class RecentPagesController extends Notifier<List<String>> {
  static const String _key = 'nav_recent';
  static const int _max = 8;

  @override
  List<String> build() {
    _restore();
    return const <String>[];
  }

  Future<void> _restore() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key) ?? const <String>[];
  }

  /// Records a visit to [location], moving it to the front (deduped, capped).
  Future<void> visit(String location) async {
    if (state.isNotEmpty && state.first == location) {
      return;
    }
    final List<String> next = <String>[
      location,
      ...state.where((String l) => l != location),
    ];
    if (next.length > _max) {
      next.removeRange(_max, next.length);
    }
    state = next;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next);
  }
}

final NotifierProvider<RecentPagesController, List<String>> recentPagesProvider =
    NotifierProvider<RecentPagesController, List<String>>(
        RecentPagesController.new);
