import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/app.dart';

void main() {
  testWidgets('App builds verification', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // OrderMateApp requires Riverpod's ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: OrderMateApp(),
      ),
    );

    // Verify that the app builds (finds the MaterialApp)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
