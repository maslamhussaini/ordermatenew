import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:ordermate/features/accounting/domain/repositories/accounting_repository.dart';
import '../../data/models/accounting_models.dart';

class AccountingSetupService {
  final AccountingRepository _repository;

  AccountingSetupService(this._repository);

  Future<void> setupDefaultAccounting(int organizationId) async {
    // Invoice types + voucher prefixes are foundational, required for basic
    // invoice/order creation to work at all -- seed them first and in their
    // own try/catch, so a failure in the account-types/categories/chart-of-
    // accounts import below (which can throw, e.g. on a bulk-insert error)
    // can never prevent this organization from getting them. This was the
    // confirmed cause of an organization missing its SI/SIR/PI/PR invoice
    // types despite this method already calling
    // seedInvoiceTypesAndVoucherPrefixes at the end of the old, single
    // shared try block below.
    try {
      await seedInvoiceTypesAndVoucherPrefixes(organizationId);
    } catch (e) {
      debugPrint(
          'Error seeding invoice types/voucher prefixes for org $organizationId: $e');
    }

    try {
      // 1. Import Account Types
      final typesJson = await rootBundle
          .loadString('assets/json/accounting/account_types.json');
      final List<dynamic> typesData = jsonDecode(typesJson);
      final types = typesData.map((e) {
        final model = AccountTypeModel.fromJson(e);
        return AccountTypeModel(
          id: model.id,
          typeName: model.typeName,
          status: model.status,
          isSystem: model.isSystem,
          organizationId: organizationId,
        );
      }).toList();
      await _repository.bulkCreateAccountTypes(types);

      // 2. Import Account Categories
      final catsJson = await rootBundle
          .loadString('assets/json/accounting/account_categories.json');
      final List<dynamic> catsData = jsonDecode(catsJson);
      final categories = catsData.map((e) {
        final model = AccountCategoryModel.fromJson(e);
        return AccountCategoryModel(
          id: model.id,
          categoryName: model.categoryName,
          accountTypeId: model.accountTypeId,
          status: model.status,
          isSystem: model.isSystem,
          organizationId: organizationId,
        );
      }).toList();
      await _repository.bulkCreateAccountCategories(categories);

      // 3. Import Chart of Accounts
      final coaJson = await rootBundle
          .loadString('assets/json/accounting/chart_of_accounts.json');
      final List<dynamic> coaData = jsonDecode(coaJson);

      final now = DateTime.now();
      final accounts = coaData.map((json) {
        // We might want to give them unique IDs for this organization if needed,
        // but if IDs are 'sys-xxx' they might be shared or need to be unique.
        // The user said "import json file into chart of account with is active = 1 and isystme = 1"
        return ChartOfAccountModel(
          id: '${json['id']}-$organizationId', // Make it unique per org
          accountCode: json['account_code'],
          accountTitle: json['account_title'],
          level: json['level'],
          accountTypeId: json['account_type_id'],
          accountCategoryId: json['account_category_id'],
          organizationId: organizationId,
          isActive: true,
          isSystem: true,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      await _repository.bulkCreateChartOfAccounts(accounts);

      // Invoice types + voucher prefixes are already seeded independently
      // above, before this try block, so they aren't skipped if any step
      // here throws.

      debugPrint('Accounting setup complete for organization: $organizationId');
    } catch (e) {
      debugPrint('Error during accounting setup: $e');
    }
  }

  /// The canonical, fixed system-baseline invoice types (SI/SIR/PI/PR) and
  /// voucher prefixes (CRV/BRV/SI/SIR/CPV/BPV/JV) for one organization.
  ///
  /// Extracted from [setupDefaultAccounting] (Phase QA P0.1) so it can be
  /// called on its own -- from real self-service signup -- without also
  /// re-running that method's account-types/categories/chart-of-accounts
  /// seeding, which is already owned by `AccountingSeedService` on the real
  /// signup path and would otherwise risk two divergent chart-of-accounts
  /// data sets for the same organization.
  ///
  /// Idempotent: re-running this for an organization that already has some
  /// or all of these rows will not create duplicates. Invoice types rely on
  /// `createInvoiceType`'s existing `.upsert()` (its id_invoice_type is a
  /// fixed natural key, so upsert already dedupes correctly). Voucher
  /// prefixes did NOT dedupe before this fix -- `createVoucherPrefix` always
  /// inserts a new row when called with `id: 0` (confirmed: `VoucherPrefixModel.toJson()`
  /// omits `id` entirely when it's 0, so `.upsert()` always performs a plain
  /// insert) -- so this method now fetches the organization's existing
  /// voucher-prefix codes first and skips any prefix code already present.
  Future<void> seedInvoiceTypesAndVoucherPrefixes(int organizationId) async {
    // 1. Invoice Types -- naturally idempotent via upsert on the fixed
    // id_invoice_type key, no pre-check needed.
    final defaultInvoiceTypes = [
      const InvoiceTypeModel(
          idInvoiceType: 'SI',
          description: 'Sales Invoice',
          forUsed: 'Sales Invoice',
          isActive: true,
          organizationId: 0),
      const InvoiceTypeModel(
          idInvoiceType: 'SIR',
          description: 'Sales Invoice Return',
          forUsed: 'Sales Return',
          isActive: true,
          organizationId: 0),
      const InvoiceTypeModel(
          idInvoiceType: 'PI',
          description: 'Purchase Invoice',
          forUsed: 'Purchase Invoice',
          isActive: true,
          organizationId: 0),
      const InvoiceTypeModel(
          idInvoiceType: 'PR',
          description: 'Purchase Return',
          forUsed: 'Purchase Return',
          isActive: true,
          organizationId: 0),
    ];

    for (var type in defaultInvoiceTypes) {
      try {
        await _repository.createInvoiceType(InvoiceTypeModel(
          idInvoiceType: type.idInvoiceType,
          description: type.description,
          forUsed: type.forUsed,
          organizationId: organizationId,
          isActive: true,
        ));
      } catch (e) {
        debugPrint(
            'Error creating default invoice type ${type.idInvoiceType}: $e');
      }
    }

    // 2. Voucher Prefixes -- explicit existing-code check added (was not
    // idempotent before this fix; see method doc comment above).
    final defaultPrefixes = [
      {'code': 'CRV', 'desc': 'Cash Receipt Voucher', 'type': 'Receipt'},
      {'code': 'BRV', 'desc': 'Bank Receipt Voucher', 'type': 'Receipt'},
      {'code': 'SI', 'desc': 'Sales Invoice', 'type': 'Sales'},
      {'code': 'SIR', 'desc': 'Sales Invoice Return', 'type': 'Returns'},
      {'code': 'CPV', 'desc': 'Cash Payment Voucher', 'type': 'Payment'},
      {'code': 'BPV', 'desc': 'Bank Payment Voucher', 'type': 'Payment'},
      {'code': 'JV', 'desc': 'Journal Voucher', 'type': 'Journal'},
    ];

    Set<String> existingPrefixCodes = {};
    try {
      final existing = await _repository.getVoucherPrefixes(
          organizationId: organizationId);
      existingPrefixCodes = existing.map((p) => p.prefixCode).toSet();
    } catch (e) {
      debugPrint(
          'Error fetching existing voucher prefixes for org $organizationId: $e');
      // If we can't confirm what already exists, don't risk duplicate
      // inserts -- abort this half of the seed rather than guess.
      return;
    }

    for (var p in defaultPrefixes) {
      final code = p['code']!;
      if (existingPrefixCodes.contains(code)) {
        continue;
      }
      try {
        await _repository.createVoucherPrefix(VoucherPrefixModel(
          id: 0,
          prefixCode: code,
          description: p['desc'],
          voucherType: p['type']!,
          organizationId: organizationId,
          status: true,
        ));
      } catch (e) {
        debugPrint('Error creating default prefix $code: $e');
      }
    }
  }
}
