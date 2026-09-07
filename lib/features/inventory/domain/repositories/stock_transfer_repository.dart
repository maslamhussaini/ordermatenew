import 'package:ordermate/features/inventory/domain/entities/stock_transfer.dart';

abstract class StockTransferRepository {
  Future<List<StockTransfer>> getTransfers({int? organizationId, int? storeId});
  Future<StockTransfer> createTransfer(StockTransfer transfer);
  Future<void> updateTransfer(StockTransfer transfer);
  Future<void> deleteTransfer(String id);
  Future<String> generateTransferNumber(String prefix);
}
