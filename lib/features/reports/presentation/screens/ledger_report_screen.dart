// lib/features/reports/presentation/screens/ledger_report_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/features/reports/presentation/providers/report_provider.dart';
import 'package:ordermate/features/accounting/domain/entities/chart_of_account.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/services/sync_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ordermate/features/reports/presentation/utils/ledger_printer.dart';

class LedgerReportScreen extends ConsumerStatefulWidget {
  final String type; // customer, vendor, bank, cash, gl
  const LedgerReportScreen({super.key, required this.type});

  @override
  ConsumerState<LedgerReportScreen> createState() => _LedgerReportScreenState();
}

class _LedgerReportScreenState extends ConsumerState<LedgerReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  dynamic _selectedEntity; // BusinessPartner or ChartOfAccount
  double _openingBalance = 0.0;
  List<Map<String, dynamic>> _ledgerEntries = [];
  bool _isLoading = false;
  bool _showAging = false;
  List<Map<String, dynamic>> _agingInvoices = [];

  void _setDateRange(int days) {
    setState(() {
      _endDate = DateTime.now();
      if (days == 0) {
        _startDate = DateTime(_endDate.year, _endDate.month, _endDate.day);
      } else if (days == 7) {
        _startDate = _endDate.subtract(const Duration(days: 7));
      } else if (days == 30) {
        _startDate = DateTime(_endDate.year, _endDate.month, 1);
      } else if (days == -1) {
        // Current Year
        _startDate = DateTime(_endDate.year, 1, 1);
      }
    });
    _loadLedger();
  }

  final NumberFormat _amtFormat = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (widget.type == 'customer') {
        ref.read(businessPartnerProvider.notifier).loadCustomers();
        ref.read(accountingProvider.notifier).loadAll();
      } else if (widget.type == 'vendor') {
        ref.read(businessPartnerProvider.notifier).loadVendors();
        ref.read(accountingProvider.notifier).loadAll();
      } else if (widget.type == 'gl') {
        ref.read(accountingProvider.notifier).loadAll();
      } else if (widget.type == 'bank' || widget.type == 'cash') {
        ref.read(accountingProvider.notifier).loadBankCashAccounts();
        ref.read(accountingProvider.notifier).loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title =
        "${widget.type[0].toUpperCase()}${widget.type.substring(1)} Ledger";

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Parameters',
            onPressed: _showParametersDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync Data',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing server data...')),
              );
              await ref.read(syncServiceProvider).syncAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sync complete! Refreshing...')),
                );
                if (_selectedEntity != null) _loadLedger();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _selectedEntity == null
                ? _buildEntitySelector()
                : _buildLedgerView(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    if (_selectedEntity == null) return const SizedBox.shrink();

    final orgState = ref.watch(organizationProvider);
    final orgName = orgState.selectedOrganization?.name ?? 'Organization';
    final storeName = orgState.selectedStore?.name ?? 'Store';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getEntityName().toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: Colors.indigo.shade900,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        "${_getEntityCode()} · ${widget.type.toUpperCase()}",
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          "Statement: ${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}",
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(orgName,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.grey.shade800)),
                  Text(storeName,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          _amtFormat.format(_openingBalance +
                              _ledgerEntries.fold(
                                  0.0,
                                  (sum, item) =>
                                      sum +
                                      ((item['debit'] as num?)?.toDouble() ??
                                          0) -
                                      ((item['credit'] as num?)?.toDouble() ??
                                          0))),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Action Buttons Row
          Row(
            children: [
              _buildActionButton(Icons.tune_outlined, "Parameters",
                  () => _showParametersDialog()),
              const SizedBox(width: 12),
              _buildActionButton(Icons.print_outlined, "Print", () async {
                if (_selectedEntity == null) return;

                final orgState = ref.read(organizationProvider);
                final orgName =
                    orgState.selectedOrganization?.name ?? 'Organization';
                bool invertBalance =
                    (widget.type == 'customer' || widget.type == 'vendor');

                await LedgerPrinter.printLedger(
                  entityName: _getEntityName(),
                  startDate: _startDate,
                  endDate: _endDate,
                  openingBalance: _openingBalance,
                  transactions: _ledgerEntries,
                  organizationName: orgName,
                  invertBalance: invertBalance,
                  agingInvoices: _showAging ? _agingInvoices : null,
                );
              }),
              const SizedBox(width: 12),
              _buildActionButton(Icons.share_outlined, "Share", () async {
                final text =
                    "Ledger for ${_getEntityName()} from ${DateFormat('yyyy-MM-dd').format(_startDate)} to ${DateFormat('yyyy-MM-dd').format(_endDate)}";
                try {
                  await Share.share(text);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Sharing Statement: $text"),
                      duration: const Duration(seconds: 5),
                      action:
                          SnackBarAction(label: 'Dismiss', onPressed: () {}),
                    ));
                  }
                }
              }),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectedEntity = null;
                  _ledgerEntries = [];
                  _openingBalance = 0.0;
                  _agingInvoices = [];
                }),
                icon: const Icon(Icons.change_circle_outlined, size: 18),
                label: const Text('Change Account'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateChip("Today", 0),
                const SizedBox(width: 8),
                _buildDateChip("Last 7 Days", 7),
                const SizedBox(width: 8),
                _buildDateChip("This Month", 30),
                const SizedBox(width: 8),
                _buildDateChip("This Year", -1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.indigo.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.indigo.shade700),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateChip(String label, int days) {
    return InkWell(
      onTap: () => _setDateRange(days),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.indigo.withValues(alpha: 0.1)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800)),
      ),
    );
  }

  String _getEntityCode() {
    if (_selectedEntity is BusinessPartner) return "BP";
    if (_selectedEntity is BankCash) return "BC";
    if (_selectedEntity is ChartOfAccount) {
      return (_selectedEntity as ChartOfAccount).accountCode;
    }
    return "ACC";
  }

  String _getEntityName() {
    if (_selectedEntity is BusinessPartner) {
      return (_selectedEntity as BusinessPartner).name;
    }
    if (_selectedEntity is BankCash) return (_selectedEntity as BankCash).name;
    if (_selectedEntity is ChartOfAccount) {
      return (_selectedEntity as ChartOfAccount).accountTitle;
    }
    return "Unknown";
  }





  Widget _buildEntitySelector() {
    if (widget.type == 'customer' || widget.type == 'vendor') {
      final state = ref.watch(businessPartnerProvider);
      final partners =
          widget.type == 'customer' ? state.customers : state.vendors;

      return ListView.builder(
        itemCount: partners.length,
        itemBuilder: (context, index) {
          final p = partners[index];
          return ListTile(
            leading: CircleAvatar(child: Text(p.name[0])),
            title: Text(p.name),
            subtitle: Text(p.phone ?? p.email ?? ''),
            onTap: () {
              setState(() => _selectedEntity = p);
              _loadLedger();
            },
          );
        },
      );
    } else if (widget.type == 'bank' || widget.type == 'cash') {
      final accountingState = ref.watch(accountingProvider);
      final bankCash = accountingState.bankCashAccounts;
      final accounts = accountingState.accounts;
      final categories = accountingState.categories;

      final filteredList = bankCash.where((bc) {
        final account =
            accounts.where((a) => a.id == bc.chartOfAccountId).firstOrNull;
        if (account == null) return false;

        final category = categories
            .where((c) => c.id == account.accountCategoryId)
            .firstOrNull;
        if (category == null) return false;

        final catName = category.categoryName.toLowerCase();
        if (widget.type == 'bank') return catName.contains('bank');
        if (widget.type == 'cash') return catName.contains('cash');
        return false;
      }).toList();

      return ListView.builder(
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final bc = filteredList[index];
          final account =
              accounts.where((a) => a.id == bc.chartOfAccountId).firstOrNull;

          return ListTile(
            leading: Icon(
                widget.type == 'bank' ? Icons.account_balance : Icons.payments,
                color: Colors.indigo),
            title: Text(bc.name),
            subtitle: Text(account?.accountTitle ?? ''),
            onTap: () {
              setState(() => _selectedEntity = bc);
              _loadLedger();
            },
          );
        },
      );
    } else {
      // Generic GL
      final accounts = ref.watch(accountingProvider).accounts;
      return ListView.builder(
        itemCount: accounts.length,
        itemBuilder: (context, index) {
          final acc = accounts[index];
          return ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(acc.accountTitle),
            subtitle: Text(acc.accountCode),
            onTap: () {
              setState(() => _selectedEntity = acc);
              _loadLedger();
            },
          );
        },
      );
    }
  }

  Future<void> _loadLedger() async {
    String accountId = '';
    String? moduleAccount;

    if (_selectedEntity is BusinessPartner) {
      final p = _selectedEntity as BusinessPartner;
      moduleAccount = p.id;
      accountId = p.chartOfAccountId ?? '';
    } else if (_selectedEntity is BankCash) {
      final b = _selectedEntity as BankCash;
      moduleAccount = b.id;
      accountId = b.chartOfAccountId;
    } else if (_selectedEntity is ChartOfAccount) {
      accountId = (_selectedEntity as ChartOfAccount).id;
    }

    if (accountId.isEmpty && (moduleAccount == null || moduleAccount.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Critical: No Valid ID found for entity.")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(reportRepositoryProvider);
      final orgState = ref.read(organizationProvider);
      final accState = ref.read(accountingProvider);

      final orgId = orgState.selectedOrganization?.id;
      final storeId = orgState.selectedStore?.id;
      final sYear = accState.selectedFinancialSession?.sYear;

      final result = await repo.getLedgerData(
        accountId,
        startDate: _startDate,
        endDate: _endDate,
        organizationId: orgId,
        storeId: storeId,
        sYear: sYear,
        moduleAccount: moduleAccount,
      );

      if (mounted) {
        setState(() {
          _openingBalance = result['openingBalance'] as double;
          _ledgerEntries = List<Map<String, dynamic>>.from(
              result['transactions'] as Iterable);
        });

        // If aging is requested, fetch it properly from the DB
        if (_showAging && moduleAccount != null) {
          final aging = await repo.getAgingData(moduleAccount,
              organizationId: orgId, storeId: storeId);
          setState(() {
            _agingInvoices = List<Map<String, dynamic>>.from(aging);
          });
        } else {
          setState(() {
            _agingInvoices = [];
          });
        }

        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showParametersDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Report Parameters',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Dates',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                _buildDatePickerLocal(
                  label: 'From Date',
                  value: _startDate,
                  context: context,
                  onChanged: (date) => setLocalState(() => _startDate = date),
                ),
                const SizedBox(height: 12),
                _buildDatePickerLocal(
                  label: 'Through Date',
                  value: _endDate,
                  context: context,
                  onChanged: (date) => setLocalState(() => _endDate = date),
                ),
                const SizedBox(height: 20),
                if (widget.type == 'customer' || widget.type == 'vendor')
                  Row(
                    children: [
                      Checkbox(
                        value: _showAging,
                        activeColor: AppColors.primary,
                        onChanged: (val) =>
                            setLocalState(() => _showAging = val ?? false),
                      ),
                      const Expanded(
                          child: Text('Show unpaid Invoice in Aging Column')),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (_selectedEntity != null) _loadLedger();
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              child: const Text('Go'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerLocal(
      {required String label,
      required DateTime value,
      required BuildContext context,
      required ValueChanged<DateTime> onChanged}) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) onChanged(date);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(DateFormat('dd-MMM-yyyy').format(value),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_ledgerEntries.isEmpty && _openingBalance == 0) {
      return const Center(
          child: Text("No transactions found for the selected period."));
    }

    bool invertBalance = (widget.type == 'vendor');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.indigo.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 60,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 100,
                columnSpacing: 24,
                horizontalMargin: 20,
                headingRowColor: WidgetStateProperty.all(
                    Colors.indigo.shade50.withValues(alpha: 0.5)),
                columns: const [
                  DataColumn(
                      label: Text('Date',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.indigo))),
                  DataColumn(
                      label: Text('Voucher #',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.indigo))),
                  DataColumn(
                      label: Text('Account / Description',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.indigo))),
                  DataColumn(
                      label: Text('Debit',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.indigo)),
                      numeric: true),
                  DataColumn(
                      label: Text('Credit',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.indigo)),
                      numeric: true),
                  DataColumn(
                      label: Text('Balance',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.indigo)),
                      numeric: true),
                ],
                rows: [
                  // Opening Balance Row
                  DataRow(
                    color: WidgetStateProperty.all(Colors.grey.shade50),
                    cells: [
                      DataCell(Text(
                          DateFormat('dd-MMM-yyyy').format(_startDate),
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12))),
                      const DataCell(Text('')),
                      const DataCell(Text('OPENING BALANCE',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              color: Colors.black54))),
                      const DataCell(Text('')),
                      const DataCell(Text('')),
                      DataCell(Text(
                          _amtFormat.format(invertBalance
                              ? -_openingBalance
                              : _openingBalance),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black87))),
                    ],
                  ),
                  ..._ledgerEntries.map<DataRow>((tx) {
                    final debit = (tx['debit'] as num?)?.toDouble() ?? 0.0;
                    final credit = (tx['credit'] as num?)?.toDouble() ?? 0.0;
                    final date = DateTime.fromMillisecondsSinceEpoch(
                        tx['voucher_date'] as int);
                    final accName = tx['acname'] as String? ?? 'General Ledger';

                    double balance =
                        (tx['running_sum'] as num?)?.toDouble() ?? 0.0;
                    balance += _openingBalance;
                    if (invertBalance) balance = -balance;

                    return DataRow(
                      cells: [
                        DataCell(Text(DateFormat('dd-MMM-yyyy').format(date),
                            style: const TextStyle(fontSize: 12))),
                        DataCell(Text(tx['voucher_number']?.toString() ?? '-',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.indigo.shade300,
                                fontWeight: FontWeight.bold))),
                        DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(accName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.black87)),
                                if (tx['description'] != null &&
                                    tx['description'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      tx['description'].toString(),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                          height: 1.3),
                                      maxLines: 2,
                                      softWrap: true,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(Text(debit > 0 ? _amtFormat.format(debit) : '',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87))),
                        DataCell(Text(
                            credit > 0 ? _amtFormat.format(credit) : '',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87))),
                        DataCell(Text(_amtFormat.format(balance),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.black))),
                      ],
                    );
                  }),
                ],
              ),
            ),
            if (_showAging &&
                (widget.type == 'customer' || widget.type == 'vendor'))
              _buildAgingFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildAgingFooter() {
    // Use _agingInvoices fetched from DB instead of inferring from ledger
    Map<String, List<Map<String, dynamic>>> agingBreakdown = {
      '1 - 30': [],
      '31 - 60': [],
      '61 - 90': [],
      '91 - 120': [],
      '> 120': [],
    };
    Map<String, double> agingTotals = {
      '1 - 30': 0,
      '31 - 60': 0,
      '61 - 90': 0,
      '91 - 120': 0,
      '> 120': 0,
    };

    double totalOutstanding = 0;
    final now = DateTime.now();

    for (var inv in _agingInvoices) {
      final amount = (inv['outstanding_amount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= 0) continue;

      final dateStr = inv['invoice_date']?.toString() ?? '';
      DateTime? date;
      if (dateStr.isNotEmpty) {
        if (int.tryParse(dateStr) != null) {
          date = DateTime.fromMillisecondsSinceEpoch(int.parse(dateStr));
        } else {
          date = DateTime.tryParse(dateStr);
        }
      }
      date ??= now;

      final days = now.difference(date).inDays;
      String bucket;
      if (days <= 30) {
        bucket = '1 - 30';
      } else if (days <= 60) {
        bucket = '31 - 60';
      } else if (days <= 90) {
        bucket = '61 - 90';
      } else if (days <= 120) {
        bucket = '91 - 120';
      } else {
        bucket = '> 120';
      }

      agingTotals[bucket] = (agingTotals[bucket] ?? 0) + amount;
      agingBreakdown[bucket]!.add(inv);
      totalOutstanding += amount;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.indigo.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CUSTOMER AGING (OUTSTANDING BREAKDOWN)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.1,
                    color: Colors.indigo.shade900),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'TOTAL DUE: ${_amtFormat.format(totalOutstanding)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: agingBreakdown.keys
                  .where((bucket) => agingBreakdown[bucket]!.isNotEmpty)
                  .map((bucket) {
                final list = agingBreakdown[bucket]!;
                final total = agingTotals[bucket]!;
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bucket,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.indigo)),
                      const SizedBox(height: 12),
                      ...list.map((inv) {
                        final dateStr = inv['invoice_date']?.toString() ?? '';
                        DateTime? date;
                        if (dateStr.isNotEmpty) {
                          if (int.tryParse(dateStr) != null) {
                            date = DateTime.fromMillisecondsSinceEpoch(
                                int.parse(dateStr));
                          } else {
                            date = DateTime.tryParse(dateStr);
                          }
                        }
                        date ??= DateTime.now();
                        final days = DateTime.now().difference(date).inDays;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      inv['invoice_number']?.toString() ??
                                          'N/A',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                      "${DateFormat('MMM dd').format(date)} ($days d)",
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                              Text(_amtFormat.format(inv['outstanding_amount']),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.indigo.shade700,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 24),
                      Text(
                        'Bucket Total: ${_amtFormat.format(total)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black87),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
