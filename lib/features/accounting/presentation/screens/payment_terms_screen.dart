// lib/features/accounting/presentation/screens/payment_terms_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/accounting_provider.dart';
import '../../domain/entities/chart_of_account.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class PaymentTermsScreen extends ConsumerStatefulWidget {
  const PaymentTermsScreen({super.key});

  @override
  ConsumerState<PaymentTermsScreen> createState() => _PaymentTermsScreenState();
}

class _PaymentTermsScreenState extends ConsumerState<PaymentTermsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);
    final filtered = state.paymentTerms.where((p) {
      return p.name.toLowerCase().contains(_searchQuery) ||
          (p.description?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Terms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final orgId =
                  ref.read(organizationProvider).selectedOrganization?.id;
              ref
                  .read(accountingProvider.notifier)
                  .loadAll(organizationId: orgId);
            },
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('Error: ${state.error}'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search payment terms...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _searchController.clear())
                              : null,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final term = filtered[index];
                          return Card(
                            child: ListTile(
                              onTap: () => context.push(
                                  '/accounting/payment-terms/edit/${term.id}'),
                              leading:
                                  const Icon(Icons.payment, color: Colors.blue),
                              title: Text(term.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: term.description != null
                                  ? Text(term.description!)
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    term.isActive
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: term.isActive
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.grey),
                                    onPressed: () => _confirmDelete(term),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/accounting/payment-terms/create'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(PaymentTerm term) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Term'),
        content: Text('Are you sure you want to delete "${term.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final orgId = ref.read(organizationProvider).selectedOrganization?.id;
        await ref
            .read(accountingProvider.notifier)
            .deletePaymentTerm(term.id, organizationId: orgId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment term deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
