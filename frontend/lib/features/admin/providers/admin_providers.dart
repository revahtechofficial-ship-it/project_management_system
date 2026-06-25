import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/admin_member.dart';
import '../../../data/models/audit_event.dart';
import '../../../data/models/workspace_settings.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../providers/dio_provider.dart';

/// The admin repository, built from the shared Dio client (AGENTS.md §1).
final Provider<AdminRepository> adminRepositoryProvider =
    Provider<AdminRepository>((ref) {
      return AdminRepository(ref.watch(dioProvider));
    });

/// All workspace members with their role and status. Invalidate to refresh.
final FutureProvider<List<AdminMember>> adminMembersProvider =
    FutureProvider<List<AdminMember>>((ref) {
      return ref.watch(adminRepositoryProvider).members();
    });

/// The security/administration audit log. Invalidate to refresh.
final FutureProvider<List<AuditEvent>> auditLogProvider =
    FutureProvider<List<AuditEvent>>((ref) {
      return ref.watch(adminRepositoryProvider).auditLog();
    });

/// Workspace security settings. Invalidate to refresh.
final FutureProvider<WorkspaceSettings> workspaceSettingsProvider =
    FutureProvider<WorkspaceSettings>((ref) {
      return ref.watch(adminRepositoryProvider).settings();
    });
