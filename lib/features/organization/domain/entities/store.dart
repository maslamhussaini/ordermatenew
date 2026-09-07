import 'package:equatable/equatable.dart';

class Store extends Equatable {
  const Store({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.storeDefaultCurrency = 'USD',
    this.location,
    this.city,
    this.country,
    this.postalCode,
    this.phone,
    this.isActive = true,
  });

  final int id;
  final int organizationId;
  final String name;
  final String storeDefaultCurrency;
  final String? location;
  final String? city;
  final String? country;
  final String? postalCode;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        organizationId,
        name,
        storeDefaultCurrency,
        location,
        city,
        country,
        postalCode,
        phone,
        isActive,
        createdAt,
        updatedAt
      ];

  /// Resolves which of [stores] should be pre-selected, mirroring
  /// `FinancialSession.resolveDefault`: only ever auto-picks when the choice
  /// is unambiguous, otherwise returns null so the caller shows a dropdown
  /// for the user to choose explicitly.
  ///
  /// `omtbl_stores` has no default/primary-store flag today, so "there is
  /// exactly one store" is the only unambiguous automatic case.
  static Store? resolveDefault(
    List<Store> stores, {
    int? previouslySelectedId,
  }) {
    if (stores.isEmpty) return null;

    if (previouslySelectedId != null) {
      final previous =
          stores.where((s) => s.id == previouslySelectedId).firstOrNull;
      if (previous != null) return previous;
    }

    if (stores.length == 1) return stores.first;

    return null;
  }
}
