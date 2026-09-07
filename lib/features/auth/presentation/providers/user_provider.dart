import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordermate/core/database/database_helper.dart';
import 'package:ordermate/core/network/supabase_client.dart';
import 'package:ordermate/core/providers/auth_provider.dart';
import 'package:ordermate/features/auth/domain/entities/user.dart';

final userProfileProvider = FutureProvider<User?>((ref) async {
  // Watching authProvider ensures this refreshes on login/logout
  final authState = ref.watch(authProvider);
  if (!authState.isLoggedIn) return null;

  final sessionUser = SupabaseConfig.client.auth.currentUser;
  final userId = sessionUser?.id;
  if (userId == null) return null;

  try {
    final response = await SupabaseConfig.client
        .from('omtbl_users')
        .select()
        .or('id.eq.$userId,auth_id.eq.$userId,email.eq.${sessionUser!.email!}')
        .maybeSingle();

    if (response == null) return null;
    final data = response;
    var user = User(
      id: data['id'] as String,
      email: data['email'] as String,
      fullName: (data['full_name'] as String?) ??
          (sessionUser.userMetadata?['full_name'] as String?) ??
          '',
      phone: data['phone'] as String?,
      role: (data['role'] as String?) ?? 'employee',
      lastLatitude: (data['last_latitude'] as num?)?.toDouble(),
      lastLongitude: (data['last_longitude'] as num?)?.toDouble(),
      lastLocationUpdatedAt: data['last_location_updated_at'] != null
          ? DateTime.parse(data['last_location_updated_at'] as String)
          : null,
      isActive: (data['is_active'] as bool?) ?? true,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      organizationId: data['organization_id'] as int?,
      storeId: data['store_id'] as int?,
      roleId: data['role_id'] as int?,
      businessPartnerId: data['business_partner_id'] as String?,
    );

      // Auto-link Business Partner if missing but email matches
    if (user.businessPartnerId == null && user.email.isNotEmpty) {
      try {
        // Handle duplicates: Use limit(1) and get the first record instead of maybeSingle() which throws on duplicates
        final partnerResponseList = await SupabaseConfig.client
            .from('omtbl_businesspartners')
            .select('id')
            .eq('email', user.email)
            .limit(1);

        if (partnerResponseList.isNotEmpty) {
          final bpId = partnerResponseList.first['id'] as String;
          user = user.copyWith(businessPartnerId: bpId);

          // Update user to link to this existing BP
          unawaited(SupabaseConfig.client
              .from('omtbl_users')
              .update({'business_partner_id': bpId}).eq('id', user.id));

          debugPrint(
              'Auto-linked user ${user.email} to existing Business Partner $bpId');
        } else {
          // Auto-create Business Partner
          
          // Resolve Organization ID
          int? orgId = user.organizationId;
          int? storeId = user.storeId;

          if (orgId == null) {
            try {
              final ownedOrg = await SupabaseConfig.client
                  .from('omtbl_organizations')
                  .select('id')
                  .eq('auth_user_id', user.id)
                  .maybeSingle();
              if (ownedOrg != null) {
                orgId = ownedOrg['id'] as int;
              }
            } catch (e) {
               debugPrint('Error finding org for new User BP: $e');
            }
          }

          // Fetch Admin Role ID if we have an org context
          int? adminRoleId;
          if (orgId != null) {
            try {
              final roleRes = await SupabaseConfig.client
                  .from('omtbl_roles')
                  .select('id')
                  .eq('organization_id', orgId)
                  .ilike('role_name', '%Admin%')
                  .limit(1)
                  .maybeSingle(); // Use maybeSingle combined with limit 1 for safety
              
              if (roleRes != null) {
                adminRoleId = roleRes['id'] as int;
              }
            } catch (e) {
              debugPrint('Error fetching Admin role: $e');
            }
          }

          final newBpId = const Uuid().v4();
          final newPartner = {
            'id': newBpId,
            'name': user.fullName.isNotEmpty
                ? user.fullName
                : user.email.split('@')[0],
            'email': user.email,
            'phone': user.phone ?? '',
            'address': '',
            'is_employee': 1,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'organization_id': orgId,
            'store_id': storeId,
            'created_by': user.id,
            'role_id': adminRoleId, // Assign Admin role to the BP
          };

          await SupabaseConfig.client
              .from('omtbl_businesspartners')
              .insert(newPartner);

          final Map<String, dynamic> userUpdate = {
            'business_partner_id': newBpId,
          };
          if (orgId != null && user.organizationId == null) {
             userUpdate['organization_id'] = orgId;
          }
          // Also link the Role ID to the user record if found
          if (adminRoleId != null && user.roleId == null) {
            userUpdate['role_id'] = adminRoleId;
          }

          await SupabaseConfig.client
              .from('omtbl_users')
              .update(userUpdate).eq('id', user.id);

          user = user.copyWith(
              businessPartnerId: newBpId,
              organizationId: orgId ?? user.organizationId,
              storeId: storeId ?? user.storeId,
              roleId: adminRoleId ?? user.roleId
          );
          
          debugPrint(
              'Auto-created and linked Employee record for ${user.email} (Org: $orgId, Role: $adminRoleId)');
        }
      } catch (e) {
        debugPrint('Failed to auto-link/create BP: $e');
      }
    }

    // Cache locally
    try {
      final db = await DatabaseHelper.instance.database;
      final existing =
          await db.query('local_users', where: 'id = ?', whereArgs: [user.id]);
      if (existing.isNotEmpty) {
        await db.update(
            'local_users',
            {
              'full_name': user.fullName,
              'role': user.role,
              'business_partner_id': user.businessPartnerId
            },
            where: 'id = ?',
            whereArgs: [user.id]);
      } else {
        await db.insert('local_users', {
          'email': user.email,
          'id': user.id,
          'full_name': user.fullName,
          'role': user.role,
          'business_partner_id': user.businessPartnerId
        });
      }
    } catch (_) {}

    return user;
  } catch (e) {
    // Fallback 1: Local Database
    try {
      final db = await DatabaseHelper.instance.database;
      final maps =
          await db.query('local_users', where: 'id = ?', whereArgs: [userId]);
      if (maps.isNotEmpty) {
        final data = maps.first;
        return User(
          id: data['id']! as String,
          email: data['email']! as String,
          fullName: (data['full_name'] as String?) ?? '',
          role: (data['role'] as String?) ?? 'employee',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    } catch (_) {}

    // Fallback 2: Supabase Session Data (Last Resort)
    return User(
      id: userId,
      email: sessionUser?.email ?? 'Unknown',
      fullName: (sessionUser?.userMetadata?['full_name'] as String?) ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
});
