import 'package:equatable/equatable.dart';

class GLSetup extends Equatable {
  final int organizationId;
  final String inventoryAccountId;
  final String cogsAccountId;
  final String salesAccountId;
  final String? receivableAccountId;
  final String? payableAccountId;
  final String? bankAccountId;
  final String? cashAccountId;
  final String? taxOutputAccountId;
  final String? taxInputAccountId;
  final String? salesDiscountAccountId;
  final String? purchaseDiscountAccountId;
  final String? employeeSalaryAccountId;

  const GLSetup({
    required this.organizationId,
    required this.inventoryAccountId,
    required this.cogsAccountId,
    required this.salesAccountId,
    this.receivableAccountId,
    this.payableAccountId,
    this.bankAccountId,
    this.cashAccountId,
    this.taxOutputAccountId,
    this.taxInputAccountId,
    this.salesDiscountAccountId,
    this.purchaseDiscountAccountId,
    this.employeeSalaryAccountId,
  });

  @override
  List<Object?> get props => [
        organizationId,
        inventoryAccountId,
        cogsAccountId,
        salesAccountId,
        receivableAccountId,
        payableAccountId,
        bankAccountId,
        cashAccountId,
        taxOutputAccountId,
        taxInputAccountId,
        salesDiscountAccountId,
        purchaseDiscountAccountId,
        employeeSalaryAccountId,
      ];

  GLSetup copyWith({
    int? organizationId,
    String? inventoryAccountId,
    String? cogsAccountId,
    String? salesAccountId,
    String? receivableAccountId,
    String? payableAccountId,
    String? bankAccountId,
    String? cashAccountId,
    String? taxOutputAccountId,
    String? taxInputAccountId,
    String? salesDiscountAccountId,
    String? purchaseDiscountAccountId,
    String? employeeSalaryAccountId,
  }) {
    return GLSetup(
      organizationId: organizationId ?? this.organizationId,
      inventoryAccountId: inventoryAccountId ?? this.inventoryAccountId,
      cogsAccountId: cogsAccountId ?? this.cogsAccountId,
      salesAccountId: salesAccountId ?? this.salesAccountId,
      receivableAccountId: receivableAccountId ?? this.receivableAccountId,
      payableAccountId: payableAccountId ?? this.payableAccountId,
      bankAccountId: bankAccountId ?? this.bankAccountId,
      cashAccountId: cashAccountId ?? this.cashAccountId,
      taxOutputAccountId: taxOutputAccountId ?? this.taxOutputAccountId,
      taxInputAccountId: taxInputAccountId ?? this.taxInputAccountId,
      salesDiscountAccountId:
          salesDiscountAccountId ?? this.salesDiscountAccountId,
      purchaseDiscountAccountId:
          purchaseDiscountAccountId ?? this.purchaseDiscountAccountId,
      employeeSalaryAccountId:
          employeeSalaryAccountId ?? this.employeeSalaryAccountId,
    );
  }
}
