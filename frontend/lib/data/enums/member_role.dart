import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// A team member's role. Tied to the `TeamMember` model, so it carries
/// `toJson` / `fromJson` with a sentinel default (AGENTS.md §9 Enums).
enum MemberRole {
  owner,
  admin,
  manager,
  developer,
  designer,
  qa,
  marketing,
  other;

  String get label => switch (this) {
        MemberRole.owner => 'Owner',
        MemberRole.admin => 'Admin',
        MemberRole.manager => 'Project Manager',
        MemberRole.developer => 'Developer',
        MemberRole.designer => 'Designer',
        MemberRole.qa => 'QA Engineer',
        MemberRole.marketing => 'Marketing',
        MemberRole.other => 'Member',
      };

  Color get color => switch (this) {
        MemberRole.owner => AppColors.brand,
        MemberRole.admin => AppColors.violet,
        MemberRole.manager => AppColors.sky,
        MemberRole.developer => AppColors.teal,
        MemberRole.designer => AppColors.rose,
        MemberRole.qa => AppColors.amber,
        MemberRole.marketing => AppColors.orange,
        MemberRole.other => AppColors.slate,
      };

  String toJson() => switch (this) {
        MemberRole.owner => 'owner',
        MemberRole.admin => 'admin',
        MemberRole.manager => 'manager',
        MemberRole.developer => 'developer',
        MemberRole.designer => 'designer',
        MemberRole.qa => 'qa',
        MemberRole.marketing => 'marketing',
        MemberRole.other => '',
      };

  factory MemberRole.fromJson(String value) => switch (value) {
        'owner' => MemberRole.owner,
        'admin' => MemberRole.admin,
        'manager' => MemberRole.manager,
        'developer' => MemberRole.developer,
        'designer' => MemberRole.designer,
        'qa' => MemberRole.qa,
        'marketing' => MemberRole.marketing,
        _ => MemberRole.other,
      };
}
