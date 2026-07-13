import 'package:dio/dio.dart';

import '../../core/utils/date_format.dart';
import '../models/daily_content.dart';

/// Talks to /api/v1/daily — the parts of the patro that are written rather than
/// computed: observances, the quote, the rashifal
/// (AGENTS.md §1 `data/repositories`).
class DailyRepository {
  const DailyRepository(this._dio);

  final Dio _dio;

  /// Every observance. There are a few dozen and they recur every year, so the
  /// whole list is fetched once and matched against a date by month and day.
  Future<List<Observance>> observances() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/daily/observances',
    );
    return <Observance>[
      for (final dynamic e in res.data ?? <dynamic>[])
        Observance.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// The quote for [on], or null when nobody has entered any — the server
  /// answers 204 rather than inventing one.
  Future<Quote?> quoteOfTheDay(DateTime on) async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>(
          '/api/v1/daily/quote',
          queryParameters: <String, dynamic>{'date': dateParam(on)},
        );
    final Map<String, dynamic>? data = res.data;
    return data == null ? null : Quote.fromJson(data);
  }

  /// Every reading covering [on] — daily, weekly and monthly, all twelve signs.
  /// Empty until an astrologer's readings are entered.
  Future<List<Rashifal>> rashifal(DateTime on) async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/daily/rashifal',
      queryParameters: <String, dynamic>{'date': dateParam(on)},
    );
    return <Rashifal>[
      for (final dynamic e in res.data ?? <dynamic>[])
        Rashifal.fromJson(e as Map<String, dynamic>),
    ];
  }
}
