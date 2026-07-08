import 'file_download.dart';

/// CSV export helpers (AGENTS.md §1 `core/utils`). Build an RFC 4180 document
/// from headers + rows and download it in the browser.

String _escape(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Serialises [headers] + [rows] into an RFC 4180 CSV string (CRLF line
/// endings, quoted fields where needed).
String toCsv(List<String> headers, List<List<String>> rows) {
  final StringBuffer buffer = StringBuffer()
    ..write(headers.map(_escape).join(','))
    ..write('\r\n');
  for (final List<String> row in rows) {
    buffer
      ..write(row.map(_escape).join(','))
      ..write('\r\n');
  }
  return buffer.toString();
}

/// Builds a CSV from [headers] + [rows] and downloads it as [filename]. A UTF-8
/// BOM is prepended so Excel opens accented text correctly.
void exportCsv(String filename, List<String> headers, List<List<String>> rows) {
  final String name = filename.toLowerCase().endsWith('.csv')
      ? filename
      : '$filename.csv';
  downloadTextFile(name, '﻿${toCsv(headers, rows)}', 'text/csv');
}
