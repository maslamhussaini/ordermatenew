// lib/core/providers/store_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';

/// Provider for the currently active store
/// This should be set when the user selects a store or when the app initializes
final currentStoreProvider = StateProvider<Store?>((ref) => null);

/// Provider that returns the currency code from the current store
/// Falls back to 'USD' if no store is selected
final currentCurrencyProvider = Provider<String>((ref) {
  final store = ref.watch(currentStoreProvider);
  return store?.storeDefaultCurrency ?? 'USD';
});
