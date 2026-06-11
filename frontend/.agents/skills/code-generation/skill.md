# Flutter Code Generation Skill

## Description
Active execution rules for building files that require code generation
(Riverpod, Freezed, AutoRoute). Note: JSON serialization in this project is
written **manually**, so `json_serializable` / `json_annotation` are **not**
used — see the *Application Architecture → Data Handling & Serialization*
section of `AGENTS.md`.

## Setup
- Ensure `build_runner` is listed as a `dev_dependency` in `pubspec.yaml`,
  alongside the relevant generators (e.g., `riverpod_generator`).
- Use `build_runner` for all code generation tasks, such as for `riverpod`
  (`riverpod_generator`) and `freezed`.

## Execution Rules
1. **DO NOT** manually generate or attempt to write the contents of `.g.dart` or `.freezed.dart` files.
2. You must write the correct `part '[file_name].g.dart';` or `part '[file_name].freezed.dart';` declarations in the primary Dart file.
3. After setting up the primary file and part directives, use the available MCP terminal tool to execute the build runner CLI command automatically.
4. If the MCP tool fails or environment constraints prevent execution, explicitly instruct the user to run the build command.

## Critical Build Commands
- Primary: `dart run build_runner build -d`
- Fallback: `flutter pub run build_runner build --delete-conflicting-outputs`
