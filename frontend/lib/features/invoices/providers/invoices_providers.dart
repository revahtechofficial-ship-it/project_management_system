import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/invoice.dart';
import '../../../data/repositories/invoices_repository.dart';
import '../../../providers/dio_provider.dart';

/// The invoices repository, from the shared Dio client (AGENTS.md §1).
final Provider<InvoicesRepository> invoicesRepositoryProvider =
    Provider<InvoicesRepository>((ref) {
  return InvoicesRepository(ref.watch(dioProvider));
});

/// All invoices (list view, without line items). Invalidate to refresh.
final FutureProvider<List<Invoice>> invoicesProvider =
    FutureProvider<List<Invoice>>((ref) {
  return ref.watch(invoicesRepositoryProvider).list();
});

/// One invoice with its line items, keyed by invoice id.
final invoiceDetailProvider =
    FutureProvider.family<Invoice, int>((ref, int id) {
  return ref.watch(invoicesRepositoryProvider).get(id);
});
