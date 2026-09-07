// lib/features/accounting/presentation/providers/voucher_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/accounting_repository.dart';
import 'accounting_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../orders/domain/entities/order.dart';
import '../../domain/entities/chart_of_account.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_item.dart';
// Ensure type is available if needed

import 'package:ordermate/features/orders/domain/repositories/order_repository.dart';
import 'package:ordermate/features/products/domain/repositories/product_repository.dart';
import 'package:ordermate/features/orders/presentation/providers/order_provider.dart';
import 'package:ordermate/features/products/presentation/providers/product_provider.dart';

import 'package:ordermate/features/business_partners/domain/repositories/business_partner_repository.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';

import 'package:ordermate/features/organization/domain/repositories/organization_repository.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class VoucherService {
  final AccountingRepository _repository;
  final OrderRepository _orderRepository;
  final ProductRepository _productRepository;
  final BusinessPartnerRepository _businessPartnerRepository;
  final OrganizationRepository _organizationRepository;

  VoucherService(
    this._repository,
    this._orderRepository,
    this._productRepository,
    this._businessPartnerRepository,
    this._organizationRepository,
  );

  Future<String> generateVoucherNumber({
    required String prefixCode,
    required int storeId,
    String storePrefix = 'ST',
    int? organizationId,
    int? sYear,
  }) async {
    final now = DateTime.now();
    final currentYear = now.year;
    final nextYear = currentYear + 1;
    final fiscalYear = '$currentYear-$nextYear';

    // FIX (H-1): the previous implementation called
    //   getTransactions(storeId: storeId)
    // with no organizationId and no sYear, so the count was taken over
    // whatever the local cache happened to hold. On a fresh install or a
    // cleared cache the count was far below the true value and the generated
    // number collided with existing vouchers.
    //
    // We now scope the query to (organization, store, fiscal year) and derive
    // the next number from the highest sequence actually in use rather than a
    // row count, so gaps and partial caches cannot cause a collision.
    //
    // REMAINING RISK (documented, not silently fixed): this is still
    // client-side allocation. Two devices generating offline can produce the
    // same number. Closing that requires a server-side sequence plus a
    // UNIQUE (organization_id, voucher_number) constraint — a remote schema
    // change, which is out of scope for this pass. See the deferred list.
    final txs = await _repository.getTransactions(
      organizationId: organizationId,
      storeId: storeId,
      sYear: sYear,
    );

    final suffix = '$storePrefix$storeId/$fiscalYear';
    var maxSeq = 0;
    for (final t in txs) {
      final n = t.voucherNumber;
      if (!n.startsWith('$prefixCode-') || !n.endsWith(suffix)) continue;
      final parts = n.split('-');
      if (parts.length < 2) continue;
      final seq = int.tryParse(parts[1]);
      if (seq != null && seq > maxSeq) maxSeq = seq;
    }

    final sequenceNum = (maxSeq + 1).toString().padLeft(7, '0');
    return '$prefixCode-$sequenceNum-$suffix';
  }

  int _validateSYear(DateTime date, List<FinancialSession> sessions) {
    if (sessions.isEmpty) {
      throw Exception(
          'No financial years configured. Please configure a financial session first.');
    }

    final session = sessions.cast<FinancialSession?>().firstWhere(
          (s) =>
              s != null &&
              (date.isAtSameMomentAs(s.startDate) ||
                  date.isAfter(s.startDate)) &&
              (date.isAtSameMomentAs(s.endDate) ||
                  date.isBefore(s.endDate.add(const Duration(days: 1)))),
          orElse: () => null,
        );

    if (session == null) {
      final dateStr = date.toIso8601String().split('T')[0];
      throw Exception(
          'Date $dateStr does not fall within any configured Financial Year.');
    }

    if (session.isClosed) {
      throw Exception(
          'Financial Year ${session.sYear} is closed. Cannot transact.');
    }

    return session.sYear;
  }

  Future<void> convertOrderToInvoice(Order order,
      {required List<ChartOfAccount> accounts}) async {
    // if (order.isInvoiced) return; // Allow manual regeneration
    final sessions = await _repository.getFinancialSessions(
        organizationId: order.organizationId);
    final voucherDate = DateTime.now();
    final sYear = order.sYear ?? _validateSYear(voucherDate, sessions);

    // Determine whether GL is enabled for this organization
    final organization = await _organizationRepository.getOrganization(order.organizationId);
    final isGLEnabled = organization?.isGL ?? false;

    // Invoice + Items are created regardless of GL. GL transactions are
    // conditional on isGL.
    final invoiceId = const Uuid().v4();
    String invoiceNumber;

    if (isGLEnabled) {
      // GL path: preserve existing voucher-numbering behavior
      final glSetup = await _repository.getGLSetup(order.organizationId);
      if (glSetup == null) {
        throw Exception(
            'Accounting GL Configuration not found for this organization. Please setup GL accounts first.');
      }

      // Fetch Customer to get specific GL Account logic
      final customer = await _businessPartnerRepository
          .getPartnerById(order.businessPartnerId);
      final customerGLAccountId = customer?.chartOfAccountId;

      // Use Customer GL Account, fallback to Global Receivable if set, else error
      final receivableAccountId =
          customerGLAccountId ?? glSetup.receivableAccountId;
      if (receivableAccountId == null) {
        throw Exception(
            'No Receivable GL Account found. Please set "Customer GL Account" for this customer or configure a default "Accounts Receivable" in GL Setup.');
      }

      // Fetch up-to-date prefixes
      final prefixes = await _repository.getVoucherPrefixes();

      // 1. Generate SINV Voucher (Revenue)
      final sinvPrefix = prefixes.firstWhere(
        (p) =>
            p.voucherType.replaceAll(' ', '_') == 'SALES_INVOICE' ||
            p.prefixCode == 'SINV',
        orElse: () =>
            throw Exception('Sales Invoice (SINV) prefix not configured'),
      );

      invoiceNumber = await generateVoucherNumber(
        prefixCode: sinvPrefix.prefixCode,
        storeId: order.storeId,
        organizationId: order.organizationId,
        sYear: sYear,
      );

      final jvPrefix = prefixes.where((p) => p.prefixCode == 'JV').firstOrNull;

      // 2. Create Transaction Entry (Revenue: Dr Receivable, Cr Sales)
      final revenueTransaction = Transaction(
        id: const Uuid().v4(),
        voucherPrefixId: sinvPrefix.id,
        voucherNumber: invoiceNumber,
        voucherDate: voucherDate,
        accountId: receivableAccountId, // Debit Receivable (GL Account)
        moduleAccount: order.businessPartnerId, // Sub-Ledger: Customer
        offsetAccountId: glSetup.salesAccountId, // Credit Sales
        offsetModuleAccount: glSetup.salesAccountId,
        amount: order.totalAmount,
        description: 'Sales Invoice for Order #${order.orderNumber}',
        organizationId: order.organizationId,
        storeId: order.storeId,
        sYear: sYear,
        invoiceId: invoiceId,
      );

      await _repository.createTransaction(revenueTransaction);

      // 3. Automated Inventory/COGS Entry (Dr COGS, Cr Inventory)
      try {
        final orderItemsData = await _orderRepository.getOrderItems(order.id);
        double totalCost = 0;

        for (final itemJson in orderItemsData) {
          final productId = itemJson['product_id'] as String;
          final qty = (itemJson['quantity'] as num).toDouble();
          try {
            final product = await _productRepository.getProductById(productId);
            totalCost += (product.cost * qty);
          } catch (e) {
            // ignore: avoid_print
            print(
                'VoucherService: Could not fetch cost for product $productId, skipping in COGS calculation');
          }
        }

        if (totalCost > 0 && jvPrefix != null) {
          // Generate a dedicated JV number for COGS
          final jvVoucherNumber = await generateVoucherNumber(
            prefixCode: jvPrefix.prefixCode,
            storeId: order.storeId,
            organizationId: order.organizationId,
            sYear: sYear,
          );

          final cogsTransaction = Transaction(
            id: const Uuid().v4(),
            voucherPrefixId: jvPrefix.id,
            voucherNumber: jvVoucherNumber,
            voucherDate: voucherDate,
            accountId: glSetup.cogsAccountId, // Debit COGS
            moduleAccount:
                glSetup.cogsAccountId, // Internal: Module same as Account
            offsetAccountId: glSetup.inventoryAccountId, // Credit Inventory
            offsetModuleAccount: glSetup
                .inventoryAccountId, // Internal: Offset Module same as Offset Account
            amount: totalCost,
            description: 'COGS for Order #${order.orderNumber}',
            organizationId: order.organizationId,
            storeId: order.storeId,
            sYear: sYear,
            invoiceId: invoiceId,
          );
          await _repository.createTransaction(cogsTransaction);
        }
      } catch (e) {
        // ignore: avoid_print
        print('VoucherService: Error generating COGS entry: $e');
      }

      // 4. Handle Cash Receipt if Payment Term is Cash (ID = 1 or Name = Cash)
      if (order.paymentTermId == 1) {
        try {
          final crvPrefix = prefixes.firstWhere(
            (p) =>
                p.voucherType.replaceAll(' ', '_') == 'PAYMENT_VOUCHER' ||
                p.prefixCode == 'CRV' ||
                p.prefixCode == 'RV',
            orElse: () =>
                throw Exception('Receipt Voucher prefix not configured'),
          );

          final receiptVoucherNumber = await generateVoucherNumber(
            prefixCode: crvPrefix.prefixCode,
            storeId: order.storeId,
            organizationId: order.organizationId,
            sYear: sYear,
          );

          final cashAcctId = glSetup.cashAccountId;
          if (cashAcctId == null) {
            throw Exception(
                'No Cash Account configured for receipt.');
          }

          final bankCashAccounts = await _repository.getBankCashAccounts(
              organizationId: order.organizationId);
          final cashModuleId = bankCashAccounts
              .where((bc) => bc.chartOfAccountId == cashAcctId)
              .firstOrNull
              ?.id;

          final receiptTransaction = Transaction(
            id: const Uuid().v4(),
            voucherPrefixId: crvPrefix.id,
            voucherNumber: receiptVoucherNumber,
            voucherDate: voucherDate,
            accountId: cashAcctId, // Debit Cash
            moduleAccount: cashModuleId, // Sub-Ledger: Bank/Cash
            offsetAccountId:
                receivableAccountId, // Credit Receivable (GL Account)
            offsetModuleAccount: order.businessPartnerId, // Sub-Ledger: Customer
            amount: order.totalAmount,
            description: 'Receipt for Order #${order.orderNumber}',
            organizationId: order.organizationId,
            storeId: order.storeId,
            sYear: sYear,
            invoiceId: invoiceId,
          );

          await _repository.createTransaction(receiptTransaction);
        } catch (e) {
          // ignore: avoid_print
          print('VoucherService: Receipt voucher generation failed: $e');
          rethrow;
        }
      }
    } else {
      // Non-GL path: simple unique invoice number
      final existing = await _repository.getInvoices(
        organizationId: order.organizationId,
        storeId: order.storeId,
        sYear: sYear,
      );
      final seq = existing.length + 1;
      invoiceNumber = 'INV-${seq.toString().padLeft(7, '0')}';
    }

    // 5. Create Invoice Record (Header + Details)
    // ---------------------------------------------------------
    // Fetch or determine Invoice Type
    final rawInvoiceTypes =
        await _repository.getInvoiceTypes(organizationId: order.organizationId);
    final invoiceTypes = rawInvoiceTypes.cast<InvoiceType>();

    // logic to find correct invoice type based on order type
    final targetPrefix = order.orderType == 'PO' ? 'PI' : 'SI';
    final sinvType = invoiceTypes.firstWhere(
      (t) =>
          t.idInvoiceType == targetPrefix ||
          (order.orderType == 'SO' &&
              t.idInvoiceType == 'SI') ||
          (order.orderType == 'PO' &&
              t.idInvoiceType == 'PI') ||
          t.description.toLowerCase().contains(targetPrefix.toLowerCase()),
      orElse: () => InvoiceType(
        idInvoiceType: targetPrefix,
        description: targetPrefix == 'PI'
            ? 'Purchase Invoice'
            : 'Sales Invoice',
        forUsed: targetPrefix == 'PI' ? 'Purchase' : 'Sales',
        isActive: true,
        organizationId: order.organizationId,
      ),
    );

    final newInvoice = Invoice(
      id: invoiceId,
      invoiceNumber: invoiceNumber,
      invoiceDate: voucherDate,
      idInvoiceType: sinvType.idInvoiceType,
      businessPartnerId: order.businessPartnerId,
      orderId: order.id,
      totalAmount: order.totalAmount,
      status: 'Unpaid',
      organizationId: order.organizationId,
      storeId: order.storeId,
      sYear: sYear,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final orderItemsData = await _orderRepository.getOrderItems(order.id);
    final invoiceItems = <InvoiceItem>[];

    for (final itemJson in orderItemsData) {
      final productId = itemJson['product_id'] as String;
      final qty = (itemJson['quantity'] as num).toDouble();
      final price = (itemJson['price'] as num?)?.toDouble() ??
          (itemJson['rate'] as num?)?.toDouble() ??
          0.0;
      final total = (itemJson['total'] as num?)?.toDouble() ?? (qty * price);

      String? productName;
      try {
        final p = await _productRepository.getProductById(productId);
        productName = p.name;
      } catch (_) {}

      invoiceItems.add(InvoiceItem(
        id: const Uuid().v4(),
        invoiceId: invoiceId,
        productId: productId,
        productName: productName,
        quantity: qty,
        rate: price,
        total: total,
        createdAt: DateTime.now(),
      ));
    }

    await _repository.createInvoiceWithItems(newInvoice, invoiceItems);

    // 6. Update Order status
    await _orderRepository.updateOrderInvoiced(order.id, true);
  }
}

final voucherServiceProvider = Provider<VoucherService>((ref) {
  final repo = ref.watch(accountingRepositoryProvider);
  final orderRepo = ref.watch(orderRepositoryProvider);
  final productRepo = ref.watch(productRepositoryProvider);
  final partnerRepo = ref.watch(businessPartnerRepositoryProvider);
  final orgRepo = ref.watch(organizationRepositoryProvider);
  return VoucherService(repo, orderRepo, productRepo, partnerRepo, orgRepo);
});
