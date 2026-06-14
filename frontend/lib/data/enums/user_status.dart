import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A user's presence status. `offline` is derived (no live connection) and is
/// not user-settable. Tied to presence data, so it carries `toJson`/`fromJson`
/// with a sentinel default (AGENTS.md §9).
enum UserStatus {
  active,
  away,
  busy,
  dnd,
  offline;

  String get label => switch (this) {
        UserStatus.active => 'Active',
        UserStatus.away => 'Away',
        UserStatus.busy => 'Busy',
        UserStatus.dnd => 'Do Not Disturb',
        UserStatus.offline => 'Offline',
      };

  Color get color => switch (this) {
        UserStatus.active => AppColors.green,
        UserStatus.away => AppColors.amber,
        UserStatus.busy => AppColors.orange,
        UserStatus.dnd => AppColors.rose,
        UserStatus.offline => AppColors.slate,
      };

  IconData get icon => switch (this) {
        UserStatus.active => Icons.check_circle,
        UserStatus.away => Icons.nightlight_round,
        UserStatus.busy => Icons.remove_circle,
        UserStatus.dnd => Icons.do_not_disturb_on,
        UserStatus.offline => Icons.circle_outlined,
      };

  String toJson() => switch (this) {
        UserStatus.active => 'active',
        UserStatus.away => 'away',
        UserStatus.busy => 'busy',
        UserStatus.dnd => 'dnd',
        UserStatus.offline => 'offline',
      };

  factory UserStatus.fromJson(String value) => switch (value) {
        'active' => UserStatus.active,
        'away' => UserStatus.away,
        'busy' => UserStatus.busy,
        'dnd' => UserStatus.dnd,
        'offline' => UserStatus.offline,
        _ => UserStatus.active,
      };

  /// The statuses a user can choose for themselves.
  static List<UserStatus> get selectableValue => <UserStatus>[
        UserStatus.active,
        UserStatus.away,
        UserStatus.busy,
        UserStatus.dnd,
      ];
}
