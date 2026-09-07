import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/build_info.dart';
import 'package:ordermate/core/theme/app_colors.dart';
import 'package:ordermate/features/auth/presentation/providers/user_provider.dart';
import 'package:ordermate/core/localization/app_localizations.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/services/sync_service.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';
import 'package:ordermate/features/entitlement/presentation/providers/entitlement_providers.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _inventoryExpanded = false;
  bool _customersExpanded = false;
  bool _customersSetupExpanded = false;
  bool _customersReportsExpanded = false;
  bool _suppliersExpanded = false;
  bool _employeeExpanded = false;
  bool _managementExpanded = false;
  bool _setupsExpanded = false;
  bool _accountingExpanded = false;
  bool _accountingSetupExpanded = false;
  bool _bankCashExpanded = false;
  bool _bankCashSetupExpanded = false;
  bool _reportsExpanded = false;

  void _closeDrawerIfOpen(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.hasDrawer && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
    }
  }

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider).value;
    final auth = ref.watch(authProvider);
    final orgState = ref.watch(organizationProvider);
    final selectedOrg = orgState.selectedOrganization;
    final salesAccess = ref.watch(moduleAccessProvider('sales'));
    final inventoryAccess = ref.watch(moduleAccessProvider('inventory'));
    final hrAccess = ref.watch(moduleAccessProvider('hr'));
    final glAccess = ref.watch(moduleAccessProvider('gl'));

    var userName = userProfile?.fullName ?? '';
    if (userName.isEmpty || userName.toLowerCase() == 'unknown user') {
      userName = userProfile?.email ?? 'User';
    }

    return Drawer(
      width: 300,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.loginGradientStart,
                  AppColors.loginGradientEnd,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      height: 32,
                      width: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Triangletech\nOrder Mate',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User: $userName',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 8.0,
              radius: const Radius.circular(4.0),
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                shrinkWrap: false,
                primary: false,
                children: [
                  _buildMenuItem(
                    icon: Icons.dashboard,
                    title: AppLocalizations.of(context)?.get('dashboard') ??
                        'Dashboard',
                    onTap: () {
                      _closeDrawerIfOpen(context);
                      context.go('/dashboard');
                      // Start sync as requested
                      ref.read(syncServiceProvider).syncAll();
                    },
                  ),

                  _buildMenuItem(
                    icon: Icons.history_rounded,
                    title:
                        AppLocalizations.of(context)?.get('recent_changes') ??
                            'Recent Changes',
                    onTap: () {
                      _closeDrawerIfOpen(context);
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                              AppLocalizations.of(context)?.get('whats_new') ??
                                  "What's New"),
                          content: const SingleChildScrollView(
                            child: Text(whatsNew),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                  AppLocalizations.of(context)?.get('close') ??
                                      'Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const Divider(),

                  // GL Account (Expandable)
                  if (auth.can('accounting', Permission.read) &&
                      (selectedOrg == null || glAccess.value == true))
                    _buildExpandableMenuItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: AppLocalizations.of(context)?.get('gl_account') ??
                          'GL Account',
                      isExpanded: _accountingExpanded,
                      onTap: () {
                        setState(
                            () => _accountingExpanded = !_accountingExpanded);
                      },
                      children: [
                        _buildSubMenuItem(
                          title: AppLocalizations.of(context)
                                  ?.get('gl_transactions') ??
                              'GL Transactions',
                          icon: Icons.receipt_long_outlined,
                          onTap: () {
                            _closeDrawerIfOpen(context);
                            context.push('/accounting/transactions');
                          },
                        ),
                        _buildExpandableSubMenuItem(
                          icon: Icons.settings_outlined,
                          title: 'Setup Menu',
                          isExpanded: _accountingSetupExpanded,
                          onTap: () {
                            setState(() => _accountingSetupExpanded =
                                !_accountingSetupExpanded);
                          },
                          children: [
                            _buildSubMenuItem(
                              title: 'Accounting Overview',
                              icon: Icons.grid_view_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/accounting');
                              },
                              leftPadding: 48,
                            ),
                            _buildSubMenuItem(
                              title: 'Chart of Accounts',
                              icon: Icons.account_tree_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/accounting/coa');
                              },
                              leftPadding: 48,
                            ),
                            _buildSubMenuItem(
                              title: 'General Ledger Setup',
                              icon: Icons.settings_applications_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/accounting/gl-setup');
                              },
                              leftPadding: 48,
                            ),
                            _buildSubMenuItem(
                              title: 'Account Types',
                              icon: Icons.category_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/accounting/account-types');
                              },
                              leftPadding: 48,
                            ),
                            _buildSubMenuItem(
                              title: 'Account Categories',
                              icon: Icons.list_alt_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/accounting/account-categories');
                              },
                              leftPadding: 48,
                            ),
                             _buildSubMenuItem(
                               title: 'Voucher Prefixes',
                               icon: Icons.label_outline,
                               onTap: () {
                                 _closeDrawerIfOpen(context);
                                 context.push('/accounting/voucher-prefixes');
                               },
                               leftPadding: 48,
                             ),
                             _buildSubMenuItem(
                               title: 'Financial Sessions',
                               icon: Icons.date_range_outlined,
                               onTap: () {
                                 _closeDrawerIfOpen(context);
                                 context.push('/accounting/financial-sessions');
                               },
                               leftPadding: 48,
                             ),
                          ],
                        ),
                      ],
                    ),

                  // BankCash Management (Expandable)
                  if (auth.can('accounting', Permission.read) &&
                      (selectedOrg == null || glAccess.value == true))
                    _buildExpandableMenuItem(
                      icon: Icons.account_balance_outlined,
                      title: AppLocalizations.of(context)
                              ?.get('bank_cash_management') ??
                          'BankCash Management',
                      isExpanded: _bankCashExpanded,
                      onTap: () {
                        setState(
                            () => _bankCashExpanded = !_bankCashExpanded);
                      },
                      children: [
                        _buildSubMenuItem(
                          title: 'Transactions',
                          icon: Icons.receipt_long_outlined,
                          onTap: () {
                            _closeDrawerIfOpen(context);
                            context.push('/accounting/transactions?onlyBankCash=true');
                          },
                        ),
                        _buildExpandableSubMenuItem(
                          icon: Icons.settings_outlined,
                          title: 'Setup',
                          isExpanded: _bankCashSetupExpanded,
                          onTap: () {
                            setState(() => _bankCashSetupExpanded =
                                !_bankCashSetupExpanded);
                          },
                          children: [
                            _buildSubMenuItem(
                              title: 'Bank & Cash',
                              icon: Icons.account_balance_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/accounting/bank-cash');
                              },
                              leftPadding: 48,
                            ),
                          ],
                        ),
                      ],
                    ),

                  // Admin Menu (Expandable)
                  if (auth.can('organization', Permission.read) ||
                      auth.can('stores', Permission.read))
                    _buildExpandableMenuItem(
                      icon: Icons.admin_panel_settings_outlined,
                      title:
                          AppLocalizations.of(context)?.get('admin') ?? 'Admin',
                      isExpanded: _managementExpanded,
                      onTap: () {
                        setState(
                            () => _managementExpanded = !_managementExpanded);
                      },
                      children: [
                        if (auth.can('organization', Permission.read))
                          _buildSubMenuItem(
                            title: AppLocalizations.of(context)
                                    ?.get('organizations_list') ??
                                'Organizations List',
                            icon: Icons.list,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/organizations-list');
                            },
                          ),
                        if (auth.can('stores', Permission.read))
                          _buildSubMenuItem(
                            title: AppLocalizations.of(context)
                                    ?.get('branches_list') ??
                                'Branches List',
                            icon: Icons.store,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/branches');
                            },
                          ),
                      ],
                    ),

                  // Customers Management (Sales)
                  if ((auth.can('customers', Permission.read) ||
                          auth.can('orders', Permission.read) ||
                          auth.can('invoices', Permission.read)) &&
                      (selectedOrg == null || salesAccess.value == true))
                    _buildExpandableMenuItem(
                      icon: Icons.people,
                      title: AppLocalizations.of(context)
                              ?.get('customers_management') ??
                          'Customers Management',
                      isExpanded: _customersExpanded,
                      onTap: () {
                        setState(
                            () => _customersExpanded = !_customersExpanded);
                      },
                      children: [
                        if (auth.can('orders', Permission.read))
                          _buildSubMenuItem(
                            title:
                                AppLocalizations.of(context)?.get('orders') ??
                                    'Orders',
                            icon: Icons.shopping_cart,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/orders',
                                  extra: {'initialFilterType': 'SO'});
                            },
                          ),
                        if (auth.can('invoices', Permission.read))
                          _buildSubMenuItem(
                            title: 'Sales Invoices',
                            icon: Icons.receipt,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/invoices');
                            },
                          ),
                        if (auth.can('accounting', Permission.read))
                          _buildSubMenuItem(
                            title: 'Transactions List',
                            icon: Icons.receipt_long_outlined,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push(
                                  '/accounting/transactions?onlyCustomers=true');
                            },
                          ),

                        // Setup Sub-Menu
                        _buildExpandableSubMenuItem(
                          icon: Icons.settings_outlined,
                          title:
                              AppLocalizations.of(context)?.get('setups') ??
                                  'Setup',
                          isExpanded: _customersSetupExpanded,
                          onTap: () {
                            setState(() => _customersSetupExpanded =
                                !_customersSetupExpanded);
                          },
                          children: [
                            if (auth.can('customers', Permission.read))
                              _buildSubMenuItem(
                                title: AppLocalizations.of(context)
                                        ?.get('customer_list') ??
                                    'Customer List',
                                icon: Icons.list_alt,
                                onTap: () {
                                  _closeDrawerIfOpen(context);
                                  context.push('/customers');
                                },
                                leftPadding: 48,
                              ),
                            _buildSubMenuItem(
                              title: AppLocalizations.of(context)
                                      ?.get('sales_manager') ??
                                  'SalesMan List',
                              icon: Icons.badge_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push(
                                  '/employees',
                                  extra: {
                                    'title': 'SalesMan List',
                                    'filterRole': 'Salesman',
                                    'filterDept': 'Sales'
                                  },
                                );
                              },
                              leftPadding: 48,
                            ),
                          ],
                        ),

                        if (auth.can('customers', Permission.read))
                          _buildSubMenuItem(
                            title: AppLocalizations.of(context)
                                    ?.get('payment_terms') ??
                                'Payment Terms',
                            icon: Icons.calendar_today_outlined,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/accounting/payment-terms');
                            },
                            leftPadding: 48,
                          ),

                        // Reports Sub-Menu
                        _buildExpandableSubMenuItem(
                          icon: Icons.bar_chart_outlined,
                          title:
                              AppLocalizations.of(context)?.get('reports') ??
                                  'Reports',
                          isExpanded: _customersReportsExpanded,
                          onTap: () {
                            setState(() => _customersReportsExpanded =
                                !_customersReportsExpanded);
                          },
                          children: [
                            // Sales Reports
                            _buildSubMenuItem(
                              title:
                                  "${AppLocalizations.of(context)?.get('sales_reports') ?? 'Sales Reports'} (${AppLocalizations.of(context)?.get('product_wise') ?? 'Product Wise'})",
                              icon: Icons.inventory_2_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/reports/sales/product');
                              },
                              leftPadding: 48,
                            ),
                            _buildSubMenuItem(
                              title:
                                  "${AppLocalizations.of(context)?.get('sales_reports') ?? 'Sales Reports'} (${AppLocalizations.of(context)?.get('customer_wise') ?? 'Customer Wise'})",
                              icon: Icons.groups_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/reports/sales/customer');
                              },
                              leftPadding: 48,
                            ),
                            // Sales Return Reports
                            _buildSubMenuItem(
                              title:
                                  "${AppLocalizations.of(context)?.get('sales_return_reports') ?? 'Sales Return Reports'} (${AppLocalizations.of(context)?.get('product_wise') ?? 'Product Wise'})",
                              icon: Icons.assignment_return_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/reports/returns/product');
                              },
                              leftPadding: 48,
                            ),
                            _buildSubMenuItem(
                              title:
                                  "${AppLocalizations.of(context)?.get('sales_return_reports') ?? 'Sales Return Reports'} (${AppLocalizations.of(context)?.get('customer_wise') ?? 'Customer Wise'})",
                              icon: Icons.person_remove_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/reports/returns/customer');
                              },
                              leftPadding: 48,
                            ),
                            // Customer Ledger
                            _buildSubMenuItem(
                              title: AppLocalizations.of(context)
                                      ?.get('customer_ledger') ??
                                  'Customer Ledger',
                              icon: Icons.person_search_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/reports/ledger/customer');
                              },
                              leftPadding: 48,
                            ),
                            // Sales Manager (Location)
                            _buildSubMenuItem(
                              title:
                                  "${AppLocalizations.of(context)?.get('sales_manager') ?? 'Sales Manager'} (Loc)",
                              icon: Icons.location_on_outlined,
                              onTap: () {
                                _closeDrawerIfOpen(context);
                                context.push('/reports/location');
                              },
                              leftPadding: 48,
                            ),
                          ],
                        ),
                      ],
                    ),

                  // Employee Management (HR)
                  if (auth.can('employees', Permission.read) &&
                      (selectedOrg == null || hrAccess.value == true))
                    _buildExpandableMenuItem(
                      icon: Icons.badge,
                      title: AppLocalizations.of(context)
                              ?.get('employee_management') ??
                          'Employee Management',
                      isExpanded: _employeeExpanded,
                      onTap: () {
                        setState(() => _employeeExpanded = !_employeeExpanded);
                      },
                      children: [
                        _buildSubMenuItem(
                          title: AppLocalizations.of(context)
                                  ?.get('employees_list') ??
                              'Employees List',
                          icon: Icons.people_outline,
                          onTap: () {
                            _closeDrawerIfOpen(context);
                            context.push('/employees');
                          },
                        ),
                        _buildSubMenuItem(
                          title: 'Departments',
                          icon: Icons.work_outline,
                          onTap: () {
                            _closeDrawerIfOpen(context);
                            context.push('/employees/departments');
                          },
                        ),
                        _buildSubMenuItem(
                          title: 'Roles',
                          icon: Icons.security,
                          onTap: () {
                            _closeDrawerIfOpen(context);
                            context.push('/employees/roles');
                          },
                        ),
                        _buildSubMenuItem(
                          title: 'Application Users',
                          icon: Icons.people_alt_outlined,
                          onTap: () {
                            _closeDrawerIfOpen(context);
                            context.push('/employees/users');
                          },
                        ),
                        _buildSubMenuItem(
                          title: 'Permissions & Privileges',
                          icon: Icons.admin_panel_settings,
                          onTap: () {
                            _closeDrawerIfOpen(context);
                            context.push('/employees/privileges');
                          },
                        ),
                      ],
                    ),

                  // Inventory Management
                  if ((auth.can('inventory', Permission.read) ||
                          auth.can('products', Permission.read)) &&
                      (selectedOrg == null || inventoryAccess.value == true))
                    _buildExpandableMenuItem(
                      icon: Icons.inventory_2,
                      title: AppLocalizations.of(context)
                              ?.get('inventory_management') ??
                          'Inventory Management',
                      isExpanded: _inventoryExpanded,
                      onTap: () {
                        setState(
                            () => _inventoryExpanded = !_inventoryExpanded);
                      },
                      children: [
                        if (auth.can('products', Permission.read))
                          _buildSubMenuItem(
                            title:
                                AppLocalizations.of(context)?.get('products') ??
                                    'Product',
                            icon: Icons.shopping_bag_outlined,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/products');
                            },
                          ),
                        if (auth.can('inventory', Permission.read))
                          _buildSubMenuItem(
                            title:
                                AppLocalizations.of(context)?.get('brands') ??
                                    'Brands',
                            icon: Icons.branding_watermark,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/inventory/brands');
                            },
                          ),
                        if (auth.can('inventory', Permission.read))
                          _buildSubMenuItem(
                            title: AppLocalizations.of(context)
                                    ?.get('categories') ??
                                'Categories',
                            icon: Icons.category,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/inventory/categories');
                            },
                          ),
                        if (auth.can('inventory', Permission.read))
                          _buildSubMenuItem(
                            title: AppLocalizations.of(context)
                                    ?.get('product_types') ??
                                'Product Types',
                            icon: Icons.merge_type,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/inventory/product-types');
                            },
                          ),
                        if (auth.can('inventory', Permission.read))
                          _buildSubMenuItem(
                            title: 'Units of Measure',
                            icon: Icons.straighten,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/inventory/units-of-measure');
                            },
                          ),
                        if (auth.can('inventory', Permission.read))
                          _buildSubMenuItem(
                            title: 'Unit Conversions',
                            icon: Icons.compare_arrows,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/inventory/unit-conversions');
                            },
                          ),
                        if (auth.can('stock_transfer', Permission.read))
                          _buildSubMenuItem(
                            title: AppLocalizations.of(context)
                                    ?.get('stock_transfers') ??
                                'Stock Transfers',
                            icon: Icons.swap_horiz,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/inventory/transfers');
                            },
                          ),
                      ],
                    ),

                  if (auth.can('reports', Permission.read))
                    _buildExpandableMenuItem(
                      icon: Icons.bar_chart_outlined,
                      title: 'Reports',
                      isExpanded: _reportsExpanded,
                      onTap: () {
                        setState(() => _reportsExpanded = !_reportsExpanded);
                      },
                      children: [
                        _buildSubMenuItem(
                          title: 'Reports Hub',
                          icon: Icons.grid_view_outlined,
                          onTap: () {
                            _closeDrawerIfOpen(context);
                            context.go('/reports');
                          },
                        ),
                        _buildSubMenuItem(
                          title: AppLocalizations.of(context)
                                  ?.get('day_summary') ??
                              'Day Summary',
                          icon: Icons.summarize_rounded,
                          onTap: () {
                            _closeDrawerIfOpen(context);
                            context.push('/reports/day-closing');
                          },
                        ),
                      ],
                    ),

                  // Setups (Expandable)
                  if (auth.can('settings', Permission.read) ||
                      auth.can('organization', Permission.read))
                    _buildExpandableMenuItem(
                      icon: Icons.settings,
                      title: AppLocalizations.of(context)?.get('setups') ??
                          'Setups',
                      isExpanded: _setupsExpanded,
                      onTap: () {
                        setState(() => _setupsExpanded = !_setupsExpanded);
                      },
                      children: [
                        if (auth.can('organization', Permission.read))
                          _buildSubMenuItem(
                            title: AppLocalizations.of(context)
                                    ?.get('organization_profile') ??
                                'Organization Profile',
                            icon: Icons.business,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/organization');
                            },
                          ),
                        if (auth.can('organization',
                            Permission.read)) // Usually same level
                          _buildSubMenuItem(
                            title: AppLocalizations.of(context)
                                    ?.get('organizations_list') ??
                                'Organizations List',
                            icon: Icons.list,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/organizations-list');
                            },
                          ),
                        if (auth.can('stores', Permission.read))
                          _buildSubMenuItem(
                            title: AppLocalizations.of(context)
                                    ?.get('branches_list') ??
                                'Branches List',
                            icon: Icons.store_mall_directory,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/branches');
                            },
                          ),
                      ],
                    ),

                  // Suppliers Management
                  if ((auth.can('vendors', Permission.read) ||
                          auth.can('orders', Permission.read)) &&
                      (selectedOrg == null || inventoryAccess.value == true))
                    _buildExpandableMenuItem(
                      icon: Icons.local_shipping,
                      title: AppLocalizations.of(context)
                              ?.get('suppliers_management') ??
                          'Suppliers Management',
                      isExpanded: _suppliersExpanded,
                      onTap: () {
                        setState(
                            () => _suppliersExpanded = !_suppliersExpanded);
                      },
                      children: [
                        if (auth.can('vendors', Permission.read))
                          _buildSubMenuItem(
                            title:
                                AppLocalizations.of(context)?.get('vendors') ??
                                    'Vendors',
                            icon: Icons.store,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/vendors');
                            },
                          ),
                        if (auth.can('vendors', Permission.read))
                          _buildSubMenuItem(
                            title: 'Suppliers',
                            icon: Icons.inventory,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/vendors',
                                  extra: {'showSuppliersOnly': true});
                            },
                          ),
                        if (auth.can('orders', Permission.read))
                          _buildSubMenuItem(
                            title: AppLocalizations.of(context)
                                    ?.get('purchase_orders') ??
                                'Orders',
                            icon: Icons.shopping_cart_checkout,
                            onTap: () {
                              _closeDrawerIfOpen(context);
                              context.push('/orders',
                                  extra: {'initialFilterType': 'PO'});
                            },
                          ),
                      ],
                    ),

                  const Divider(),

                  if (auth.can('settings', Permission.read))
                    _buildMenuItem(
                      icon: Icons.settings_outlined,
                      title: AppLocalizations.of(context)?.get('settings') ??
                          'Settings',
                      onTap: () {
                        _closeDrawerIfOpen(context);
                        context.push('/settings');
                      },
                    ),
                ],
              ),
            ),
          ),

          // Footer (Pinned at bottom)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white12
                    : Colors.grey.shade300,
              )),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/triangletech_logo.jpg',
                  height: 50,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 4),
                Text(
                  // ignore: prefer_interpolation_to_compose_strings
                  (AppLocalizations.of(context)?.get('version') ?? 'Version') +
                      ' $appVersion • Build $buildTime',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                            AppLocalizations.of(context)?.get('whats_new') ??
                                "What's New"),
                        content: const SingleChildScrollView(
                          child: Text(whatsNew),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                                AppLocalizations.of(context)?.get('close') ??
                                    'Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      AppLocalizations.of(context)?.get('whats_new') ??
                          "What's New?",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 24),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16),
      ),
      onTap: onTap,
    );
  }

  Widget _buildExpandableMenuItem({
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, size: 24),
          title: Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
          trailing: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.keyboard_arrow_down),
          ),
          onTap: onTap,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(children: children),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildSubMenuItem({
    required String title,
    required VoidCallback onTap,
    IconData? icon,
    double leftPadding = 32,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: leftPadding, right: 16),
      leading: icon != null
          ? Icon(icon,
              size: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey.shade700)
          : null,
      title: Text(
        title,
        style: TextStyle(
          fontSize: leftPadding > 32 ? 13 : 14,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildExpandableSubMenuItem({
    required IconData icon,
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.only(left: 32, right: 16),
          leading: Icon(icon,
              size: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.grey.shade700),
          title: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          trailing: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.keyboard_arrow_down, size: 20),
          ),
          onTap: onTap,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(children: children),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
