import 'dart:convert';

import 'package:flutter/material.dart' hide FormField;

import '../../data/enums/form_field_type.dart';
import '../../data/models/form_field.dart';
import '../../data/models/form_task_config.dart';

/// A built-in starter form: a ready-made field set (and optional auto-task
/// config) a user can spin a new form up from. These power the Lead Capture,
/// Request, Bug Report and Survey quick-starts in the Forms tab.
class FormStarter {
  const FormStarter({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.title,
    required this.fields,
    this.taskConfig = const FormTaskConfig(),
  });

  final String key;
  final String label;
  final String description;
  final IconData icon;
  final String title;
  final List<FormField> fields;
  final FormTaskConfig taskConfig;

  /// The page body JSON for a new form created from this starter.
  String body() => jsonEncode(<String, dynamic>{
    'fields': <Map<String, dynamic>>[
      for (final FormField f in fields) f.toJson(),
    ],
    'create_task': taskConfig.toJson(),
  });
}

FormField _field(
  String id,
  String label,
  FormFieldType type, {
  bool required = false,
  List<String> options = const <String>[],
}) => FormField(
  id: id,
  label: label,
  type: type,
  required: required,
  options: options,
);

/// The catalogue of starter forms offered in the Forms tab.
List<FormStarter> formStarters() => <FormStarter>[
  FormStarter(
    key: 'lead',
    label: 'Lead capture',
    description: 'Collect prospect details; each lead becomes a task',
    icon: Icons.person_add_alt_1_outlined,
    title: 'Lead capture',
    taskConfig: const FormTaskConfig(
      enabled: true,
      titleField: 'f0',
      priority: 'normal',
    ),
    fields: <FormField>[
      _field('f0', 'Full name', FormFieldType.text, required: true),
      _field('f1', 'Work email', FormFieldType.text, required: true),
      _field('f2', 'Company', FormFieldType.text),
      _field('f3', 'Phone', FormFieldType.text),
      _field(
        'f4',
        'What are you interested in?',
        FormFieldType.select,
        options: <String>[
          'Web development',
          'Mobile app',
          'Consulting',
          'Other',
        ],
      ),
      _field('f5', 'How can we help?', FormFieldType.textarea),
    ],
  ),
  FormStarter(
    key: 'request',
    label: 'Request form',
    description: 'Intake internal requests; each one becomes a task',
    icon: Icons.assignment_outlined,
    title: 'Request form',
    taskConfig: const FormTaskConfig(
      enabled: true,
      titleField: 'f0',
      priority: 'normal',
    ),
    fields: <FormField>[
      _field('f0', 'Request title', FormFieldType.text, required: true),
      _field(
        'f1',
        'Request type',
        FormFieldType.select,
        options: <String>['Access', 'Hardware', 'Software', 'Other'],
      ),
      _field('f2', 'Details', FormFieldType.textarea, required: true),
      _field(
        'f3',
        'Urgency',
        FormFieldType.select,
        options: <String>['Low', 'Medium', 'High'],
      ),
    ],
  ),
  FormStarter(
    key: 'bug',
    label: 'Bug report',
    description: 'Capture defects; each report becomes a high-priority task',
    icon: Icons.bug_report_outlined,
    title: 'Bug report',
    taskConfig: const FormTaskConfig(
      enabled: true,
      titleField: 'f0',
      priority: 'high',
    ),
    fields: <FormField>[
      _field('f0', 'Summary', FormFieldType.text, required: true),
      _field(
        'f1',
        'Steps to reproduce',
        FormFieldType.textarea,
        required: true,
      ),
      _field('f2', 'Expected result', FormFieldType.textarea),
      _field('f3', 'Actual result', FormFieldType.textarea),
      _field(
        'f4',
        'Severity',
        FormFieldType.select,
        options: <String>['Low', 'Medium', 'High', 'Critical'],
      ),
      _field('f5', 'Environment / device', FormFieldType.text),
    ],
  ),
  FormStarter(
    key: 'survey',
    label: 'Survey',
    description: 'Gather feedback with rating and open-ended questions',
    icon: Icons.poll_outlined,
    title: 'Survey',
    fields: <FormField>[
      _field(
        'f0',
        'How would you rate your experience?',
        FormFieldType.select,
        required: true,
        options: <String>['1 - Poor', '2', '3', '4', '5 - Excellent'],
      ),
      _field('f1', 'What did you like most?', FormFieldType.textarea),
      _field('f2', 'What could we improve?', FormFieldType.textarea),
      _field(
        'f3',
        'Would you recommend us?',
        FormFieldType.select,
        options: <String>['Yes', 'No', 'Maybe'],
      ),
    ],
  ),
];
