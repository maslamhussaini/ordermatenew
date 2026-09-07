import 'package:ordermate/features/products/domain/entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts({int? storeId, int? organizationId});
  Future<Product> getProductById(String id);
  Future<Product> createProduct(Product product);
  Future<Product> updateProduct(Product product);
  Future<void> deleteProduct(String id);
}
