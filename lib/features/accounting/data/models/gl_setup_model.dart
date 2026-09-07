import '../../domain/entities/gl_setup.dart';

class GLSetupModel extends GLSetup {
  const GLSetupModel({
    required super.organizationId,
    required super.inventoryAccountId,
    required super.cogsAccountId,
    required super.salesAccountId,
    super.receivableAccountId,
    super.payableAccountId,
    super.bankAccountId,
    super.cashAccountId,
    super.taxOutputAccountId,
    super.taxInputAccountId,
    super.salesDiscountAccountId,
    super.purchaseDiscountAccountId,
    super.employeeSalaryAccountId,
  });

  factory GLSetupModel.fromJson(Map<String, dynamic> json) {
    return GLSetupModel(
      organizationId: json['organization_id'] as int,
      inventoryAccountId: json['inventory_account_id'] as String,
      cogsAccountId: json['cogs_account_id'] as String,
      salesAccountId: json['sales_account_id'] as String,
      receivableAccountId: json['receivable_account_id'] as String?,
      payableAccountId: json['payable_account_id'] as String?,
      bankAccountId: json['bank_account_id'] as String?,
      cashAccountId: json['cash_account_id'] as String?,
      taxOutputAccountId: json['tax_output_account_id'] as String?,
      taxInputAccountId: json['tax_input_account_id'] as String?,
      salesDiscountAccountId: json['sales_discount_account_id'] as String?,
      purchaseDiscountAccountId:
          json['purchase_discount_account_id'] as String?,
      employeeSalaryAccountId:
          json['employee_salary_account_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organization_id': organizationId,
      'inventory_account_id': inventoryAccountId,
      'cogs_account_id': cogsAccountId,
      'sales_account_id': salesAccountId,
      'receivable_account_id': receivableAccountId,
      'payable_account_id': payableAccountId,
      'bank_account_id': bankAccountId,
      'cash_account_id': cashAccountId,
      'tax_output_account_id': taxOutputAccountId,
      'tax_input_account_id': taxInputAccountId,
      'sales_discount_account_id': salesDiscountAccountId,
      'purchase_discount_account_id': purchaseDiscountAccountId,
      'employee_salary_account_id': employeeSalaryAccountId,
    };
  }

  factory GLSetupModel.fromEntity(GLSetup entity) {
    return GLSetupModel(
      organizationId: entity.organizationId,
      inventoryAccountId: entity.inventoryAccountId,
      cogsAccountId: entity.cogsAccountId,
      salesAccountId: entity.salesAccountId,
      receivableAccountId: entity.receivableAccountId,
      payableAccountId: entity.payableAccountId,
      bankAccountId: entity.bankAccountId,
      cashAccountId: entity.cashAccountId,
      taxOutputAccountId: entity.taxOutputAccountId,
      taxInputAccountId: entity.taxInputAccountId,
      salesDiscountAccountId: entity.salesDiscountAccountId,
      purchaseDiscountAccountId: entity.purchaseDiscountAccountId,
      employeeSalaryAccountId: entity.employeeSalaryAccountId,
    );
  }
}
