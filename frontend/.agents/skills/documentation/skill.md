# Skill: Documentation

> **Status: starter stub.** Extend with Revah Management System documentation conventions.

## Rules
- Add `///` dartdoc comments to **all public APIs**: classes, constructors,
  public methods, and top-level functions/providers.
- Start with a one-sentence summary in the imperative/declarative mood; add
  detail and examples below when behavior is non-obvious.
- Document **why**, not what the code already says. Avoid over-commenting
  self-explanatory code.
- **No trailing comments** (`AGENTS.md` §6) — put the comment on its own line
  above the code.
- Reference related symbols with square brackets (`[TasksRepository]`) so
  dartdoc links them.
- Keep comments truthful and in sync with the code; a stale comment is worse
  than none. Update docs in the same change as the code.
