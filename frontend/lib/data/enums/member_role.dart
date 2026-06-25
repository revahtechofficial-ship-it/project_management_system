import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A workspace member's access role. Tied to the `TeamMember`/`AuthUser`
/// models, so it carries `toJson` / `fromJson` (AGENTS.md §9 Enums). Unknown
/// values default to the least-privileged role (`member`).
enum MemberRole {
  owner,
  admin,
  member,
  guest;

  String get label => switch (this) {
        MemberRole.owner => 'Owner',
        MemberRole.admin => 'Admin',
        MemberRole.member => 'Member',
        MemberRole.guest => 'Guest',
      };

  Color get color => switch (this) {
        MemberRole.owner => AppColors.amber,
        MemberRole.admin => AppColors.violet,
        MemberRole.member => AppColors.slate,
        MemberRole.guest => AppColors.teal,
      };

  /// Whether this role may perform admin-only actions (manage roles, delete
  /// projects/milestones, set baselines).
  bool get isAdmin => this == MemberRole.owner || this == MemberRole.admin;

  /// Guests have read-only access to the workspace (enforced server-side).
  bool get isGuest => this == MemberRole.guest;

  String toJson() => switch (this) {
        MemberRole.owner => 'owner',
        MemberRole.admin => 'admin',
        MemberRole.member => 'member',
        MemberRole.guest => 'guest',
      };

  factory MemberRole.fromJson(String value) => switch (value) {
        'owner' => MemberRole.owner,
        'admin' => MemberRole.admin,
        'guest' => MemberRole.guest,
        _ => MemberRole.member,
      };

  /// Roles an admin can assign via the API (the owner is fixed).
  static List<MemberRole> get assignable =>
      <MemberRole>[MemberRole.admin, MemberRole.member, MemberRole.guest];
}
