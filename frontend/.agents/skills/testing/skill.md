# Skill: Testing

> **Status: starter stub.** Extend with NexaX coverage targets and CI rules.

## Rules
- Structure every test **Arrange-Act-Assert**.
- **Unit tests** for pure logic (models, repositories, utils). Test
  `Task.fromJson`/`toJson`/`==` round-trips.
- **Widget tests** for UI. Keep them offline: override providers with
  `ProviderScope(overrides: [...])` instead of hitting the network
  (see `test/widget_test.dart`).
- **Integration tests** for critical end-to-end flows.
- Inject fakes via Riverpod overrides (fake `Dio`/repositories) — design code
  for testability (`AGENTS.md` §5). Avoid real timers/network in widget tests
  (causes "pending timer" failures).
- Run: `flutter test` (add `--coverage` for coverage).
- A test should fail for exactly one reason; assert on behavior, not internals.
