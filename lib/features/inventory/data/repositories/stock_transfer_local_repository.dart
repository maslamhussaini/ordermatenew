import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/inventory/data/models/stock_transfer_model.dart';
import 'package:sqflite/sqflite.dart';

class StockTransferLocalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<StockTransferModel>> getTransfers(
      {int? organizationId, int? storeId}) async {
    final db = await _dbHelper.database;
    String whereClause = '1=1';
    List<dynamic> args = [];

    if (organizationId != null) {
      whereClause += ' AND organization_id = ?';
      args.add(organizationId);
    }
    if (storeId != null) {
      // Show transfers where store is source OR destination
      whereClause += ' AND (source_store_id = ? OR destination_store_id = ?)';
      args.add(storeId);
      args.add(storeId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'local_stock_transfers',
      where: whereClause,
      whereArgs: args,
      orderBy: 'transfer_date DESC, created_at DESC',
    );

    return List.generate(
        maps.length, (i) => StockTransferModel.fromJson(maps[i]));
  }

  Future<void> addTransfer(StockTransferModel transfer) async {
    final db = await _dbHelper.database;
    await db.insert(
      'local_stock_transfers',
      transfer.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransfer(StockTransferModel transfer) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_stock_transfers',
      transfer.toJson(),
      where: 'id = ?',
      whereArgs: [transfer.id],
    );
  }

  Future<void> deleteTransfer(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'local_stock_transfers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<StockTransferModel>> getUnsyncedTransfers(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND organization_id = ?';
      args.add(organizationId);
    }
    final List<Map<String, dynamic>> maps = await db.query(
      'local_stock_transfers',
      where: where,
      whereArgs: args,
    );
    return List.generate(
        maps.length, (i) => StockTransferModel.fromJson(maps[i]));
  }

  Future<void> markTransferAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_stock_transfers',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cacheTransfers(List<StockTransferModel> transfers) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var t in transfers) {
      final json = t.toJson();
      json['is_synced'] =
          1; // Explicitly marked as synced when coming from server
      batch.insert('local_stock_transfers', json,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
