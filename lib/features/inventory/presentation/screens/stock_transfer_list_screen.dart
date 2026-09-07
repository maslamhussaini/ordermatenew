import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/features/inventory/domain/entities/stock_transfer.dart';
import 'package:ordermate/features/inventory/presentation/providers/stock_transfer_provider.dart';
import 'package:ordermate/features/inventory/data/services/inventory_posting_service.dart';
import 'package:ordermate/features/organization/presentation/providers/organization_provider.dart';

class StockTransferListScreen extends ConsumerStatefulWidget {
  const StockTransferListScreen({super.key});

  @override
  ConsumerState<StockTransferListScreen> createState() =>
      _StockTransferListScreenState();
}

class _StockTransferListScreenState
    extends ConsumerState<StockTransferListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(stockTransferProvider.notifier).loadTransfers();
      ref
          .read(organizationProvider.notifier)
          .loadOrganizations(); // Ensure stores are loaded for lookup
    });
  }

  Future<void> _deleteTransfer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transfer?'),
        content: const Text('Are you sure you want to delete this Gate Pass?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(stockTransferProvider.notifier).deleteTransfer(id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gate Pass deleted')));
      }
    }
  }

  Future<void> _postTransfer(StockTransfer transfer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post to Inventory?'),
        content: const Text(
            'This will deduct stock from Source and add to Destination (or In-Transit). This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('Post'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final postingService = InventoryPostingService();
      final orgId = transfer.organizationId;
      final transferId = transfer.id;

      final existing = await SupabaseConfig.client
          .from('omtbl_inventory_movements')
          .select('id')
          .eq('reference_table', 'omtbl_stock_transfers')
          .eq('reference_id', transferId)
          .limit(1)
          .timeout(const Duration(seconds: 15));

      if (existing.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('This transfer has already been posted.'),
              backgroundColor: Colors.orange));
        }
        return;
      }

      for (final item in transfer.items) {
        if (transfer.sourceStoreId != null) {
          await postingService.postTransferOut(
            organizationId: orgId,
            transferId: transferId,
            productId: item.productId,
            sourceStoreId: transfer.sourceStoreId,
            quantity: item.quantity,
          );
        }
        if (transfer.destinationStoreId != null) {
          await postingService.postTransferIn(
            organizationId: orgId,
            transferId: transferId,
            productId: item.productId,
            destinationStoreId: transfer.destinationStoreId!,
            quantity: item.quantity,
          );
        }
      }

      final updated =
          transfer.copyWith(status: 'Posted', updatedAt: DateTime.now());
      await ref.read(stockTransferProvider.notifier).updateTransfer(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Posted successfully'),
            backgroundColor: Colors.green));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockTransferProvider);
    final orgState = ref.watch(organizationProvider);

    // Helper to get Store Name
    String getStoreName(int? id) {
      if (id == null) return 'Unknown';
      final store = orgState.stores.where((s) => s.id == id).firstOrNull;
      return store?.name ?? 'Store #$id';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Pass / Transfers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(stockTransferProvider.notifier).loadTransfers(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/inventory/transfers/create'),
        label: const Text('New Gate Pass'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('Error: ${state.error}'))
              : state.transfers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.commute,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No Gate Passes found.',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80, top: 8),
                      itemCount: state.transfers.length,
                      itemBuilder: (context, index) {
                        final transfer = state.transfers[index];
                        final isDraft = transfer.status == 'Draft';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              // Open details or edit based on status?
                              // For now, let's open edit/view screen
                              if (isDraft) {
                                context.pushNamed('stock-transfer-edit',
                                    pathParameters: {'id': transfer.id});
                              } else {
                                // View Only - could reuse form in read-only mode or show bottom sheet
                                // re-using form for now (it's edit capable)
                                context.pushNamed('stock-transfer-edit',
                                    pathParameters: {'id': transfer.id});
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(transfer.transferNumber,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.teal)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color:
                                              _getStatusColor(transfer.status),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          transfer.status.toUpperCase(),
                                          style: TextStyle(
                                              color: _getStatusTextColor(
                                                  transfer.status),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                          DateFormat('dd MMM yyyy')
                                              .format(transfer.transferDate),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.inventory_2_outlined,
                                          size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text('${transfer.items.length} Items',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  // Route Info
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Source',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey)),
                                            Text(
                                                getStoreName(
                                                    transfer.sourceStoreId),
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward,
                                          color: Colors.grey, size: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            const Text('Destination',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey)),
                                            Text(
                                                getStoreName(transfer
                                                    .destinationStoreId),
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (transfer.driverName != null &&
                                      transfer.driverName!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person,
                                              size: 14, color: Colors.blueGrey),
                                          const SizedBox(width: 4),
                                          Text(transfer.driverName!,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blueGrey)),
                                          if (transfer.vehicleNumber != null &&
                                              transfer.vehicleNumber!
                                                  .isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            const Icon(Icons.local_shipping,
                                                size: 14,
                                                color: Colors.blueGrey),
                                            const SizedBox(width: 4),
                                            Text(transfer.vehicleNumber!,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blueGrey)),
                                          ]
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (isDraft)
                                        TextButton.icon(
                                          onPressed: () => context.pushNamed(
                                              'stock-transfer-edit',
                                              pathParameters: {
                                                'id': transfer.id
                                              }),
                                          icon:
                                              const Icon(Icons.edit, size: 16),
                                          label: const Text('Edit'),
                                          style: TextButton.styleFrom(
                                              foregroundColor: Colors.blueGrey),
                                        ),
                                      if (isDraft)
                                        TextButton.icon(
                                          onPressed: () =>
                                              _deleteTransfer(transfer.id),
                                          icon: const Icon(Icons.delete,
                                              size: 16),
                                          label: const Text('Delete'),
                                          style: TextButton.styleFrom(
                                              foregroundColor: Colors.red),
                                        ),
                                      if (isDraft)
                                        TextButton.icon(
                                          onPressed: () =>
                                              _postTransfer(transfer),
                                          icon: const Icon(Icons.check_circle,
                                              size: 16),
                                          label: const Text('Post'),
                                          style: TextButton.styleFrom(
                                              foregroundColor: Colors.teal),
                                        ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert,
                                            color: Colors.grey),
                                        onSelected: (val) {
                                          if (val == 'print') {
                                            // Print Logic
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Print functionality coming soon')));
                                          } else if (val == 'share') {
                                            // Share Logic
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Share functionality coming soon')));
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                              value: 'print',
                                              child: Row(children: [
                                                Icon(Icons.print, size: 16),
                                                SizedBox(width: 8),
                                                Text('Print Gate Pass')
                                              ])),
                                          const PopupMenuItem(
                                              value: 'share',
                                              child: Row(children: [
                                                Icon(Icons.share, size: 16),
                                                SizedBox(width: 8),
                                                Text('Share')
                                              ])),
                                        ],
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey.shade200;
      case 'posted':
        return Colors.green.shade100;
      case 'approved':
        return Colors.blue.shade100;
      case 'cancelled':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey.shade800;
      case 'posted':
        return Colors.green.shade800;
      case 'approved':
        return Colors.blue.shade800;
      case 'cancelled':
        return Colors.red.shade800;
      default:
        return Colors.black;
    }
  }
}
