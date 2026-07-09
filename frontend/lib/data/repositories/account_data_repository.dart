import 'package:dio/dio.dart';

/// Talks to /api/v1/account — the GDPR-style personal data export (AGENTS.md
/// §1 `data/repositories`).
class AccountDataRepository {
  const AccountDataRepository(this._dio);

  final Dio _dio;

  /// Fetches the authenticated user's exportable data as a JSON map.
  Future<Map<String, dynamic>> export() async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/account/export');
    return res.data ?? <String, dynamic>{};
  }
}
