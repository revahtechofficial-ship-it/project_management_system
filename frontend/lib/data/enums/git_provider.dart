import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The hosting provider of a registered [GitRepo]. Tied to the model, so it
/// carries `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum GitProvider {
  github,
  gitlab,
  bitbucket,
  other;

  String get label => switch (this) {
    GitProvider.github => 'GitHub',
    GitProvider.gitlab => 'GitLab',
    GitProvider.bitbucket => 'Bitbucket',
    GitProvider.other => 'Other',
  };

  Color get color => switch (this) {
    GitProvider.github => AppColors.slate,
    GitProvider.gitlab => AppColors.orange,
    GitProvider.bitbucket => AppColors.sky,
    GitProvider.other => AppColors.violet,
  };

  IconData get icon => switch (this) {
    GitProvider.github => Icons.hub_outlined,
    GitProvider.gitlab => Icons.account_tree_outlined,
    GitProvider.bitbucket => Icons.source_outlined,
    GitProvider.other => Icons.commit,
  };

  String toJson() => switch (this) {
    GitProvider.github => 'github',
    GitProvider.gitlab => 'gitlab',
    GitProvider.bitbucket => 'bitbucket',
    GitProvider.other => 'other',
  };

  factory GitProvider.fromJson(String value) => switch (value) {
    'gitlab' => GitProvider.gitlab,
    'bitbucket' => GitProvider.bitbucket,
    'other' => GitProvider.other,
    _ => GitProvider.github,
  };
}
