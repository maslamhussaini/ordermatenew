// lib/features/reports/presentation/screens/reports_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/features/entitlement/presentation/providers/entitlement_providers.dart';

/// Phase 3B-3: each tile now carries the live `omtbl_app_forms.id` it
/// corresponds to (IDs live-verified in the Phase 3B audit session,
/// 2026-09-03 -- never invented) and is only rendered once
/// `reportAccessProvider(formId)` resolves to `true` through
/// `EffectiveAccessService.effectiveReportAccess` -- the same evaluation
/// path the router guard uses, so menu/hub visibility and direct-navigation
/// blocking can never disagree.
///
/// Titles/icons/colors/routes are intentionally kept as the existing
/// hand-authored presentation data (they were already an exact match for
/// the live `form_name`/ordering, and `omtbl_app_forms` has no icon/color
/// columns to source those from) -- only *which reports to show* is now
/// commercially gated, not the presentation metadata. See the Phase 3B-3
/// report for why this was chosen over a fully DB-sourced tile list.
class ReportsHubScreen extends ConsumerWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Reports Center',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
      ),
      // drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(context, ref, 'FINANCIAL LEDGERS', [
              _ReportItem(
                  formId: 9, // RPT_LEDGER_CUSTOMER
                  title: 'Customer Ledgers',
                  icon: Icons.person_search,
                  route: '/reports/ledger/customer',
                  color: Colors.blue),
              _ReportItem(
                  formId: 10, // RPT_LEDGER_VENDOR
                  title: 'Vendor Ledgers',
                  icon: Icons.local_shipping,
                  route: '/reports/ledger/vendor',
                  color: Colors.orange),
              _ReportItem(
                  formId: 11, // RPT_LEDGER_BANK
                  title: 'Bank Ledgers',
                  icon: Icons.account_balance,
                  route: '/reports/ledger/bank',
                  color: Colors.green),
              _ReportItem(
                  formId: 12, // RPT_LEDGER_CASH
                  title: 'Cash Ledgers',
                  icon: Icons.payments,
                  route: '/reports/ledger/cash',
                  color: Colors.teal),
              _ReportItem(
                  formId: 13, // RPT_LEDGER_GL
                  title: 'GL Account Ledgers',
                  icon: Icons.account_tree,
                  route: '/reports/ledger/gl',
                  color: Colors.indigo),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, ref, 'SALES REPORTS', [
              _ReportItem(
                  formId: 14, // RPT_SALES_PRODUCT
                  title: 'Sales - Product Wise',
                  icon: Icons.inventory_2,
                  route: '/reports/sales/product',
                  color: Colors.purple),
              _ReportItem(
                  formId: 15, // RPT_SALES_CUSTOMER
                  title: 'Sales - Customer Wise',
                  icon: Icons.groups,
                  route: '/reports/sales/customer',
                  color: Colors.deepPurple),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, ref, 'SALES RETURNS', [
              _ReportItem(
                  formId: 16, // RPT_RETURNS_PRODUCT
                  title: 'Returns - Product Wise',
                  icon: Icons.assignment_return,
                  route: '/reports/returns/product',
                  color: Colors.red),
              _ReportItem(
                  formId: 17, // RPT_RETURNS_CUSTOMER
                  title: 'Returns - Customer Wise',
                  icon: Icons.person_remove,
                  route: '/reports/returns/customer',
                  color: Colors.pink),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, ref, 'INVENTORY REPORTS', [
              _ReportItem(
                  formId: 18, // RPT_INVENTORY_JOURNAL
                  title: 'General Journal',
                  icon: Icons.history_edu,
                  route: '/reports/inventory-journal',
                  color: Colors.brown),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, ref, 'OTHER REPORTS', [
              _ReportItem(
                  formId: 19, // RPT_SALES_LOCATION
                  title: 'Sales Manager (Loc)',
                  icon: Icons.location_on,
                  route: '/reports/location',
                  color: Colors.blueGrey),
              _ReportItem(
                  formId: 20, // RPT_DAY_SUMMARY
                  title: 'Day Summary Report',
                  icon: Icons.summarize,
                  route: '/reports/day-closing',
                  color: Colors.indigo),
              _ReportItem(
                  formId: 37, // RPT_ORDER_LIST
                  title: 'Order List',
                  icon: Icons.list_alt,
                  route: '/reports/orders',
                  color: Colors.grey),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, ref, 'SALES REPORTS', [
              _ReportItem(
                  formId: 22, // RPT_ITEM_WISE_SALES
                  title: 'Item Wise Sales',
                  icon: Icons.shopping_basket,
                  route: '/reports/sales/item-wise',
                  color: Colors.purple),
              _ReportItem(
                  formId: 26, // RPT_SALES_INVOICE_CUSTOMER_WISE
                  title: 'Invoice - Customer Wise',
                  icon: Icons.groups,
                  route: '/reports/sales/invoice-customer-wise',
                  color: Colors.deepPurple),
              _ReportItem(
                  formId: 25, // RPT_SALES_INVOICE_ITEM_WISE
                  title: 'Invoice - Item Wise',
                  icon: Icons.inventory_2,
                  route: '/reports/sales/invoice-item-wise',
                  color: Colors.deepOrange),
              _ReportItem(
                  formId: 29, // RPT_MONTH_WISE_SALES
                  title: 'Month Wise Sales',
                  icon: Icons.calendar_month,
                  route: '/reports/sales/monthly-customer',
                  color: Colors.teal),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, ref, 'SALES ANALYSIS', [
              _ReportItem(
                  formId: 23, // RPT_GROSS_SALES
                  title: 'Gross Sales',
                  icon: Icons.trending_up,
                  route: '/reports/sales/gross',
                  color: Colors.green),
              _ReportItem(
                  formId: 24, // RPT_NET_SALES
                  title: 'Net Sales',
                  icon: Icons.account_balance_wallet,
                  route: '/reports/sales/net',
                  color: Colors.blue),
              _ReportItem(
                  formId: 21, // RPT_CUSTOMER_WISE_SALES
                  title: 'Customer Wise Sales',
                  icon: Icons.person_search,
                  route: '/reports/sales/customer-wise',
                  color: Colors.indigo),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, ref, 'RETURNS', [
              _ReportItem(
                  formId: 27, // RPT_SALES_RETURN_ITEM_WISE
                  title: 'Returns - Item Wise',
                  icon: Icons.assignment_return,
                  route: '/reports/returns/item-wise',
                  color: Colors.red),
              _ReportItem(
                  formId: 28, // RPT_SALES_RETURN_CUSTOMER_WISE
                  title: 'Returns - Customer Wise',
                  icon: Icons.person_remove,
                  route: '/reports/returns/customer-wise',
                  color: Colors.pink),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, ref, 'FINANCIAL', [
              _ReportItem(
                  formId: 30, // RPT_RECEIVABLE
                  title: 'Receivable Report',
                  icon: Icons.request_quote,
                  route: '/reports/receivable',
                  color: Colors.orange),
              _ReportItem(
                  formId: 31, // RPT_CUSTOMER_BALANCE
                  title: 'Customer Balance',
                  icon: Icons.balance,
                  route: '/reports/balance',
                  color: Colors.amber),
            ]),
            const SizedBox(height: 24),
            _buildSection(context, ref, 'PRODUCT REPORTS', [
              _ReportItem(
                  formId: 32, // RPT_PRODUCT_LIST
                  title: 'Product List',
                  icon: Icons.list_alt,
                  route: '/reports/products/list',
                  color: Colors.brown),
              _ReportItem(
                  formId: 33, // RPT_CATEGORY_WISE
                  title: 'Category Wise',
                  icon: Icons.category,
                  route: '/reports/products/category-wise',
                  color: Colors.cyan),
              _ReportItem(
                  formId: 34, // RPT_BRAND_WISE
                  title: 'Brand Wise',
                  icon: Icons.branding_watermark,
                  route: '/reports/products/brand-wise',
                  color: Colors.lime),
              _ReportItem(
                  formId: 35, // RPT_TYPE_WISE
                  title: 'Type Wise',
                  icon: Icons.type_specimen,
                  route: '/reports/products/type-wise',
                  color: Colors.purpleAccent),
              _ReportItem(
                  formId: 36, // RPT_SUPPLIER_WISE
                  title: 'Supplier Wise',
                  icon: Icons.local_shipping,
                  route: '/reports/products/supplier-wise',
                  color: Colors.deepOrangeAccent),
            ]),
          ],
        ),
      ),
    );
  }

  /// Renders a section only for the items that resolved entitled==true;
  /// hides the whole section (including its header) if none of its items
  /// are entitled (or all are still loading), so no empty section header
  /// is ever left dangling above nothing.
  Widget _buildSection(
      BuildContext context, WidgetRef ref, String title, List<_ReportItem> items) {
    final entitledItems = items.where((item) {
      final access = ref.watch(reportAccessProvider(item.formId));
      return access.maybeWhen(data: (entitled) => entitled, orElse: () => false);
    }).toList();

    if (entitledItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        _buildReportGrid(context, entitledItems),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildReportGrid(BuildContext context, List<_ReportItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 1100) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: () => context.push(item.route),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: item.color, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportItem {
  final int formId;
  final String title;
  final IconData icon;
  final String route;
  final Color color;

  _ReportItem(
      {required this.formId,
      required this.title,
      required this.icon,
      required this.route,
      required this.color});
}
