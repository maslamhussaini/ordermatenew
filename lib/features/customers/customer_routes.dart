import 'package:flutter/material.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/router/app_route_model.dart';
import 'package:ordermate/core/router/route_names.dart';

import 'package:ordermate/features/customers/presentation/screens/customer_form_screen.dart';
import 'package:ordermate/features/customers/presentation/screens/customer_list_screen.dart';
import 'package:ordermate/features/customers/presentation/screens/customer_invoices_screen.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';

final List<AppRoute> customerRoutes = [
  AppRoute(
    path: '/customers',
    title: 'Customers',
    routeName: RouteNames.customers,
    module: 'customers',
    icon: Icons.people,
    roles: [UserRole.admin, UserRole.staff],
    formId: 3, // FRM_CUSTOMERS (live-verified omtbl_app_forms.id)
    builder: (_, __) => const CustomerListScreen(),
    children: [
      AppRoute(
        path: 'create',
        title: 'Create Customer',
        routeName: RouteNames.customerCreate,
        module: 'customers',
        showInMenu: false,
        roles: [UserRole.admin, UserRole.staff],
        builder: (_, __) => const CustomerFormScreen(),
      ),
      AppRoute(
        path: 'edit/:id',
        title: 'Edit Customer',
        routeName: RouteNames.customerEdit,
        module: 'customers',
        showInMenu: false,
        roles: [UserRole.admin, UserRole.staff],
        builder: (_, state) =>
            CustomerFormScreen(customerId: state.pathParameters['id']!),
      ),
      AppRoute(
        path: ':id/invoices',
        title: 'Customer Invoices',
        routeName: RouteNames.customerInvoices,
        module: 'customers',
        showInMenu: false,
        roles: [UserRole.admin, UserRole.staff],
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return CustomerInvoicesScreen(
              customer: extra['customer'] as BusinessPartner);
        },
      ),
    ],
  ),
];
