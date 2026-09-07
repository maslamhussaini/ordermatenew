import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/inventory/data/repositories/stock_transfer_repository_impl.dart';
import 'package:ordermate/features/inventory/data/repositories/stock_transfer_local_repository.dart';
import 'package:ordermate/features/inventory/domain/entities/stock_transfer.dart';
import 'package:ordermate/features/inventory/domain/repositories/stock_transfer_repository.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

// State
class StockTransferState {
  final List<StockTransfer> transfers;
  final bool isLoading;
  final String? error;

  const StockTransferState({
    this.transfers = const [],
    this.isLoading = false,
    this.error,
  });

  StockTransferState copyWith({
    List<StockTransfer>? transfers,
    bool? isLoading,
    String? error,
  }) {
    return StockTransferState(
      transfers: transfers ?? this.transfers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Notifier
class StockTransferNotifier extends StateNotifier<StockTransferState> {
  final StockTransferRepository _repository;
  final Ref _ref;

  StockTransferNotifier(this._repository, this._ref)
      : super(const StockTransferState());

  Future<void> loadTransfers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orgState = _ref.read(organizationProvider);
      if (orgState.selectedOrganizationId == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final transfers = await _repository.getTransfers(
        organizationId: orgState.selectedOrganizationId,
        storeId: orgState.selectedStore?.id,
      );
      state = state.copyWith(transfers: transfers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createTransfer(StockTransfer transfer) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.createTransfer(transfer);
      await loadTransfers();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<String> generateNumber() async {
    return await _repository.generateTransferNumber('GP');
  }

  Future<void> updateTransfer(StockTransfer transfer) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.updateTransfer(transfer);
      await loadTransfers();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteTransfer(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.deleteTransfer(id);
      await loadTransfers();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

// Providers
final stockTransferRepositoryProvider =
    Provider<StockTransferRepository>((ref) {
  return StockTransferRepositoryImpl();
});

final stockTransferLocalRepositoryProvider =
    Provider<StockTransferLocalRepository>((ref) {
  return StockTransferLocalRepository();
});

final stockTransferProvider =
    StateNotifierProvider<StockTransferNotifier, StockTransferState>((ref) {
  final repo = ref.watch(stockTransferRepositoryProvider);
  return StockTransferNotifier(repo, ref);
});
