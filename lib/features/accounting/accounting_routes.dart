import 'package:flutter/material.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/router/app_route_model.dart';
import 'package:ordermate/core/router/route_names.dart';

import 'package:ordermate/features/accounting/presentation/screens/chart_of_accounts_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/payment_terms_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/bank_cash_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/voucher_prefixes_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/transactions_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/accounting_menu_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/bank_cash_form_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/payment_term_form_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/voucher_prefix_form_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/chart_of_account_form_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/account_types_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/account_type_form_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/account_categories_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/account_category_form_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/financial_sessions_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/financial_session_form_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/gl_setup_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/cash_flow_screen.dart';
import 'package:ordermate/features/accounting/presentation/screens/receipt_screen.dart';
import 'package:ordermate/features/accounting/domain/entities/invoice.dart';

final List<AppRoute> accountingRoutes = [
  AppRoute(
      path: '/accounting',
      title: 'Accounting',
      routeName: RouteNames.accounting,
      module: 'accounting',
      icon: Icons.account_balance,
      roles: [UserRole.admin, UserRole.staff],
      builder: (_, __) => const AccountingMenuScreen(),
      children: [
        AppRoute(
            path: 'transactions',
            title: 'Transactions',
            routeName: RouteNames.transactions,
            module: 'accounting',
            roles: [UserRole.admin, UserRole.staff],
            builder: (_, state) {
              final onlyBankCash =
                  state.uri.queryParameters['onlyBankCash'] == 'true';
              final onlyCustomers =
                  state.uri.queryParameters['onlyCustomers'] == 'true';
              return TransactionsScreen(
                onlyBankCash: onlyBankCash,
                onlyCustomers: onlyCustomers,
              );
            }),
        AppRoute(
            path: 'coa',
            title: 'Chart of Accounts',
            routeName: RouteNames.coa,
            module: 'accounting',
            roles: [UserRole.admin, UserRole.staff],
            builder: (_, __) => const ChartOfAccountsScreen(),
            children: [
              AppRoute(
                  path: 'create',
                  title: 'Create Account',
                  routeName: RouteNames.coaCreate,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, __) => const ChartOfAccountFormScreen()),
              AppRoute(
                  path: 'edit/:id',
                  title: 'Edit Account',
                  routeName: RouteNames.coaEdit,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, state) => ChartOfAccountFormScreen(
                      accountId: state.pathParameters['id'])),
            ]),
        AppRoute(
            path: 'gl-setup',
            title: 'GL Setup',
            routeName: RouteNames.glSetup,
            module: 'accounting',
            roles: [UserRole.admin, UserRole.staff],
            builder: (_, __) => const GLSetupScreen()),
        AppRoute(
            path: 'cash-flow',
            title: 'Cash Flow',
            routeName: RouteNames.cashFlow,
            module: 'accounting',
            roles: [UserRole.admin, UserRole.staff],
            builder: (_, __) => const CashFlowScreen()),
        AppRoute(
            path: 'bank-cash',
            title: 'Bank & Cash',
            routeName: RouteNames.bankCash,
            module: 'accounting',
            roles: [UserRole.admin, UserRole.staff],
            builder: (_, __) => const BankCashScreen(),
            children: [
              AppRoute(
                  path: 'create',
                  title: 'Create',
                  routeName: RouteNames.bankCashCreate,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, __) => const BankCashFormScreen()),
              AppRoute(
                  path: 'edit/:id',
                  title: 'Edit',
                  routeName: RouteNames.bankCashEdit,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, state) => BankCashFormScreen(
                      bankCashId: state.pathParameters['id'])),
            ]),
        AppRoute(
            path: 'account-types',
            title: 'Account Types',
            routeName: RouteNames.accountTypes,
            module: 'accounting',
            roles: [UserRole.admin, UserRole.staff],
            builder: (_, __) => const AccountTypesScreen(),
            children: [
              AppRoute(
                  path: 'create',
                  title: 'Create',
                  routeName: RouteNames.accountTypeCreate,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, __) => const AccountTypeFormScreen()),
              AppRoute(
                  path: 'edit/:id',
                  title: 'Edit',
                  routeName: RouteNames.accountTypeEdit,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, state) => AccountTypeFormScreen(
                      accountTypeId:
                          int.tryParse(state.pathParameters['id'] ?? ''))),
            ]),
        AppRoute(
            path: 'account-categories',
            title: 'Account Categories',
            routeName: RouteNames.accountCategories,
            module: 'accounting',
            roles: [UserRole.admin, UserRole.staff],
            builder: (_, __) => const AccountCategoriesScreen(),
            children: [
              AppRoute(
                  path: 'create',
                  title: 'Create',
                  routeName: RouteNames.accountCategoryCreate,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, __) => const AccountCategoryFormScreen()),
              AppRoute(
                  path: 'edit/:id',
                  title: 'Edit',
                  routeName: RouteNames.accountCategoryEdit,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, state) => AccountCategoryFormScreen(
                      accountCategoryId:
                          int.tryParse(state.pathParameters['id'] ?? ''))),
            ]),
        AppRoute(
            path: 'payment-terms',
            title: 'Payment Terms',
            routeName: RouteNames.paymentTerms,
            module: 'customers',
            roles: [UserRole.admin, UserRole.staff],
            builder: (_, __) => const PaymentTermsScreen(),
            children: [
              AppRoute(
                  path: 'create',
                  title: 'Create',
                  routeName: RouteNames.paymentTermCreate,
                  module: 'customers',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, __) => const PaymentTermFormScreen()),
              AppRoute(
                  path: 'edit/:id',
                  title: 'Edit',
                  routeName: RouteNames.paymentTermEdit,
                  module: 'customers',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, state) => PaymentTermFormScreen(
                      paymentTermId:
                          int.tryParse(state.pathParameters['id'] ?? ''))),
            ]),
        AppRoute(
            path: 'voucher-prefixes',
            title: 'Voucher Prefixes',
            routeName: RouteNames.voucherPrefixes,
            module: 'accounting',
            roles: [UserRole.admin, UserRole.staff],
            builder: (_, __) => const VoucherPrefixesScreen(),
            children: [
              AppRoute(
                  path: 'create',
                  title: 'Create',
                  routeName: RouteNames.voucherPrefixCreate,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, __) => const VoucherPrefixFormScreen()),
              AppRoute(
                  path: 'edit/:id',
                  title: 'Edit',
                  routeName: RouteNames.voucherPrefixEdit,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, state) => VoucherPrefixFormScreen(
                      prefixId:
                          int.tryParse(state.pathParameters['id'] ?? ''))),
            ]),
        AppRoute(
            path: 'financial-sessions',
            title: 'Financial Sessions',
            routeName: RouteNames.financialSessions,
            module: 'accounting',
            roles: [UserRole.admin, UserRole.staff],
            builder: (_, __) => const FinancialSessionsScreen(),
            children: [
              AppRoute(
                  path: 'create',
                  title: 'Create',
                  routeName: RouteNames.financialSessionCreate,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, __) => const FinancialSessionFormScreen()),
              AppRoute(
                  path: 'edit/:id',
                  title: 'Edit',
                  routeName: RouteNames.financialSessionEdit,
                  module: 'accounting',
                  showInMenu: false,
                  roles: [UserRole.admin, UserRole.staff],
                  builder: (_, state) => FinancialSessionFormScreen(
                      sYear: int.tryParse(state.pathParameters['id'] ?? ''))),
            ]),
        AppRoute(
            path: 'receipt',
            title: 'Receipt',
            routeName: RouteNames.receipt,
            module: 'accounting',
            showInMenu: false,
            roles: [UserRole.admin, UserRole.staff],
            builder: (_, state) {
              final invoice = state.extra as Invoice;
              return ReceiptScreen(invoice: invoice);
            }),
      ]),
];
