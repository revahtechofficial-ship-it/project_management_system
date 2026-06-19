import 'package:flutter/material.dart';

/// The available task views. UI/navigation-only, so it carries no JSON
/// serialization (AGENTS.md §9 Enums).
enum TaskView {
  list,
  board,
  table,
  calendar,
  timeline,
  gantt,
  workload,
  activity,
  mindMap;

  String get label => switch (this) {
    TaskView.list => 'List',
    TaskView.board => 'Board',
    TaskView.table => 'Table',
    TaskView.calendar => 'Calendar',
    TaskView.timeline => 'Timeline',
    TaskView.gantt => 'Gantt',
    TaskView.workload => 'Workload',
    TaskView.activity => 'Activity',
    TaskView.mindMap => 'Mind Map',
  };

  IconData get icon => switch (this) {
    TaskView.list => Icons.view_list_rounded,
    TaskView.board => Icons.view_kanban_rounded,
    TaskView.table => Icons.table_chart_rounded,
    TaskView.calendar => Icons.calendar_month_rounded,
    TaskView.timeline => Icons.timeline_rounded,
    TaskView.gantt => Icons.view_timeline_rounded,
    TaskView.workload => Icons.equalizer_rounded,
    TaskView.activity => Icons.history_rounded,
    TaskView.mindMap => Icons.hub_rounded,
  };

  /// Whether bulk multi-select applies to this view (only the flat list).
  bool get supportsSelection => this == TaskView.list;
}
