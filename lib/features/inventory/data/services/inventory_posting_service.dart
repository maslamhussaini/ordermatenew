import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/inventory/data/models/inventory_movement_model.dart';

class InventoryPostingService {
  Future<void> postMovement({
    required int organizationId,
    required String productId,
    required int storeId,
    required String movementType,
    required double quantity,
    String? referenceTable,
    String? referenceId,
  }) async {
    final model = InventoryMovementModel(
      id: 0,
      organizationId: organizationId,
      productId: productId,
      storeId: storeId,
      movementType: movementType,
      quantity: quantity,
      referenceTable: referenceTable,
      referenceId: referenceId,
      createdAt: DateTime.now(),
    );

    final json = model.toJson();

    await SupabaseConfig.client
        .from('omtbl_inventory_movements')
        .insert(json)
        .timeout(const Duration(seconds: 15));
  }

  Future<void> postPurchaseInvoice({
    required int organizationId,
    required String invoiceId,
    required String productId,
    required int storeId,
    required double quantity,
  }) async {
    await postMovement(
      organizationId: organizationId,
      productId: productId,
      storeId: storeId,
      movementType: 'PURCHASE',
      quantity: quantity,
      referenceTable: 'omtbl_invoices',
      referenceId: invoiceId,
    );
  }

  Future<void> postSalesInvoice({
    required int organizationId,
    required String invoiceId,
    required String productId,
    required int storeId,
    required double quantity,
  }) async {
    await postMovement(
      organizationId: organizationId,
      productId: productId,
      storeId: storeId,
      movementType: 'SALE',
      quantity: -quantity,
      referenceTable: 'omtbl_invoices',
      referenceId: invoiceId,
    );
  }

  Future<void> postTransferOut({
    required int organizationId,
    required String transferId,
    required String productId,
    required int sourceStoreId,
    required double quantity,
  }) async {
    await postMovement(
      organizationId: organizationId,
      productId: productId,
      storeId: sourceStoreId,
      movementType: 'TRANSFER_OUT',
      quantity: -quantity,
      referenceTable: 'omtbl_stock_transfers',
      referenceId: transferId,
    );
  }

  Future<void> postTransferIn({
    required int organizationId,
    required String transferId,
    required String productId,
    required int destinationStoreId,
    required double quantity,
  }) async {
    await postMovement(
      organizationId: organizationId,
      productId: productId,
      storeId: destinationStoreId,
      movementType: 'TRANSFER_IN',
      quantity: quantity,
      referenceTable: 'omtbl_stock_transfers',
      referenceId: transferId,
    );
  }

  Future<void> postPurchaseInvoiceReturn({
    required int organizationId,
    required String invoiceId,
    required String productId,
    required int storeId,
    required double quantity,
  }) async {
    await postMovement(
      organizationId: organizationId,
      productId: productId,
      storeId: storeId,
      movementType: 'PURCHASE_RETURN',
      quantity: -quantity,
      referenceTable: 'omtbl_invoices',
      referenceId: invoiceId,
    );
  }

  Future<void> postSalesInvoiceReturn({
    required int organizationId,
    required String invoiceId,
    required String productId,
    required int storeId,
    required double quantity,
  }) async {
    await postMovement(
      organizationId: organizationId,
      productId: productId,
      storeId: storeId,
      movementType: 'SALE_RETURN',
      quantity: quantity,
      referenceTable: 'omtbl_invoices',
      referenceId: invoiceId,
    );
  }

  Future<double> getAvailableStock({
    required int organizationId,
    required String productId,
    required int storeId,
  }) async {
    final response = await SupabaseConfig.client
        .from('omtbl_inventory_movements')
        .select('quantity, movement_type')
        .eq('organization_id', organizationId)
        .eq('product_id', productId)
        .eq('store_id', storeId)
        .timeout(const Duration(seconds: 15));

    double total = 0;
    for (final row in response as List) {
      final qty = (row['quantity'] as num).toDouble();
      final type = row['movement_type'] as String;
      switch (type) {
        case 'PURCHASE':
        case 'TRANSFER_IN':
        case 'SALE_RETURN':
          total += qty;
          break;
        case 'PURCHASE_RETURN':
        case 'SALE':
        case 'TRANSFER_OUT':
          total -= qty;
          break;
        default:
          total += qty >= 0 ? qty : -qty;
      }
    }
    return total;
  }
}
