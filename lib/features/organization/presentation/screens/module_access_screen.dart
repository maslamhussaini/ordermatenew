import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/network/supabase_client.dart';

class ModuleAccessScreen extends ConsumerStatefulWidget {
  final String orgId;

  const ModuleAccessScreen({super.key, required this.orgId});

  @override
  ConsumerState<ModuleAccessScreen> createState() => _ModuleAccessScreenState();
}

class _ModuleAccessScreenState extends ConsumerState<ModuleAccessScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  
  bool _isGL = true;
  bool _isSales = true;
  bool _isInventory = true;
  bool _isHR = true;
  String _orgName = '';
  String _planType = 'free';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await SupabaseConfig.client
          .from('omtbl_organizations')
          .select('name, is_gl, is_sales, is_inventory, is_hr, plan_type')
          .eq('id', widget.orgId)
          .single();
      
      if (mounted) {
        setState(() {
          _orgName = data['name'] ?? 'Organization';
          _isGL = data['is_gl'] ?? true;
          _isSales = data['is_sales'] ?? true;
          _isInventory = data['is_inventory'] ?? true;
          _isHR = data['is_hr'] ?? true;
          _planType = data['plan_type'] ?? 'free';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // If plan_type doesn't exist yet, it's fine, we default to free
        if (e.toString().contains('plan_type')) {
           // Retry without plan_type or just ignore
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveData() async {
    setState(() => _isSaving = true);
    try {
      await SupabaseConfig.client.from('omtbl_organizations').update({
        'is_gl': _isGL,
        'is_sales': _isSales,
        'is_inventory': _isInventory,
        'is_hr': _isHR,
        'plan_type': _planType,
      }).eq('id', widget.orgId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Module and Plan updated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Module & Plan Configuration'),
        backgroundColor: AppColors.loginGradientStart,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Managing Access for $_orgName',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure subscription plan and available modules.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  
                  // Plan Selection
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Subscription Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          RadioListTile<String>(
                            title: const Text('Free Plan'),
                            subtitle: const Text('Restricted: 10 transactions/day/type, 10 products total'),
                            value: 'free',
                            groupValue: _planType,
                            onChanged: (value) => setState(() => _planType = value!),
                            activeColor: AppColors.loginGradientStart,
                          ),
                          RadioListTile<String>(
                            title: const Text('Paid Plan'),
                            subtitle: const Text('Unlimited Access'),
                            value: 'paid',
                            groupValue: _planType,
                            onChanged: (value) => setState(() => _planType = value!),
                            activeColor: AppColors.loginGradientStart,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Module Selection
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Modules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _buildModuleSwitch('General Ledger (Accounting)', _isGL, (v) => setState(() => _isGL = v)),
                          const Divider(),
                          _buildModuleSwitch('Sales & Billing', _isSales, (v) => setState(() => _isSales = v)),
                          const Divider(),
                          _buildModuleSwitch('Inventory Management', _isInventory, (v) => setState(() => _isInventory = v)),
                          const Divider(),
                          _buildModuleSwitch('Human Resources', _isHR, (v) => setState(() => _isHR = v)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.loginGradientStart,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildModuleSwitch(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.loginGradientStart,
    );
  }
}
