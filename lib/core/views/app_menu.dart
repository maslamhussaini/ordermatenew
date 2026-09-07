import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/router/app_routes_config.dart';
import 'package:ordermate/features/entitlement/presentation/providers/entitlement_providers.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class AppMenu extends ConsumerWidget {
  const AppMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    final orgState = ref.watch(organizationProvider);
    final selectedOrg = orgState.selectedOrganization;
 
    // Filter by Role AND DB-Driven Permission (Read Access) AND Org Module Settings
    final menuItems = appRoutes.where((r) {
      // 0. Special Admin Config Check.
      // Phase 3B-4A-R: sourced from auth.role (itself now backed by the
      // is_platform_admin() DB check in auth_provider.dart), not a
      // second independent hardcoded email comparison.
      if (r.path == '/module-config') {
        return auth.role == UserRole.superUser;
      }

      // 1. Basic role/visibility/permission checks
      final isBasicAllowed = r.roles.contains(auth.role) &&
          r.showInMenu &&
          auth.can(r.module, Permission.read);
      if (!isBasicAllowed) return false;
 
      // 2. Commercial entitlement filtering.
      if (selectedOrg == null) return true; // Show all if no org yet (e.g. superuser)

      // Catalog-backed routes go through the same EffectiveAccessService
      // path the router guard uses (formAccessProvider) -- one entitlement
      // decision, never a second independent implementation. Defaults to
      // hidden while the async lookup is in flight or on error, never
      // fail-open. Non-catalog routes keep the existing shared
      // Organization.isModuleEnabled() check, unchanged.
      if (r.formId != null) {
        final access = ref.watch(formAccessProvider(r.formId!));
        return access.maybeWhen(data: (entitled) => entitled, orElse: () => false);
      }

      return selectedOrg.isModuleEnabled(r.module);
    }).toList();

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text('Role: ${auth.role.name.toUpperCase()}'),
            accountEmail: Text(auth.isLoggedIn ? 'Online' : 'Offline'),
            currentAccountPicture:
                const CircleAvatar(child: Icon(Icons.person)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final route = menuItems[index];
                return ListTile(
                  leading: Icon(route.icon ?? Icons.circle_outlined),
                  title: Text(route.title),
                  onTap: () {
                    if (route.routeName != null) {
                      context.goNamed(route.routeName!);
                    } else {
                      context.go(route.path);
                    }
                    if (Scaffold.of(context).hasDrawer &&
                        Scaffold.of(context).isDrawerOpen) {
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              ref.read(authProvider.notifier).logout();
              ref.read(organizationProvider.notifier).clearSelection();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
