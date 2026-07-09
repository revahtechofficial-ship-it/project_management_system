import 'package:dio/dio.dart';

import '../models/digest_data.dart';

/// The result of asking the server to email your digest.
typedef DigestEmailResult = ({bool sent, String reason});

/// Talks to /api/v1/digest — the personal activity summary (AGENTS.md §1
/// `data/repositories`).
class DigestRepository {
  const DigestRepository(this._dio);

  final Dio _dio;

  /// Your current digest: unread notifications and tasks due soon or overdue.
  Future<DigestData> get() async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/digest');
    return DigestData.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Emails the digest to yourself. Returns whether it was sent and, if not,
  /// why (e.g. email notifications turned off).
  Future<DigestEmailResult> emailToMe() async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>('/api/v1/digest/email');
    final Map<String, dynamic> data = res.data ?? <String, dynamic>{};
    return (
      sent: data['sent'] as bool? ?? false,
      reason: data['reason'] as String? ?? '',
    );
  }
}
