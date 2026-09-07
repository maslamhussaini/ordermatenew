import 'package:flutter/foundation.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/location_tracking/data/models/location_history_model.dart';
import 'package:ordermate/features/location_tracking/domain/entities/location_history.dart';
import 'package:ordermate/features/location_tracking/domain/repositories/location_repository.dart';

class SupabaseLocationRepository implements LocationRepository {
  @override
  Future<void> saveLocation(LocationHistory location) async {
    try {
      final model = LocationHistoryModel(
        id: location.id,
        createdAt: location.createdAt,
        organizationId: location.organizationId,
        storeId: location.storeId,
        userId: location.userId,
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
      );

      final json = model.toJson();
      // Remove ID to let Supabase generate it if it's default UUID
      if (json['id'].isEmpty) json.remove('id');
      json.remove('created_at'); // Let DB use default

      await SupabaseConfig.client.from('omtbl_location_history').insert(json);
    } catch (e) {
      debugPrint('Error saving location: $e');
      rethrow;
    }
  }

  @override
  Future<List<LocationHistory>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    int? organizationId,
  }) async {
    try {
      var query =
          SupabaseConfig.client.from('omtbl_location_history').select('''
            *,
            omtbl_businesspartners!user_id (name)
          ''');

      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      if (organizationId != null) {
        query = query.eq('organization_id', organizationId);
      }
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((json) {
        // Enriched with user name for display if needed
        final history = LocationHistoryModel.fromJson(json);
        return history;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching location history: $e');
      return [];
    }
  }
}
