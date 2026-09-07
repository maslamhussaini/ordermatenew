// lib/features/dashboard/data/models/dashboard_stats_model.dart

import 'package:ordermate/features/dashboard/domain/entities/dashboard_stats.dart';

class DashboardStatsModel extends DashboardStats {
  const DashboardStatsModel({
    required super.totalCustomers,
    required super.totalProducts,
    required super.customersInArea,
    required super.ordersBooked,
    required super.ordersApproved,
    required super.ordersPending,
    required super.ordersRejected,
    super.myOrdersToday,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      totalCustomers: json['total_customers'] as int? ?? 0,
      totalProducts: json['total_products'] as int? ?? 0,
      customersInArea: json['customers_in_area'] as int? ?? 0,
      ordersBooked: json['orders_booked'] as int? ?? 0,
      ordersApproved: json['orders_approved'] as int? ?? 0,
      ordersPending: json['orders_pending'] as int? ?? 0,
      ordersRejected: json['orders_rejected'] as int? ?? 0,
      myOrdersToday: json['my_orders_today'] as int? ?? 0,
    );
  }

  DashboardStats toEntity() => this;
}
