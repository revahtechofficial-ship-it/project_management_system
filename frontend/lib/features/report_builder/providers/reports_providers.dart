import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/report_def.dart';
import '../../../data/repositories/reports_repository.dart';
import '../../../providers/dio_provider.dart';

/// The reports repository, from the shared Dio client (AGENTS.md §1).
final Provider<ReportsRepository> reportsRepositoryProvider =
    Provider<ReportsRepository>((ref) {
      return ReportsRepository(ref.watch(dioProvider));
    });

/// All saved report definitions. Invalidate to refresh after a change.
final FutureProvider<List<ReportDef>> savedReportsProvider =
    FutureProvider<List<ReportDef>>((ref) {
      return ref.watch(reportsRepositoryProvider).list();
    });
