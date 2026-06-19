import 'package:flutter/material.dart';

/// The kind of workspace page. Tied to the [WorkspacePage] model, so it carries
/// `toJson`/`fromJson` with `snake_case`-free API string values (AGENTS.md §9).
enum PageType {
  doc,
  whiteboard,
  form;

  String get label => switch (this) {
    PageType.doc => 'Docs',
    PageType.whiteboard => 'Whiteboard',
    PageType.form => 'Form',
  };

  IconData get icon => switch (this) {
    PageType.doc => Icons.description_outlined,
    PageType.whiteboard => Icons.gesture_outlined,
    PageType.form => Icons.dynamic_form_outlined,
  };

  String toJson() => switch (this) {
    PageType.doc => 'doc',
    PageType.whiteboard => 'whiteboard',
    PageType.form => 'form',
  };

  factory PageType.fromJson(String value) => switch (value) {
    'whiteboard' => PageType.whiteboard,
    'form' => PageType.form,
    _ => PageType.doc,
  };
}
