import 'package:dio/dio.dart';

import '../models/admin_member.dart';
import '../models/audit_event.dart';
import '../models/workspace_settings.dart';

/// Talks to /api/v1/admin — the admin console: member access management, the
/// audit log and workspace security settings (AGENTS.md §1 `data/repositories`).
class AdminRepository {
  const AdminRepository(this._dio);

  final Dio _dio;

  Future<List<AdminMember>> members() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/admin/members',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => AdminMember.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> setRole(int id, String role) => _dio.patch<void>(
    '/api/v1/admin/members/$id/role',
    data: <String, dynamic>{'role': role},
  );

  Future<void> setActive(int id, bool active) => _dio.patch<void>(
    '/api/v1/admin/members/$id/active',
    data: <String, dynamic>{'active': active},
  );

  Future<List<AuditEvent>> auditLog() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/admin/audit-log',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => AuditEvent.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<WorkspaceSettings> settings() async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/admin/settings');
    return WorkspaceSettings.fromJson(res.data ?? const <String, dynamic>{});
  }

  Future<void> updateSettings(WorkspaceSettings settings) => _dio.put<void>(
    '/api/v1/admin/settings',
    data: <String, dynamic>{
      'name': settings.name,
      'allowed_domains': settings.allowedDomains,
      'require_2fa': settings.require2fa,
      'session_hours': settings.sessionHours,
    },
  );
}
