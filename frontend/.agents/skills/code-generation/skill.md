# Skill: Code Generation

> **Status: starter stub.** Reflects current project reality; extend with Revah Management System
> team standards as needed.

## Current stance in this project
Per `AGENTS.md` §9, models use **manual** JSON serialization — `json_serializable`,
`json_annotation`, and `build_runner` are **not** dependencies, and there are no
`*.g.dart` / `*.freezed.dart` files. Do not reintroduce them for models.

## If/when codegen is adopted (e.g. `riverpod_generator`)
1. Add the generator + `build_runner` as dev dependencies via the `pub` tool.
2. Add the `part 'x.g.dart';` directive to the source file.
3. Generate:
   ```sh
   dart run build_runner build --delete-conflicting-outputs
   ```
   Use `watch` during active development.
4. Commit generated files (`*.g.dart`) so CI and fresh clones build without a
   generation step.
5. Never hand-edit generated files; change the source + regenerate.
