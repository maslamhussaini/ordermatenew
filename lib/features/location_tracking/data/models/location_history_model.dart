import 'package:ordermate/features/location_tracking/domain/entities/location_history.dart';

class LocationHistoryModel extends LocationHistory {
  const LocationHistoryModel({
    required super.id,
    required super.createdAt,
    super.organizationId,
    super.storeId,
    required super.userId,
    required super.latitude,
    required super.longitude,
    super.accuracy,
  });

  factory LocationHistoryModel.fromJson(Map<String, dynamic> json) {
    return LocationHistoryModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      organizationId: json['organization_id'] as int?,
      storeId: json['store_id'] as int?,
      userId: json['user_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'organization_id': organizationId,
      'store_id': storeId,
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    };
  }
}
