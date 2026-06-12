import 'package:dio/dio.dart';

import '../models/search_results.dart';

/// Talks to the workspace search endpoint (AGENTS.md §1 `data/repositories`).
class SearchRepository {
  const SearchRepository(this._dio);

  final Dio _dio;

  /// Searches tasks and projects for [query]. Tasks are paginated via
  /// [limit]/[offset]; projects come back only on the first page (offset 0).
  Future<SearchResults> search(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final Response<Map<String, dynamic>> res =
        await _dio.get<Map<String, dynamic>>(
      '/api/v1/search',
      queryParameters: <String, dynamic>{
        'q': query,
        'limit': limit,
        'offset': offset,
      },
    );
    return SearchResults.fromJson(res.data ?? const <String, dynamic>{});
  }
}
