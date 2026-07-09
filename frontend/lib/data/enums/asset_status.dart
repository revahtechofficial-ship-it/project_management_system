import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Lifecycle state of an inventory [Asset]. Tied to the model, so it carries
/// `toJson` / `fromJson` (AGENTS.md §9 Enums).
enum AssetStatus {
  available,
  inUse,
  maintenance,
  retired;

  String get label => switch (this) {
    AssetStatus.available => 'Available',
    AssetStatus.inUse => 'In use',
    AssetStatus.maintenance => 'Maintenance',
    AssetStatus.retired => 'Retired',
  };

  Color get color => switch (this) {
    AssetStatus.available => AppColors.green,
    AssetStatus.inUse => AppColors.brand,
    AssetStatus.maintenance => AppColors.amber,
    AssetStatus.retired => AppColors.slate,
  };

  String toJson() => switch (this) {
    AssetStatus.available => 'available',
    AssetStatus.inUse => 'in_use',
    AssetStatus.maintenance => 'maintenance',
    AssetStatus.retired => 'retired',
  };

  factory AssetStatus.fromJson(String value) => switch (value) {
    'in_use' => AssetStatus.inUse,
    'maintenance' => AssetStatus.maintenance,
    'retired' => AssetStatus.retired,
    _ => AssetStatus.available,
  };
}
