import 'package:flutter_test/flutter_test.dart';
import 'package:ordermate/features/products/data/repositories/recipe_sale_local_repository.dart';
import 'package:ordermate/features/products/domain/entities/recipe_sale.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('RecipeSaleLocalRepository', () {
    late RecipeSaleLocalRepository repo;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      repo = RecipeSaleLocalRepository();
    });

    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('local_recipe_sales', where: 'organization_id = ?', whereArgs: [95001]);
      await db.delete('local_recipe_sale_items', where: 'recipe_sale_id IN (SELECT id FROM local_recipe_sales WHERE organization_id = 95001)');
    });

    test('saveRecipeSale persists header and items locally', () async {
      final sale = RecipeSale(
        id: 'sale-1',
        organizationId: 95001,
        storeId: 1,
        saleDate: DateTime(2026, 9, 14),
        totalAmount: 100.0,
        totalCost: 60.0,
        totalProfit: 40.0,
      );

      final items = [
        const RecipeSaleItem(
          id: 'item-1',
          recipeSaleId: 'sale-1',
          productId: 'p1',
          quantitySold: 10.0,
          rate: 10.0,
          amount: 100.0,
          cost: 60.0,
          profit: 40.0,
          wastageQty: 1.0,
        ),
      ];

      await repo.saveRecipeSale(sale, items, isSynced: false);

      final localSales = await repo.getLocalRecipeSales(organizationId: 95001, storeId: 1);
      expect(localSales.length, 1);
      expect(localSales.first.id, 'sale-1');
      expect(localSales.first.totalAmount, 100.0);

      final localItems = await repo.getLocalRecipeSaleItems('sale-1');
      expect(localItems.length, 1);
      expect(localItems.first.productId, 'p1');
      expect(localItems.first.wastageQty, 1.0);
    });

    test('getUnsyncedRecipeSales returns only dirty records', () async {
      final sale1 = RecipeSale(
        id: 'sale-unsynced',
        organizationId: 95001,
        storeId: 1,
        saleDate: DateTime(2026, 9, 14),
      );
      final sale2 = RecipeSale(
        id: 'sale-synced',
        organizationId: 95001,
        storeId: 1,
        saleDate: DateTime(2026, 9, 14),
      );

      await repo.saveRecipeSale(sale1, const [], isSynced: false);
      await repo.saveRecipeSale(sale2, const [], isSynced: true);
      await repo.markRecipeSaleAsSynced('sale-unsynced');

      final unsynced = await repo.getUnsyncedRecipeSales(organizationId: 95001);
      expect(unsynced.isEmpty, isTrue);
    });
  });
}
