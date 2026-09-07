// lib/features/customers/domain/repositories/customer_repository.dart

import 'package:ordermate/features/customers/domain/entities/customer.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getCustomersByLocation({
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
  });

  Future<Customer> createCustomer(Customer customer);

  Future<Customer> updateCustomer(Customer customer);

  Future<List<Customer>> getCustomersByUser(String userId);

  Future<void> deleteCustomer(String id);
}
