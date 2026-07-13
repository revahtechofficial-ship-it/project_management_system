import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// The ceremony a saait is good for. Tied to the `Muhurat` model, so it carries
/// `toJson` / `fromJson` with [other] as the resilient default
/// (AGENTS.md §9 Enums).
enum MuhuratKind {
  marriage,
  bratabandha,
  grihaPravesh,
  annaprashan,
  business,
  other;

  String get label => switch (this) {
    MuhuratKind.marriage => 'Marriage',
    MuhuratKind.bratabandha => 'Bratabandha',
    MuhuratKind.grihaPravesh => 'Griha Pravesh',
    MuhuratKind.annaprashan => 'Annaprashan',
    MuhuratKind.business => 'Business',
    MuhuratKind.other => 'Other',
  };

  String get labelNe => switch (this) {
    MuhuratKind.marriage => 'विवाह',
    MuhuratKind.bratabandha => 'व्रतबन्ध',
    MuhuratKind.grihaPravesh => 'गृह प्रवेश',
    MuhuratKind.annaprashan => 'अन्नप्राशन',
    MuhuratKind.business => 'व्यापार',
    MuhuratKind.other => 'अन्य',
  };

  Color get color => switch (this) {
    MuhuratKind.marriage => AppColors.rose,
    MuhuratKind.bratabandha => AppColors.orange,
    MuhuratKind.grihaPravesh => AppColors.teal,
    MuhuratKind.annaprashan => AppColors.amber,
    MuhuratKind.business => AppColors.brand,
    MuhuratKind.other => AppColors.slate,
  };

  IconData get icon => switch (this) {
    MuhuratKind.marriage => Icons.favorite_outline,
    MuhuratKind.bratabandha => Icons.self_improvement_outlined,
    MuhuratKind.grihaPravesh => Icons.home_outlined,
    MuhuratKind.annaprashan => Icons.restaurant_outlined,
    MuhuratKind.business => Icons.storefront_outlined,
    MuhuratKind.other => Icons.event_available_outlined,
  };

  String toJson() => switch (this) {
    MuhuratKind.grihaPravesh => 'griha_pravesh',
    _ => name,
  };

  factory MuhuratKind.fromJson(String value) => switch (value) {
    'marriage' => MuhuratKind.marriage,
    'bratabandha' => MuhuratKind.bratabandha,
    'griha_pravesh' => MuhuratKind.grihaPravesh,
    'annaprashan' => MuhuratKind.annaprashan,
    'business' => MuhuratKind.business,
    _ => MuhuratKind.other,
  };
}
