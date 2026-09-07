import 'package:flutter/material.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/module_access/data/repositories/module_access_repository.dart';
import 'package:ordermate/features/module_access/domain/entities/module_models.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';

class ModuleConfigScreen extends StatefulWidget {
  const ModuleConfigScreen({super.key});

  @override
  State<ModuleConfigScreen> createState() => _ModuleConfigScreenState();
}

class _ModuleConfigScreenState extends State<ModuleConfigScreen> {
  final _repository = ModuleAccessRepository();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<Organization> _organizations = [];
  List<Module> _modules = [];
  List<AppForm> _allForms = [];

  Organization? _selectedOrg;
  
  // State: ModuleID -> isActive
  Map<String, bool> _moduleStates = {};
  // State: FormID -> isEnabled
  Map<int, bool> _formStates = {};

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    // Security check.
    // Phase 3B-4A-R: replaced the hardcoded email comparison with the
    // real is_platform_admin() DB-backed check (see
    // audit_results/PHASE3B_4A_R_PLATFORM_ADMIN_AUTHORITY.md) -- this is
    // still only a client-side gate (this screen has no functioning write
    // path regardless, per the Phase 3B architecture audit), but it no
    // longer duplicates the hardcoded email as its own independent check.
    bool isPlatformAdmin = false;
    try {
      final rpcResult = await SupabaseConfig.client
          .rpc('is_platform_admin')
          .timeout(const Duration(seconds: 10));
      isPlatformAdmin = rpcResult == true;
    } catch (e) {
      debugPrint('ModuleConfigScreen: is_platform_admin() check failed: $e');
    }

    if (!isPlatformAdmin) {
      setState(() {
        _errorMessage = 'Access Denied. Only authorized administrators can view this screen.';
        _isLoading = false;
      });
      return;
    }

    try {
      final orgs = await _repository.getOrganizations();
      final modules = await _repository.getModules();
      final forms = await _repository.getForms();

      setState(() {
        _organizations = orgs;
        _modules = modules;
        _allForms = forms;
        
        if (_organizations.isNotEmpty) {
          _selectedOrg = _organizations.first;
          _loadOrgData(_selectedOrg!.id);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load initial data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrgData(int orgId) async {
    setState(() => _isLoading = true);
    try {
      final data = await _repository.getAccessData(orgId);
      
      final accessList = data['access'] as List;
      final itemsList = data['items'] as List;

      final newModuleStates = <String, bool>{};
      final newFormStates = <int, bool>{};

      // Default all to false first
      for (var m in _modules) newModuleStates[m.id] = false;
      for (var f in _allForms) newFormStates[f.id] = false;

      // Apply DB values
      for (var item in accessList) {
        newModuleStates[item['module_id']] = item['is_active'] ?? false;
      }
      for (var item in itemsList) {
        newFormStates[item['form_id']] = item['is_enabled'] ?? false;
      }

      setState(() {
        _moduleStates = newModuleStates;
        _formStates = newFormStates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load organization settings: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_selectedOrg == null) return;
    
    setState(() => _isSaving = true);
    try {
      final accesses = _moduleStates.entries.map((e) => ModuleAccess(
        moduleId: e.key,
        organizationId: _selectedOrg!.id,
        isActive: e.value,
      )).toList();

      final items = <ModuleAccessItem>[];
      
      // We iterate over all forms. 
      // Important: We need the module_id for each form to construct the ModuleAccessItem.
      // Assuming _allForms has accurate module_id.
      for (var form in _allForms) {
        if (form.moduleId != null && _moduleStates.containsKey(form.moduleId)) {
           items.add(ModuleAccessItem(
             formId: form.id,
             moduleId: form.moduleId!,
             organizationId: _selectedOrg!.id,
             isEnabled: _formStates[form.id] ?? false,
           ));
        }
      }

      await _repository.saveConfiguration(
        organizationId: _selectedOrg!.id,
        accesses: accesses,
        items: items,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _toggleModule(String moduleId, bool? value) {
    setState(() {
      _moduleStates[moduleId] = value ?? false;
      // Optional: If module disabled, disable all children? 
      // User didn't ask for this explicitly, but it's good UX. 
      // Or maybe just leave them as is. Let's leave as is to preserve state if re-enabled.
    });
  }

  void _toggleForm(int formId, bool? value) {
    setState(() {
      _formStates[formId] = value ?? false;
    });
  }

  // "All Enabled" - Enable logic for a list of forms
  void _toggleAllFormsInModule(String moduleId, bool value) {
    setState(() {
        final formsInModule = _allForms.where((f) => f.moduleId == moduleId);
        for (var f in formsInModule) {
            _formStates[f.id] = value;
        }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Group forms by module
    final formsByModule = <String, List<AppForm>>{};
    for (var m in _modules) formsByModule[m.id] = [];
    for (var f in _allForms) {
      if (f.moduleId != null && formsByModule.containsKey(f.moduleId)) {
        formsByModule[f.moduleId]!.add(f);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Module Configuration'),
      ),
      body: _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : Column(
              children: [
                if (_isLoading) const LinearProgressIndicator(),
                
                // Org Selector
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<Organization>(
                    key: const Key('org_dropdown'),
                    decoration: const InputDecoration(
                      labelText: 'Select Organization',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedOrg,
                    items: _organizations.map((org) => DropdownMenuItem(
                      value: org,
                      child: Text(org.name),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedOrg = val);
                        _loadOrgData(val.id);
                      }
                    },
                  ),
                ),

                // Modules List
                Expanded(
                  child: _isLoading && _modules.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          key: const Key('module_list'),
                          itemCount: _modules.length,
                          itemBuilder: (context, index) {
                            final module = _modules[index];
                            final isModuleActive = _moduleStates[module.id] ?? false;
                            final forms = formsByModule[module.id] ?? [];

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ExpansionTile(
                                leading: Icon(
                                  Icons.view_module, 
                                  color: isModuleActive ? Colors.blue : Colors.grey
                                ),
                                title: Text(module.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Master toggle for Module
                                        Switch(
                                            value: isModuleActive, 
                                            onChanged: (val) => _toggleModule(module.id, val)
                                        ),
                                        // Expansion arrow is default
                                    ],
                                ),
                                children: [
                                  // "All" Toggle Row inside for convenience
                                  Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                              const Text("Enable All Forms: "),
                                              Switch(
                                                  value: forms.every((f) => _formStates[f.id] == true),
                                                  onChanged: (val) => _toggleAllFormsInModule(module.id, val)
                                              )
                                          ],
                                      ),
                                  ),
                                  const Divider(),
                                  // Form Items
                                  ...forms.map((form) {
                                    final isEnabled = _formStates[form.id] ?? false;
                                    return ListTile(
                                      title: Text(form.name),
                                      trailing: Switch(
                                        value: isEnabled,
                                        onChanged: (val) => _toggleForm(form.id, val),
                                        activeColor: Colors.green,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveChanges,
        label: _isSaving ? const Text('Saving...') : const Text('Save Changes'),
        icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
      ),
    );
  }
}
