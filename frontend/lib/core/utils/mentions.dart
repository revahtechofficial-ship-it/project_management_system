import 'package:flutter/widgets.dart';

import '../../data/models/team_member.dart';

/// Matches an `@token` (a first name or email local-part) in free text. Shared
/// by task comments and chat (AGENTS.md §1 `core/utils`).
final RegExp mentionRegExp = RegExp(r'@([A-Za-z0-9._-]+)');

/// Maps lowercased mention tokens (first name, email local-part) to member ids.
Map<String, int> mentionTokenMap(List<TeamMember> members) {
  final Map<String, int> map = <String, int>{};
  for (final TeamMember m in members) {
    final List<String> parts = m.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String s) => s.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) {
      map.putIfAbsent(parts.first.toLowerCase(), () => m.id);
    }
    final String local = m.email.split('@').first.toLowerCase();
    if (local.isNotEmpty) {
      map.putIfAbsent(local, () => m.id);
    }
  }
  return map;
}

/// The member ids mentioned in [body], resolved against a [tokens] map.
List<int> parseMentions(String body, Map<String, int> tokens) {
  final Set<int> ids = <int>{};
  for (final RegExpMatch m in mentionRegExp.allMatches(body)) {
    final int? id = tokens[m.group(1)!.toLowerCase()];
    if (id != null) {
      ids.add(id);
    }
  }
  return ids.toList();
}

/// Inline spans for [body] with valid @mentions (those whose token is in
/// [validTokens]) highlighted in [color].
List<InlineSpan> mentionSpans(
  String body,
  Set<String> validTokens,
  Color color,
) {
  final List<InlineSpan> spans = <InlineSpan>[];
  int last = 0;
  for (final RegExpMatch m in mentionRegExp.allMatches(body)) {
    if (m.start > last) {
      spans.add(TextSpan(text: body.substring(last, m.start)));
    }
    final String text = body.substring(m.start, m.end);
    if (validTokens.contains(m.group(1)!.toLowerCase())) {
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      );
    } else {
      spans.add(TextSpan(text: text));
    }
    last = m.end;
  }
  if (last < body.length) {
    spans.add(TextSpan(text: body.substring(last)));
  }
  return spans;
}
