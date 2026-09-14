import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/products/domain/entities/product.dart';
import 'package:sqflite/sqflite.dart';

class ProductLocalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> cacheProducts(List<Product> products) async {
    final db = await _dbHelper.database;

    // Get list of unsynced products (dirty) to avoid overwriting them with server data
    // effectively giving local changes priority until they are pushed.
    final List<Map<String, dynamic>> unsyncedMaps = await db.query(
      'local_products',
      columns: ['id'],
      where: 'is_synced = 0',
    );
    final Set<String> unsyncedIds =
        unsyncedMaps.map((m) => m['id'] as String).toSet();

    final batch = db.batch();

    for (var p in products) {
      // If local copy is dirty, don't overwrite it with server data
      if (unsyncedIds.contains(p.id)) {
        continue;
      }

      batch.insert(
          'local_products',
          {
            'id': p.id,
            'name': p.name,
            'sku': p.sku,
            'rate': p.rate,
            'cost': p.cost,
            'brand_id': p.brandId?.toString(),
            'category_id': p.categoryId?.toString(),
            'product_type_id': p.productTypeId?.toString(),
            'business_partner_id': p.businessPartnerId,
            'organization_id': p.organizationId,
            'uom_id': p.uomId,
            'uom_symbol': p.uomSymbol,
            'base_quantity': p.baseQuantity,
            'stock_qty': p.stockQty,
            'is_active': p.isActive ? 1 : 0,
            'updated_at': p.updatedAt.millisecondsSinceEpoch,
            'limit_price': p.limitPrice,
            'limtprice': p.limitPrice,
            'inventory_gl_id': p.inventoryGlId,
            'cogs_gl_id': p.cogsGlId,
            'cogs_id': p.cogsGlId,
            'revenue_gl_id': p.revenueGlId,
            'revnue_id': p.revenueGlId,
            'defult_discount_percnt': p.defaultDiscountPercent,
            'defult_discount_percnt_limit': p.defaultDiscountPercentLimit,
            'sales_discount_id': p.salesDiscountGlId,
            'is_recipe': p.isRecipe ? 1 : 0,
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// SECURITY (OFF-01): `organizationId` is `required` (though still
  /// nullable) so every caller must explicitly state its tenant context.
  /// If none is available, this returns an empty list rather than
  /// removing the organization predicate -- "no tenant context" must
  /// never mean "all tenants". The predicate is always a strict,
  /// parameterized equality match.
  Future<List<Product>> getLocalProducts(
      {required int? organizationId, int? storeId}) async {
    if (organizationId == null) {
      return [];
    }

    final db = await _dbHelper.database;
    String sql = '''
      SELECT
        p.*,
        b.name as brand_name,
        c.name as category_name,
        pt.name as type_name,
        bp.name as partner_name,
        u.unit_name as uom_name,
        COALESCE(p.uom_symbol, u.unit_symbol) as uom_display_symbol
      FROM local_products p
      LEFT JOIN local_brands b ON CAST(p.brand_id AS INTEGER) = b.id
      LEFT JOIN local_categories c ON CAST(p.category_id AS INTEGER) = c.id
      LEFT JOIN local_product_types pt ON CAST(p.product_type_id AS INTEGER) = pt.id
      LEFT JOIN local_businesspartners bp ON p.business_partner_id = bp.id
      LEFT JOIN local_units_of_measure u ON p.uom_id = u.id
      WHERE p.organization_id = ?
    ''';

    List<dynamic> args = [organizationId];

    sql += ' ORDER BY p.name ASC';

    final maps = await db.rawQuery(sql, args);

    return maps.map((map) {
      return _mapToProduct(map);
    }).toList();
  }

  Future<List<Product>> getUnsyncedProducts(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String sql = '''
      SELECT 
        p.*,
        b.name as brand_name,
        c.name as category_name,
        pt.name as type_name,
        bp.name as partner_name,
        u.unit_name as uom_name,
        COALESCE(p.uom_symbol, u.unit_symbol) as uom_display_symbol
      FROM local_products p
      LEFT JOIN local_brands b ON CAST(p.brand_id AS INTEGER) = b.id
      LEFT JOIN local_categories c ON CAST(p.category_id AS INTEGER) = c.id
      LEFT JOIN local_product_types pt ON CAST(p.product_type_id AS INTEGER) = pt.id
      LEFT JOIN local_businesspartners bp ON p.business_partner_id = bp.id
      LEFT JOIN local_units_of_measure u ON p.uom_id = u.id
      WHERE p.is_synced = 0
    ''';

    List<dynamic> args = [];
    if (organizationId != null) {
      sql += ' AND p.organization_id = ?';
      args.add(organizationId);
    }

    final maps = await db.rawQuery(sql, args);
    return maps.map((map) => _mapToProduct(map)).toList();
  }

  Future<void> markProductAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update('local_products', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addProduct(Product p) async {
    final db = await _dbHelper.database;
    await db.insert(
        'local_products',
        {
          'id': p.id,
          'name': p.name,
          'sku': p.sku,
          'rate': p.rate,
          'cost': p.cost,
          'brand_id': p.brandId?.toString(),
          'category_id': p.categoryId?.toString(),
          'product_type_id': p.productTypeId?.toString(),
          'business_partner_id': p.businessPartnerId,
          'organization_id': p.organizationId,
          'uom_id': p.uomId,
          'uom_symbol': p.uomSymbol,
          'base_quantity': p.baseQuantity,
          'stock_qty': p.stockQty,
          'is_active': p.isActive ? 1 : 0,
          'updated_at': p.updatedAt.millisecondsSinceEpoch,
          'limit_price': p.limitPrice,
          'limtprice': p.limitPrice,
          'inventory_gl_id': p.inventoryGlId,
          'cogs_gl_id': p.cogsGlId,
          'cogs_id': p.cogsGlId,
          'revenue_gl_id': p.revenueGlId,
          'revnue_id': p.revenueGlId,
          'defult_discount_percnt': p.defaultDiscountPercent,
          'defult_discount_percnt_limit': p.defaultDiscountPercentLimit,
          'sales_discount_id': p.salesDiscountGlId,
          'is_recipe': p.isRecipe ? 1 : 0,
          'is_synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateProduct(Product p) async {
    final db = await _dbHelper.database;
    await db.update(
        'local_products',
        {
          'name': p.name,
          'sku': p.sku,
          'rate': p.rate,
          'cost': p.cost,
          'brand_id': p.brandId?.toString(),
          'category_id': p.categoryId?.toString(),
          'product_type_id': p.productTypeId?.toString(),
          'business_partner_id': p.businessPartnerId,
          'organization_id': p.organizationId,
          'uom_id': p.uomId,
          'uom_symbol': p.uomSymbol,
          'base_quantity': p.baseQuantity,
          'updated_at': p.updatedAt.millisecondsSinceEpoch,
          'limit_price': p.limitPrice,
          'limtprice': p.limitPrice,
          'stock_qty': p.stockQty,
          'inventory_gl_id': p.inventoryGlId,
          'cogs_gl_id': p.cogsGlId,
          'cogs_id': p.cogsGlId,
          'revenue_gl_id': p.revenueGlId,
          'revnue_id': p.revenueGlId,
          'defult_discount_percnt': p.defaultDiscountPercent,
          'defult_discount_percnt_limit': p.defaultDiscountPercentLimit,
          'sales_discount_id': p.salesDiscountGlId,
          'is_recipe': p.isRecipe ? 1 : 0,
          'is_synced': 0,
        },
        where: 'id = ?',
        whereArgs: [p.id]);
  }

  Future<void> deleteProduct(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Record the deletion for sync
      await txn.insert('local_deleted_records', {
        'entity_table': 'local_products',
        'entity_id': id,
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
      });

      // 2. Perform the local delete
      await txn.delete(
        'local_products',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Product _mapToProduct(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      sku: map['sku'] as String? ?? '',
      rate: map['rate'] as double? ?? 0.0,
      cost: map['cost'] as double? ?? 0.0,
      brandId: int.tryParse(map['brand_id'] as String? ?? ''),
      categoryId: int.tryParse(map['category_id'] as String? ?? ''),
      productTypeId: int.tryParse(map['product_type_id'] as String? ?? ''),
      businessPartnerId: map['business_partner_id'] as String?,
      isActive: map['is_active'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      description: null,
      // Map names from JOIN
      brandName: map['brand_name'] as String?,
      categoryName: map['category_name'] as String?,
      productTypeName: map['type_name'] as String?,
      businessPartnerName: map['partner_name'] as String?,
      uomId: map['uom_id'] as int?,
      uomSymbol: map['uom_display_symbol'] as String?,
      baseQuantity: (map['base_quantity'] as num?)?.toDouble() ?? 1.0,
      storeId: (map['store_id'] as int?) ?? 0,
      organizationId: (map['organization_id'] as int?) ?? 0,
      limitPrice: (map['limit_price'] as num? ?? map['limtprice'] as num?)
              ?.toDouble() ??
          0.0,
      stockQty: (map['stock_qty'] as num?)?.toDouble() ?? 0.0,
      inventoryGlId: map['inventory_gl_id'] as String?,
      cogsGlId: (map['cogs_gl_id'] as String?) ?? (map['cogs_id'] as String?),
      revenueGlId:
          (map['revenue_gl_id'] as String?) ?? (map['revnue_id'] as String?),
      defaultDiscountPercent:
          (map['defult_discount_percnt'] as num?)?.toDouble() ?? 0.0,
      defaultDiscountPercentLimit:
          (map['defult_discount_percnt_limit'] as num?)?.toDouble() ?? 0.0,
      salesDiscountGlId: (map['sales_discount_id'] as String?) ??
          (map['sales_discount_gl_id'] as String?),
      isRecipe: (map['is_recipe'] as int?) == 1,
    );
  }
}
