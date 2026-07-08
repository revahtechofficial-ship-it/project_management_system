import 'package:dio/dio.dart';

import '../models/report_def.dart';

/// Talks to /api/v1/reports — saved report definitions (AGENTS.md §1
/// `data/repositories`).
class ReportsRepository {
  const ReportsRepository(this._dio);

  final Dio _dio;

  /// Every saved report definition.
  Future<List<ReportDef>> list() async {
    final Response<List<dynamic>> res =
        await _dio.get<List<dynamic>>('/api/v1/reports');
    return <ReportDef>[
      for (final dynamic e in res.data ?? <dynamic>[])
        ReportDef.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// Saves a new report definition and returns it.
  Future<ReportDef> create({
    required String name,
    required List<String> columns,
    required List<ReportFilter> filters,
  }) async {
    final Response<Map<String, dynamic>> res =
        await _dio.post<Map<String, dynamic>>(
      '/api/v1/reports',
      data: _body(name, columns, filters),
    );
    return ReportDef.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Updates an existing report definition.
  Future<ReportDef> update(
    int id, {
    required String name,
    required List<String> columns,
    required List<ReportFilter> filters,
  }) async {
    final Response<Map<String, dynamic>> res =
        await _dio.put<Map<String, dynamic>>(
      '/api/v1/reports/$id',
      data: _body(name, columns, filters),
    );
    return ReportDef.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Deletes a saved report.
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/reports/$id');

  Map<String, dynamic> _body(
    String name,
    List<String> columns,
    List<ReportFilter> filters,
  ) =>
      <String, dynamic>{
        'name': name,
        'config': <String, dynamic>{
          'columns': columns,
          'filters': filters.map((ReportFilter f) => f.toJson()).toList(),
        },
      };
}
