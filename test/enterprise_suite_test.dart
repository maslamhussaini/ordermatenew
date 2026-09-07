import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/entities/permission_object.dart';
import 'package:ordermate/core/enums/permission.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/core/router/app_router.dart';
import 'package:ordermate/core/views/app_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mocks
class MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(isLoggedIn: false);
  }

  void setPermissions(List<PermissionObject> perms, UserRole role) {
    state = state.copyWith(
      isLoggedIn: true,
      role: role,
      permissions: perms,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Enterprise Permission Suite', () {
    // 1️⃣ Unit Test - Permission Logic
    test('can() returns true only for matching module/action', () {
      const state = AuthState(
        isLoggedIn: true,
        role: UserRole.staff,
        permissions: [
          PermissionObject('customers', Permission.read),
          PermissionObject('orders', Permission.write),
        ],
      );

      // Positive
      expect(state.can('customers', Permission.read), isTrue);
      expect(state.can('orders', Permission.write), isTrue);

      // Negative
      expect(state.can('customers', Permission.write), isFalse);
      expect(state.can('accounting', Permission.read), isFalse);
    });

    // 2️⃣ Widget Test - Menu Hides Restricted Items
    testWidgets('AppMenu hides Accounting for Staff without permissions',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(MockAuthNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AppMenu()),
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(AppMenu));
      final ProviderContainer container = ProviderScope.containerOf(context);

      // Simulate Staff Login
      final MockAuthNotifier notifier =
          container.read(authProvider.notifier) as MockAuthNotifier;
      notifier.setPermissions(
          [const PermissionObject('customers', Permission.read)],
          UserRole.staff);

      await tester.pumpAndSettle();

      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Accounting'), findsNothing);
    });

    // 3️⃣ Router Guard Test
    testWidgets('Router redirects unauthorized access to Dashboard',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(MockAuthNotifier.new),
          ],
          child: const MaterialAppWithRouter(),
        ),
      );

      final BuildContext context =
          tester.element(find.byType(MaterialAppWithRouter));
      final ProviderContainer container = ProviderScope.containerOf(context);
      final GoRouter router = container.read(routerProvider);

      // Setup Auth
      final MockAuthNotifier notifier =
          container.read(authProvider.notifier) as MockAuthNotifier;
      notifier.setPermissions(
          [const PermissionObject('dashboard', Permission.read)],
          UserRole.staff);

      await tester.pumpAndSettle();

      // Attempt Navigation
      router.go('/accounting');
      await tester.pumpAndSettle();

      // Expect Fallback
      expect(router.routerDelegate.currentConfiguration.uri.toString(),
          '/dashboard');
    });
  });
}

class MaterialAppWithRouter extends ConsumerWidget {
  const MaterialAppWithRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      routerConfig: router,
    );
  }
}
