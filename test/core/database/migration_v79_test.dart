import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('DatabaseHelper v79 migration', () {
    test('creates recipe tables on upgrade from v78', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final helper = DatabaseHelper.instance;
      final db = await helper.database;

      final tables = await db.query(
        "sqlite_master",
        where: "type = 'table' AND (name LIKE 'local_recipe%' OR name = 'local_product_recipes')",
      );

      final tableNames = tables.map((t) => t['name'] as String).toSet();
      expect(tableNames, containsAll(['local_product_recipes', 'local_recipe_sales', 'local_recipe_sale_items']));

      final indexes = await db.query(
        "sqlite_master",
        where: "type = 'index' AND name LIKE 'idx_local_recipe%'",
      );
      final indexNames = indexes.map((t) => t['name'] as String).toSet();
      expect(indexNames, containsAll(['idx_local_recipe_sales_org_date', 'idx_local_recipe_sale_items_sale']));
    });
  });
}
