import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/products/domain/entities/product_recipe.dart';
import 'package:sqflite/sqflite.dart';

class ProductRecipeLocalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> cacheRecipes(List<ProductRecipe> recipes) async {
    final db = await _dbHelper.database;
    final unsyncedMaps = await db.query(
      'local_product_recipes',
      columns: ['id'],
      where: 'is_synced = 0',
    );
    final Set<String> unsyncedIds =
        unsyncedMaps.map((m) => m['id'] as String).toSet();

    final batch = db.batch();
    for (var r in recipes) {
      if (unsyncedIds.contains(r.id)) continue;
      batch.insert(
        'local_product_recipes',
        {
          'id': r.id,
          'product_id': r.productId,
          'component_product_id': r.componentProductId,
          'quantity': r.quantity,
          'uom_id': r.uomId,
          'wastage_percent': r.wastagePercent,
          'organization_id': r.organizationId,
          'created_at': r.createdAt?.millisecondsSinceEpoch,
          'updated_at': r.updatedAt?.millisecondsSinceEpoch,
          'is_synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ProductRecipe>> getLocalRecipes(
      {required int? organizationId}) async {
    if (organizationId == null) return [];
    final db = await _dbHelper.database;
    final maps = await db.query(
      'local_product_recipes',
      where: 'organization_id = ?',
      whereArgs: [organizationId],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) {
      return ProductRecipe(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        componentProductId: map['component_product_id'] as String,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        uomId: (map['uom_id'] as num?)?.toInt() ?? 0,
        wastagePercent: (map['wastage_percent'] as num?)?.toDouble() ?? 0.0,
        organizationId: (map['organization_id'] as num?)?.toInt() ?? 0,
        createdAt: map['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
            : null,
      );
    }).toList();
  }

  Future<List<ProductRecipe>> getUnsyncedRecipes({int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND organization_id = ?';
      args.add(organizationId);
    }
    final maps = await db.query('local_product_recipes',
        where: where, whereArgs: args);
    return maps.map((map) {
      return ProductRecipe(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        componentProductId: map['component_product_id'] as String,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
        uomId: (map['uom_id'] as num?)?.toInt() ?? 0,
        wastagePercent: (map['wastage_percent'] as num?)?.toDouble() ?? 0.0,
        organizationId: (map['organization_id'] as num?)?.toInt() ?? 0,
        createdAt: map['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
            : null,
      );
    }).toList();
  }

  Future<void> markRecipeAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update('local_product_recipes', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addRecipe(ProductRecipe recipe) async {
    final db = await _dbHelper.database;
    await db.insert(
      'local_product_recipes',
      {
        'id': recipe.id,
        'product_id': recipe.productId,
        'component_product_id': recipe.componentProductId,
        'quantity': recipe.quantity,
        'uom_id': recipe.uomId,
        'wastage_percent': recipe.wastagePercent,
        'organization_id': recipe.organizationId,
        'created_at': recipe.createdAt?.millisecondsSinceEpoch,
        'updated_at': recipe.updatedAt?.millisecondsSinceEpoch,
        'is_synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateRecipe(ProductRecipe recipe) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_product_recipes',
      {
        'product_id': recipe.productId,
        'component_product_id': recipe.componentProductId,
        'quantity': recipe.quantity,
        'uom_id': recipe.uomId,
        'wastage_percent': recipe.wastagePercent,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [recipe.id],
    );
  }

  Future<void> deleteRecipe(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'local_product_recipes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
