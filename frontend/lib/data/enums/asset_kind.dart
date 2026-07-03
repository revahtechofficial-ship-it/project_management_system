import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The type of an inventory [Asset]. Tied to the model, so it carries
/// `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum AssetKind {
  hardware,
  software,
  license,
  accessory;

  String get label => switch (this) {
        AssetKind.hardware => 'Hardware',
        AssetKind.software => 'Software',
        AssetKind.license => 'License',
        AssetKind.accessory => 'Accessory',
      };

  Color get color => switch (this) {
        AssetKind.hardware => AppColors.sky,
        AssetKind.software => AppColors.violet,
        AssetKind.license => AppColors.amber,
        AssetKind.accessory => AppColors.teal,
      };

  IconData get icon => switch (this) {
        AssetKind.hardware => Icons.laptop_mac_outlined,
        AssetKind.software => Icons.apps_outlined,
        AssetKind.license => Icons.vpn_key_outlined,
        AssetKind.accessory => Icons.headset_mic_outlined,
      };

  /// Label for the identifier field, which means different things per kind.
  String get identifierLabel => switch (this) {
        AssetKind.hardware => 'Serial number',
        AssetKind.accessory => 'Serial number',
        AssetKind.software => 'License key',
        AssetKind.license => 'License key',
      };

  String toJson() => switch (this) {
        AssetKind.hardware => 'hardware',
        AssetKind.software => 'software',
        AssetKind.license => 'license',
        AssetKind.accessory => 'accessory',
      };

  factory AssetKind.fromJson(String value) => switch (value) {
        'software' => AssetKind.software,
        'license' => AssetKind.license,
        'accessory' => AssetKind.accessory,
        _ => AssetKind.hardware,
      };
}
