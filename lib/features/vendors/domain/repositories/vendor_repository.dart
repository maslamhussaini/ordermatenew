import 'package:ordermate/features/vendors/domain/entities/vendor.dart';

abstract class VendorRepository {
  Future<List<Vendor>> getVendors({int? organizationId});
  Future<List<Vendor>> getSuppliers({int? organizationId});
  Future<Vendor> createVendor(Vendor vendor);
  Future<void> updateVendor(Vendor vendor);
  Future<void> deleteVendor(String id);
}
