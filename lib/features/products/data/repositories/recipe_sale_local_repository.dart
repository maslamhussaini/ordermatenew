import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/products/domain/entities/recipe_sale.dart';
import 'package:sqflite/sqflite.dart';

class RecipeSaleLocalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> cacheRecipeSales(List<RecipeSale> sales) async {
    final db = await _dbHelper.database;
    final unsyncedMaps = await db.query(
      'local_recipe_sales',
      columns: ['id'],
      where: 'is_synced = 0',
    );
    final Set<String> unsyncedIds =
        unsyncedMaps.map((m) => m['id'] as String).toSet();

    final batch = db.batch();
    for (var s in sales) {
      if (unsyncedIds.contains(s.id)) continue;
      batch.insert(
        'local_recipe_sales',
        {
          'id': s.id,
          'organization_id': s.organizationId,
          'store_id': s.storeId,
          'sale_date': s.saleDate.millisecondsSinceEpoch,
          'total_amount': s.totalAmount,
          'total_cost': s.totalCost,
          'total_profit': s.totalProfit,
          'created_by': s.createdBy,
          'created_at': s.createdAt?.millisecondsSinceEpoch,
          'is_synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<RecipeSale>> getLocalRecipeSales(
      {required int? organizationId, int? storeId}) async {
    if (organizationId == null) return [];
    final db = await _dbHelper.database;
    String where = 'organization_id = ?';
    List<dynamic> args = [organizationId];
    if (storeId != null) {
      where += ' AND store_id = ?';
      args.add(storeId);
    }
    final maps = await db.query(
      'local_recipe_sales',
      where: where,
      whereArgs: args,
      orderBy: 'sale_date DESC',
    );
    return maps.map((map) {
      return RecipeSale(
        id: map['id'] as String,
        organizationId: (map['organization_id'] as num?)?.toInt() ?? 0,
        storeId: (map['store_id'] as num?)?.toInt() ?? 0,
        saleDate: DateTime.fromMillisecondsSinceEpoch(map['sale_date'] as int),
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
        totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
        totalProfit: (map['total_profit'] as num?)?.toDouble() ?? 0.0,
        createdBy: map['created_by'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
            : null,
      );
    }).toList();
  }

  Future<List<RecipeSaleItem>> getLocalRecipeSaleItems(String recipeSaleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'local_recipe_sale_items',
      where: 'recipe_sale_id = ?',
      whereArgs: [recipeSaleId],
    );
    return maps.map((map) {
      return RecipeSaleItem(
        id: map['id'] as String,
        recipeSaleId: map['recipe_sale_id'] as String,
        productId: map['product_id'] as String,
        quantitySold: (map['quantity_sold'] as num?)?.toDouble() ?? 0.0,
        rate: (map['rate'] as num?)?.toDouble() ?? 0.0,
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
        profit: (map['profit'] as num?)?.toDouble() ?? 0.0,
        wastageQty: (map['wastage_qty'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  Future<void> saveRecipeSale(RecipeSale sale, List<RecipeSaleItem> items,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    await db.insert(
      'local_recipe_sales',
      {
        'id': sale.id,
        'organization_id': sale.organizationId,
        'store_id': sale.storeId,
        'sale_date': sale.saleDate.millisecondsSinceEpoch,
        'total_amount': sale.totalAmount,
        'total_cost': sale.totalCost,
        'total_profit': sale.totalProfit,
        'created_by': sale.createdBy,
        'created_at': sale.createdAt?.millisecondsSinceEpoch,
        'is_synced': isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final batch = db.batch();
    for (var item in items) {
      batch.insert(
        'local_recipe_sale_items',
        {
          'id': item.id,
          'recipe_sale_id': item.recipeSaleId,
          'product_id': item.productId,
          'quantity_sold': item.quantitySold,
          'rate': item.rate,
          'amount': item.amount,
          'cost': item.cost,
          'profit': item.profit,
          'wastage_qty': item.wastageQty,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<RecipeSale>> getUnsyncedRecipeSales({int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND organization_id = ?';
      args.add(organizationId);
    }
    final maps = await db.query('local_recipe_sales', where: where, whereArgs: args);
    return maps.map((map) {
      return RecipeSale(
        id: map['id'] as String,
        organizationId: (map['organization_id'] as num?)?.toInt() ?? 0,
        storeId: (map['store_id'] as num?)?.toInt() ?? 0,
        saleDate: DateTime.fromMillisecondsSinceEpoch(map['sale_date'] as int),
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
        totalCost: (map['total_cost'] as num?)?.toDouble() ?? 0.0,
        totalProfit: (map['total_profit'] as num?)?.toDouble() ?? 0.0,
        createdBy: map['created_by'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
            : null,
      );
    }).toList();
  }

  Future<void> markRecipeSaleAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update('local_recipe_sales', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }
}
