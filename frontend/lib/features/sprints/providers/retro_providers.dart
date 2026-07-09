import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/enums/retro_kind.dart';
import '../../../data/models/retro_item.dart';
import '../../../providers/dio_provider.dart';

/// Talks to the sprint retrospective endpoints.
class RetroRepository {
  const RetroRepository(this._dio);

  final Dio _dio;

  Future<List<RetroItem>> list(int sprintId) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/sprints/$sprintId/retro',
    );
    return <RetroItem>[
      for (final dynamic e in res.data ?? <dynamic>[])
        RetroItem.fromJson(e as Map<String, dynamic>),
    ];
  }

  Future<void> add(int sprintId, RetroKind kind, String body) =>
      _dio.post<void>(
        '/api/v1/sprints/$sprintId/retro',
        data: <String, dynamic>{'kind': kind.toJson(), 'body': body},
      );

  Future<void> setDone(int itemId, bool done) => _dio.patch<void>(
    '/api/v1/sprints/retro/$itemId',
    data: <String, dynamic>{'done': done},
  );

  Future<void> delete(int itemId) =>
      _dio.delete<void>('/api/v1/sprints/retro/$itemId');
}

final Provider<RetroRepository> retroRepositoryProvider =
    Provider<RetroRepository>((ref) {
      return RetroRepository(ref.watch(dioProvider));
    });

/// The retrospective items for a sprint, keyed by sprint id.
final sprintRetroProvider = FutureProvider.family<List<RetroItem>, int>((
  ref,
  int sprintId,
) {
  return ref.watch(retroRepositoryProvider).list(sprintId);
});
