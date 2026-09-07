import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/core/enums/user_role.dart';
import 'package:ordermate/core/router/app_router.dart';
import 'package:ordermate/core/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.testIsLoggedIn = true;
    AuthService.testRole = UserRole.admin;
  });

  testWidgets('Admin can access Accounting', (tester) async {
    AuthService.testRole = UserRole.admin;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialAppWithRouter(),
      ),
    );

    final context = tester.element(find.byType(MaterialAppWithRouter));
    final container = ProviderScope.containerOf(context);
    // Explicit cast to avoid type inference issues in test environment
    final router = container.read(routerProvider);

    router.go('/accounting');
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/accounting');
  });

  testWidgets('Staff CANNOT access Accounting (Redirects to Dashboard)',
      (tester) async {
    AuthService.testRole = UserRole.staff;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialAppWithRouter(),
      ),
    );

    final context = tester.element(find.byType(MaterialAppWithRouter));
    final container = ProviderScope.containerOf(context);
    // Explicit cast
    final router = container.read(routerProvider);

    router.go('/accounting');
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/dashboard');
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
