// test/features/module_access/module_catalog_mapping_test.dart
//
// Phase 3B-1 dead-code/model cleanup regression guard.
//
// omtbl_modules (live schema) has no `name` column -- it has `display_name`.
// Module.fromJson previously read json['name'], which is null for every real
// row and would throw once a non-null String was required downstream.
// ModuleAccessRepository.getModules() previously ordered by the nonexistent
// `name` column, which fails at the PostgREST layer before the row ever
// reaches Module.fromJson.
//
// These tests prove:
//   1. Module.fromJson() correctly reads display_name.
//   2. The getModules() query no longer references the nonexistent `name`
//      column for ordering (verified by source inspection, since exercising
//      the real query requires a live Supabase connection -- see note below).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/module_access/domain/entities/module_models.dart';

void main() {
  group('Module.fromJson', () {
    test('reads display_name (the actual live omtbl_modules column)', () {
      final module = Module.fromJson({
        'id': 'sales',
        'display_name': 'Sales',
      });

      expect(module.id, 'sales');
      expect(module.name, 'Sales');
    });

    test('does not silently fall back to a nonexistent name column', () {
      // A row shaped exactly like the live schema (no `name` key at all)
      // must still populate a usable display value.
      final module = Module.fromJson({
        'id': 'inventory',
        'display_name': 'Inventory',
        // no 'name' key present, matching the live omtbl_modules row shape
      });

      expect(module.name, isNot(isNull));
      expect(module.name, 'Inventory');
    });
  });

  group('ModuleAccessRepository.getModules() source guard', () {
    test('orders by display_name, not the nonexistent name column', () {
      final source = File(
        'lib/features/module_access/data/repositories/module_access_repository.dart',
      ).readAsStringSync();

      final getModulesStart = source.indexOf('Future<List<Module>> getModules()');
      expect(getModulesStart, greaterThanOrEqualTo(0),
          reason: 'getModules() method not found in repository source');

      final getModulesEnd = source.indexOf('\n  }', getModulesStart);
      final getModulesBody =
          source.substring(getModulesStart, getModulesEnd == -1 ? source.length : getModulesEnd);

      expect(getModulesBody.contains("order('name'"), isFalse,
          reason: 'getModules() must not order by the nonexistent omtbl_modules.name column');
      expect(getModulesBody.contains("order('display_name'"), isTrue,
          reason: 'getModules() must order by the live omtbl_modules.display_name column');
    });
  });
}

// Note: getModules() itself is not exercised end-to-end here because it
// calls the real Supabase client (SupabaseConfig.client), which requires a
// live network/database connection this test suite does not have. The
// source-inspection test above is a deliberate, narrow substitute that
// verifies the exact regression without fabricating database behavior.
