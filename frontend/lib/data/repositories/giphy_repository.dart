import 'package:dio/dio.dart';

import '../../core/constants/app_config.dart';
import '../models/giphy_item.dart';

/// Talks to the Giphy REST API for GIFs and stickers (AGENTS.md §1
/// `data/repositories`). Uses its own Dio (Giphy is a separate host, no app
/// auth header).
class GiphyRepository {
  GiphyRepository() : _dio = Dio();

  final Dio _dio;
  static const String _base = 'https://api.giphy.com/v1';

  /// Trending or searched GIFs/stickers. Returns an empty list when no key is
  /// configured or the request fails.
  Future<List<GiphyItem>> fetch({
    required bool stickers,
    String query = '',
  }) async {
    if (!AppConfig.giphyEnabled) {
      return const <GiphyItem>[];
    }
    final String kind = stickers ? 'stickers' : 'gifs';
    final String trimmed = query.trim();
    final String path = trimmed.isEmpty
        ? '$_base/$kind/trending'
        : '$_base/$kind/search';
    try {
      final Response<Map<String, dynamic>> res = await _dio
          .get<Map<String, dynamic>>(
            path,
            queryParameters: <String, dynamic>{
              'api_key': AppConfig.giphyApiKey,
              if (trimmed.isNotEmpty) 'q': trimmed,
              'limit': 24,
              'rating': 'pg',
              'bundle': 'fixed_height',
            },
          );
      final List<dynamic> data =
          (res.data?['data'] as List<dynamic>?) ?? <dynamic>[];
      return data
          .map((dynamic e) => GiphyItem.fromJson(e as Map<String, dynamic>))
          .where((GiphyItem g) => g.url.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <GiphyItem>[];
    }
  }
}
