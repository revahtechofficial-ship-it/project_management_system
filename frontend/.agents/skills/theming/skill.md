# Skill: Visual Design & Theming

> **Status: starter stub.** Extend with NexaX brand/theme decisions.

## Rules
- Use **Material 3** (`useMaterial3: true`) with `ColorScheme.fromSeed`.
- Define the theme once and pass it to `MaterialApp.router(theme: ...)` in
  `lib/app.dart`. For anything non-trivial, extract a `core/` theme builder.
- Centralize colors as `const` in `lib/core/constants/` (e.g. `AppColors`);
  never hard-code `Color(0x...)` inside widgets.
- Style components via component themes (`appBarTheme`, `filledButtonTheme`,
  `cardTheme`, …) rather than per-widget overrides.
- For interactive state styling use `WidgetStateProperty.resolveWith` (hover /
  pressed / disabled), not manual state tracking.
- Read colors/text styles from `Theme.of(context)` — don't reach for raw
  constants in `build()` when a theme token exists.
- Support light/dark via `theme` + `darkTheme` + `themeMode`.
