import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// What kind of day a holiday is. Independent of whether the office closes —
/// Christmas is religious and public, Gai Jatra is local and is not.
///
/// Tied to the `Holiday` model, so it carries `toJson` / `fromJson`, with
/// [other] as the resilient default (AGENTS.md §9 Enums).
enum FestivalCategory {
  religious,
  national,
  local,
  international,
  other;

  String get label => switch (this) {
    FestivalCategory.religious => 'Religious',
    FestivalCategory.national => 'National',
    FestivalCategory.local => 'Local',
    FestivalCategory.international => 'International',
    FestivalCategory.other => 'Other',
  };

  String get labelNe => switch (this) {
    FestivalCategory.religious => 'धार्मिक',
    FestivalCategory.national => 'राष्ट्रिय',
    FestivalCategory.local => 'स्थानीय',
    FestivalCategory.international => 'अन्तर्राष्ट्रिय',
    FestivalCategory.other => 'अन्य',
  };

  Color get color => switch (this) {
    FestivalCategory.religious => AppColors.orange,
    FestivalCategory.national => AppColors.brand,
    FestivalCategory.local => AppColors.teal,
    FestivalCategory.international => AppColors.sky,
    FestivalCategory.other => AppColors.slate,
  };

  IconData get icon => switch (this) {
    FestivalCategory.religious => Icons.temple_hindu_outlined,
    FestivalCategory.national => Icons.flag_outlined,
    FestivalCategory.local => Icons.location_city_outlined,
    FestivalCategory.international => Icons.public_outlined,
    FestivalCategory.other => Icons.event_outlined,
  };

  String toJson() => name;

  factory FestivalCategory.fromJson(String value) => switch (value) {
    'religious' => FestivalCategory.religious,
    'national' => FestivalCategory.national,
    'local' => FestivalCategory.local,
    'international' => FestivalCategory.international,
    _ => FestivalCategory.other,
  };
}
