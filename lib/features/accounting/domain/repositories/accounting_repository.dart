// lib/features/accounting/domain/repositories/accounting_repository.dart

import '../entities/chart_of_account.dart';
import '../entities/invoice.dart';
import '../entities/gl_setup.dart';
import '../entities/invoice_item.dart';
import '../entities/daily_balance.dart';

abstract class AccountingRepository {
  Future<List<ChartOfAccount>> getChartOfAccounts({int? organizationId});
  Future<void> createChartOfAccount(ChartOfAccount account);
  Future<void> updateChartOfAccount(ChartOfAccount account);

  Future<List<AccountType>> getAccountTypes({int? organizationId});
  Future<void> createAccountType(AccountType type);
  Future<void> updateAccountType(AccountType type);

  Future<List<AccountCategory>> getAccountCategories({int? organizationId});
  Future<void> createAccountCategory(AccountCategory category);
  Future<void> updateAccountCategory(AccountCategory category);

  Future<void> bulkCreateAccountTypes(List<AccountType> types);
  Future<void> bulkCreateAccountCategories(List<AccountCategory> categories);
  Future<void> bulkCreateChartOfAccounts(List<ChartOfAccount> accounts);

  Future<void> deleteChartOfAccount(String id);
  Future<void> deleteAccountType(int id);
  Future<void> deleteAccountCategory(int id);

  Future<bool> isAccountUsed(String accountId);
  Future<bool> isAccountTypeUsed(int typeId);
  Future<bool> isAccountCategoryUsed(int categoryId);

  Future<List<PaymentTerm>> getPaymentTerms({int? organizationId});
  Future<void> createPaymentTerm(PaymentTerm term);
  Future<void> updatePaymentTerm(PaymentTerm term);

  Future<List<FinancialSession>> getFinancialSessions({int? organizationId});
  Future<FinancialSession?> getActiveFinancialSession({int? organizationId});
  Future<void> createFinancialSession(FinancialSession session);
  Future<void> updateFinancialSession(FinancialSession session);

  Future<void> createTransaction(Transaction transaction);
  Future<void> updateTransaction(Transaction transaction);
  Future<void> deleteTransaction(String id);
  Future<List<Transaction>> getTransactions(
      {int? organizationId, int? storeId, int? sYear});

  Future<List<Map<String, dynamic>>> getUnpaidInvoices(String customerId,
      {int? organizationId});

  Future<List<BankCash>> getBankCashAccounts({int? organizationId});
  Future<void> createBankCashAccount(BankCash account);
  Future<void> updateBankCashAccount(BankCash account);
  Future<void> deleteBankCashAccount(String id);
  Future<bool> isBankCashUsed(String bankCashId);

  Future<List<VoucherPrefix>> getVoucherPrefixes({int? organizationId});
  Future<void> createVoucherPrefix(VoucherPrefix prefix);
  Future<void> updateVoucherPrefix(VoucherPrefix prefix);
  Future<void> deleteVoucherPrefix(int id);
  Future<void> deletePaymentTerm(int id);

  // Invoice Methods
  Future<List<InvoiceType>> getInvoiceTypes({int? organizationId});
  Future<void> createInvoiceType(InvoiceType type);

  Future<List<Invoice>> getInvoices(
      {int? organizationId, int? storeId, int? sYear});
  Future<void> createInvoice(Invoice invoice);
  Future<void> updateInvoice(Invoice invoice);
  Future<void> createInvoiceWithItems(Invoice invoice, List<InvoiceItem> items);
  Future<void> updateInvoiceWithItems(Invoice invoice, List<InvoiceItem> items);
  Future<void> deleteInvoice(String id);

  // Invoice Item Methods
  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId);
  Future<List<InvoiceItem>> getInvoiceItemsByOrg(int organizationId);
  Future<void> createInvoiceItems(List<InvoiceItem> items);
  Future<void> deleteInvoiceItems(String invoiceId);

  // GL Setup Methods
  Future<GLSetup?> getGLSetup(int organizationId);
  Future<void> saveGLSetup(GLSetup setup);

  // Daily Balance / Cash Flow Methods
  Future<DailyBalance?> getLatestDailyBalance(String accountId,
      {int? organizationId});
  Future<void> saveDailyBalance(DailyBalance balance);

  // Opening Balance Methods
  Future<List<OpeningBalance>> getOpeningBalances(
      {int? organizationId, int? sYear});
  Future<void> saveOpeningBalance(OpeningBalance balance);
}
