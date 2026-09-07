import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/services/subscription_service.dart';
import 'package:ordermate/features/products/data/repositories/product_repository_impl.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:ordermate/features/products/domain/repositories/product_repository.dart';
import 'package:ordermate/features/products/data/repositories/product_local_repository.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

import 'package:ordermate/features/dashboard/presentation/providers/dashboard_provider.dart';

// State
class ProductState {
  const ProductState({
    this.products = const [],
    this.isLoading = false,
    this.error,
  });
  final List<Product> products;
  final bool isLoading;
  final String? error;

  ProductState copyWith({
    List<Product>? products,
    bool? isLoading,
    String? error,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Notifier
class ProductNotifier extends StateNotifier<ProductState> {
  final Ref ref;
  final ProductRepository repository;
  final ProductLocalRepository localRepository;

  ProductNotifier(this.ref, this.repository, this.localRepository)
      : super(const ProductState());

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true);
    final orgId = ref.read(organizationProvider).selectedOrganizationId;

    try {
      if (!mounted) return;
      final products =
          await repository.getProducts(organizationId: orgId);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, products: products);
    } catch (e) {
      try {
        final localProducts = await localRepository.getLocalProducts(
            organizationId: orgId);
        if (!mounted) return;
        if (localProducts.isNotEmpty) {
          state = state.copyWith(
              isLoading: false, products: localProducts, error: null);
        } else {
          state = state.copyWith(isLoading: false, error: e.toString());
        }
      } catch (localE) {
        if (!mounted) return;
        state = state.copyWith(
            isLoading: false, error: 'Online: $e, Offline: $localE');
      }
    }
  }

  Future<void> addProduct(Product product) async {
    state = state.copyWith(isLoading: true);
    final orgId = ref.read(organizationProvider).selectedOrganizationId;

    try {
      if (orgId != null) {
        await ref.read(subscriptionServiceProvider).checkAction(orgId, 'product');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return;
    }

    final productWithOrg = product.copyWith(organizationId: orgId);
    try {
      await repository.createProduct(productWithOrg);
      if (!mounted) return;
      await loadProducts();
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        try {
          await localRepository.addProduct(product);
          if (!mounted) return;
          final localProducts = await localRepository.getLocalProducts(
              organizationId: orgId);
          if (!mounted) return;
          state = state.copyWith(isLoading: false, products: localProducts);
          ref.read(dashboardProvider.notifier).refresh();
          return;
        } catch (localE) {
          if (!mounted) return;
          state = state.copyWith(
              isLoading: false, error: 'Offline add failed: $localE');
          rethrow;
        }
      }
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    state = state.copyWith(isLoading: true);
    final orgId = ref.read(organizationProvider).selectedOrganizationId;
    final productWithOrg = product.copyWith(organizationId: orgId);
    try {
      await repository.updateProduct(productWithOrg);
      if (!mounted) return;
      await loadProducts();
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network')) {
        try {
          await localRepository.updateProduct(product);
          if (!mounted) return;
          final localProducts = await localRepository.getLocalProducts(
              organizationId: orgId);
          if (!mounted) return;
          state = state.copyWith(isLoading: false, products: localProducts);
          ref.read(dashboardProvider.notifier).refresh();
          return;
        } catch (localE) {
          if (!mounted) return;
          state = state.copyWith(
              isLoading: false, error: 'Offline update failed: $localE');
          rethrow;
        }
      }
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await repository.deleteProduct(id);
      if (!mounted) return;
      await loadProducts();
      ref.read(dashboardProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

// Providers
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl();
});

final productLocalRepositoryProvider = Provider<ProductLocalRepository>((ref) {
  return ProductLocalRepository();
});

final productProvider =
    StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  final localRepository = ref.watch(productLocalRepositoryProvider);

  final notifier = ProductNotifier(ref, repository, localRepository);
  Future.microtask(() => notifier.loadProducts());

  return notifier;
});
