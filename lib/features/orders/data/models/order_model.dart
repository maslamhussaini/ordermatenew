// lib/features/orders/data/models/order_model.dart

import 'dart:convert';
import 'package:ordermate/features/orders/domain/entities/order.dart';
import 'package:ordermate/features/orders/domain/entities/order_item.dart';

class OrderModel extends Order {
  const OrderModel({
    required super.id,
    required super.orderNumber,
    required super.businessPartnerId,
    required super.orderType,
    required super.createdBy,
    required super.status,
    required super.totalAmount,
    required super.orderDate,
    required super.createdAt,
    required super.updatedAt,
    super.businessPartnerName,
    super.createdByName,
    super.notes,
    required super.organizationId,
    required super.storeId,
    super.latitude,
    super.longitude,
    super.loginLatitude,
    super.loginLongitude,
    super.paymentTermId,
    super.dispatchStatus,
    super.dispatchDate,
    super.dueDate,
    super.isInvoiced,
    super.sYear,
    super.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    List<OrderItem> parsedItems = [];
    if (json['items'] != null) {
      if (json['items'] is List) {
        parsedItems =
            (json['items'] as List).map((i) => OrderItem.fromJson(i)).toList();
      }
    } else if (json['items_payload'] != null &&
        json['items_payload'].toString().isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(json['items_payload']);
        parsedItems = list.map((e) => OrderItem.fromJson(e)).toList();
      } catch (_) {}
    }

    return OrderModel(
      id: json['id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? 'UNKNOWN',
      businessPartnerId: json['business_partner_id'] as String? ?? '',
      businessPartnerName: json['business_partner_name'] as String?,
      orderType: json['order_type'] as String? ?? 'SO',
      createdBy: json['created_by'] as String? ?? '',
      createdByName: json['created_by_name'] as String?,
      status: OrderStatus.fromString(json['status'] as String? ?? 'Booked'),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      orderDate: json['order_date'] != null
          ? DateTime.parse(json['order_date'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      organizationId: (json['organization_id'] as int?) ?? 0,
      storeId: (json['store_id'] as int?) ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      loginLatitude: (json['login_latitude'] as num?)?.toDouble(),
      loginLongitude: (json['login_longitude'] as num?)?.toDouble(),
      paymentTermId: json['payment_term_id'] as int?,
      dispatchStatus: json['dispatch_status'] as String? ?? 'pending',
      dispatchDate: json['dispatch_date'] != null
          ? DateTime.parse(json['dispatch_date'] as String)
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      isInvoiced: json['is_invoiced'] == true || json['is_invoiced'] == 1,
      sYear: json['syear'] as int?,
      items: parsedItems,
    );
  }

  factory OrderModel.fromEntity(Order order) {
    return OrderModel(
      id: order.id,
      orderNumber: order.orderNumber,
      businessPartnerId: order.businessPartnerId,
      orderType: order.orderType,
      createdBy: order.createdBy,
      status: order.status,
      totalAmount: order.totalAmount,
      orderDate: order.orderDate,
      createdAt: order.createdAt,
      updatedAt: order.updatedAt,
      businessPartnerName: order.businessPartnerName,
      createdByName: order.createdByName,
      notes: order.notes,
      organizationId: order.organizationId,
      storeId: order.storeId,
      latitude: order.latitude,
      longitude: order.longitude,
      loginLatitude: order.loginLatitude,
      loginLongitude: order.loginLongitude,
      paymentTermId: order.paymentTermId,
      dispatchStatus: order.dispatchStatus,
      dispatchDate: order.dispatchDate,
      dueDate: order.dueDate,
      isInvoiced: order.isInvoiced,
      sYear: order.sYear,
      items: order.items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'business_partner_id': businessPartnerId,
      'order_type': orderType,
      'created_by': createdBy,
      'status': status.displayName,
      'total_amount': totalAmount,
      'notes': notes,
      'order_date': orderDate.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'organization_id': organizationId,
      'store_id': storeId,
      'latitude': latitude,
      'longitude': longitude,
      'login_latitude': loginLatitude,
      'login_longitude': loginLongitude,
      'payment_term_id': paymentTermId,
      'dispatch_status': dispatchStatus,
      'dispatch_date': dispatchDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'is_invoiced': isInvoiced ? 1 : 0,
      'syear': sYear,
      'items_payload': jsonEncode(items.map((e) => e.toJson()).toList()),
    };
  }

  Order toEntity() => this;
}
