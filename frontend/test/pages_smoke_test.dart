import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:revahms_web/data/enums/dependency_type.dart';
import 'package:revahms_web/data/models/task.dart';
import 'package:revahms_web/data/models/task_dependency.dart';
import 'package:revahms_web/features/dashboard/dashboard_page.dart';
import 'package:revahms_web/features/notifications/notifications_page.dart';
import 'package:revahms_web/features/notifications/providers/notifications_providers.dart';
import 'package:revahms_web/features/projects/projects_page.dart';
import 'package:revahms_web/features/projects/providers/projects_providers.dart';
import 'package:revahms_web/features/reports/reports_page.dart';
import 'package:revahms_web/features/settings/settings_page.dart';
import 'package:revahms_web/features/tasks/providers/dependencies_providers.dart';
import 'package:revahms_web/features/tasks/providers/milestones_providers.dart';
import 'package:revahms_web/features/tasks/providers/tasks_providers.dart';
import 'package:revahms_web/features/tasks/tasks_page.dart';
import 'package:revahms_web/features/tasks/widgets/task_board_view.dart';
import 'package:revahms_web/features/tasks/widgets/task_calendar_view.dart';
import 'package:revahms_web/features/tasks/widgets/task_gantt_view.dart';
import 'package:revahms_web/features/team/providers/team_providers.dart';
import 'package:revahms_web/features/team/team_page.dart';
import 'package:revahms_web/providers/auth_provider.dart';

/// Reports signed-out without touching plugins.
class _SignedOutController extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.signedOut();
}

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1440, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedOutController.new),
        tasksProvider.overrideWith((ref) async => const <Task>[]),
        teamMembersProvider.overrideWith((ref) async => const []),
        projectsProvider.overrideWith((ref) async => const []),
        notificationsProvider.overrideWith((ref) async => const []),
        dependenciesProvider.overrideWith((ref) async => const []),
        milestonesProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(home: Scaffold(body: page)),
    ),
  );
  // First pump flushes the overridden provider futures (loading → data) so
  // pages that show a skeleton while loading settle onto their real content.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Dashboard renders', (WidgetTester tester) async {
    await _pump(tester, const DashboardPage());
    expect(find.text('Total tasks'), findsOneWidget);
  });

  testWidgets('Team renders', (WidgetTester tester) async {
    await _pump(tester, const TeamPage());
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Team members'), findsOneWidget);
  });

  testWidgets('Projects renders', (WidgetTester tester) async {
    await _pump(tester, const ProjectsPage());
    expect(find.text('Projects'), findsOneWidget);
  });

  testWidgets('Reports renders', (WidgetTester tester) async {
    await _pump(tester, const ReportsPage());
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Top contributors'), findsOneWidget);
  });

  testWidgets('Settings renders', (WidgetTester tester) async {
    await _pump(tester, const SettingsPage());
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('Inbox renders', (WidgetTester tester) async {
    await _pump(tester, const NotificationsPage());
    expect(find.text('Inbox'), findsOneWidget);
  });

  testWidgets('Tasks page renders (empty)', (WidgetTester tester) async {
    await _pump(tester, const TasksPage());
    expect(find.text('Tasks'), findsOneWidget);
  });

  testWidgets('Kanban board renders status columns',
      (WidgetTester tester) async {
    await _pump(
      tester,
      TaskBoardView(tasks: _sampleTasks(), onTapTask: (_) {}),
    );
    expect(find.text('Backlog'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('Calendar view renders dated tasks',
      (WidgetTester tester) async {
    await _pump(
      tester,
      TaskCalendarView(tasks: _sampleTasks(), onTapTask: (_) {}),
    );
    expect(find.byType(TaskCalendarView), findsOneWidget);
  });

  testWidgets('Gantt view renders dated tasks',
      (WidgetTester tester) async {
    await _pump(
      tester,
      TaskGanttView(tasks: _sampleTasks(), onTapTask: (_) {}),
    );
    // 'Set baseline' is admin-only; 'Milestones' is always shown.
    expect(find.text('Milestones'), findsOneWidget);
  });

  testWidgets('Gantt highlights the critical path',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutController.new),
          tasksProvider.overrideWith((ref) async => const <Task>[]),
          teamMembersProvider.overrideWith((ref) async => const []),
          projectsProvider.overrideWith((ref) async => const []),
          notificationsProvider.overrideWith((ref) async => const []),
          dependenciesProvider.overrideWith(
            (ref) async => const <TaskDependency>[
              TaskDependency(
                id: 1,
                predecessorId: 1,
                successorId: 2,
                type: DependencyType.finishToStart,
              ),
            ],
          ),
          milestonesProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TaskGanttView(tasks: _sampleTasks(), onTapTask: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    // Both linked tasks land on the critical path -> bolt markers shown.
    expect(find.byIcon(Icons.bolt), findsWidgets);
  });
}

List<Task> _sampleTasks() {
  final DateTime base = DateTime(2026, 6, 10);
  return <Task>[
    Task(
      id: 1,
      done: false,
      createdAt: base,
      updatedAt: base,
      title: 'Alpha',
      startDate: DateTime(2026, 6, 12),
      dueDate: DateTime(2026, 6, 16),
    ),
    Task(
      id: 2,
      done: true,
      createdAt: base,
      updatedAt: base,
      title: 'Beta',
      dueDate: DateTime(2026, 6, 14),
    ),
  ];
}
