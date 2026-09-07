// lib/features/customers/data/repositories/customer_repository_impl.dart

import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/customers/data/models/customer_model.dart'; // Import the model for fromJson
import 'package:ordermate/features/customers/domain/entities/customer.dart';
import 'package:ordermate/features/customers/domain/repositories/customer_repository.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  // final CustomerRemoteDataSource remoteDataSource; // Docs didn't use this in 6.8

  CustomerRepositoryImpl();

  @override
  Future<List<Customer>> getCustomersByLocation({
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
  }) async {
    try {
      final result = await SupabaseConfig.client.rpc(
        'get_customers_by_location',
        params: <String, dynamic>{
          'user_lat': latitude,
          'user_lng': longitude,
          'radius_meters': radiusMeters,
        },
      );

      return (result as List)
          .map((json) => CustomerModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If RPC fails (e.g. function doesn't exist yet), return empty list or throw
      // For scaffolding, we log and rethrow
      rethrow;
    }
  }

  @override
  Future<Customer> createCustomer(Customer customer) async {
    try {
      // Resolve the correct user ID from omtbl_users based on the authenticated user's email
      // This prevents Foreign Key violations if Auth ID != omtbl_users.id
      String? validCreatedBy;
      final currentUserEmail = SupabaseConfig.currentUser?.email;

      if (currentUserEmail != null) {
        final userModel = await SupabaseConfig.client
            .from('omtbl_users')
            .select('id')
            .eq('email', currentUserEmail)
            .maybeSingle();

        if (userModel != null) {
          final userData = userModel;
          validCreatedBy = userData['id'] as String;
        }
      }

      final customerModel = CustomerModel(
        // For creation, we can let DB generate ID if we want, OR we use the one we generated.
        // But if we generated one and retried, it crashes.
        // Safer to let DB generate it.
        // BUT, our local entity needs an ID to update the UI optimistically?
        // The RPC returns the created record with the DB-generated ID.
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        address: customer.address,
        latitude: customer.latitude,
        longitude: customer.longitude,
        createdBy: validCreatedBy,
        isActive: customer.isActive,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
        distanceMeters: customer.distanceMeters,
        businessTypeId: customer.businessTypeId,
      );

      // Remove ID from JSON for insert to strictly use DB generation?
      // If we pass ID, Postgres uses it.
      // If we don't pass ID, Postgres uses DEFAULT gen_random_uuid().

      final json = customerModel.toJson();
      json.remove(
        'id',
      ); // Force DB to generate ID to avoid collisions (or resubmits of same ID)

      final response = await SupabaseConfig.client
          .from('omtbl_customers')
          .insert(json)
          .select('*, omtbl_business_types(business_type)')
          .single();

      return CustomerModel.fromJson(response);
    } catch (e) {
      if (e.toString().contains('23505') ||
          e.toString().contains('generic detail: Key (phone)')) {
        throw Exception('Customer with this phone number already exists.');
      }
      throw Exception('Failed to create customer: $e');
    }
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    try {
      final customerModel = CustomerModel(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        address: customer.address,
        latitude: customer.latitude,
        longitude: customer.longitude,
        createdBy: customer.createdBy,
        isActive: customer.isActive,
        createdAt: customer.createdAt,
        updatedAt: customer.updatedAt,
        distanceMeters: customer.distanceMeters,
        businessTypeId: customer.businessTypeId,
      );

      final response = await SupabaseConfig.client
          .from('omtbl_customers')
          .update(customerModel.toJson())
          .eq('id', customer.id)
          .select('*, omtbl_business_types(business_type)')
          .single();

      return CustomerModel.fromJson(response);
    } catch (e) {
      if (e.toString().contains('23505') ||
          e.toString().contains('generic detail: Key (phone)')) {
        throw Exception('Another customer already has this phone number.');
      }
      throw Exception('Failed to update customer: $e');
    }
  }

  @override
  Future<List<Customer>> getCustomersByUser(String userId) async {
    try {
      final response = await SupabaseConfig.client
          .from('omtbl_customers')
          .select('*, omtbl_business_types(business_type)')
          .eq('created_by', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => CustomerModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Helper to fetch business types for autocomplete
  Future<List<Map<String, dynamic>>> searchBusinessTypes(String query) async {
    try {
      var dbQuery = SupabaseConfig.client
          .from('omtbl_business_types')
          .select('id, business_type')
          .eq('status', 1);

      if (query.isNotEmpty) {
        dbQuery = dbQuery.ilike('business_type', '%$query%');
      }

      final response = await dbQuery.limit(10);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    try {
      await SupabaseConfig.client
          .from('omtbl_customers')
          .update({'is_active': false}).eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete customer: $e');
    }
  }
}
