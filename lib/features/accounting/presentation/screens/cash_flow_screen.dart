import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/daily_balance.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:uuid/uuid.dart';

class CashFlowScreen extends ConsumerStatefulWidget {
  const CashFlowScreen({super.key});

  @override
  ConsumerState<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends ConsumerState<CashFlowScreen> {
  String? _selectedAccountId;
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final org = ref.read(organizationProvider).selectedOrganization;
      ref.read(accountingProvider.notifier).loadAll(organizationId: org?.id);

      // Try to select the default cash account if GL setup is available
      final glSetup = ref.read(accountingProvider).glSetup;
      if (glSetup?.cashAccountId != null) {
        setState(() => _selectedAccountId = glSetup!.cashAccountId);
        _refreshBalance();
      }
    });
  }

  void _refreshBalance() {
    if (_selectedAccountId == null) return;
    final org = ref.read(organizationProvider).selectedOrganization;
    ref
        .read(accountingProvider.notifier)
        .loadDailyBalance(_selectedAccountId!, organizationId: org?.id);
  }

  Future<void> _closeDay() async {
    final state = ref.read(accountingProvider);
    final org = ref.read(organizationProvider).selectedOrganization;

    if (_selectedAccountId == null || org == null) return;

    final currentBalance = state.currentDailyBalance;
    final transactions = state.transactions
        .where((t) =>
            t.accountId == _selectedAccountId &&
            t.voucherDate.year == _selectedDate.year &&
            t.voucherDate.month == _selectedDate.month &&
            t.voucherDate.day == _selectedDate.day)
        .toList();

    double dr = 0;
    double cr = 0;
    for (var tx in transactions) {
      dr += tx
          .amount; // In simplified terms, we'd need to check Dr/Cr side properly
      // If we assume Transaction accountId is the primary, we'd need logic to know if it's Dr or Cr
      // For now, let's assume we sum all transactions for that account
    }

    // Calculate final closing
    double opening = currentBalance?.closingBalance ?? 0.0;
    // In a real system, you'd calculate dr/cr based on transaction type
    // This is a placeholder for the logic
    double closing = opening + dr - cr;

    final newBalance = DailyBalance(
      id: const Uuid().v4(),
      accountId: _selectedAccountId!,
      date: _selectedDate,
      openingBalance: opening,
      closingBalance: closing,
      transactionsDebit: dr,
      transactionsCredit: cr,
      isClosed: true,
      organizationId: org.id,
    );

    await ref.read(accountingProvider.notifier).saveDailyBalance(newBalance);

    // Create opening balance for next day
    final nextDay = _selectedDate.add(const Duration(days: 1));
    final nextDayOpening = DailyBalance(
      id: const Uuid().v4(),
      accountId: _selectedAccountId!,
      date: nextDay,
      openingBalance: closing,
      closingBalance: closing,
      transactionsDebit: 0,
      transactionsCredit: 0,
      isClosed: false,
      organizationId: org.id,
    );

    await ref
        .read(accountingProvider.notifier)
        .saveDailyBalance(nextDayOpening);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Day closed successfully and next day record created.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);
    final cashAccounts = state.accounts
        .where((a) => a.accountTypeId == 1)
        .toList(); // Assets (Cash/Bank usually)
    final dailyBalance = state.currentDailyBalance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Cash Flow'),
        actions: [
          IconButton(
            onPressed: _refreshBalance,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountId,
              decoration: const InputDecoration(
                labelText: 'Select Cash/Bank Account',
                border: OutlineInputBorder(),
              ),
              items: cashAccounts.map((a) {
                return DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.accountCode} - ${a.accountTitle}'),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedAccountId = val);
                _refreshBalance();
              },
            ),
            const SizedBox(height: 24),
            if (dailyBalance != null) ...[
              _buildStatCard(
                'Opening Balance',
                dailyBalance.openingBalance,
                Icons.start,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Today\'s Transactions',
                dailyBalance.transactionsDebit -
                    dailyBalance.transactionsCredit,
                Icons.swap_horiz,
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Closing Balance',
                dailyBalance.closingBalance,
                Icons.account_balance_wallet,
                Colors.green,
                isPrimary: true,
              ),
              const Spacer(),
              if (!dailyBalance.isClosed)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _closeDay,
                    icon: const Icon(Icons.lock),
                    label: const Text('Close Day & Generate Tomorrow'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              else
                const Card(
                  color: Colors.greenAccent,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle),
                        SizedBox(width: 8),
                        Text('Day is Closed',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ] else if (_selectedAccountId != null)
              const Center(
                  child: Text('No balance records found for this account.'))
            else
              const Center(
                  child: Text('Please select an account to view cash flow.')),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, double amount, IconData icon, Color color,
      {bool isPrimary = false}) {
    return Card(
      elevation: isPrimary ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  amount.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isPrimary ? color : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
