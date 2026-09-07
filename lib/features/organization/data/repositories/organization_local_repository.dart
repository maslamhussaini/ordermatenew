import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/features/organization/domain/entities/organization.dart';
import 'package:ordermate/features/organization/domain/entities/store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class OrganizationLocalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<void> cacheOrganizations(List<Organization> orgs) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // Clear existing synced records to sync with remote
    await db.delete('local_organizations', where: 'is_synced = 1');

    for (var org in orgs) {
      batch.insert(
          'local_organizations',
          {
            'id': org.id,
            'name': org.name,
            'code': org.code,
            'is_active': org.isActive ? 1 : 0,
            'created_at': org.createdAt.toIso8601String(),
            'updated_at': org.updatedAt.toIso8601String(),
            'logo_url': org.logoUrl,
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getLocalOrganizationsWithSync() async {
    final db = await _dbHelper.database;
    final maps = await db.query('local_organizations', orderBy: 'name ASC');
    return maps;
  }

  Future<List<Organization>> getLocalOrganizations() async {
    final maps = await getLocalOrganizationsWithSync();
    return maps.map((map) {
      return Organization(
        id: map['id'] as int,
        name: map['name'] as String,
        code: map['code'] as String?,
        isActive: (map['is_active'] as int) == 1,
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
            DateTime.now(),
        logoUrl: map['logo_url'] as String?,
      );
    }).toList();
  }

  Future<List<Organization>> mergeOrganizations(
      List<Organization> remote) async {
    final localMaps = await getLocalOrganizationsWithSync();
    final merged = <Organization>[];
    final remoteMap = {for (var org in remote) org.id: org};
    final localMap = {for (var map in localMaps) map['id'] as int: map};

    // Add remote, but if local unsynced exists, use local
    for (var remoteOrg in remote) {
      if (localMap.containsKey(remoteOrg.id)) {
        final localData = localMap[remoteOrg.id]!;
        if (localData['is_synced'] == 0) {
          // Use local unsynced
          merged.add(Organization(
            id: localData['id'] as int,
            name: localData['name'] as String,
            code: localData['code'] as String?,
            isActive: (localData['is_active'] as int) == 1,
            createdAt:
                DateTime.tryParse(localData['created_at'] as String? ?? '') ??
                    DateTime.now(),
            updatedAt:
                DateTime.tryParse(localData['updated_at'] as String? ?? '') ??
                    DateTime.now(),
            logoUrl: localData['logo_url'] as String?,
          ));
        } else {
          merged.add(remoteOrg);
        }
      } else {
        merged.add(remoteOrg);
      }
    }

    // Add local not in remote (unsynced additions)
    for (var localData in localMaps) {
      if (!remoteMap.containsKey(localData['id']) && localData['is_synced'] == 0) {
        merged.add(Organization(
          id: (localData['id'] as int?) ?? 0,
          name: localData['name'] as String,
          code: localData['code'] as String?,
          isActive: (localData['is_active'] as int) == 1,
          createdAt:
              DateTime.tryParse(localData['created_at'] as String? ?? '') ??
                  DateTime.now(),
          updatedAt:
              DateTime.tryParse(localData['updated_at'] as String? ?? '') ??
                  DateTime.now(),
          logoUrl: localData['logo_url'] as String?,
        ));
      }
    }

    return merged;
  }

  Future<void> addOrganization(Organization org) async {
    final db = await _dbHelper.database;
    // We might need to generate a temporary negative ID or random ID if auto-increment is on server.
    // But here local table has primary key too.
    // If we insert manually, we use that ID.
    await db.insert(
        'local_organizations',
        {
          'id': org.id, // Assuming this is generated or handled before
          'name': org.name,
          'code': org.code,
          'is_active': org.isActive ? 1 : 0,
          'created_at': org.createdAt.toIso8601String(),
          'updated_at': org.updatedAt.toIso8601String(),
          'logo_url': org.logoUrl,
          'is_synced': 0, // Not synced
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteOrganization(int id) async {
    final db = await _dbHelper.database;
    await db.delete('local_organizations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> cacheLogo(int orgId, Uint8List logoBytes) async {
    if (kIsWeb) return;
    final dir = await getApplicationDocumentsDirectory();
    final logoDir = Directory('${dir.path}/logos');
    if (!logoDir.existsSync()) {
      logoDir.createSync(recursive: true);
    }
    final file = File('${logoDir.path}/org_$orgId.png');
    await file.writeAsBytes(logoBytes);
  }

  Future<Uint8List?> getCachedLogo(int orgId) async {
    if (kIsWeb) return null;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/logos/org_$orgId.png');
    if (file.existsSync()) {
      return file.readAsBytes();
    }
    return null;
  }

  // --- Stores ---

  Future<void> cacheStores(int organizationId, List<Store> stores) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // Clear existing synced records for this org to remove deleted/stale stores
    await db.delete('local_stores',
        where: 'organization_id = ? AND is_synced = 1',
        whereArgs: [organizationId]);

    for (var store in stores) {
      batch.insert(
          'local_stores',
          {
            'id': store.id,
            'organization_id': store.organizationId,
            'name': store.name,
            'location': store.location,
            'store_city': store.city,
            'store_country': store.country,
            'store_postal_code': store.postalCode,
            'store_default_currency': store.storeDefaultCurrency,
            'is_active': store.isActive ? 1 : 0,
            'created_at': store.createdAt.toIso8601String(),
            'updated_at': store.updatedAt.toIso8601String(),
            'is_synced': 1,
            'phone': store.phone,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateLocalStore(Store store) async {
    final db = await _dbHelper.database;
    await db.insert(
        'local_stores',
        {
          'id': store.id,
          'organization_id': store.organizationId,
          'name': store.name,
          'location': store.location,
          'store_city': store.city,
          'store_country': store.country,
          'store_postal_code': store.postalCode,
          'store_default_currency': store.storeDefaultCurrency,
          'is_active': store.isActive ? 1 : 0,
          'created_at': store.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0, // Marked as unsynced
          'phone': store.phone,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getLocalStoresWithSync(
      int organizationId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('local_stores',
        where: 'organization_id = ?',
        whereArgs: [organizationId],
        orderBy: 'name ASC');
    return maps;
  }

  Future<List<Store>> getLocalStores(int organizationId) async {
    final maps = await getLocalStoresWithSync(organizationId);
    return maps.map((map) {
      return Store(
        id: map['id'] as int,
        organizationId: map['organization_id'] as int,
        name: map['name'] as String,
        location: map['location'] as String?,
        city: map['store_city'] as String?,
        country: map['store_country'] as String?,
        postalCode: map['store_postal_code'] as String?,
        storeDefaultCurrency: map['store_default_currency'] as String? ?? 'USD',
        phone: map['phone'] as String?,
        isActive: (map['is_active'] as int) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
    }).toList();
  }

  Future<List<Store>> mergeStores(
      List<Store> remote, int organizationId) async {
    final localMaps = await getLocalStoresWithSync(organizationId);
    final merged = <Store>[];
    final remoteMap = {for (var store in remote) store.id: store};
    final localMap = {for (var map in localMaps) map['id'] as int: map};

    // Add remote, but if local unsynced exists, use local
    for (var remoteStore in remote) {
      if (localMap.containsKey(remoteStore.id)) {
        final localData = localMap[remoteStore.id]!;
        if (localData['is_synced'] == 0) {
          // Use local unsynced
          merged.add(Store(
            id: localData['id'] as int,
            organizationId: localData['organization_id'] as int,
            name: localData['name'] as String,
            location: localData['location'] as String?,
            city: localData['store_city'] as String?,
            country: localData['store_country'] as String?,
            postalCode: localData['store_postal_code'] as String?,
            phone: localData['phone'] as String?,
            isActive: (localData['is_active'] as int) == 1,
            createdAt: DateTime.parse(localData['created_at'] as String),
            updatedAt: DateTime.parse(localData['updated_at'] as String),
          ));
        } else {
          merged.add(remoteStore);
        }
      } else {
        merged.add(remoteStore);
      }
    }

    // Add local not in remote (unsynced additions)
    for (var localData in localMaps) {
      // Only keep local-only stores if they are unsynced (pending upload)
      if (!remoteMap.containsKey(localData['id']) && localData['is_synced'] == 0) {
        merged.add(Store(
          id: (localData['id'] as int?) ?? 0,
          organizationId: localData['organization_id'] as int,
          name: localData['name'] as String,
          location: localData['location'] as String?,
          city: localData['store_city'] as String?,
          country: localData['store_country'] as String?,
          postalCode: localData['store_postal_code'] as String?,
          phone: localData['phone'] as String?,
          isActive: (localData['is_active'] as int) == 1,
          createdAt: DateTime.parse(localData['created_at'] as String),
          updatedAt: DateTime.parse(localData['updated_at'] as String),
        ));
      }
    }

    return merged;
  }

  Future<void> deleteStore(int id) async {
    final db = await _dbHelper.database;
    await db.delete('local_stores', where: 'id = ?', whereArgs: [id]);
  }
}
