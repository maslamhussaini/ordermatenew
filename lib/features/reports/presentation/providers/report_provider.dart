// lib/features/reports/presentation/providers/report_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/report_repository.dart';
import '../../data/repositories/report_repository_impl.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl();
});
