import 'package:equatable/equatable.dart';

class InvoiceType extends Equatable {
  final String idInvoiceType;
  final String description;
  final String forUsed;
  final int organizationId;
  final bool isActive;

  const InvoiceType({
    required this.idInvoiceType,
    required this.description,
    required this.forUsed,
    required this.organizationId,
    this.isActive = true,
  });

  @override
  List<Object?> get props =>
      [idInvoiceType, description, forUsed, organizationId, isActive];
}

class Invoice extends Equatable {
  final String id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String idInvoiceType;
  final String businessPartnerId;
  final String? orderId;
  final double totalAmount;
  final double paidAmount;
  final String status;
  final String? notes;
  final int organizationId;
  final int storeId;
  final int? sYear;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    this.dueDate,
    required this.idInvoiceType,
    required this.businessPartnerId,
    this.orderId,
    this.totalAmount = 0.0,
    this.paidAmount = 0.0,
    this.status = 'Unpaid',
    this.notes,
    required this.organizationId,
    required this.storeId,
    this.sYear,
    this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        invoiceNumber,
        invoiceDate,
        dueDate,
        idInvoiceType,
        businessPartnerId,
        orderId,
        totalAmount,
        paidAmount,
        status,
        notes,
        organizationId,
        storeId,
        sYear,
        createdAt,
        updatedAt
      ];

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? idInvoiceType,
    String? businessPartnerId,
    String? orderId,
    double? totalAmount,
    double? paidAmount,
    String? status,
    String? notes,
    int? organizationId,
    int? storeId,
    int? sYear,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      idInvoiceType: idInvoiceType ?? this.idInvoiceType,
      businessPartnerId: businessPartnerId ?? this.businessPartnerId,
      orderId: orderId ?? this.orderId,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      organizationId: organizationId ?? this.organizationId,
      storeId: storeId ?? this.storeId,
      sYear: sYear ?? this.sYear,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
