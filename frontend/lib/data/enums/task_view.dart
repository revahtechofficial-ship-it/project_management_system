import 'package:flutter/material.dart';

/// The available task views. UI/navigation-only, so it carries no JSON
/// serialization (AGENTS.md §9 Enums).
enum TaskView {
  list,
  board,
  calendar,
  gantt;

  String get label => switch (this) {
        TaskView.list => 'List',
        TaskView.board => 'Board',
        TaskView.calendar => 'Calendar',
        TaskView.gantt => 'Timeline',
      };

  IconData get icon => switch (this) {
        TaskView.list => Icons.view_list_rounded,
        TaskView.board => Icons.view_kanban_rounded,
        TaskView.calendar => Icons.calendar_month_rounded,
        TaskView.gantt => Icons.view_timeline_rounded,
      };
}
