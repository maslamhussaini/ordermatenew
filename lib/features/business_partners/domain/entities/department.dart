import 'package:equatable/equatable.dart';

class Department extends Equatable {
  final int id;
  final String name;
  final int? organizationId;
  final bool status;
  final bool isSynced;

  const Department({
    required this.id,
    required this.name,
    required this.organizationId,
    this.status = true,
    this.isSynced = true,
  });

  @override
  List<Object?> get props => [id, name, organizationId, status, isSynced];
}
