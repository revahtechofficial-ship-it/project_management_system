import 'package:dio/dio.dart';

import '../../core/utils/date_format.dart';
import '../models/asset.dart';

/// Talks to the backend's /api/v1/assets endpoints (AGENTS.md §1
/// `data/repositories`).
class AssetsRepository {
  const AssetsRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _body(Asset a) => <String, dynamic>{
        'name': a.name,
        'kind': a.kind.toJson(),
        'status': a.status.toJson(),
        'identifier': a.identifier,
        'vendor': a.vendor,
        'assignee_id': a.assigneeId,
        'cost_cents': a.costCents,
        'purchased_on': dateParam(a.purchasedOn) ?? '',
        'expires_on': dateParam(a.expiresOn) ?? '',
        'notes': a.notes,
      };

  /// The full inventory, ordered by name.
  Future<List<Asset>> list() async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/assets');
    return <Asset>[
      for (final dynamic e in res.data ?? <dynamic>[])
        Asset.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Adds a new inventory item.
  Future<void> create(Asset a) =>
      _dio.post<void>('/api/v1/assets', data: _body(a));

  /// Saves edits to an existing item.
  Future<void> update(int id, Asset a) =>
      _dio.patch<void>('/api/v1/assets/$id', data: _body(a));

  /// Removes an item from the inventory.
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/assets/$id');
}
