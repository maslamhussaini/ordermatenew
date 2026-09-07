import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:ordermate/features/accounting/data/repositories/local_accounting_repository.dart';
import 'package:ordermate/features/accounting/domain/repositories/accounting_repository.dart';

final localAccountingRepositoryProvider =
    Provider<LocalAccountingRepository>((ref) {
  return LocalAccountingRepository();
});

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  final localRepo = ref.watch(localAccountingRepositoryProvider);
  return AccountingRepositoryImpl(localRepo);
});
