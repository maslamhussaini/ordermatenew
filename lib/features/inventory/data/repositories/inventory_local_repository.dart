import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/inventory/domain/entities/brand.dart';
import 'package:ordermate/features/inventory/domain/entities/product_category.dart';
import 'package:ordermate/features/inventory/domain/entities/product_type.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_of_measure.dart';
import 'package:ordermate/features/inventory/domain/entities/unit_conversion.dart';
import 'package:sqflite/sqflite.dart';

class InventoryLocalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // --- Brands ---
  Future<void> cacheBrands(List<Brand> brands) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // Protect unsynced brands
    final List<Map<String, dynamic>> unsyncedMaps = await db.query(
      'local_brands',
      columns: ['id'],
      where: 'is_synced = 0',
    );
    final Set<int> unsyncedIds =
        unsyncedMaps.map((m) => m['id'] as int).toSet();

    for (var item in brands) {
      if (unsyncedIds.contains(item.id)) continue;

      batch.insert(
          'local_brands',
          {
            'id': item.id,
            'name': item.name,
            'status': item.status,
            'organization_id': item.organizationId,
            'created_at': item.createdAt.millisecondsSinceEpoch,
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// SECURITY (OFF-01): `organizationId` is `required` (still nullable)
  /// so no caller can silently omit tenant context; no organization id
  /// means no data, never an unfiltered read. Strict equality only --
  /// neither `organization_id = 0` nor `IS NULL` may act as a wildcard
  /// match for every organization (this was the most permissive variant
  /// found across the whole codebase in the OFF-01 verification).
  Future<List<Brand>> getLocalBrands({required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    String where = 'status = 1 AND organization_id = ?';
    List<dynamic> args = [organizationId];

    final maps = await db.query('local_brands',
        where: where, whereArgs: args, orderBy: 'name ASC');

    return maps.map((map) {
      return Brand(
        id: map['id'] as int,
        name: map['name'] as String,
        status: map['status'] as int,
        organizationId: (map['organization_id'] as int?) ?? 0,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        productCount: 0, // Not stored locally
      );
    }).toList();
  }

  Future<int> saveBrand(Brand item, {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = {
      'name': item.name,
      'status': item.status,
      'organization_id': item.organizationId,
      'created_at': item.createdAt.millisecondsSinceEpoch,
      'is_synced': isSynced ? 1 : 0,
    };
    if (item.id != 0) {
      map['id'] = item.id;
    }

    final id = await db.insert('local_brands', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<List<Brand>> getUnsyncedBrands({int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];

    if (organizationId != null) {
      where +=
          ' AND (organization_id = ? OR organization_id = 0 OR organization_id IS NULL)';
      args.add(organizationId);
    }

    final maps = await db.query('local_brands', where: where, whereArgs: args);
    return maps
        .map((map) => Brand(
              id: map['id'] as int,
              name: map['name'] as String,
              status: map['status'] as int,
              organizationId: (map['organization_id'] as int?) ?? 0,
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
            ))
        .toList();
  }

  Future<void> markBrandAsSynced(int id) async {
    final db = await _dbHelper.database;
    await db.update('local_brands', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // --- Categories ---
  Future<void> cacheCategories(List<ProductCategory> items) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // Protect unsynced categories
    final List<Map<String, dynamic>> unsyncedMaps = await db.query(
      'local_categories',
      columns: ['id'],
      where: 'is_synced = 0',
    );
    final Set<int> unsyncedIds =
        unsyncedMaps.map((m) => m['id'] as int).toSet();

    for (var item in items) {
      if (unsyncedIds.contains(item.id)) continue;

      batch.insert(
          'local_categories',
          {
            'id': item.id,
            'name': item.name,
            'status': item.status,
            'organization_id': item.organizationId,
            'created_at': item.createdAt.millisecondsSinceEpoch,
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// SECURITY (OFF-01): see getLocalBrands' doc comment -- same fix shape.
  Future<List<ProductCategory>> getLocalCategories(
      {required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    String where = 'status = 1 AND organization_id = ?';
    List<dynamic> args = [organizationId];

    final maps = await db.query('local_categories',
        where: where, whereArgs: args, orderBy: 'name ASC');

    return maps.map((map) {
      return ProductCategory(
        id: map['id'] as int,
        name: map['name'] as String,
        status: map['status'] as int,
        organizationId: (map['organization_id'] as int?) ?? 0,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        productCount: 0,
      );
    }).toList();
  }

  Future<int> saveCategory(ProductCategory item,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = {
      'name': item.name,
      'status': item.status,
      'organization_id': item.organizationId,
      'created_at': item.createdAt.millisecondsSinceEpoch,
      'is_synced': isSynced ? 1 : 0,
    };
    if (item.id != 0) {
      map['id'] = item.id;
    }

    final id = await db.insert('local_categories', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<List<ProductCategory>> getUnsyncedCategories(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];

    if (organizationId != null) {
      where +=
          ' AND (organization_id = ? OR organization_id = 0 OR organization_id IS NULL)';
      args.add(organizationId);
    }

    final maps =
        await db.query('local_categories', where: where, whereArgs: args);
    return maps
        .map((map) => ProductCategory(
              id: map['id'] as int,
              name: map['name'] as String,
              status: map['status'] as int,
              organizationId: (map['organization_id'] as int?) ?? 0,
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
            ))
        .toList();
  }

  Future<void> markCategoryAsSynced(int id) async {
    final db = await _dbHelper.database;
    await db.update('local_categories', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // --- Product Types ---
  Future<void> cacheProductTypes(List<ProductType> items) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // Protect unsynced product types
    final List<Map<String, dynamic>> unsyncedMaps = await db.query(
      'local_product_types',
      columns: ['id'],
      where: 'is_synced = 0',
    );
    final Set<int> unsyncedIds =
        unsyncedMaps.map((m) => m['id'] as int).toSet();

    for (var item in items) {
      if (unsyncedIds.contains(item.id)) continue;

      batch.insert(
          'local_product_types',
          {
            'id': item.id,
            'name': item.name,
            'status': item.status,
            'organization_id': item.organizationId,
            'created_at': item.createdAt.millisecondsSinceEpoch,
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// SECURITY (OFF-01): see getLocalBrands' doc comment -- same fix shape.
  Future<List<ProductType>> getLocalProductTypes(
      {required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    String where = 'status = 1 AND organization_id = ?';
    List<dynamic> args = [organizationId];

    final maps = await db.query('local_product_types',
        where: where, whereArgs: args, orderBy: 'name ASC');

    return maps.map((map) {
      return ProductType(
        id: map['id'] as int,
        name: map['name'] as String,
        status: map['status'] as int,
        organizationId: (map['organization_id'] as int?) ?? 0,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        productCount: 0,
      );
    }).toList();
  }

  Future<int> saveProductType(ProductType item, {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = {
      'name': item.name,
      'status': item.status,
      'organization_id': item.organizationId,
      'created_at': item.createdAt.millisecondsSinceEpoch,
      'is_synced': isSynced ? 1 : 0,
    };
    if (item.id != 0) {
      map['id'] = item.id;
    }

    final id = await db.insert('local_product_types', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<List<ProductType>> getUnsyncedProductTypes(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];

    if (organizationId != null) {
      where +=
          ' AND (organization_id = ? OR organization_id = 0 OR organization_id IS NULL)';
      args.add(organizationId);
    }

    final maps =
        await db.query('local_product_types', where: where, whereArgs: args);
    return maps
        .map((map) => ProductType(
              id: map['id'] as int,
              name: map['name'] as String,
              status: map['status'] as int,
              organizationId: (map['organization_id'] as int?) ?? 0,
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
            ))
        .toList();
  }

  Future<void> markProductTypeAsSynced(int id) async {
    final db = await _dbHelper.database;
    await db.update('local_product_types', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // --- Units of Measure ---
  Future<void> cacheUnitsOfMeasure(List<UnitOfMeasure> items) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // Protect unsynced UOMs
    final List<Map<String, dynamic>> unsyncedMaps = await db.query(
      'local_units_of_measure',
      columns: ['id'],
      where: 'is_synced = 0',
    );
    final Set<int> unsyncedIds =
        unsyncedMaps.map((m) => m['id'] as int).toSet();

    for (var item in items) {
      if (unsyncedIds.contains(item.id)) continue;

      batch.insert(
          'local_units_of_measure',
          {
            'id': item.id,
            'unit_name': item.name,
            'unit_symbol': item.symbol,
            'unit_type': item.type,
            'is_decimal_allowed': item.isDecimalAllowed ? 1 : 0,
            'organization_id': item.organizationId,
            'created_at': item.createdAt?.millisecondsSinceEpoch,
            'updated_at': item.updatedAt?.millisecondsSinceEpoch,
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// SECURITY (OFF-01): see getLocalBrands' doc comment -- same fix shape.
  Future<List<UnitOfMeasure>> getLocalUnitsOfMeasure(
      {required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    String where = 'status = 1 AND organization_id = ?';
    List<dynamic> args = [organizationId];

    final maps = await db.query('local_units_of_measure',
        where: where, whereArgs: args, orderBy: 'unit_name ASC');

    return maps.map((map) {
      return UnitOfMeasure(
        id: map['id'] as int,
        name: map['unit_name'] as String,
        symbol: map['unit_symbol'] as String,
        type: map['unit_type'] as String?,
        isDecimalAllowed: (map['is_decimal_allowed'] as int) == 1,
        organizationId: (map['organization_id'] as int?) ?? 0,
        createdAt: map['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
            : null,
      );
    }).toList();
  }

  Future<int> saveUnitOfMeasure(UnitOfMeasure item,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = {
      'unit_name': item.name,
      'unit_symbol': item.symbol,
      'unit_type': item.type,
      'is_decimal_allowed': item.isDecimalAllowed ? 1 : 0,
      'organization_id': item.organizationId,
      'created_at': item.createdAt?.millisecondsSinceEpoch,
      'updated_at': item.updatedAt?.millisecondsSinceEpoch,
      'is_synced': isSynced ? 1 : 0,
    };
    if (item.id != 0) {
      map['id'] = item.id;
    }

    final id = await db.insert('local_units_of_measure', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<List<UnitOfMeasure>> getUnsyncedUnitsOfMeasure(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];

    if (organizationId != null) {
      where +=
          ' AND (organization_id = ? OR organization_id = 0 OR organization_id IS NULL)';
      args.add(organizationId);
    }

    final maps =
        await db.query('local_units_of_measure', where: where, whereArgs: args);
    return maps
        .map((map) => UnitOfMeasure(
              id: map['id'] as int,
              name: map['unit_name'] as String,
              symbol: map['unit_symbol'] as String,
              type: map['unit_type'] as String?,
              isDecimalAllowed: (map['is_decimal_allowed'] as int) == 1,
              organizationId: (map['organization_id'] as int?) ?? 0,
              createdAt: map['created_at'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      map['created_at'] as int)
                  : null,
              updatedAt: map['updated_at'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      map['updated_at'] as int)
                  : null,
            ))
        .toList();
  }

  Future<void> markUnitOfMeasureAsSynced(int id) async {
    final db = await _dbHelper.database;
    await db.update('local_units_of_measure', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // --- Unit Conversions ---
  Future<void> cacheUnitConversions(List<UnitConversion> items) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // Protect unsynced Conversions
    final List<Map<String, dynamic>> unsyncedMaps = await db.query(
      'local_unit_conversions',
      columns: ['id'],
      where: 'is_synced = 0',
    );
    final Set<int> unsyncedIds =
        unsyncedMaps.map((m) => m['id'] as int).toSet();

    for (var item in items) {
      if (unsyncedIds.contains(item.id)) continue;

      batch.insert(
          'local_unit_conversions',
          {
            'id': item.id,
            'from_unit_id': item.fromUnitId,
            'to_unit_id': item.toUnitId,
            'conversion_factor': item.conversionFactor,
            'organization_id': item.organizationId,
            'created_at': item.createdAt?.millisecondsSinceEpoch,
            'updated_at': item.updatedAt?.millisecondsSinceEpoch,
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// SECURITY (OFF-01): see getLocalBrands' doc comment -- same fix shape.
  Future<List<UnitConversion>> getLocalUnitConversions(
      {required int? organizationId}) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    String where = 'status = 1 AND organization_id = ?';
    List<dynamic> args = [organizationId];

    final maps =
        await db.query('local_unit_conversions', where: where, whereArgs: args);

    return maps.map((map) {
      return UnitConversion(
        id: map['id'] as int,
        fromUnitId: map['from_unit_id'] as int,
        toUnitId: map['to_unit_id'] as int,
        conversionFactor: (map['conversion_factor'] as num).toDouble(),
        organizationId: (map['organization_id'] as int?) ?? 0,
        createdAt: map['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
            : null,
      );
    }).toList();
  }

  Future<int> saveUnitConversion(UnitConversion item,
      {bool isSynced = false}) async {
    final db = await _dbHelper.database;
    final map = {
      'from_unit_id': item.fromUnitId,
      'to_unit_id': item.toUnitId,
      'conversion_factor': item.conversionFactor,
      'organization_id': item.organizationId,
      'created_at': item.createdAt?.millisecondsSinceEpoch,
      'updated_at': item.updatedAt?.millisecondsSinceEpoch,
      'is_synced': isSynced ? 1 : 0,
    };
    if (item.id != 0) {
      map['id'] = item.id;
    }

    final id = await db.insert('local_unit_conversions', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<List<UnitConversion>> getUnsyncedUnitConversions(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];

    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }

    final maps =
        await db.query('local_unit_conversions', where: where, whereArgs: args);
    return maps
        .map((map) => UnitConversion(
              id: map['id'] as int,
              fromUnitId: map['from_unit_id'] as int,
              toUnitId: map['to_unit_id'] as int,
              conversionFactor: (map['conversion_factor'] as num).toDouble(),
              organizationId: (map['organization_id'] as int?) ?? 0,
              createdAt: map['created_at'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      map['created_at'] as int)
                  : null,
              updatedAt: map['updated_at'] != null
                  ? DateTime.fromMillisecondsSinceEpoch(
                      map['updated_at'] as int)
                  : null,
            ))
        .toList();
  }

  Future<void> markUnitConversionAsSynced(int id) async {
    final db = await _dbHelper.database;
    await db.update('local_unit_conversions', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }
}
