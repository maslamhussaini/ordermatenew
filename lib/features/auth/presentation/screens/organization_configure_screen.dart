import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/widgets/step_indicator.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/services/accounting_seed_service.dart';
import 'package:ordermate/features/accounting/presentation/providers/accounting_provider.dart';

class OrganizationConfigureScreen extends ConsumerStatefulWidget {
  final int orgId;

  const OrganizationConfigureScreen({super.key, required this.orgId});

  @override
  ConsumerState<OrganizationConfigureScreen> createState() =>
      _OrganizationConfigureScreenState();
}

class _OrganizationConfigureScreenState
    extends ConsumerState<OrganizationConfigureScreen> {
  bool _isLoading = false;
  bool _isSeeding = false;
  bool _importData = true;
  Map<String, dynamic>? _defaultData;

  @override
  void initState() {
    super.initState();
    _loadDefaultData();
  }

  Future<void> _loadDefaultData() async {
    setState(() => _isLoading = true);
    try {
      final data = await AccountingSeedService().fetchDefaultData();
      setState(() => _defaultData = data);
    } catch (e) {
      debugPrint('Error loading default data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _finishSetup() async {
    setState(() => _isSeeding = true);

    // Foundational system data (invoice types + voucher prefixes) is not an
    // opt-in "chart of accounts" preference -- unlike the _importData-gated
    // seedOrganization call below, this always runs, in its own try/catch,
    // so a real signup ends with a usable organization regardless of the
    // COA-import choice AND regardless of whether seedOrganization below
    // throws. Idempotent: see
    // AccountingSetupService.seedInvoiceTypesAndVoucherPrefixes.
    try {
      await ref
          .read(accountingSetupServiceProvider)
          .seedInvoiceTypesAndVoucherPrefixes(widget.orgId);
    } catch (e) {
      debugPrint(
          'Error seeding invoice types/voucher prefixes for org ${widget.orgId}: $e');
    }

    try {
      if (_importData) {
        await AccountingSeedService().seedOrganization(widget.orgId);
      }

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Setup Complete!',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            content: const Text(
                'Your organization has been configured successfully.',
                style: TextStyle(color: Colors.black87)),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(c);
                  // Explicitly end the registration session before returning
                  // to /login -- without this, the same session (S1) used
                  // during org/store creation carries through unchanged, the
                  // router's isLoggedIn guard skips the login screen, and
                  // Workspace loads stores under that same stale session
                  // (observed as "No stores found" until a manual sign-out
                  // and fresh sign-in). Awaited so /login is only reached
                  // once the sign-out has actually completed.
                  await SupabaseConfig.client.auth.signOut();
                  if (context.mounted) {
                    context.go('/login'); // Now genuinely starts a fresh session
                  }
                },
                child: const Text('Go to Login',
                    style: TextStyle(
                        color: AppColors.loginGradientStart,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const SizedBox.shrink(), // No back button on final step?
        title: const Text(
          'Configure Organization',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.loginGradientStart, AppColors.loginGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const StepIndicator(
                currentStep: 6,
                totalSteps: 6,
                stepLabels: [
                  'Account',
                  'Org',
                  'Branch',
                  'Team',
                  'Verify',
                  'Config'
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Final Setup',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Review and import default settings',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // Import Checkbox
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: CheckboxListTile(
                          title: const Text(
                            'Import Default Chart of Accounts',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Selecting this will pre-populate your accounting system with standard accounts.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          activeColor: Colors.white,
                          checkColor: AppColors.loginGradientStart,
                          value: _importData,
                          onChanged: (v) => setState(() => _importData = v ?? true),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Tree View Header
                      if (_importData) ...[
                        const Text(
                          'Preview of Default Accounts:',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : _buildAccountTree(),
                          ),
                        ),
                      ] else 
                        const Expanded(child: Center(child: Text('Default data will not be imported.', style: TextStyle(color: Colors.white70)))),

                      const SizedBox(height: 24),
                      
                      _isSeeding
                          ? const Center(
                              child: CircularProgressIndicator(color: Colors.white))
                          : ElevatedButton(
                              onPressed: _finishSetup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.loginGradientStart,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Finish Setup',
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTree() {
    if (_defaultData == null) return const Center(child: Text('No data loaded'));

    final types = List<Map<String, dynamic>>.from(_defaultData!['account_types']);
    final categories = List<Map<String, dynamic>>.from(_defaultData!['account_categories']);
    final accounts = List<Map<String, dynamic>>.from(_defaultData!['chart_of_accounts']);

    // Organize Data Hierarchy
    // Type -> [Categories] -> [Accounts]
    
    return ListView.builder(
      itemCount: types.length,
      itemBuilder: (context, typeIndex) {
        final type = types[typeIndex];
        final typeName = type['type_name'];
        
        final typeCategories = categories.where((c) => c['type_name'] == typeName).toList();
        
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(typeName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            children: typeCategories.map((cat) {
              final catName = cat['category_name'];
              final catAccounts = accounts.where((a) => a['category_name'] == catName).toList();
              
              return ExpansionTile(
                title: Text(catName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                childrenPadding: const EdgeInsets.only(left: 16),
                children: catAccounts.map((acc) {
                  return ListTile(
                    dense: true,
                    title: Text('${acc['account_code']} - ${acc['account_title']}'),
                    leading: const Icon(Icons.circle, size: 8, color: Colors.grey),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
