import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/services/onboarding_state_service.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/core/widgets/step_indicator.dart';
import 'package:ordermate/features/business_partners/presentation/providers/business_partner_provider.dart';

class TeamSetupScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> onboardingData;

  const TeamSetupScreen({super.key, required this.onboardingData});

  @override
  ConsumerState<TeamSetupScreen> createState() => _TeamSetupScreenState();
}

class _TeamSetupScreenState extends ConsumerState<TeamSetupScreen> {
  late Map<String, dynamic> _data;
  final List<Map<String, String>> _teamMembers = [];
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'Staff';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.onboardingData);
    _hydrateOnboardingData();
  }

  Future<void> _hydrateOnboardingData() async {
    final resumeData = await OnboardingStateService.resumeData();
    if (resumeData != null) {
      _data.putIfAbsent('orgId', () => resumeData['orgId']);
      _data.putIfAbsent('storeId', () => resumeData['storeId']);
      _data.putIfAbsent('email', () => resumeData['email']);
      _data.putIfAbsent('fySyear', () => resumeData['fySyear']);
    }
  }

  void _addMember() {
    if (_nameController.text.isEmpty) return;

    setState(() {
      _teamMembers.add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
      });
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
    });
  }

  void _removeMember(int index) {
    setState(() {
      _teamMembers.removeAt(index);
    });
  }

  Future<int> _resolveRoleId(String roleName, int orgId) async {
    final repo = ref.read(businessPartnerRepositoryProvider);

    final roles = await repo.getRoles(organizationId: orgId);
    final existing = roles.firstWhere(
      (r) => (r['role_name'] as String?)?.toLowerCase() == roleName.toLowerCase(),
      orElse: () => const <String, dynamic>{},
    );
    if (existing.isNotEmpty) {
      return existing['id'] as int;
    }

    await repo.addRole(roleName, null, organizationId: orgId);
    final refreshed = await repo.getRoles(organizationId: orgId);
    final created = refreshed.firstWhere(
      (r) => (r['role_name'] as String?)?.toLowerCase() == roleName.toLowerCase(),
      orElse: () => throw Exception('Failed to create "$roleName" role.'),
    );
    return created['id'] as int;
  }

  Future<void> _finish() async {
    await _hydrateOnboardingData();
    setState(() => _isLoading = true);

    try {
      final orgId = _data['orgId'];
      final storeId = _data['storeId'];

      // Save team members to database if any
      for (var member in _teamMembers) {
        final roleId = await _resolveRoleId(member['role'] as String, orgId as int);
        await SupabaseConfig.client.from('omtbl_businesspartners').insert({
          'name': member['name'],
          'email': member['email']!.isEmpty ? null : member['email'],
          'phone': member['phone']!,
          'role_id': roleId,
          'is_employee': 1,
          'is_active': true,
          'organization_id': orgId,
          'store_id': storeId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        context.push('/onboarding/verify', extra: {
          ..._data,
          'teamMembers': _teamMembers,
        });

        await OnboardingStateService.save(
          inProgress: true,
          route: '/onboarding/verify',
          orgId: orgId,
          storeId: storeId,
          email: _data['email'] as String,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Team Setup',
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
                currentStep: 3,
                totalSteps: 6,
                stepLabels: [
                  'Account',
                  'Organization',
                  'Branch',
                  'Team',
                  'Verify',
                  'Config'
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      const Icon(Icons.group_add_outlined,
                          size: 60, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        'Invite Your Team',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add staff members to help manage your business',
                        style: TextStyle(fontSize: 14, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Add Member Form
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            _buildTextField(
                                controller: _nameController,
                                hint: 'Full Name',
                                icon: Icons.person),
                            const SizedBox(height: 12),
                            _buildTextField(
                                controller: _emailController,
                                hint: 'Email Address',
                                icon: Icons.email),
                            const SizedBox(height: 12),
                            _buildTextField(
                                controller: _phoneController,
                                hint: 'Phone Number',
                                icon: Icons.phone),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedRole,
                                        isExpanded: true,
                                        items: ['Staff', 'Manager', 'Admin']
                                            .map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value,
                                                style: const TextStyle(
                                                    color: Colors.black)),
                                          );
                                        }).toList(),
                                        onChanged: (val) => setState(
                                            () => _selectedRole = val!),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _addMember,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor:
                                        AppColors.loginGradientStart,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                  ),
                                  child: const Icon(Icons.add),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Team List
                      if (_teamMembers.isNotEmpty) ...[
                        const Text(
                          'Team Members',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_teamMembers.length, (index) {
                          final member = _teamMembers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.loginGradientStart,
                                child: Text(member['name']![0].toUpperCase(),
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ),
                              title: Text(member['name']!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  '${member['role']} • ${member['phone']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red),
                                onPressed: () => _removeMember(index),
                              ),
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 40),

                      _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white))
                          : ElevatedButton(
                              onPressed: _finish,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.loginGradientStart,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Proceed to Verification',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                      const SizedBox(height: 40),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.loginGradientStart, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: const TextStyle(color: Colors.black, fontSize: 14),
      ),
    );
  }
}
