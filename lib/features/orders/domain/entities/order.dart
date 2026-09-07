// lib/features/orders/domain/entities/order.dart

import 'package:equatable/equatable.dart';
import 'package:ordermate/features/orders/domain/entities/order_item.dart';

enum OrderStatus {
  booked,
  approved,
  pending,
  rejected;

  String get displayName {
    switch (this) {
      case OrderStatus.booked:
        return 'Booked';
      case OrderStatus.approved:
        return 'Approved';
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.rejected:
        return 'Rejected';
    }
  }

  static OrderStatus fromString(String status) {
    return OrderStatus.values.firstWhere(
      (e) => e.displayName.toLowerCase() == status.toLowerCase(),
      orElse: () => OrderStatus.booked,
    );
  }
}

class Order extends Equatable {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.businessPartnerId,
    required this.orderType,
    required this.createdBy,
    required this.status,
    required this.totalAmount,
    required this.orderDate,
    required this.createdAt,
    required this.updatedAt,
    this.businessPartnerName,
    this.createdByName,
    this.notes,
    required this.organizationId,
    required this.storeId,
    this.latitude,
    this.longitude,
    this.loginLatitude,
    this.loginLongitude,
    this.paymentTermId,
    this.dispatchStatus = 'pending',
    this.dispatchDate,
    this.dueDate,
    this.isInvoiced = false,
    this.sYear,
    this.items = const [],
  });
  final String id;
  final String orderNumber;
  final String businessPartnerId;
  final String? businessPartnerName;
  final String orderType; // 'SO' or 'PO'
  final String createdBy;
  final String? createdByName;
  final OrderStatus status;
  final double totalAmount;
  final String? notes;
  final DateTime orderDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int organizationId;
  final int storeId;
  final double? latitude;
  final double? longitude;
  final double? loginLatitude;
  final double? loginLongitude;
  final int? paymentTermId;
  final String dispatchStatus;
  final DateTime? dispatchDate;
  final DateTime? dueDate;
  final bool isInvoiced;
  final int? sYear;
  final List<OrderItem> items;

  Order copyWith({
    String? id,
    String? orderNumber,
    String? businessPartnerId,
    String? businessPartnerName,
    String? orderType,
    String? createdBy,
    String? createdByName,
    OrderStatus? status,
    double? totalAmount,
    String? notes,
    DateTime? orderDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? organizationId,
    int? storeId,
    double? latitude,
    double? longitude,
    double? loginLatitude,
    double? loginLongitude,
    int? paymentTermId,
    String? dispatchStatus,
    DateTime? dispatchDate,
    DateTime? dueDate,
    bool? isInvoiced,
    int? sYear,
    List<OrderItem>? items,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      businessPartnerId: businessPartnerId ?? this.businessPartnerId,
      businessPartnerName: businessPartnerName ?? this.businessPartnerName,
      orderType: orderType ?? this.orderType,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      orderDate: orderDate ?? this.orderDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      organizationId: organizationId ?? this.organizationId,
      storeId: storeId ?? this.storeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      loginLatitude: loginLatitude ?? this.loginLatitude,
      loginLongitude: loginLongitude ?? this.loginLongitude,
      paymentTermId: paymentTermId ?? this.paymentTermId,
      dispatchStatus: dispatchStatus ?? this.dispatchStatus,
      dispatchDate: dispatchDate ?? this.dispatchDate,
      dueDate: dueDate ?? this.dueDate,
      isInvoiced: isInvoiced ?? this.isInvoiced,
      sYear: sYear ?? this.sYear,
      items: items ?? this.items,
    );
  }

  // Note: Use formatCurrency() utility function in UI instead
  String get formattedTotal => totalAmount.toStringAsFixed(2);

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        businessPartnerId,
        businessPartnerName,
        orderType,
        createdBy,
        createdByName,
        status,
        totalAmount,
        notes,
        orderDate,
        createdAt,
        updatedAt,
        organizationId,
        storeId,
        latitude,
        longitude,
        loginLatitude,
        loginLongitude,
        paymentTermId,
        dispatchStatus,
        dispatchDate,
        dueDate,
        isInvoiced,
        sYear,
        items,
      ];
}
