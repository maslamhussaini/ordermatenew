// lib/features/customers/domain/usecases/get_customers_by_location_usecase.dart

import 'package:ordermate/features/customers/domain/entities/customer.dart';
import 'package:ordermate/features/customers/domain/repositories/customer_repository.dart';

class GetCustomersByLocationUseCase {
  GetCustomersByLocationUseCase(this.repository);
  final CustomerRepository repository;

  Future<List<Customer>> call({
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
  }) {
    return repository.getCustomersByLocation(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }
}
