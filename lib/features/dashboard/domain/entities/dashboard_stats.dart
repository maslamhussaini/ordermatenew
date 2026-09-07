// lib/features/dashboard/domain/entities/dashboard_stats.dart

import 'package:equatable/equatable.dart';

class DashboardStats extends Equatable {
  const DashboardStats({
    required this.totalCustomers,
    required this.totalProducts,
    required this.customersInArea,
    required this.ordersBooked,
    required this.ordersApproved,
    required this.ordersPending,
    required this.ordersRejected,
    this.totalVendors = 0,
    this.totalSuppliers = 0,
    this.totalEmployees = 0,
    this.myOrdersToday = 0,
    this.salesInvoicesCount = 0,
    this.salesReturnsCount = 0,
    this.purchaseInvoicesCount = 0,
    this.purchaseReturnsCount = 0,
  });
  final int totalCustomers;
  final int totalProducts;
  final int customersInArea;
  final int ordersBooked;
  final int ordersApproved;
  final int ordersPending;
  final int ordersRejected;
  final int totalVendors;
  final int totalSuppliers;
  final int totalEmployees;
  final int myOrdersToday;
  final int salesInvoicesCount;
  final int salesReturnsCount;
  final int purchaseInvoicesCount;
  final int purchaseReturnsCount;

  int get totalOrders =>
      ordersBooked + ordersApproved + ordersPending + ordersRejected;

  @override
  List<Object?> get props => [
        totalCustomers,
        totalProducts,
        customersInArea,
        ordersBooked,
        ordersApproved,
        ordersPending,
        ordersRejected,
        totalVendors,
        totalSuppliers,
        totalEmployees,
        myOrdersToday,
        salesInvoicesCount,
        salesReturnsCount,
        purchaseInvoicesCount,
        purchaseReturnsCount,
      ];
}
