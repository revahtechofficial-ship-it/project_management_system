# Skill: Layout

> **Status: starter stub.** Extend with Revah Management System layout conventions.

## Rules
- Build **overflow-safe** layouts: wrap flexible children in `Expanded` /
  `Flexible` inside `Row`/`Column`; use `Wrap` when content should reflow.
- Long/possibly-scrolling content goes in a scroll view (`SingleChildScrollView`,
  `ListView`); use `ListView.builder` / `SliverList` for long/lazy lists.
- Use `SafeArea` for screen-edge insets; `LayoutBuilder` / `MediaQuery` for
  responsive breakpoints (web has wide viewports).
- Prefer `Stack` + `Positioned` for overlays anchored to the layout; use
  `OverlayPortal` for transient floating UI (menus, tooltips, popovers).
- Avoid fixed pixel sizes that break on small/large screens; prefer intrinsic
  sizing, `Flexible`, and constraints.
- Keep `build()` shallow — extract sub-trees into small private `Widget`
  classes (see `AGENTS.md` §7) rather than deeply nesting.
