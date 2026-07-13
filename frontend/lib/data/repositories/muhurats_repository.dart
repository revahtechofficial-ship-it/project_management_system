import 'package:dio/dio.dart';

import '../../core/utils/date_format.dart';
import '../models/muhurat.dart';

/// Talks to /api/v1/muhurats — the saait (AGENTS.md §1 `data/repositories`).
class MuhuratsRepository {
  const MuhuratsRepository(this._dio);

  final Dio _dio;

  /// Saait between [from] and [to]; the server defaults to a wide window.
  Future<List<Muhurat>> list({DateTime? from, DateTime? to}) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/muhurats',
      queryParameters: <String, dynamic>{
        if (from != null) 'from': dateParam(from),
        if (to != null) 'to': dateParam(to),
      },
    );
    return <Muhurat>[
      for (final dynamic e in res.data ?? <dynamic>[])
        Muhurat.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Adds a saait, ignoring its id (admin only, enforced server-side).
  Future<void> create(Muhurat muhurat) =>
      _dio.post<void>('/api/v1/muhurats', data: muhurat.toJson());

  /// Removes a saait (admin only).
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/muhurats/$id');
}
