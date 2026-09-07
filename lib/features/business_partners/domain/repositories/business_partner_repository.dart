import 'package:ordermate/features/business_partners/domain/entities/app_user.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';

abstract class BusinessPartnerRepository {
  Future<List<BusinessPartner>> getPartners({
    bool? isCustomer,
    bool? isVendor,
    bool? isEmployee,
    bool? isSupplier,
    int? storeId,
    int? organizationId,
  });

  Future<BusinessPartner> createPartner(BusinessPartner partner);
  Future<int> createPartners(List<BusinessPartner> partners);
  Future<void> updatePartner(BusinessPartner partner);
  Future<void> deletePartner(String id);

  Future<BusinessPartner?> getPartnerById(String id);

  Future<List<Map<String, dynamic>>> searchBusinessTypes(String query);

  Future<List<Map<String, dynamic>>> getBusinessTypes();
  Future<void> addBusinessType(String name);

  Future<List<Map<String, dynamic>>> getCities();
  Future<void> addCity(String name);

  Future<List<Map<String, dynamic>>> getStates();
  Future<void> addState(String name);

  Future<List<Map<String, dynamic>>> getCountries();
  Future<void> addCountry(String name);

  Future<List<Map<String, dynamic>>> getRoles({int? organizationId});
  Future<void> addRole(
    String name,
    int? departmentId, {
    bool canRead = false,
    bool canWrite = false,
    bool canEdit = false,
    bool canPrint = false,
    int? storeId,
    int? syear,
    bool isSystem = false,
    int? organizationId,
  });
  Future<void> updateRole(
    int id,
    String name,
    int? departmentId, {
    bool canRead = false,
    bool canWrite = false,
    bool canEdit = false,
    bool canPrint = false,
    int? storeId,
    int? syear,
  });
  Future<void> deleteRole(int id);

  Future<void> createAppUser({
    required String partnerId,
    required String email,
    required int roleId,
    String? fullName,
    int? organizationId,
    int? storeId,
    String? password,
  });

  Future<AppUser?> getAppUser(String partnerId);
  Future<List<AppUser>> getAppUsers(int organizationId);
  Future<void> updateAppUser(AppUser user, {String? password});

  Future<List<Map<String, dynamic>>> getDepartments(int organizationId);
  Future<void> addDepartment(String name, int organizationId);
  Future<void> updateDepartment(int id, String name);
  Future<void> deleteDepartment(int id);

  Future<List<Map<String, dynamic>>> getAppForms();
  Future<List<Map<String, dynamic>>> getFormPrivileges(
      {int? roleId, String? employeeId});
  Future<void> saveBatchFormPrivileges(List<Map<String, dynamic>> privileges);

  // Store Access Methods
  Future<List<int>> getRoleStoreAccess(int roleId);
  Future<void> saveRoleStoreAccess(
      int roleId, List<int> storeIds, int organizationId);
  Future<List<int>> getUserStoreAccess(String employeeId);
  Future<void> saveUserStoreAccess(
      String employeeId, List<int> storeIds, int organizationId);

  Future<void> sendEmployeeCredentials(
      BusinessPartner employee, String password);
}
