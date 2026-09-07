import 'package:equatable/equatable.dart';

class LocationHistory extends Equatable {
  final String id;
  final DateTime createdAt;
  final int? organizationId;
  final int? storeId;
  final String userId;
  final double latitude;
  final double longitude;
  final double? accuracy;

  const LocationHistory({
    required this.id,
    required this.createdAt,
    this.organizationId,
    this.storeId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  @override
  List<Object?> get props => [
        id,
        createdAt,
        organizationId,
        storeId,
        userId,
        latitude,
        longitude,
        accuracy,
      ];
}
