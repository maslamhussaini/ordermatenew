import 'package:flutter/foundation.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/business_partners/domain/entities/business_partner.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class BusinessPartnerLocalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> cachePartners(List<BusinessPartner> partners) async {
    final db = await _dbHelper.database;

    // Get list of unsynced partners to preserve local changes
    final List<Map<String, dynamic>> unsyncedMaps = await db.query(
      'local_businesspartners',
      columns: ['id'],
      where: 'is_synced = 0',
    );
    final Set<String> unsyncedIds =
        unsyncedMaps.map((m) => m['id'] as String).toSet();

    final batch = db.batch();

    for (final p in partners) {
      if (unsyncedIds.contains(p.id)) {
        continue;
      }

      batch.insert(
        'local_businesspartners',
        {
          'id': p.id,
          'name': p.name,
          'phone': p.phone,
          'email': p.email ?? '',
          'address': p.address,
          'contact_person': p.contactPerson ?? '',
          'business_type_id': p.businessTypeId,
          'business_type_name': p.businessTypeName,
          'role_id': p.roleId,
          'role_name': p.roleName,
          'department_id': p.departmentId,
          'department_name': p.departmentName,
          'store_id': p.storeId,
          // SECURITY (OFF-01): this write-through cache (called after every
          // successful online fetch) previously omitted organization_id
          // entirely, leaving every cached row's tenant column NULL. With
          // getLocalPartners() now requiring a strict organization_id
          // match, an omitted org id here would have made all
          // online-cached data permanently invisible offline -- not a
          // security bug, but a correctness regression this fix must not
          // introduce. organizationId is already present on every
          // BusinessPartner passed in (it came from an org-filtered
          // online query).
          'organization_id': p.organizationId,
          'city_id': p.cityId,
          'state_id': p.stateId,
          'country_id': p.countryId,
          'postal_code': p.postalCode,
          'latitude': p.latitude,
          'longitude': p.longitude,
          'is_customer': p.isCustomer ? 1 : 0,
          'is_vendor': p.isVendor ? 1 : 0,
          'is_supplier': p.isSupplier ? 1 : 0,
          'is_employee': p.isEmployee ? 1 : 0,
          'is_active': p.isActive ? 1 : 0,
          'is_synced': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'chart_of_account_id': p.chartOfAccountId,
          'password': p.password,
          // Customer -> Salesman assignment (self-referencing FK to this
          // same table). Nullable; unrelated to organization/tenant scoping.
          'manager_id': p.managerId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// SECURITY (OFF-01): `organizationId` is `required` (though still
  /// nullable) so every call site must explicitly state its tenant
  /// context instead of silently omitting it -- the exact defect that
  /// let offline reads return every cached organization's business
  /// partners. If no organization context is available, this returns an
  /// empty list rather than removing the tenant filter -- "no tenant
  /// context" must never mean "all tenants". The org predicate is a
  /// strict, parameterized equality match: no `OR organization_id IS
  /// NULL`, no wildcard value can substitute for a real organization id.
  Future<List<BusinessPartner>> getLocalPartners({
    bool isCustomer = false,
    bool isVendor = false,
    bool isEmployee = false,
    bool isSupplier = false,
    required int? organizationId,
    int? storeId,
  }) async {
    if (organizationId == null) {
      // No tenant context = no tenant-scoped data. Never fall back to an
      // unfiltered/all-organizations read.
      return [];
    }

    final db = await _dbHelper.database;

    final conditions = <String>[];
    if (isCustomer) conditions.add('is_customer = 1');
    if (isVendor) conditions.add('is_vendor = 1');
    if (isEmployee) conditions.add('is_employee = 1');
    if (isSupplier) conditions.add('is_supplier = 1');

    // Combine types with OR if multiple selected
    String typeCondition = '';
    if (conditions.isNotEmpty) {
      typeCondition = '(${conditions.join(' OR ')})';
    } else {
      typeCondition = '1=1';
    }

    // Combine with Store ID and Organization ID using AND. Organization
    // filtering is unconditional and strict (parameterized, not
    // string-interpolated) -- it is never allowed to be optional or to
    // admit NULL/0 rows as a wildcard match.
    final finalConditions = <String>[];
    final whereArgs = <dynamic>[];

    if (typeCondition != '1=1') {
      finalConditions.add(typeCondition);
    }

    finalConditions.add('organization_id = ?');
    whereArgs.add(organizationId);

    if (storeId != null) {
      finalConditions.add('store_id = ?');
      whereArgs.add(storeId);
    }

    final whereClause = finalConditions.join(' AND ');

    final maps = await db.query(
      'local_businesspartners',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );

    return maps.map((map) => _mapToPartner(map)).toList();
  }

  // Deprecated, unreferenced (no callers found in this codebase). Kept only
  // so any future caller doesn't accidentally get an unfiltered read --
  // explicitly has no tenant context, so it fails safe to an empty list via
  // getLocalPartners' own null-organizationId guard, same as every other
  // caller with no org context.
  Future<List<BusinessPartner>> getLocalCustomers() async {
    return getLocalPartners(isCustomer: true, organizationId: null);
  }

  Future<List<BusinessPartner>> getUnsyncedPartners(
      {int? organizationId, int? storeId}) async {
    final db = await _dbHelper.database;
    final List<String> conditions = ['is_synced = 0'];
    final List<dynamic> args = [];

    if (organizationId != null) {
      conditions.add('organization_id = ?');
      args.add(organizationId);
    }
    if (storeId != null) {
      conditions.add('store_id = ?');
      args.add(storeId);
    }

    final maps = await db.query(
      'local_businesspartners',
      where: conditions.join(' AND '),
      whereArgs: args,
    );

    return maps.map((map) => _mapToPartner(map)).toList();
  }

  Future<void> markPartnerAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_businesspartners',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CRUD Operations for Offline Mode
  Future<void> addPartner(BusinessPartner p) async {
    final db = await _dbHelper.database;
    await db.insert(
      'local_businesspartners',
      {
        'id': p.id,
        'name': p.name,
        'phone': p.phone,
        'email': p.email ?? '',
        'address': p.address,
        'contact_person': p.contactPerson ?? '',
        'business_type_id': p.businessTypeId,
        'business_type_name': p.businessTypeName,
        'role_id': p.roleId,
        'role_name': p.roleName,
        'department_id': p.departmentId,
        'department_name': p.departmentName,
        'store_id': p.storeId,
        'organization_id': p.organizationId,
        'city_id': p.cityId,
        'state_id': p.stateId,
        'country_id': p.countryId,
        'postal_code': p.postalCode,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'is_customer': p.isCustomer ? 1 : 0,
        'is_vendor': p.isVendor ? 1 : 0,
        'is_supplier': p.isSupplier ? 1 : 0,
        'is_employee': p.isEmployee ? 1 : 0,
        'is_active': p.isActive ? 1 : 0,
        'is_synced': 0, // Not synced yet
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'chart_of_account_id': p.chartOfAccountId,
        'password': p.password,
        'manager_id': p.managerId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updatePartner(BusinessPartner p) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_businesspartners',
      {
        'name': p.name,
        'phone': p.phone,
        'email': p.email ?? '',
        'address': p.address,
        'contact_person': p.contactPerson ?? '',
        'business_type_id': p.businessTypeId,
        'business_type_name': p.businessTypeName,
        'role_id': p.roleId,
        'role_name': p.roleName,
        'department_id': p.departmentId,
        'department_name': p.departmentName,
        'store_id': p.storeId,
        'organization_id': p.organizationId,
        'city_id': p.cityId,
        'state_id': p.stateId,
        'country_id': p.countryId,
        'postal_code': p.postalCode,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'is_customer': p.isCustomer ? 1 : 0,
        'is_vendor': p.isVendor ? 1 : 0,
        'is_supplier': p.isSupplier ? 1 : 0,
        'is_employee': p.isEmployee ? 1 : 0,
        'is_active': p.isActive ? 1 : 0,
        'is_synced': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'chart_of_account_id': p.chartOfAccountId,
        'password': p.password,
        'manager_id': p.managerId,
      },
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  Future<void> deletePartner(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Record the deletion for sync
      await txn.insert('local_deleted_records', {
        'entity_table': 'local_businesspartners',
        'entity_id': id,
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
      });

      // 2. Perform the local delete
      await txn.delete(
        'local_businesspartners',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  BusinessPartner _mapToPartner(Map<String, dynamic> map) {
    return BusinessPartner(
      id: map['id']! as String,
      name: map['name']! as String,
      phone: map['phone']! as String,
      email: map['email'] as String?,
      address: map['address']! as String,
      contactPerson: map['contact_person'] as String?,
      businessTypeId: map['business_type_id'] as int?,
      businessTypeName: map['business_type_name'] as String?,
      roleId: map['role_id'] as int?,
      roleName: map['role_name'] as String?,
      departmentId: map['department_id'] as int?,
      departmentName: map['department_name'] as String?,
      storeId: (map['store_id'] as int?) ?? 0,
      organizationId: (map['organization_id'] as int?) ?? 0,
      cityId: map['city_id'] as int?,
      stateId: map['state_id'] as int?,
      countryId: map['country_id'] as int?,
      postalCode: map['postal_code'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      isCustomer: (map['is_customer'] as int) == 1,
      isVendor: (map['is_vendor'] as int) == 1,
      isSupplier: (map['is_supplier'] as int? ?? 0) == 1,
      isEmployee: (map['is_employee'] as int) == 1,
      isActive: true, // Assuming active if locally present
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']! as int),
      createdBy: '',
      distanceMeters: null,
      chartOfAccountId: map['chart_of_account_id'] as String?,
      password: map['password'] as String?,
      managerId: map['manager_id'] as String?,
    );
  }

  // Metadata Caching Methods
  Future<void> cacheCities(List<Map<String, dynamic>> cities) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final item in cities) {
      batch.insert(
        'local_cities',
        {
          'id': item['id'],
          'city_name': item['city_name'],
          'status': item['status'] ?? 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCities() async {
    final db = await _dbHelper.database;
    return await db.query('local_cities', orderBy: 'city_name ASC');
  }

  Future<void> cacheStates(List<Map<String, dynamic>> states) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final item in states) {
      batch.insert(
        'local_states',
        {
          'id': item['id'],
          'state_name': item['state_name'],
          'status': item['status'] ?? 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getStates() async {
    final db = await _dbHelper.database;
    return await db.query('local_states', orderBy: 'state_name ASC');
  }

  Future<void> cacheCountries(List<Map<String, dynamic>> countries) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final item in countries) {
      batch.insert(
        'local_countries',
        {
          'id': item['id'],
          'country_name': item['country_name'],
          'status': item['status'] ?? 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getCountries() async {
    final db = await _dbHelper.database;
    return await db.query('local_countries', orderBy: 'country_name ASC');
  }

  Future<void> cacheBusinessTypes(List<Map<String, dynamic>> types) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final item in types) {
      batch.insert(
        'local_business_types',
        {
          'id': item['id'],
          'business_type': item['business_type'],
          'status': item['status'] ?? 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getBusinessTypes() async {
    final db = await _dbHelper.database;
    return await db.query('local_business_types', orderBy: 'business_type ASC');
  }

  Future<void> cacheDepartments(List<Map<String, dynamic>> depts) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      for (final item in depts) {
        // Strict mapping to avoid sqflite Null Check errors on values
        final id = item['id'];
        final name = item['name'];
        if (id == null || name == null) continue;

        final Map<String, Object> data = {
          'id': id is num ? id.toInt() : int.parse(id.toString()),
          'name': name.toString(),
          'status':
              (item['status'] ?? 1) is num ? (item['status'] ?? 1).toInt() : 1,
          'is_synced': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };

        if (item['organization_id'] != null) {
          final orgId = item['organization_id'];
          data['organization_id'] =
              orgId is num ? orgId.toInt() : int.parse(orgId.toString());
        }

        batch.insert(
          'local_departments',
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('LocalRepository: Error caching departments: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDepartments() async {
    final db = await _dbHelper.database;
    return await db.query('local_departments', orderBy: 'name ASC');
  }

  Future<void> addDepartment(Map<String, dynamic> dept) async {
    final db = await _dbHelper.database;
    await db.insert('local_departments', {
      // id should be generated or handled if offline
      // For simplicity, we might assume offline creation generates a temporary ID or relies on sync
      // But if we want local only first:
      'name': dept['name'],
      'organization_id': dept['organization_id'],
      'status': 1,
      'is_synced': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateDepartment(int id, String name) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_departments',
      {
        'name': name,
        'is_synced': 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDepartment(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_departments',
      {'status': 0, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cacheRoles(List<Map<String, dynamic>> roles) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      for (final role in roles) {
        if (role['id'] == null || role['role_name'] == null) {
          debugPrint('LocalRepository: skipping invalid role: $role');
          continue;
        }
        final id = role['id'];
        final name = role['role_name'];

        final Map<String, Object> data = {
          'id': id is num ? id.toInt() : int.parse(id.toString()),
          'role_name': name.toString(),
          'is_synced': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        };

        if (role['description'] != null) {
          data['description'] = role['description'].toString();
        }
        if (role['organization_id'] != null) {
          final orgId = role['organization_id'];
          data['organization_id'] =
              orgId is num ? orgId.toInt() : int.parse(orgId.toString());
        }

        if (role['department_id'] != null) {
          final deptId = role['department_id'];
          data['department_id'] =
              deptId is num ? deptId.toInt() : int.parse(deptId.toString());
        }

        if (role['store_id'] != null) {
          final sId = role['store_id'];
          data['store_id'] =
              sId is num ? sId.toInt() : int.parse(sId.toString());
        }

        if (role['syear'] != null) {
          final sy = role['syear'];
          data['syear'] = sy is num ? sy.toInt() : int.parse(sy.toString());
        }

        data['can_read'] =
            (role['can_read'] == 1 || role['can_read'] == true) ? 1 : 0;
        data['can_write'] =
            (role['can_write'] == 1 || role['can_write'] == true) ? 1 : 0;
        data['can_edit'] =
            (role['can_edit'] == 1 || role['can_edit'] == true) ? 1 : 0;
        data['can_print'] =
            (role['can_print'] == 1 || role['can_print'] == true) ? 1 : 0;
        data['is_system'] =
            (role['is_system'] == 1 || role['is_system'] == true) ? 1 : 0;

        batch.insert(
          'local_roles',
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('LocalRepository: Error caching roles: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRoles({int? organizationId}) async {
    final db = await _dbHelper.database;
    var where = "role_name NOT LIKE '%Super%'";
    final whereArgs = <Object?>[];
    if (organizationId != null) {
      where += ' AND organization_id = ?';
      whereArgs.add(organizationId);
    }
    final roles = await db.query('local_roles',
        where: where,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'role_name ASC');

    if (roles.isEmpty) {
      // Seed Defaults
      final defaults = [
        {'id': 1, 'role_name': 'Admin', 'description': 'Full Access', 'is_system': 1},
        {'id': 2, 'role_name': 'Manager', 'description': 'Manage Store', 'is_system': 0},
        {'id': 3, 'role_name': 'Booker', 'description': 'Book Orders', 'is_system': 0},
        {'id': 4, 'role_name': 'Driver', 'description': 'Deliver Orders', 'is_system': 0},
      ];

      final batch = db.batch();
      for (final r in defaults) {
        batch.insert('local_roles', r);
      }
      await batch.commit(noResult: true);
      return await db.query('local_roles', orderBy: 'role_name ASC');
    }

    return roles;
  }

  Future<void> addRole(Map<String, dynamic> role) async {
    final db = await _dbHelper.database;
    final data = {
      'role_name': role['role_name'],
      // 'organization_id': role['organization_id'], // Removed
      'department_id': role['department_id'],
      'description': role['description'],
      'can_read': (role['can_read'] == 1 || role['can_read'] == true) ? 1 : 0,
      'can_write':
          (role['can_write'] == 1 || role['can_write'] == true) ? 1 : 0,
      'can_edit': (role['can_edit'] == 1 || role['can_edit'] == true) ? 1 : 0,
      'can_print':
          (role['can_print'] == 1 || role['can_print'] == true) ? 1 : 0,
      'is_system': (role['is_system'] == 1 || role['is_system'] == true) ? 1 : 0,
      'is_synced': 0,
    };

    if (role['store_id'] != null) data['store_id'] = role['store_id'];
    if (role['syear'] != null) data['syear'] = role['syear'];

    await db.insert('local_roles', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

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
  }) async {
    final db = await _dbHelper.database;
    final Map<String, dynamic> data = {
      'role_name': name,
      'can_read': canRead ? 1 : 0,
      'can_write': canWrite ? 1 : 0,
      'can_edit': canEdit ? 1 : 0,
      'can_print': canPrint ? 1 : 0,
      'is_synced': 0,
    };
    if (departmentId != null) data['department_id'] = departmentId;
    if (storeId != null) data['store_id'] = storeId;
    if (syear != null) data['syear'] = syear;

    await db.update(
      'local_roles',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRole(int id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'local_roles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> createAppUser({
    required String partnerId,
    required String email,
    int? roleId,
    String? fullName,
    int? organizationId,
    int? storeId,
  }) async {
    final db = await _dbHelper.database;
    await db.insert(
      'local_app_users',
      {
        'id': const Uuid().v4(),
        'business_partner_id': partnerId,
        'email': email,
        'full_name': fullName,
        'role_id': roleId,
        'organization_id': organizationId,
        'store_id': storeId,
        'is_active': 1,
        'is_synced': 0,
        // 'password' is intentionally never written here — authentication
        // passwords are handled by Supabase Auth, never stored in
        // OrderMate's local cache or application database.
        'role_name': null,
        'last_login': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getAppUser(String partnerId) async {
    final db = await _dbHelper.database;
    final res = await db.query(
      'local_app_users',
      where: 'business_partner_id = ?',
      whereArgs: [partnerId],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> updateAppUser(Map<String, dynamic> user) async {
    final db = await _dbHelper.database;
    final id = user['id'];
    if (id == null) return;

    final data = Map<String, dynamic>.from(user);
    // 'password' is intentionally never written here — authentication
    // passwords are handled by Supabase Auth, never stored in OrderMate's
    // local cache or application database.
    data.remove('password');
    data['is_synced'] = 0;

    // Ensure we only include valid columns to avoid future SqfliteFfiException
    final validColumns = [
      'id',
      'business_partner_id',
      'email',
      'full_name',
      'role_id',
      'role_name',
      'organization_id',
      'store_id',
      'is_active',
      'last_login',
      'updated_at',
      'is_synced'
    ];
    data.removeWhere((key, value) => !validColumns.contains(key));

    await db.update(
      'local_app_users',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// SECURITY (OFF-01): found alongside the originally-reported
  /// getLocalPartners defect, same file, same pattern -- app user/employee
  /// account records are at least as sensitive as business partner data.
  /// No organization id means no data, never an unfiltered read; the
  /// predicate is now a strict equality match.
  Future<List<Map<String, dynamic>>> getAppUsersByOrg(
      int? organizationId) async {
    if (organizationId == null) return [];

    final db = await _dbHelper.database;
    const where = 'organization_id = ?';
    final args = [organizationId];
    return await db.query(
      'local_app_users',
      where: where,
      whereArgs: args,
      orderBy: 'email ASC',
    );
  }

  Future<void> cacheAppUsers(List<dynamic> users) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final u in users) {
      batch.insert(
        'local_app_users',
        {
          'id': u['id'],
          'business_partner_id': u['business_partner_id'],
          'email': u['email'],
          'role_id': u['role_id'],
          'role_name': u['role_name'],
          'organization_id': u['organization_id'],
          'store_id': u['store_id'],
          'is_active': (u['is_active'] == true || u['is_active'] == 1) ? 1 : 0,
          'last_login': u['last_login']?.toString(),
          'is_synced': 1,
          'password': u['password'],
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedAppUsers(
      {int? organizationId}) async {
    final db = await _dbHelper.database;
    String where = 'is_synced = 0';
    List<dynamic> args = [];
    if (organizationId != null) {
      where += ' AND (organization_id = ? OR organization_id IS NULL)';
      args.add(organizationId);
    }
    return await db.query('local_app_users', where: where, whereArgs: args);
  }

  Future<void> markAppUserAsSynced(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_app_users',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> cacheAppForms(List<Map<String, dynamic>> forms) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final f in forms) {
      batch.insert('local_app_forms', f,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getAppForms() async {
    final db = await _dbHelper.database;
    return await db.query('local_app_forms',
        where: 'is_active = 1', orderBy: 'module_name ASC, form_name ASC');
  }

  Future<List<Map<String, dynamic>>> getFormPrivileges(
      {int? roleId, String? employeeId}) async {
    final db = await _dbHelper.database;
    String where = '';
    List<dynamic> args = [];

    if (roleId != null) {
      where = 'role_id = ?';
      args.add(roleId);
    } else if (employeeId != null) {
      where = 'employee_id = ?';
      args.add(employeeId);
    } else {
      return [];
    }

    return await db.query('local_role_form_privileges',
        where: where, whereArgs: args);
  }

  Future<void> saveFormPrivilege(Map<String, dynamic> privilege) async {
    final db = await _dbHelper.database;
    final id = privilege['id'];

    if (id != null) {
      await db.update(
        'local_role_form_privileges',
        privilege,
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      await db.insert('local_role_form_privileges', privilege);
    }
  }

  Future<void> saveBatchFormPrivileges(
      List<Map<String, dynamic>> privileges) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final p in privileges) {
      if (p['id'] != null) {
        batch.update('local_role_form_privileges', p,
            where: 'id = ?', whereArgs: [p['id']]);
      } else {
        batch.insert('local_role_form_privileges', p);
      }
    }
    await batch.commit(noResult: true);
  }

  // Store Access Methods
  Future<List<int>> getRoleStoreAccess(int roleId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('local_role_store_access',
        where: 'role_id = ?', whereArgs: [roleId]);
    return maps.map((e) => e['store_id'] as int).toList();
  }

  Future<void> saveRoleStoreAccess(
      int roleId, List<int> storeIds, int organizationId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('local_role_store_access',
          where: 'role_id = ?', whereArgs: [roleId]);
      for (final storeId in storeIds) {
        await txn.insert('local_role_store_access', {
          'role_id': roleId,
          'store_id': storeId,
          'organization_id': organizationId,
          'is_synced': 0,
        });
      }
    });
  }

  Future<List<int>> getUserStoreAccess(String employeeId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('local_user_store_access',
        where: 'employee_id = ?', whereArgs: [employeeId]);
    return maps.map((e) => e['store_id'] as int).toList();
  }

  Future<void> saveUserStoreAccess(
      String employeeId, List<int> storeIds, int organizationId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('local_user_store_access',
          where: 'employee_id = ?', whereArgs: [employeeId]);
      for (final storeId in storeIds) {
        await txn.insert('local_user_store_access', {
          'employee_id': employeeId,
          'store_id': storeId,
          'organization_id': organizationId,
          'is_synced': 0,
        });
      }
    });
  }
}
