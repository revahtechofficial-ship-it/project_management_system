import 'package:dio/dio.dart';

import '../../core/utils/date_format.dart';
import '../models/invoice.dart';

/// Talks to the backend's /api/v1/invoices endpoints (AGENTS.md §1
/// `data/repositories`).
class InvoicesRepository {
  const InvoicesRepository(this._dio);

  final Dio _dio;

  /// All invoices, newest first (without line items).
  Future<List<Invoice>> list() async {
    final Response<List<dynamic>> res = await _dio.get<List<dynamic>>(
      '/api/v1/invoices',
    );
    return <Invoice>[
      for (final dynamic e in res.data ?? <dynamic>[])
        Invoice.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// One invoice with its line items.
  Future<Invoice> get(int id) async {
    final Response<Map<String, dynamic>> res = await _dio
        .get<Map<String, dynamic>>('/api/v1/invoices/$id');
    return Invoice.fromJson(res.data ?? <String, dynamic>{});
  }

  Map<String, dynamic> _billTo({
    required int? projectId,
    required String clientName,
    required String clientEmail,
    DateTime? issueDate,
    DateTime? dueDate,
    String notes = '',
  }) => <String, dynamic>{
    'project_id': projectId,
    'client_name': clientName,
    'client_email': clientEmail,
    'issue_date': dateParam(issueDate) ?? '',
    'due_date': dateParam(dueDate) ?? '',
    'notes': notes,
  };

  /// Creates an empty draft invoice.
  Future<Invoice> create({
    int? projectId,
    String clientName = '',
    String clientEmail = '',
    DateTime? issueDate,
    DateTime? dueDate,
    String notes = '',
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/invoices',
          data: _billTo(
            projectId: projectId,
            clientName: clientName,
            clientEmail: clientEmail,
            issueDate: issueDate,
            dueDate: dueDate,
            notes: notes,
          ),
        );
    return Invoice.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Generates a draft invoice from a project's unbilled billable time.
  Future<Invoice> generate({
    required int projectId,
    String clientName = '',
    String clientEmail = '',
    int rateCents = 0,
    DateTime? issueDate,
    DateTime? dueDate,
    String notes = '',
  }) async {
    final Map<String, dynamic> data = _billTo(
      projectId: projectId,
      clientName: clientName,
      clientEmail: clientEmail,
      issueDate: issueDate,
      dueDate: dueDate,
      notes: notes,
    )..['rate_cents'] = rateCents;
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>('/api/v1/invoices/generate', data: data);
    return Invoice.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Moves an invoice through the draft → sent → paid (or void) workflow.
  Future<Invoice> setStatus(int id, String status) async {
    final Response<Map<String, dynamic>> res = await _dio
        .patch<Map<String, dynamic>>(
          '/api/v1/invoices/$id/status',
          data: <String, dynamic>{'status': status},
        );
    return Invoice.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Adds a manual line item and returns the refreshed invoice.
  Future<Invoice> addLine(
    int id, {
    required String description,
    required int amountCents,
    int quantityMinutes = 0,
    int rateCents = 0,
  }) async {
    final Response<Map<String, dynamic>> res = await _dio
        .post<Map<String, dynamic>>(
          '/api/v1/invoices/$id/lines',
          data: <String, dynamic>{
            'description': description,
            'quantity_minutes': quantityMinutes,
            'rate_cents': rateCents,
            'amount_cents': amountCents,
          },
        );
    return Invoice.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Removes a line item and returns the refreshed invoice.
  Future<Invoice> deleteLine(int id, int lineId) async {
    final Response<Map<String, dynamic>> res = await _dio
        .delete<Map<String, dynamic>>('/api/v1/invoices/$id/lines/$lineId');
    return Invoice.fromJson(res.data ?? <String, dynamic>{});
  }

  /// Deletes an invoice (releasing any time it billed).
  Future<void> delete(int id) => _dio.delete<void>('/api/v1/invoices/$id');
}
