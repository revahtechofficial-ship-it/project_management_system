# Skill: Accessibility (A11Y)

> **Status: starter stub.** Extend with Revah Management System accessibility requirements.

## Rules
- **Contrast:** meet WCAG AA (4.5:1 for body text). Verify foreground/background
  pairs from the theme, not ad-hoc colors.
- **Dynamic text:** never hard-code text that ignores scaling. Let
  `MediaQuery.textScaler` work; test at large scale factors for overflow.
- **Semantics:** give meaningful `Semantics` labels to icon-only buttons and
  images; use `tooltip`/`semanticLabel` where available. Mark decorative
  elements with `ExcludeSemantics`.
- **Tap targets:** keep interactive targets ≥ 48×48 logical px.
- **Focus & order:** ensure logical focus traversal for keyboard/switch users
  (important on web).
- **Test** with a screen reader (TalkBack / VoiceOver / NVDA) and Flutter's
  accessibility guidelines / `flutter test` semantics matchers.
