// lib/features/accounting/presentation/screens/bank_cash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounting_provider.dart';
import 'transactions_screen.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class BankCashScreen extends ConsumerStatefulWidget {
  const BankCashScreen({super.key});

  @override
  ConsumerState<BankCashScreen> createState() => _BankCashScreenState();
}

class _BankCashScreenState extends ConsumerState<BankCashScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final org = ref.read(organizationProvider).selectedOrganization;
      ref.read(accountingProvider.notifier).loadAll(organizationId: org?.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount(BankCash account) async {
    final isUsed =
        await ref.read(accountingProvider.notifier).isBankCashUsed(account.id);

    if (!mounted) return;

    if (isUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Cannot delete: This Bank/Cash account has associated transactions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${account.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final org = ref.read(organizationProvider).selectedOrganization;
        await ref
            .read(accountingProvider.notifier)
            .deleteBankCashAccount(account.id, organizationId: org?.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Bank/Cash account deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);

    final filteredAccounts = state.bankCashAccounts.where((account) {
      final query = _searchQuery.toLowerCase();
      if (query.isEmpty) return true;

      final coa = state.accounts
          .where((a) => a.id == account.chartOfAccountId)
          .firstOrNull;
      final coaMatch = coa != null &&
          (coa.accountTitle.toLowerCase().contains(query) ||
              coa.accountCode.contains(query));

      return account.name.toLowerCase().contains(query) || coaMatch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank & Cash Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final org = ref.read(organizationProvider).selectedOrganization;
              ref
                  .read(accountingProvider.notifier)
                  .loadAll(organizationId: org?.id);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search accounts or ledgers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.shade50
                    : Colors.white.withValues(alpha: 0.1),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text('Error: ${state.error}'))
                    : filteredAccounts.isEmpty
                        ? const Center(
                            child: Text('No bank/cash accounts found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredAccounts.length,
                            itemBuilder: (context, index) {
                              final account = filteredAccounts[index];
                              final coa = state.accounts
                                  .where(
                                      (a) => a.id == account.chartOfAccountId)
                                  .firstOrNull;

                              final isBank =
                                  account.name.toLowerCase().contains('bank');
                              final isDark = Theme.of(context).brightness ==
                                  Brightness.dark;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: ListTile(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TransactionsScreen(
                                          accountId: account.id,
                                          accountName: account.name,
                                        ),
                                      ),
                                    );
                                  },
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isBank
                                          ? (isDark
                                              ? Colors.blue
                                                  .withValues(alpha: 0.1)
                                              : Colors.blue.shade50)
                                          : (isDark
                                              ? Colors.orange
                                                  .withValues(alpha: 0.1)
                                              : Colors.orange.shade50),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isBank
                                          ? Icons.account_balance
                                          : Icons.money_rounded,
                                      color:
                                          isBank ? Colors.blue : Colors.orange,
                                    ),
                                  ),
                                  title: Text(
                                    account.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (coa != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            'Ledger: ${coa.accountCode} - ${coa.accountTitle}',
                                            style: TextStyle(
                                                color: isDark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade600,
                                                fontSize: 13),
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: account.status
                                              ? Colors.green
                                                  .withValues(alpha: 0.1)
                                              : Colors.red
                                                  .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          account.status
                                              ? 'ACTIVE'
                                              : 'INACTIVE',
                                          style: TextStyle(
                                            color: account.status
                                                ? Colors.green
                                                : Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            color: Colors.blue),
                                        onPressed: () => context.push(
                                            '/accounting/bank-cash/edit/${account.id}'),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _deleteAccount(account),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounting/bank-cash/create'),
        icon: const Icon(Icons.add),
        label: const Text('ADD ACCOUNT'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }
}
