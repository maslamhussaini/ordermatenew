import 'package:ordermate/features/location_tracking/domain/entities/location_history.dart';

abstract class LocationRepository {
  Future<void> saveLocation(LocationHistory location);
  Future<List<LocationHistory>> getHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    int? organizationId,
  });
}
