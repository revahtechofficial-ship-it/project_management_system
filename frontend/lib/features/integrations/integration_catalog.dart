import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// How an integration is connected, which decides the field shown in the
/// connect dialog and whether it can receive live event deliveries.
enum IntegrationKind {
  /// Delivers event notifications to a webhook URL (genuinely live).
  delivery,

  /// Connects with an access token.
  token,

  /// Connects with an account / email reference.
  account,
}

/// Static display metadata for a connectable integration. Connection state
/// lives server-side (the `Integration` model); this is just the catalogue.
class IntegrationInfo {
  const IntegrationInfo({
    required this.provider,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.kind,
    required this.category,
  });

  final String provider;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final IntegrationKind kind;
  final String category;

  /// The config key the connect dialog writes the primary value to.
  String get primaryKey => switch (kind) {
    IntegrationKind.delivery => 'url',
    IntegrationKind.token => 'token',
    IntegrationKind.account => 'account',
  };

  /// The label for the primary connect field.
  String get primaryLabel => switch (kind) {
    IntegrationKind.delivery => 'Incoming webhook URL',
    IntegrationKind.token => 'Access token',
    IntegrationKind.account => 'Account email',
  };

  bool get masked => kind == IntegrationKind.token;

  /// Whether connecting this provider delivers live event notifications.
  bool get isLive => kind == IntegrationKind.delivery;
}

/// The integrations catalogue, grouped by [IntegrationInfo.category].
const List<IntegrationInfo> kIntegrations = <IntegrationInfo>[
  IntegrationInfo(
    provider: 'slack',
    name: 'Slack',
    description: 'Post task updates to a Slack channel.',
    icon: Icons.tag,
    color: AppColors.violet,
    kind: IntegrationKind.delivery,
    category: 'Communication',
  ),
  IntegrationInfo(
    provider: 'teams',
    name: 'Microsoft Teams',
    description: 'Post task updates to a Teams channel.',
    icon: Icons.groups_outlined,
    color: AppColors.sky,
    kind: IntegrationKind.delivery,
    category: 'Communication',
  ),
  IntegrationInfo(
    provider: 'zapier',
    name: 'Zapier',
    description: 'Trigger Zaps from task events via a catch hook.',
    icon: Icons.bolt_outlined,
    color: AppColors.orange,
    kind: IntegrationKind.delivery,
    category: 'Automation',
  ),
  IntegrationInfo(
    provider: 'github',
    name: 'GitHub',
    description: 'Link a repository and reference commits & PRs.',
    icon: Icons.code,
    color: AppColors.slate,
    kind: IntegrationKind.token,
    category: 'Code',
  ),
  IntegrationInfo(
    provider: 'gitlab',
    name: 'GitLab',
    description: 'Link a GitLab project for commits & merge requests.',
    icon: Icons.merge_type,
    color: AppColors.orange,
    kind: IntegrationKind.token,
    category: 'Code',
  ),
  IntegrationInfo(
    provider: 'bitbucket',
    name: 'Bitbucket',
    description: 'Link a Bitbucket repository.',
    icon: Icons.account_tree_outlined,
    color: AppColors.sky,
    kind: IntegrationKind.token,
    category: 'Code',
  ),
  IntegrationInfo(
    provider: 'google_drive',
    name: 'Google Drive',
    description: 'Attach Drive files to tasks and docs.',
    icon: Icons.folder_shared_outlined,
    color: AppColors.green,
    kind: IntegrationKind.account,
    category: 'Storage',
  ),
  IntegrationInfo(
    provider: 'dropbox',
    name: 'Dropbox',
    description: 'Attach Dropbox files to tasks.',
    icon: Icons.cloud_outlined,
    color: AppColors.sky,
    kind: IntegrationKind.token,
    category: 'Storage',
  ),
  IntegrationInfo(
    provider: 'google_calendar',
    name: 'Google Calendar',
    description: 'Sync due dates to a Google Calendar.',
    icon: Icons.event_outlined,
    color: AppColors.sky,
    kind: IntegrationKind.account,
    category: 'Calendar',
  ),
  IntegrationInfo(
    provider: 'outlook',
    name: 'Outlook',
    description: 'Sync due dates and mail with Outlook.',
    icon: Icons.mail_outline,
    color: AppColors.brand,
    kind: IntegrationKind.account,
    category: 'Calendar',
  ),
  IntegrationInfo(
    provider: 'zoom',
    name: 'Zoom',
    description: 'Start Zoom meetings from tasks.',
    icon: Icons.videocam_outlined,
    color: AppColors.sky,
    kind: IntegrationKind.token,
    category: 'Meetings',
  ),
  IntegrationInfo(
    provider: 'figma',
    name: 'Figma',
    description: 'Embed Figma designs in tasks and docs.',
    icon: Icons.design_services_outlined,
    color: AppColors.rose,
    kind: IntegrationKind.token,
    category: 'Design',
  ),
];

/// The task events an outgoing webhook can subscribe to.
const List<(String, String)> kWebhookEvents = <(String, String)>[
  ('task.created', 'Task created'),
  ('task.updated', 'Task updated'),
  ('task.completed', 'Task completed'),
  ('comment.created', 'Comment added'),
];
