import 'package:dio/dio.dart';

import '../models/automation_rule.dart';

/// Talks to /api/v1/automations — the rule-based automation engine
/// (AGENTS.md §1 `data/repositories`).
class AutomationsRepository {
  const AutomationsRepository(this._dio);

  final Dio _dio;

  Future<List<AutomationRule>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/automations',
    );
    final List<dynamic> data = res.data ?? <dynamic>[];
    return data
        .map((dynamic e) => AutomationRule.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> create({
    required String name,
    required bool enabled,
    required String trigger,
    required List<RuleCondition> conditions,
    required List<RuleAction> actions,
  }) => _dio.post<void>(
    '/api/v1/automations',
    data: _body(name, enabled, trigger, conditions, actions),
  );

  Future<void> update(
    int id, {
    required String name,
    required bool enabled,
    required String trigger,
    required List<RuleCondition> conditions,
    required List<RuleAction> actions,
  }) => _dio.put<void>(
    '/api/v1/automations/$id',
    data: _body(name, enabled, trigger, conditions, actions),
  );

  Future<void> setEnabled(int id, bool enabled) => _dio.patch<void>(
    '/api/v1/automations/$id/enabled',
    data: <String, dynamic>{'enabled': enabled},
  );

  Future<void> delete(int id) => _dio.delete<void>('/api/v1/automations/$id');

  Map<String, dynamic> _body(
    String name,
    bool enabled,
    String trigger,
    List<RuleCondition> conditions,
    List<RuleAction> actions,
  ) => <String, dynamic>{
    'name': name,
    'enabled': enabled,
    'trigger': trigger,
    'conditions': conditions.map((RuleCondition c) => c.toJson()).toList(),
    'actions': actions.map((RuleAction a) => a.toJson()).toList(),
  };
}
