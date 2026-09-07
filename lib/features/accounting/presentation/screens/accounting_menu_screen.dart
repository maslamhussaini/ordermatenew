// lib/features/accounting/presentation/screens/accounting_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccountingMenuScreen extends StatelessWidget {
  const AccountingMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounting Management'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuCard(
            context,
            title: 'Reports & Transactions',
            items: [
              _MenuItem(
                title: 'Financial Transactions',
                subtitle: 'View all ledger entries and vouchers',
                icon: Icons.receipt_long,
                color: Colors.blue,
                route: '/accounting/transactions',
              ),
              _MenuItem(
                title: 'Daily Cash Flow',
                subtitle: 'Track daily closing and net cash',
                icon: Icons.account_balance_wallet,
                color: Colors.green,
                route: '/accounting/cash-flow',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMenuCard(
            context,
            title: 'Setup & Configuration',
            items: [
              _MenuItem(
                title: 'General Ledger Setup',
                subtitle: 'Map system operations to specific accounts',
                icon: Icons.settings_applications,
                color: Colors.blueGrey,
                route: '/accounting/gl-setup',
              ),
              _MenuItem(
                title: 'Chart of Accounts',
                subtitle: 'Manage 4-level financial structure',
                icon: Icons.account_tree,
                color: Colors.indigo,
                route: '/accounting/coa',
              ),
              _MenuItem(
                title: 'Account Types',
                subtitle: 'Manage root categories (Asset, Liability...)',
                icon: Icons.category,
                color: Colors.blue,
                route: '/accounting/account-types',
              ),
              _MenuItem(
                title: 'Account Categories',
                subtitle: 'Setup group classifications',
                icon: Icons.list_alt,
                color: Colors.teal,
                route: '/accounting/account-categories',
              ),
              _MenuItem(
                title: 'Bank & Cash Accounts',
                subtitle: 'Configure store cash and bank ledgers',
                icon: Icons.account_balance,
                color: Colors.teal,
                route: '/accounting/bank-cash',
              ),
              _MenuItem(
                title: 'Payment Terms',
                subtitle: 'Manage credit and cash terms',
                icon: Icons.payment,
                color: Colors.orange,
                route: '/accounting/payment-terms',
              ),
              _MenuItem(
                title: 'Voucher Prefixes',
                subtitle: 'Setup transaction numbering rules',
                icon: Icons.format_list_numbered,
                color: Colors.purple,
                route: '/accounting/voucher-prefixes',
              ),
              _MenuItem(
                title: 'Financial Sessions',
                subtitle: 'Manage fiscal years and periods',
                icon: Icons.date_range,
                color: Colors.redAccent,
                route: '/accounting/financial-sessions',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context,
      {required String title, required List<_MenuItem> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Column(
            children: items.map((item) {
              final isLast = items.indexOf(item) == items.length - 1;
              return Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, color: item.color),
                    ),
                    title: Text(item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(item.subtitle,
                        style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(item.route),
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 64, color: Colors.grey.shade100),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}
