import 'package:ordermate/features/orders/domain/entities/order.dart';

abstract class OrderRepository {
  Future<List<Order>> getOrders(
      {int? organizationId, int? storeId, int? sYear});
  Future<Order> createOrder(Order order);
  Future<void> updateOrder(Order order);
  Future<void> deleteOrder(String id);
  Future<String> generateOrderNumber(String prefix);
  Future<void> createOrderItems(List<Map<String, dynamic>> items);
  Future<List<Map<String, dynamic>>> getOrderItems(String orderId);
  Future<void> deleteOrderItems(String orderId);
  Future<List<Order>> getOrdersByDateRange(DateTime start, DateTime end,
      {int? organizationId, int? storeId});
  Future<void> updateDispatchInfo(String orderId, String status, DateTime date);
  Future<void> updateOrderInvoiced(String orderId, bool isInvoiced);
}
