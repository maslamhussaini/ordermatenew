// lib/features/reports/domain/repositories/report_repository.dart

import '../../../accounting/domain/entities/chart_of_account.dart';

abstract class ReportRepository {
  Future<Map<String, dynamic>> getLedgerData(
    String accountId, {
    DateTime? startDate,
    DateTime? endDate,
    int? organizationId,
    int? storeId,
    int? sYear,
    String? moduleAccount,
  });

  Future<List<Transaction>> getAccountLedger(
    String accountId, {
    DateTime? startDate,
    DateTime? endDate,
    int? organizationId,
    String? moduleAccount,
  });

  Future<List<Map<String, dynamic>>> getSalesByProduct({
    DateTime? startDate,
    DateTime? endDate,
    int? organizationId,
    String? type, // 'SI' or 'SIR'
  });

  Future<List<Map<String, dynamic>>> getSalesDetailsByProduct({
    DateTime? startDate,
    DateTime? endDate,
    int? organizationId,
    String? type,
  });

  Future<List<Map<String, dynamic>>> getSalesByCustomer({
    DateTime? startDate,
    DateTime? endDate,
    int? organizationId,
    String? type, // 'SI' or 'SIR'
  });

  Future<List<Map<String, dynamic>>> getAgingData(
    String partnerId, {
    int? organizationId,
    int? storeId,
  });

  // Gross Sales
  Future<Map<String, dynamic>> getGrossSalesSummary({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getGrossSalesDetails({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getGrossSalesByCustomer({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getGrossSalesByProduct({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
  });

  // Net Sales
  Future<Map<String, dynamic>> getNetSalesSummary({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getNetSalesDetails({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getNetSalesByCustomer({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getNetSalesByProduct({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  // Gross Purchase
  Future<Map<String, dynamic>> getGrossPurchaseSummary({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getGrossPurchaseDetails({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getGrossPurchaseByVendor({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getGrossPurchaseByProduct({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
  });

  // Net Purchase
  Future<Map<String, dynamic>> getNetPurchaseSummary({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getNetPurchaseDetails({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getNetPurchaseByVendor({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getNetPurchaseByProduct({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getReceivableReport({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getCustomerBalanceReport({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getBrandWiseReport({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getTypeWiseReport({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getProductListReport({
    required int organizationId,
    int? storeId,
  });

  Future<List<Map<String, dynamic>>> getSupplierWiseReport({
    required int organizationId,
    int? storeId,
    required int sYear,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<Map<String, dynamic>>> getInventoryMovements({
    required int organizationId,
    int? storeId,
    DateTime? startDate,
    DateTime? endDate,
    String? productId,
  });
}
