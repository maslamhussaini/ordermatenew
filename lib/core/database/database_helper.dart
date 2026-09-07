import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:ordermate/core/utils/password_hasher.dart';

class DatabaseHelper {
  DatabaseHelper._init();
  static final DatabaseHelper instance = DatabaseHelper._init();
  static const int _databaseVersion = 78;
  static Database? _database;
  static Future<Database>? _dbOpenFuture;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _dbOpenFuture ??= _initDB('ordermate_local.db');
    _database = await _dbOpenFuture;
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
// ... (existing code omitted for brevity in prompt construction, but I will target the end of file for insertion)
// Actually I need to be careful with replace_file_content to not wipe the middle.
// I will split this into two edits: one for version, one for migration.

      // 0. Essential Base Tables (Legacy/Early Versions)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_products(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          sku TEXT,
          description TEXT,
          rate REAL DEFAULT 0.0,
          cost REAL DEFAULT 0.0,
          brand_id TEXT,
          category_id TEXT,
          product_type_id TEXT,
          business_partner_id TEXT,
          store_id INTEGER,
          organization_id INTEGER,
          uom_id INTEGER,
          uom_symbol TEXT,
          base_quantity REAL DEFAULT 1.0,
          stock_quantity REAL DEFAULT 0.0,
          is_active INTEGER DEFAULT 1,
          updated_at INTEGER,
          created_at INTEGER,
          is_synced INTEGER DEFAULT 1,
          items_payload TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_orders(
          id TEXT PRIMARY KEY,
          order_number TEXT,
          business_partner_id TEXT,
          business_partner_name TEXT,
          order_type TEXT DEFAULT "SO",
          created_by TEXT,
          status TEXT,
          total_amount REAL DEFAULT 0.0,
          order_date INTEGER,
          created_at INTEGER,
          updated_at INTEGER,
          organization_id INTEGER,
          store_id INTEGER,
          syear INTEGER,
          latitude REAL,
          longitude REAL,
          login_latitude REAL,
          login_longitude REAL,
          payment_term_id INTEGER,
          dispatch_status TEXT DEFAULT "pending",
          dispatch_date INTEGER,
          is_invoiced INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 1,
          items_payload TEXT,
          notes TEXT
        )
      ''');
    }

    if (oldVersion < 2) {
      // 1. Create Business Partners Table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_businesspartners(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT,
          email TEXT,
          address TEXT,
          contact_person TEXT,
          business_type_id INTEGER,
          business_type_name TEXT,
          role_id INTEGER,
          role_name TEXT,
          department_id INTEGER,
          department_name TEXT,
          city_id INTEGER,
          state_id INTEGER,
          country_id INTEGER,
          postal_code TEXT,
          latitude REAL,
          longitude REAL,
          manager_id TEXT,
          organization_id INTEGER,
          store_id INTEGER,
          syear INTEGER,
          is_customer INTEGER DEFAULT 0,
          is_vendor INTEGER DEFAULT 0,
          is_employee INTEGER DEFAULT 0,
          is_supplier INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          is_synced INTEGER DEFAULT 1,
          chart_of_account_id TEXT,
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');

      // 2. Enhance Orders Table
      try {
        await db
            .execute('ALTER TABLE local_orders ADD COLUMN order_number TEXT');
        await db.execute(
            'ALTER TABLE local_orders ADD COLUMN business_partner_name TEXT');
        await db.execute('ALTER TABLE local_orders ADD COLUMN created_by TEXT');
      } catch (e) {
        // Columns might already exist if re-running dev builds
      }
    }

    if (oldVersion < 3) {
      // 3. User Table Enhancements (Fix for DatabaseException on v2 users)
      try {
        await db.execute(
            'ALTER TABLE local_users ADD COLUMN organization_name TEXT');
        await db
            .execute('ALTER TABLE local_users ADD COLUMN table_prefix TEXT');
      } catch (e) {
        // Columns might already exist
      }
    }

    if (oldVersion < 4) {
      // 4. Local Organizations Table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_organizations(
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          code TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT,
          logo_url TEXT,
          is_synced INTEGER DEFAULT 1
        )
      ''');

      // 5. Local Stores Table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_stores(
          id INTEGER PRIMARY KEY,
          organization_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          location TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT,
          is_synced INTEGER DEFAULT 1,
          phone TEXT,
          store_city TEXT,
          store_country TEXT,
          store_postal_code TEXT,
          store_default_currency TEXT DEFAULT "USD"
        )
      ''');
    }

    if (oldVersion < 5) {
      // 6. Local Brands
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_brands(
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          status INTEGER DEFAULT 1,
          created_at INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');

      // 7. Local Categories
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_categories(
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          status INTEGER DEFAULT 1,
          created_at INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');

      // 8. Local Product Types
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_product_types(
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          status INTEGER DEFAULT 1,
          created_at INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');
    }

    if (oldVersion < 6) {
      // 9. Add is_synced to local_products
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN is_synced INTEGER DEFAULT 1');
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN items_payload TEXT'); // Just in case for complex products later, mostly for consistency
      } catch (e) {
        // ignore
      }
    }

    if (oldVersion < 7) {
      // 10. Fix missing tables for users who were on v6 but missing tables due to incomplete _createDB
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_organizations(
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          code TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT,
          logo_url TEXT,
          is_synced INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_stores(
          id INTEGER PRIMARY KEY,
          organization_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          location TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT,
          is_synced INTEGER DEFAULT 1,
          phone TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_brands(
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          status INTEGER DEFAULT 1,
          created_at INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_categories(
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          status INTEGER DEFAULT 1,
          created_at INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_product_types(
          id INTEGER PRIMARY KEY,
          name TEXT NOT NULL,
          status INTEGER DEFAULT 1,
          created_at INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');

      // Ensure local_products has items_payload if missed
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN items_payload TEXT');
      } catch (e) {
        // ignore
      }
    }
    if (oldVersion < 8) {
      // 12. Local Deleted Records (For Offline Deletions)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_deleted_records(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity_table TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          deleted_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 9) {
      // 13. Add missing relation columns to products
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN product_type_id TEXT');
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN business_partner_id TEXT');
      } catch (e) {
        // Ignore if already exists (safeguard)
      }
    }
    if (oldVersion < 10) {
      // 14. Enrich Business Partners
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN business_type_name TEXT');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN business_type_id INTEGER');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN role_id INTEGER');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN role_name TEXT');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN store_id INTEGER');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN latitude REAL');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN longitude REAL');
      } catch (e) {
        // ignore
      }
    }

    if (oldVersion < 11) {
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN is_supplier INTEGER DEFAULT 0');
      } catch (e) {
        // ignore
      }
    }

    if (oldVersion < 12) {
      // 15. Local Location & Business Type Tables
      await db.execute('''
         CREATE TABLE IF NOT EXISTS local_cities(
           id INTEGER PRIMARY KEY,
           city_name TEXT NOT NULL,
           status INTEGER DEFAULT 1
         )
       ''');

      await db.execute('''
         CREATE TABLE IF NOT EXISTS local_states(
           id INTEGER PRIMARY KEY,
           state_name TEXT NOT NULL,
           status INTEGER DEFAULT 1
         )
       ''');

      await db.execute('''
         CREATE TABLE IF NOT EXISTS local_countries(
           id INTEGER PRIMARY KEY,
           country_name TEXT NOT NULL,
           status INTEGER DEFAULT 1
         )
       ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_business_types(
          id INTEGER PRIMARY KEY,
          business_type TEXT NOT NULL, 
          status INTEGER DEFAULT 1,
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');

      // 16. Add Location IDs to Business Partners (Merged from duplicate block)
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN city_id INTEGER');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN state_id INTEGER');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN country_id INTEGER');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN postal_code TEXT');
      } catch (e) {
        // ignore
      }
    }

    if (oldVersion < 13) {
      // 17. Add store_default_currency to local stores
      try {
        await db.execute(
            'ALTER TABLE local_stores ADD COLUMN store_default_currency TEXT DEFAULT "USD"');
      } catch (e) {
        // ignore
      }
    }

    if (oldVersion < 16) {
      // 20. Departments
      await db.execute('''
         CREATE TABLE IF NOT EXISTS local_departments(
           id INTEGER PRIMARY KEY,
           name TEXT NOT NULL,
           organization_id INTEGER,
           status INTEGER DEFAULT 1,
           created_at INTEGER,
           updated_at INTEGER,
           is_synced INTEGER DEFAULT 1
         )
       ''');

      // Add department columns to local_businesspartners
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN department_id INTEGER');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN department_name TEXT');
      } catch (e) {
        // ignore
      }
    }

    if (oldVersion < 14) {
      try {
        await db
            .execute('ALTER TABLE local_products ADD COLUMN store_id INTEGER');
      } catch (e) {
        // ignore
      }
      try {
        await db
            .execute('ALTER TABLE local_orders ADD COLUMN store_id INTEGER');
      } catch (e) {
        // ignore
      }
    }
    if (oldVersion < 17) {
      // 21. Add Address fields to Local Stores
      try {
        await db.execute('ALTER TABLE local_stores ADD COLUMN store_city TEXT');
        await db
            .execute('ALTER TABLE local_stores ADD COLUMN store_country TEXT');
        await db.execute(
            'ALTER TABLE local_stores ADD COLUMN store_postal_code TEXT');
      } catch (e) {
        // ignore
      }
    }

    if (oldVersion < 18) {
      // 22. Add is_active to Business Partners and Products, and phone to Stores
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN is_active INTEGER DEFAULT 1');
      } catch (e) {/* ignore */}

      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN is_active INTEGER DEFAULT 1');
      } catch (e) {/* ignore */}

      try {
        await db.execute('ALTER TABLE local_stores ADD COLUMN phone TEXT');
      } catch (e) {/* ignore */}
    }

    if (oldVersion < 19) {
      // 23. Retry Add is_active (Force Retry)
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN is_active INTEGER DEFAULT 1');
      } catch (e) {/* ignore */}

      try {
        await db.execute('ALTER TABLE local_stores ADD COLUMN phone TEXT');
      } catch (e) {/* ignore */}
    }

    if (oldVersion < 20) {
      // 24. Final safeguard for phone and Fix Orphaned Records
      try {
        await db.execute('ALTER TABLE local_stores ADD COLUMN phone TEXT');
      } catch (e) {/* ignore */}

      // Assign orphan records to the first store if available
      try {
        final stores = await db.query('local_stores', limit: 1);
        if (stores.isNotEmpty) {
          final firstStoreId = stores.first['id'];
          // Products
          await db.rawUpdate(
              'UPDATE local_products SET store_id = ? WHERE store_id IS NULL',
              [firstStoreId]);
          // Orders
          await db.rawUpdate(
              'UPDATE local_orders SET store_id = ? WHERE store_id IS NULL',
              [firstStoreId]);
          // Business Partners
          await db.rawUpdate(
              'UPDATE local_businesspartners SET store_id = ? WHERE store_id IS NULL',
              [firstStoreId]);
        }
      } catch (e) {
        // ignore
      }
    }

    if (oldVersion < 21) {
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN is_supplier INTEGER DEFAULT 0');
      } catch (e) {
        // ignore
      }
    }

    if (oldVersion < 22) {
      try {
        final stores = await db.query('local_stores', limit: 1);
        if (stores.isNotEmpty) {
          final firstStoreId = stores.first['id'];
          // Assign orphaned records to first store
          await db.update('local_businesspartners', {'store_id': firstStoreId},
              where: 'store_id IS NULL');
          await db.update('local_products', {'store_id': firstStoreId},
              where: 'store_id IS NULL');
          await db.update('local_orders', {'store_id': firstStoreId},
              where: 'store_id IS NULL');

          debugPrint(
              'Database: Migrated orphaned records to store $firstStoreId');
        }
      } catch (e) {
        debugPrint('Database: Orphaned records migration error: $e');
      }
    }

    if (oldVersion < 23) {
      try {
        await db
            .execute('ALTER TABLE local_roles ADD COLUMN updated_at INTEGER');
      } catch (e) {/* ignore */}
    }

    if (oldVersion < 24) {
      // Version 24: Comprehensive Field Parity with Supabase

      // 1. Business Partners: organization_id, manager_id, auth_user_id
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN organization_id INTEGER');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN manager_id TEXT');
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN auth_user_id TEXT');
      } catch (e) {/* ignore */}

      // 2. Products: organization_id
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN organization_id INTEGER');
      } catch (e) {/* ignore */}

      // 3. Orders: organization_id, order_type
      try {
        await db.execute(
            'ALTER TABLE local_orders ADD COLUMN organization_id INTEGER');
        await db.execute(
            'ALTER TABLE local_orders ADD COLUMN order_type TEXT DEFAULT "SO"');
      } catch (e) {/* ignore */}

      // 4. App Users: profile details
      try {
        await db
            .execute('ALTER TABLE local_app_users ADD COLUMN full_name TEXT');
        await db.execute('ALTER TABLE local_app_users ADD COLUMN phone TEXT');
        await db.execute('ALTER TABLE local_app_users ADD COLUMN role TEXT');
        await db.execute(
            'ALTER TABLE local_app_users ADD COLUMN updated_at INTEGER');
      } catch (e) {/* ignore */}

      // 5. Profile Cache (local_users): organization_id, store_id, phone
      try {
        await db.execute(
            'ALTER TABLE local_users ADD COLUMN organization_id INTEGER');
        await db.execute('ALTER TABLE local_users ADD COLUMN store_id INTEGER');
        await db.execute('ALTER TABLE local_users ADD COLUMN phone TEXT');
      } catch (e) {/* ignore */}

      // 6. Metadata Tables: Timestamps
      try {
        await db
            .execute('ALTER TABLE local_roles ADD COLUMN created_at INTEGER');
        await db.execute(
            'ALTER TABLE local_business_types ADD COLUMN created_at INTEGER');
        await db.execute(
            'ALTER TABLE local_business_types ADD COLUMN updated_at INTEGER');
        await db
            .execute('ALTER TABLE local_brands ADD COLUMN updated_at INTEGER');
        await db.execute(
            'ALTER TABLE local_categories ADD COLUMN updated_at INTEGER');
        await db.execute(
            'ALTER TABLE local_product_types ADD COLUMN updated_at INTEGER');
      } catch (e) {/* ignore */}

      // 7. Add local_privileges table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_privileges(
            id INTEGER PRIMARY KEY,
            privilege_key TEXT UNIQUE NOT NULL,
            description TEXT,
            status INTEGER DEFAULT 1
          )
        ''');
      } catch (e) {/* ignore */}
    }

    if (oldVersion < 25) {
      // Version 25: Maintenance & Schema Fixes - Ensure parity across all tables
      final tables = [
        'local_roles',
        'local_departments',
        'local_business_types',
        'local_brands',
        'local_categories',
        'local_product_types',
        'local_app_users',
        'local_businesspartners',
        'local_products',
        'local_orders'
      ];

      for (var table in tables) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN updated_at INTEGER');
        } catch (_) {/* ignore */}
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN created_at INTEGER');
        } catch (_) {/* ignore */}

        // Specific columns for specific tables
        if (table == 'local_businesspartners' ||
            table == 'local_products' ||
            table == 'local_orders' ||
            table == 'local_roles' ||
            table == 'local_brands' ||
            table == 'local_categories' ||
            table == 'local_product_types') {
          try {
            await db.execute(
                'ALTER TABLE $table ADD COLUMN organization_id INTEGER');
          } catch (_) {}
        }
      }
    }

    if (oldVersion < 26) {
      // 26. Units of Measure and Conversions
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_units_of_measure(
          id INTEGER PRIMARY KEY,
          unit_name TEXT NOT NULL,
          unit_symbol TEXT NOT NULL,
          unit_type TEXT,
          is_decimal_allowed INTEGER DEFAULT 1,
          organization_id INTEGER,
          status INTEGER DEFAULT 1,
          created_at INTEGER,
          updated_at INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_unit_conversions(
          id INTEGER PRIMARY KEY,
          from_unit_id INTEGER,
          to_unit_id INTEGER,
          conversion_factor REAL,
          organization_id INTEGER,
          status INTEGER DEFAULT 1,
          created_at INTEGER,
          updated_at INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 27) {
      // 27. Product UOM Support
      try {
        await db
            .execute('ALTER TABLE local_products ADD COLUMN uom_id INTEGER');
        await db
            .execute('ALTER TABLE local_products ADD COLUMN uom_symbol TEXT');
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN base_quantity REAL DEFAULT 1.0');
      } catch (e) {
        debugPrint('Migration to v27 note: $e (likely columns already exist)');
      }
    }
    if (oldVersion < 28) {
      // 28. Accounting System v1
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_account_types (
            id INTEGER PRIMARY KEY,
            account_type TEXT NOT NULL,
            organization_id INTEGER,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_account_categories (
            id INTEGER PRIMARY KEY,
            category_name TEXT NOT NULL,
            organization_id INTEGER,
            created_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_chart_of_accounts (
            id TEXT PRIMARY KEY,
            account_code TEXT UNIQUE NOT NULL,
            account_title TEXT NOT NULL,
            parent_id TEXT,
            level INTEGER,
            account_type_id INTEGER,
            account_category_id INTEGER,
            organization_id INTEGER,
            is_active INTEGER DEFAULT 1,
            created_at INTEGER,
            updated_at INTEGER,
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_bank_cash (
            id INTEGER PRIMARY KEY,
            bank_cash_name TEXT NOT NULL,
            chart_of_account_id TEXT NOT NULL,
            organization_id INTEGER,
            store_id INTEGER,
            status INTEGER DEFAULT 1,
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_voucher_prefixes (
            id INTEGER PRIMARY KEY,
            prefix_code TEXT UNIQUE NOT NULL,
            description TEXT,
            created_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_transactions (
            id TEXT PRIMARY KEY,
            voucher_prefix_id INTEGER,
            voucher_number TEXT NOT NULL,
            voucher_date INTEGER NOT NULL,
            account_id TEXT,
            offset_account_id TEXT,
            amount REAL NOT NULL,
            description TEXT,
            status TEXT DEFAULT 'posted',
            organization_id INTEGER,
            store_id INTEGER,
            syear INTEGER,
            created_at INTEGER,
            is_synced INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_payment_terms (
            id INTEGER PRIMARY KEY,
            payment_term TEXT NOT NULL,
            description TEXT,
            is_active INTEGER DEFAULT 1,
            created_at INTEGER
          )
        ''');

        // Column updates
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN chart_of_account_id TEXT');
        await db.execute(
            'ALTER TABLE local_orders ADD COLUMN payment_term_id INTEGER');
        await db.execute(
            'ALTER TABLE local_orders ADD COLUMN dispatch_status TEXT DEFAULT "pending"');
        await db.execute(
            'ALTER TABLE local_orders ADD COLUMN dispatch_date INTEGER');
        await db.execute(
            'ALTER TABLE local_orders ADD COLUMN is_invoiced INTEGER DEFAULT 0');
      } catch (e) {
        debugPrint('Migration to v28 error: $e');
      }
    }
    if (oldVersion < 29) {
      // 29. Accounting Sync Enhancements
      try {
        await db.execute(
            'ALTER TABLE local_voucher_prefixes ADD COLUMN voucher_type TEXT');
        await db.execute(
            'ALTER TABLE local_voucher_prefixes ADD COLUMN is_synced INTEGER DEFAULT 1');
        await db.execute(
            'ALTER TABLE local_payment_terms ADD COLUMN is_synced INTEGER DEFAULT 1');
        await db.execute(
            'ALTER TABLE local_account_types ADD COLUMN is_synced INTEGER DEFAULT 1');
        await db.execute(
            'ALTER TABLE local_account_categories ADD COLUMN is_synced INTEGER DEFAULT 1');
      } catch (e) {
        debugPrint('Migration to v29 error: $e');
      }
    }

    if (oldVersion < 30) {
      // 30. Fix missing tables for users affected by incomplete _createDB
      await db.execute('''
          CREATE TABLE IF NOT EXISTS local_chart_of_accounts (
            id TEXT PRIMARY KEY,
            account_code TEXT UNIQUE NOT NULL,
            account_title TEXT NOT NULL,
            parent_id TEXT,
            level INTEGER,
            account_type_id INTEGER,
            account_category_id INTEGER,
            organization_id INTEGER,
            is_active INTEGER DEFAULT 1,
            created_at INTEGER,
            updated_at INTEGER,
            is_synced INTEGER DEFAULT 1
          )
        ''');

      // Also ensure other potentially missed tables from v28 exists
      await db.execute('''
          CREATE TABLE IF NOT EXISTS local_account_types (
            id INTEGER PRIMARY KEY,
            account_type TEXT NOT NULL,
            organization_id INTEGER,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
      await db.execute('''
          CREATE TABLE IF NOT EXISTS local_account_categories (
            id INTEGER PRIMARY KEY,
            category_name TEXT NOT NULL,
            organization_id INTEGER,
            created_at INTEGER
          )
        ''');
      // Ensure column exists
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN chart_of_account_id TEXT');
      } catch (_) {/* ignore */}
    }

    if (oldVersion < 31) {
      // 31. Critical Emergency Fix: Ensure base tables exist with full schema
      // This fixes cases where users had a partially created v30 database or missing tables after clean.

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_products(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          sku TEXT,
          rate REAL DEFAULT 0.0,
          cost REAL DEFAULT 0.0,
          brand_id TEXT,
          category_id TEXT,
          product_type_id TEXT,
          business_partner_id TEXT,
          store_id INTEGER,
          organization_id INTEGER,
          uom_id INTEGER,
          uom_symbol TEXT,
          base_quantity REAL DEFAULT 1.0,
          stock_quantity REAL DEFAULT 0.0,
          is_active INTEGER DEFAULT 1,
          updated_at INTEGER,
          is_synced INTEGER DEFAULT 1,
          items_payload TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_orders(
          id TEXT PRIMARY KEY,
          customer_id TEXT,
          total_amount REAL DEFAULT 0.0,
          status TEXT,
          order_date INTEGER,
          is_synced INTEGER DEFAULT 1,
          items_payload TEXT,
          order_number TEXT,
          business_partner_name TEXT,
          created_by TEXT,
          store_id INTEGER,
          organization_id INTEGER,
          order_type TEXT DEFAULT "SO",
          payment_term_id INTEGER,
          dispatch_status TEXT DEFAULT "pending",
          dispatch_date INTEGER,
          is_invoiced INTEGER DEFAULT 0
        )
      ''');

      // Also verify legacy metadata tables that might have been skipped in partial v30
      await db.execute(
          'CREATE TABLE IF NOT EXISTS local_brands(id INTEGER PRIMARY KEY, name TEXT, status INTEGER DEFAULT 1, created_at INTEGER, updated_at INTEGER, is_synced INTEGER DEFAULT 1)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS local_categories(id INTEGER PRIMARY KEY, name TEXT, status INTEGER DEFAULT 1, created_at INTEGER, updated_at INTEGER, is_synced INTEGER DEFAULT 1)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS local_product_types(id INTEGER PRIMARY KEY, name TEXT, status INTEGER DEFAULT 1, created_at INTEGER, updated_at INTEGER, is_synced INTEGER DEFAULT 1)');
      await db.execute(
          'CREATE TABLE IF NOT EXISTS local_units_of_measure(id INTEGER PRIMARY KEY, unit_name TEXT, unit_symbol TEXT, unit_type TEXT, status INTEGER DEFAULT 1, created_at INTEGER, updated_at INTEGER, organization_id INTEGER, is_synced INTEGER DEFAULT 1)');
    }

    if (oldVersion < 32) {
      // 32. Schema Parity Fix: Ensure missing columns are added to existing tables

      // Organizations & Stores
      try {
        await db.execute(
            'ALTER TABLE local_organizations ADD COLUMN logo_url TEXT');
      } catch (_) {/* ignore */}
      try {
        await db.execute('ALTER TABLE local_stores ADD COLUMN store_city TEXT');
      } catch (_) {/* ignore */}
      try {
        await db
            .execute('ALTER TABLE local_stores ADD COLUMN store_country TEXT');
      } catch (_) {/* ignore */}
      try {
        await db.execute(
            'ALTER TABLE local_stores ADD COLUMN store_postal_code TEXT');
      } catch (_) {/* ignore */}
      try {
        await db.execute(
            'ALTER TABLE local_stores ADD COLUMN store_default_currency TEXT DEFAULT "USD"');
      } catch (_) {/* ignore */}
      try {
        await db.execute('ALTER TABLE local_stores ADD COLUMN phone TEXT');
      } catch (_) {/* ignore */}

      // Orders: Lat/Lng, Notes, Types
      try {
        await db.execute('ALTER TABLE local_orders ADD COLUMN latitude REAL');
      } catch (_) {/* ignore */}
      try {
        await db.execute('ALTER TABLE local_orders ADD COLUMN longitude REAL');
      } catch (_) {/* ignore */}
      try {
        await db
            .execute('ALTER TABLE local_orders ADD COLUMN login_latitude REAL');
      } catch (_) {/* ignore */}
      try {
        await db.execute(
            'ALTER TABLE local_orders ADD COLUMN login_longitude REAL');
      } catch (_) {/* ignore */}
      try {
        await db.execute('ALTER TABLE local_orders ADD COLUMN notes TEXT');
      } catch (_) {/* ignore */}
      try {
        await db.execute(
            'ALTER TABLE local_orders ADD COLUMN business_partner_id TEXT');
      } catch (_) {/* ignore */}
      try {
        await db.execute(
            'ALTER TABLE local_orders ADD COLUMN business_partner_name TEXT');
      } catch (_) {/* ignore */}

      // Products: Description
      try {
        await db
            .execute('ALTER TABLE local_products ADD COLUMN description TEXT');
      } catch (_) {/* ignore */}

      // Metadata tables missing updated_at
      try {
        await db
            .execute('ALTER TABLE local_brands ADD COLUMN updated_at INTEGER');
      } catch (_) {/* ignore */}
      try {
        await db.execute(
            'ALTER TABLE local_categories ADD COLUMN updated_at INTEGER');
      } catch (_) {/* ignore */}
      try {
        await db.execute(
            'ALTER TABLE local_product_types ADD COLUMN updated_at INTEGER');
      } catch (_) {/* ignore */}

      // Ensure local_users has organization_id and store_id
      try {
        await db.execute(
            'ALTER TABLE local_users ADD COLUMN organization_id INTEGER');
      } catch (_) {/* ignore */}
      try {
        await db.execute('ALTER TABLE local_users ADD COLUMN store_id INTEGER');
      } catch (_) {/* ignore */}
      try {
        await db.execute('ALTER TABLE local_users ADD COLUMN phone TEXT');
      } catch (_) {/* ignore */}
    }

    if (oldVersion < 34) {
      // 34. Robust Sync Column Verification
      final syncTables = [
        'local_products',
        'local_orders',
        'local_businesspartners',
        'local_brands',
        'local_categories',
        'local_product_types',
        'local_units_of_measure',
        'local_unit_conversions',
        'local_app_users',
        'local_chart_of_accounts',
        'local_bank_cash',
        'local_transactions',
        'local_voucher_prefixes',
        'local_payment_terms',
        'local_account_types',
        'local_account_categories'
      ];

      debugPrint('Database: Starting v34 migration for sync columns...');
      for (var table in syncTables) {
        try {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN is_synced INTEGER DEFAULT 1');
        } catch (_) {}

        try {
          await db
              .execute('ALTER TABLE $table ADD COLUMN organization_id INTEGER');
        } catch (_) {}
      }
      debugPrint('Database: v34 migration complete.');
    }

    if (oldVersion < 35) {
      // 35. Comprehensive Schema Integrity Check
      debugPrint('Database: Starting v35 schema integrity migration...');

      // Products Table Parity
      final productCols = {
        'sku': 'TEXT',
        'rate': 'REAL DEFAULT 0.0',
        'cost': 'REAL DEFAULT 0.0',
        'brand_id': 'TEXT',
        'category_id': 'TEXT',
        'product_type_id': 'TEXT',
        'business_partner_id': 'TEXT',
        'uom_id': 'INTEGER',
        'uom_symbol': 'TEXT',
        'base_quantity': 'REAL DEFAULT 1.0',
        'items_payload': 'TEXT',
        'description': 'TEXT',
        'is_active': 'INTEGER DEFAULT 1',
        'is_synced': 'INTEGER DEFAULT 1',
        'organization_id': 'INTEGER',
        'store_id': 'INTEGER'
      };

      for (var entry in productCols.entries) {
        try {
          await db.execute(
              'ALTER TABLE local_products ADD COLUMN ${entry.key} ${entry.value}');
        } catch (_) {}
      }

      // Orders Table Parity
      final orderCols = {
        'order_number': 'TEXT',
        'business_partner_id': 'TEXT',
        'customer_id': 'TEXT',
        'business_partner_name': 'TEXT',
        'order_type': 'TEXT DEFAULT "SO"',
        'created_by': 'TEXT',
        'total_amount': 'REAL DEFAULT 0.0',
        'items_payload': 'TEXT',
        'latitude': 'REAL',
        'longitude': 'REAL',
        'notes': 'TEXT',
        'payment_term_id': 'INTEGER',
        'dispatch_status': 'TEXT DEFAULT "pending"',
        'dispatch_date': 'INTEGER',
        'is_invoiced': 'INTEGER DEFAULT 0',
        'is_synced': 'INTEGER DEFAULT 1',
        'organization_id': 'INTEGER',
        'store_id': 'INTEGER'
      };

      for (var entry in orderCols.entries) {
        try {
          await db.execute(
              'ALTER TABLE local_orders ADD COLUMN ${entry.key} ${entry.value}');
        } catch (_) {}
      }

      // Business Partners Parity
      final partnerCols = {
        'is_customer': 'INTEGER DEFAULT 0',
        'is_vendor': 'INTEGER DEFAULT 0',
        'is_employee': 'INTEGER DEFAULT 0',
        'is_supplier': 'INTEGER DEFAULT 0',
        'is_active': 'INTEGER DEFAULT 1',
        'is_synced': 'INTEGER DEFAULT 1',
        'organization_id': 'INTEGER',
        'store_id': 'INTEGER',
        'department_id': 'INTEGER',
        'chart_of_account_id': 'TEXT'
      };

      for (var entry in partnerCols.entries) {
        try {
          await db.execute(
              'ALTER TABLE local_businesspartners ADD COLUMN ${entry.key} ${entry.value}');
        } catch (_) {}
      }

      debugPrint('Database: v35 schema integrity migration complete.');
    }

    if (oldVersion < 37) {
      // 37. Financial Sessions and Transaction Year
      debugPrint('Database: Starting v37 migration...');
      try {
        await db
            .execute('ALTER TABLE local_transactions ADD COLUMN syear INTEGER');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN payment_term_id INTEGER');
      } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_financial_sessions (
          syear INTEGER PRIMARY KEY,
          start_date INTEGER NOT NULL,
          end_date INTEGER NOT NULL,
          narration TEXT,
          in_use INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          organization_id INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');
      debugPrint('Database: v37 migration complete.');
    }

    if (oldVersion < 38) {
      // 38. Accounting System v2 - Adding is_system and missing category fields
      debugPrint('Database: Starting v38 migration...');
      try {
        await db.execute(
            'ALTER TABLE local_account_types ADD COLUMN status INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_account_types ADD COLUMN is_system INTEGER DEFAULT 0');
      } catch (_) {}

      try {
        await db.execute(
            'ALTER TABLE local_account_categories ADD COLUMN account_type_id INTEGER');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_account_categories ADD COLUMN status INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_account_categories ADD COLUMN is_system INTEGER DEFAULT 0');
      } catch (_) {}

      try {
        await db.execute(
            'ALTER TABLE local_chart_of_accounts ADD COLUMN is_system INTEGER DEFAULT 0');
      } catch (_) {}
      debugPrint('Database: v38 migration complete.');
    }

    if (oldVersion < 39) {
      // 39. Fix local_bank_cash schema
      debugPrint(
          'Database: Starting v39 migration (Fixing local_bank_cash)...');
      try {
        await db.execute('DROP TABLE IF EXISTS local_bank_cash');
        await db.execute('''
          CREATE TABLE local_bank_cash (
            id INTEGER PRIMARY KEY,
            bank_cash_name TEXT NOT NULL,
            chart_of_account_id TEXT NOT NULL,
            organization_id INTEGER,
            store_id INTEGER,
            status INTEGER DEFAULT 1,
            is_synced INTEGER DEFAULT 1
          )
        ''');
      } catch (e) {
        debugPrint('Database: v39 migration error: $e');
      }
      debugPrint('Database: v39 migration complete.');
    }

    if (oldVersion < 40) {
      // 40. Fix local_bank_cash schema (TEXT ID, consistent column names)
      debugPrint(
          'Database: Starting v40 migration (Fixing local_bank_cash schema)...');
      try {
        await db.execute('DROP TABLE IF EXISTS local_bank_cash');
        await db.execute('''
          CREATE TABLE local_bank_cash (
            id TEXT PRIMARY KEY,
            bank_name TEXT NOT NULL,
            account_id TEXT NOT NULL,
            account_number TEXT,
            branch_name TEXT,
            organization_id INTEGER,
            store_id INTEGER,
            is_active INTEGER DEFAULT 1,
            is_synced INTEGER DEFAULT 1
          )
        ''');
      } catch (e) {
        debugPrint('Database: v40 migration error: $e');
      }
      debugPrint('Database: v40 migration complete.');
    }

    if (oldVersion < 41) {
      // 41. Fix local_voucher_prefixes schema (Adding status column)
      debugPrint(
          'Database: Starting v41 migration (Adding status to local_voucher_prefixes)...');
      try {
        await db.execute(
            'ALTER TABLE local_voucher_prefixes ADD COLUMN status INTEGER DEFAULT 1');
      } catch (e) {
        debugPrint('Database: v41 migration error: $e');
      }
      debugPrint('Database: v41 migration complete.');
    }

    if (oldVersion < 42) {
      // 42. Adding days to payment terms and due_date to orders
      debugPrint('Database: Starting v42 migration (days and due_date)...');
      try {
        await db.execute(
            'ALTER TABLE local_payment_terms ADD COLUMN days INTEGER DEFAULT 0');
      } catch (e) {
        debugPrint('Database: v42 migration error (days): $e');
      }
      try {
        await db
            .execute('ALTER TABLE local_orders ADD COLUMN due_date INTEGER');
      } catch (e) {
        debugPrint('Database: v42 migration error (due_date): $e');
      }
      debugPrint('Database: v42 migration complete.');
    }

    if (oldVersion < 43) {
      debugPrint('Database: Starting v43 migration (Invoice Tables)...');
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_invoice_types (
            id_invoice_type TEXT PRIMARY KEY,
            description TEXT,
            for_used TEXT,
            organization_id INTEGER,
            is_active INTEGER DEFAULT 1
          )
        ''');
      } catch (e) {
        debugPrint('Database: v43 migration error (local_invoice_types): $e');
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_invoices (
            id TEXT PRIMARY KEY,
            invoice_number TEXT NOT NULL,
            invoice_date INTEGER NOT NULL,
            due_date INTEGER,
            id_invoice_type TEXT,
            business_partner_id TEXT,
            order_id TEXT,
            total_amount REAL DEFAULT 0.0,
            paid_amount REAL DEFAULT 0.0,
            status TEXT,
            notes TEXT,
            organization_id INTEGER,
            store_id INTEGER,
            syear INTEGER,
            created_at INTEGER,
            updated_at INTEGER,
            is_synced INTEGER DEFAULT 1
          )
        ''');
      } catch (e) {
        debugPrint('Database: v43 migration error (local_invoices): $e');
      }

      // Seed defaults locally
      try {
        await db.execute(
            "INSERT OR IGNORE INTO local_invoice_types (id_invoice_type, description, for_used) VALUES ('SI', 'Sales Invoice', 'Sales Invoice')");
        await db.execute(
            "INSERT OR IGNORE INTO local_invoice_types (id_invoice_type, description, for_used) VALUES ('SIR', 'Sales Invoice Return', 'Sales Invoice Return')");
        await db.execute(
            "INSERT OR IGNORE INTO local_invoice_types (id_invoice_type, description, for_used) VALUES ('PI', 'Purchase Invoice', 'Purchase Invoice')");
        await db.execute(
            "INSERT OR IGNORE INTO local_invoice_types (id_invoice_type, description, for_used) VALUES ('PIR', 'Purchase Invoice Return', 'Purchase Invoice Return')");
      } catch (e) {
        debugPrint('Database: v43 migration error (seeding): $e');
      }

      debugPrint('Database: v43 migration complete.');
    }

    if (oldVersion < 44) {
      debugPrint('Database: Starting v44 migration (Invoice Items)...');
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_invoice_items (
            id TEXT PRIMARY KEY,
            invoice_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            product_name TEXT,
            quantity REAL NOT NULL,
            rate REAL NOT NULL,
            total REAL NOT NULL,
            uom_id INTEGER,
            uom_symbol TEXT,
            created_at INTEGER
          )
        ''');
      } catch (e) {
        debugPrint('Database: v44 migration error (local_invoice_items): $e');
      }
      debugPrint('Database: v44 migration complete.');
    }

    if (oldVersion < 45) {
      debugPrint('Database: Starting v45 migration (GL Setup)...');
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_gl_setup (
            organization_id INTEGER PRIMARY KEY,
            inventory_account_id TEXT NOT NULL,
            cogs_account_id TEXT NOT NULL,
            sales_account_id TEXT NOT NULL,
            receivable_account_id TEXT NOT NULL,
            payable_account_id TEXT NOT NULL,
            bank_account_id TEXT,
            cash_account_id TEXT,
            tax_output_account_id TEXT,
            tax_input_account_id TEXT
          )
        ''');
      } catch (e) {
        debugPrint('Database: v45 migration error (local_gl_setup): $e');
      }
      debugPrint('Database: v45 migration complete.');
    }

    if (oldVersion < 46) {
      debugPrint('Database: Starting v46 migration (Daily Balances)...');
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_daily_balances (
            id TEXT PRIMARY KEY,
            account_id TEXT NOT NULL,
            date INTEGER NOT NULL,
            opening_balance REAL DEFAULT 0.0,
            closing_balance REAL DEFAULT 0.0,
            transactions_debit REAL DEFAULT 0.0,
            transactions_credit REAL DEFAULT 0.0,
            is_closed INTEGER DEFAULT 0,
            organization_id INTEGER
          )
        ''');
      } catch (e) {
        debugPrint('Database: v46 migration error (local_daily_balances): $e');
      }
      debugPrint('Database: v46 migration complete.');
    }

    if (oldVersion < 47) {
      debugPrint(
          'Database: Starting v47 migration (is_synced to GL Setup, Daily Balance, Invoice Types)...');
      try {
        await db.execute(
            'ALTER TABLE local_gl_setup ADD COLUMN is_synced INTEGER DEFAULT 1');
        await db.execute(
            'ALTER TABLE local_daily_balances ADD COLUMN is_synced INTEGER DEFAULT 1');
        await db.execute(
            'ALTER TABLE local_invoice_types ADD COLUMN is_synced INTEGER DEFAULT 1');
        await db.execute(
            'ALTER TABLE local_invoice_items ADD COLUMN is_synced INTEGER DEFAULT 1');
      } catch (e) {
        debugPrint('Database: v47 migration error: $e');
      }
      debugPrint('Database: v47 migration complete.');
    }

    if (oldVersion < 48) {
      debugPrint(
          'Database: Starting v48 migration (Missing Metadata Tables)...');
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_roles(
            id INTEGER PRIMARY KEY,
            role_name TEXT NOT NULL,
            description TEXT,
            organization_id INTEGER,
            is_synced INTEGER DEFAULT 1,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
      } catch (e) {
        debugPrint('Database: v48 migration error (local_roles): $e');
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_app_users(
            id TEXT PRIMARY KEY,
            business_partner_id TEXT,
            email TEXT,
            role_id INTEGER,
            organization_id INTEGER,
            full_name TEXT,
            phone TEXT,
            role TEXT,
            is_active INTEGER DEFAULT 1,
            is_synced INTEGER DEFAULT 1,
            updated_at INTEGER
          )
        ''');
      } catch (e) {
        debugPrint('Database: v48 migration error (local_app_users): $e');
      }
      debugPrint('Database: v48 migration complete.');
    }

    if (oldVersion < 49) {
      debugPrint(
          'Database: Starting v49 migration (Accounting Schema Parity)...');
      // Ensure local_account_types has all columns
      try {
        await db.execute(
            'ALTER TABLE local_account_types ADD COLUMN status INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_account_types ADD COLUMN is_system INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_account_types ADD COLUMN is_synced INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_account_types ADD COLUMN updated_at INTEGER');
      } catch (_) {}

      // Ensure local_account_categories has all columns
      try {
        await db.execute(
            'ALTER TABLE local_account_categories ADD COLUMN account_type_id INTEGER');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_account_categories ADD COLUMN status INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_account_categories ADD COLUMN is_system INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_account_categories ADD COLUMN is_synced INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_account_categories ADD COLUMN updated_at INTEGER');
      } catch (_) {}

      // Fix for local_chart_of_accounts
      try {
        await db.execute(
            'ALTER TABLE local_chart_of_accounts ADD COLUMN is_system INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_chart_of_accounts ADD COLUMN status INTEGER DEFAULT 1');
      } catch (_) {}

      debugPrint('Database: v49 migration complete.');
    }

    if (oldVersion < 50) {
      debugPrint('Database: Starting v50 migration (Fix Missing syear)...');
      try {
        await db
            .execute('ALTER TABLE local_transactions ADD COLUMN syear INTEGER');
      } catch (_) {}
      debugPrint('Database: v50 migration complete.');
    }

    if (oldVersion < 51) {
      debugPrint('Database: Starting v51 migration (GL Setup Discounts)...');
      try {
        await db.execute(
            'ALTER TABLE local_gl_setup ADD COLUMN sales_discount_account_id TEXT');
        await db.execute(
            'ALTER TABLE local_gl_setup ADD COLUMN purchase_discount_account_id TEXT');
      } catch (e) {
        debugPrint('Database: v51 migration error: $e');
      }
      debugPrint('Database: v51 migration complete.');
    }

    if (oldVersion < 52) {
      // 52. Role Privileges
      try {
        await db.execute(
            'ALTER TABLE local_roles ADD COLUMN can_read INTEGER DEFAULT 0');
        await db.execute(
            'ALTER TABLE local_roles ADD COLUMN can_write INTEGER DEFAULT 0');
        await db.execute(
            'ALTER TABLE local_roles ADD COLUMN can_edit INTEGER DEFAULT 0');
        await db.execute(
            'ALTER TABLE local_roles ADD COLUMN can_print INTEGER DEFAULT 0');
      } catch (e) {
        debugPrint('Migration to v52 error: $e');
      }
    }

    if (oldVersion < 53) {
      // 53. Form-based Privileges
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_app_forms(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            form_name TEXT NOT NULL,
            form_code TEXT UNIQUE NOT NULL,
            module_name TEXT,
            organization_id INTEGER,
            is_active INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_role_form_privileges(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            form_id INTEGER NOT NULL,
            role_id INTEGER,
            employee_id TEXT,
            can_view INTEGER DEFAULT 0,
            can_add INTEGER DEFAULT 0,
            can_edit INTEGER DEFAULT 0,
            can_delete INTEGER DEFAULT 0,
            can_read INTEGER DEFAULT 0,
            can_print INTEGER DEFAULT 0,
            organization_id INTEGER,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_role_store_access(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            role_id INTEGER,
            store_id INTEGER,
            organization_id INTEGER,
            is_synced INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_user_store_access(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            employee_id TEXT,
            store_id INTEGER,
            organization_id INTEGER,
            is_synced INTEGER DEFAULT 1
          )
        ''');

        // Seed some default forms
        final initialForms = [
          {
            'form_name': 'Products',
            'form_code': 'FRM_PRODUCTS',
            'module_name': 'Inventory'
          },
          {
            'form_name': 'Orders',
            'form_code': 'FRM_ORDERS',
            'module_name': 'Sales'
          },
          {
            'form_name': 'Customers',
            'form_code': 'FRM_CUSTOMERS',
            'module_name': 'CRM'
          },
          {
            'form_name': 'Vendors',
            'form_code': 'FRM_VENDORS',
            'module_name': 'Purchasing'
          },
          {
            'form_name': 'Inventory',
            'form_code': 'FRM_INVENTORY',
            'module_name': 'Inventory'
          },
          {
            'form_name': 'Reports',
            'form_code': 'FRM_REPORTS',
            'module_name': 'Admin'
          },
          {
            'form_name': 'Users',
            'form_code': 'FRM_USERS',
            'module_name': 'Admin'
          },
          {
            'form_name': 'Settings',
            'form_code': 'FRM_SETTINGS',
            'module_name': 'Admin'
          },
        ];

        for (final form in initialForms) {
          await db.insert('local_app_forms', form);
        }
      } catch (e) {
        debugPrint('Migration to v53 error: $e');
      }
    }

    if (oldVersion < 54) {
      // 54. Ensure role privileges exist (Re-run v52 logic more robustly)
      try {
        await db.execute(
            'ALTER TABLE local_roles ADD COLUMN can_read INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_roles ADD COLUMN can_write INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_roles ADD COLUMN can_edit INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_roles ADD COLUMN can_print INTEGER DEFAULT 0');
      } catch (_) {}
      debugPrint('Database: v54 migration complete (Role Privileges ensured).');
    }

    if (oldVersion < 55) {
      // 55. Product Enhancements (Limit Price, GL Accounts, Opening Stock)
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN limit_price REAL DEFAULT 0.0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN stock_qty REAL DEFAULT 0.0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN inventory_gl_id TEXT');
      } catch (_) {}
      try {
        await db
            .execute('ALTER TABLE local_products ADD COLUMN cogs_gl_id TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN revenue_gl_id TEXT');
      } catch (_) {}
      debugPrint('Database: v55 migration complete (Product Enhancements).');
    }

    if (oldVersion < 56) {
      debugPrint(
          'Database: Starting v56 migration (Invoice Item Discounts)...');
      try {
        await db.execute(
            'ALTER TABLE local_invoice_items ADD COLUMN discount_percent REAL DEFAULT 0.0');
      } catch (e) {
        debugPrint('Database: v56 migration error: $e');
      }
      debugPrint('Database: v56 migration complete.');
    }

    if (oldVersion < 57) {
      debugPrint('Database: Starting v57 migration (Business Types)...');
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_business_types (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            business_type TEXT UNIQUE NOT NULL,
            status INTEGER DEFAULT 1
          )
        ''');

        // Seed Business Types locally
        final types = [
          'Services',
          'Manufacturer',
          'Retailer',
          'Services + Retailer',
          'Wholesaler',
          'Distributor',
          'Restaurant & Cafe',
          'Logistics',
          'Healthcare',
          'Construction',
          'E-commerce',
          'Hospitality'
        ];
        for (var type in types) {
          await db.execute(
              "INSERT OR IGNORE INTO local_business_types (business_type) VALUES (?)",
              [type]);
        }

        // Add columns to local_organizations
        await db.execute(
            'ALTER TABLE local_organizations ADD COLUMN business_type_id INTEGER');
        await db.execute(
            'ALTER TABLE local_organizations ADD COLUMN is_services INTEGER DEFAULT 0');
        await db.execute(
            'ALTER TABLE local_organizations ADD COLUMN is_manufacturer INTEGER DEFAULT 0');
        await db.execute(
            'ALTER TABLE local_organizations ADD COLUMN is_retailer INTEGER DEFAULT 0');

        // Default update
        await db.execute('''
          UPDATE local_organizations 
          SET business_type_id = (SELECT id FROM local_business_types WHERE business_type = 'Retailer'),
              is_retailer = 1
        ''');
      } catch (e) {
        debugPrint('Database: v57 migration error: $e');
      }
      debugPrint('Database: v57 migration complete.');
    }

    if (oldVersion < 58) {
      // v58: Add accounting IDs and discount fields to local_products to match server parity & model
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN limtprice REAL DEFAULT 0.0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_products ADD COLUMN cogs_id TEXT');
      } catch (_) {}
      try {
        await db
            .execute('ALTER TABLE local_products ADD COLUMN revnue_id TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN defult_discount_percnt REAL DEFAULT 0.0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN defult_discount_percnt_limit REAL DEFAULT 0.0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN sales_discount_id TEXT');
      } catch (_) {}

      // Standard names as well
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN limit_price REAL DEFAULT 0.0');
      } catch (_) {}
      try {
        await db
            .execute('ALTER TABLE local_products ADD COLUMN cogs_gl_id TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN revenue_gl_id TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_products ADD COLUMN inventory_gl_id TEXT');
      } catch (_) {}
    }

    if (oldVersion < 59) {
      debugPrint(
          'Database: Starting v59 migration (Financial Year & is_closed)...');
      try {
        await db.execute('ALTER TABLE local_orders ADD COLUMN syear INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_invoices ADD COLUMN syear INTEGER');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_financial_sessions ADD COLUMN is_closed INTEGER DEFAULT 0');
      } catch (_) {}
      debugPrint('Database: v59 migration complete.');
    }

    if (oldVersion < 60) {
      debugPrint(
          'Database: Starting v60 migration (Passwords and role details)...');
      try {
        await db
            .execute('ALTER TABLE local_app_users ADD COLUMN password TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN password TEXT');
      } catch (_) {}

      // Ensure role columns exist in local_businesspartners (if missed in earlier migrations)
      try {
        await db
            .execute('ALTER TABLE local_businesspartners ADD COLUMN role TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN business_type_name TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN role_name TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN department_name TEXT');
      } catch (_) {}

      debugPrint('Database: v60 migration complete.');
    }

    if (oldVersion < 61) {
      debugPrint('Database: Starting v61 migration (Role department_id)...');
      try {
        await db.execute(
            'ALTER TABLE local_roles ADD COLUMN department_id INTEGER');
      } catch (_) {}
      debugPrint('Database: v61 migration complete.');
    }
    if (oldVersion < 62) {
      debugPrint(
          'Database: Starting v62 migration (AppUser role_name and last_login)...');
      try {
        await db
            .execute('ALTER TABLE local_app_users ADD COLUMN role_name TEXT');
      } catch (_) {}
      try {
        await db
            .execute('ALTER TABLE local_app_users ADD COLUMN last_login TEXT');
      } catch (_) {}
      debugPrint('Database: v62 migration complete.');
    }

    if (oldVersion < 63) {
      debugPrint('Database: Starting v63 migration (AppUser store_id)...');
      try {
        await db
            .execute('ALTER TABLE local_app_users ADD COLUMN store_id INTEGER');
      } catch (_) {}
      debugPrint('Database: v63 migration complete.');
    }

    if (oldVersion < 64) {
      debugPrint(
          'Database: Starting v64 migration (Ensure syear in Transactions, Invoices, Orders)...');
      // Ensure syear exists in critical tables as requested
      try {
        await db
            .execute('ALTER TABLE local_transactions ADD COLUMN syear INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_invoices ADD COLUMN syear INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_orders ADD COLUMN syear INTEGER');
      } catch (_) {}

      // Attempt to add to 'Receipts' if it implies a separate table (e.g. local_receipts), strictly as a safety check
      try {
        // Check if table exists first prevents error spam, but simple alter try-catch is fine for migration scripts
        await db.execute('ALTER TABLE local_receipts ADD COLUMN syear INTEGER');
      } catch (_) {
        // Expected if table does not exist
      }
      debugPrint('Database: v64 migration complete.');
    }

    if (oldVersion < 65) {
      debugPrint(
          'Database: Starting v65 migration (is_system for voucher prefixes)...');
      try {
        await db.execute(
            'ALTER TABLE local_voucher_prefixes ADD COLUMN is_system INTEGER DEFAULT 0');
      } catch (_) {/* ignore */}
      debugPrint('Database: v65 migration complete.');
    }
    if (oldVersion < 66) {
      debugPrint(
          'Database: Starting v66 migration (Add Store/SYear to Roles)...');
      try {
        await db.execute('ALTER TABLE local_roles ADD COLUMN store_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_roles ADD COLUMN syear INTEGER');
      } catch (_) {}
      debugPrint('Database: v66 migration complete.');
    }
    if (oldVersion < 67) {
      debugPrint(
          'Database: Starting v67 migration (Add created_at to local_app_forms)...');
      try {
        await db
            .execute('ALTER TABLE local_app_forms ADD COLUMN created_at TEXT');
      } catch (e) {
        debugPrint('Database: v67 migration error: $e');
      }
      debugPrint('Database: v67 migration complete.');
    }
    if (oldVersion < 68) {
      debugPrint(
          'Database: Starting v68 migration (Add organization_id to local_role_form_privileges)...');
      try {
        await db.execute(
            'ALTER TABLE local_role_form_privileges ADD COLUMN organization_id INTEGER');
      } catch (e) {
        debugPrint('Database: v68 migration error: $e');
      }
      debugPrint('Database: v68 migration complete.');
    }
    if (oldVersion < 69) {
      debugPrint(
          'Database: Starting v69 migration (Add Store Access Tables)...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_role_store_access(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          role_id INTEGER,
          store_id INTEGER,
          organization_id INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_user_store_access(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id TEXT,
          store_id INTEGER,
          organization_id INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');
      debugPrint('Database: v69 migration complete.');
    }

    if (oldVersion < 70) {
      debugPrint(
          'Database: Starting v70 migration (Add updated_at to local_role_form_privileges)...');
      try {
        await db.execute(
            'ALTER TABLE local_role_form_privileges ADD COLUMN updated_at TEXT');
      } catch (e) {
        if (e.toString().toLowerCase().contains('duplicate column')) {
          debugPrint(
              'Database: v70 migration - updated_at column already exists (Skipping).');
        } else {
          debugPrint('Database: v70 migration error: $e');
        }
      }
      debugPrint('Database: v70 migration complete.');
    }

    if (oldVersion < 71) {
      debugPrint(
          'Database: Starting v71 migration (Fix GL Setup Constraints)...');
      try {
        // SQLite doesn't support ALTER TABLE to drop constraints.
        // We need to recreate the table.
        await db.transaction((txn) async {
          // 1. Rename existing table
          await txn.execute(
              'ALTER TABLE local_gl_setup RENAME TO local_gl_setup_old');

          // 2. Create new table with nullable columns
          await txn.execute('''
            CREATE TABLE local_gl_setup (
              organization_id INTEGER PRIMARY KEY,
              inventory_account_id TEXT,
              cogs_account_id TEXT,
              sales_account_id TEXT,
              receivable_account_id TEXT,
              payable_account_id TEXT,
              bank_account_id TEXT,
              cash_account_id TEXT,
              tax_output_account_id TEXT,
              tax_input_account_id TEXT,
              is_synced INTEGER DEFAULT 1,
              sales_discount_account_id TEXT,
              purchase_discount_account_id TEXT
            )
          ''');

          // 3. Copy data
          await txn.execute('''
            INSERT INTO local_gl_setup (
              organization_id, inventory_account_id, cogs_account_id, sales_account_id,
              receivable_account_id, payable_account_id, bank_account_id, cash_account_id,
              tax_output_account_id, tax_input_account_id, is_synced,
              sales_discount_account_id, purchase_discount_account_id
            )
            SELECT 
              organization_id, inventory_account_id, cogs_account_id, sales_account_id,
              receivable_account_id, payable_account_id, bank_account_id, cash_account_id,
              tax_output_account_id, tax_input_account_id, is_synced,
              sales_discount_account_id, purchase_discount_account_id
            FROM local_gl_setup_old
          ''');

          // 4. Drop old table
          await txn.execute('DROP TABLE local_gl_setup_old');
        });
      } catch (e) {
        debugPrint('Database: v71 migration error: $e');
        // Fallback: If migration fails (e.g. table doesn't exist or column mismatch), just recreate it
        try {
          await db.execute('DROP TABLE IF EXISTS local_gl_setup');
          await db.execute('''
            CREATE TABLE local_gl_setup (
              organization_id INTEGER PRIMARY KEY,
              inventory_account_id TEXT,
              cogs_account_id TEXT,
              sales_account_id TEXT,
              receivable_account_id TEXT,
              payable_account_id TEXT,
              bank_account_id TEXT,
              cash_account_id TEXT,
              tax_output_account_id TEXT,
              tax_input_account_id TEXT,
              is_synced INTEGER DEFAULT 1,
              sales_discount_account_id TEXT,
              purchase_discount_account_id TEXT
            )
          ''');
        } catch (e2) {
          debugPrint('Database: v71 migration fallback failed: $e2');
        }
      }
      debugPrint('Database: v71 migration complete.');
    }

    if (oldVersion < 72) {
      debugPrint('Database: Starting v72 migration (Fix Inventory Schemas)...');
      final tables = [
        'local_brands',
        'local_categories',
        'local_product_types'
      ];

      for (var table in tables) {
        try {
          await db.execute(
              'ALTER TABLE $table ADD COLUMN organization_id INTEGER DEFAULT 0');
          debugPrint('Database: Added organization_id to $table');
        } catch (_) {
          // Column likely exists
        }
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN updated_at INTEGER');
          debugPrint('Database: Added updated_at to $table');
        } catch (_) {}
      }
      debugPrint('Database: v72 migration checking complete.');
    }

    if (oldVersion < 73) {
      debugPrint('Database: Starting v73 migration (Sub-Ledger Columns)...');
      try {
        await db.execute(
            'ALTER TABLE local_transactions ADD COLUMN module_account TEXT');
        await db.execute(
            'ALTER TABLE local_transactions ADD COLUMN offset_module_account TEXT');
      } catch (e) {
        debugPrint('Database: v73 migration error: $e');
      }
      debugPrint('Database: v73 migration complete.');
    }

    if (oldVersion < 74) {
      debugPrint(
          'Database: Starting v74 migration (Transaction Payment Details)...');
      try {
        await db.execute(
            'ALTER TABLE local_transactions ADD COLUMN payment_mode TEXT');
        await db.execute(
            'ALTER TABLE local_transactions ADD COLUMN reference_number TEXT');
        await db.execute(
            'ALTER TABLE local_transactions ADD COLUMN reference_date INTEGER');
        await db.execute(
            'ALTER TABLE local_transactions ADD COLUMN reference_bank TEXT');
        await db.execute(
            'ALTER TABLE local_transactions ADD COLUMN invoice_id TEXT');
      } catch (e) {
        debugPrint('Database: v74 migration error: $e');
      }
    }

    if (oldVersion < 75) {
      debugPrint('Database: Starting v75 migration (Stock Transfers)...');
      // 25. Stock Transfers (Gate Pass)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_stock_transfers(
          id TEXT PRIMARY KEY,
          transfer_number TEXT,
          source_store_id INTEGER,
          destination_store_id INTEGER,
          status TEXT, -- Draft, Approved, Completed, Cancelled
          transfer_date TEXT,
          created_by TEXT,
          driver_name TEXT,
          vehicle_number TEXT,
          remarks TEXT,
          organization_id INTEGER,
          syear INTEGER,
          created_at TEXT,
          updated_at TEXT,
          is_synced INTEGER DEFAULT 0,
          items_payload TEXT
        )
      ''');
      debugPrint('Database: v75 migration complete.');
    }

    if (oldVersion < 76) {
      debugPrint('Database: Starting v76 migration (Opening Balances)...');
      
      // 1. Create Opening Balances Table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_opening_balances(
          id TEXT PRIMARY KEY,
          syear INTEGER,
          amount REAL,
          entity_id TEXT,
          entity_type TEXT,
          organization_id INTEGER,
          created_at INTEGER,
          updated_at INTEGER,
          is_synced INTEGER DEFAULT 1
        )
      ''');

      // 2. Add opening balance functionality to Bank/Cash and Business Partners
      try {
        await db.execute(
            'ALTER TABLE local_businesspartners ADD COLUMN opening_balance REAL DEFAULT 0.0');
        await db.execute(
            'ALTER TABLE local_chart_of_accounts ADD COLUMN opening_balance REAL DEFAULT 0.0');
        await db.execute(
            'ALTER TABLE local_bank_cash ADD COLUMN opening_balance REAL DEFAULT 0.0');
      } catch (e) {
        debugPrint('Database: v76 migration column add error: $e');
      }
      debugPrint('Database: v76 migration complete.');
    }
    if (oldVersion < 77) {
      debugPrint(
          'Database: Starting v77 migration (Fix Financial Sessions PK)...');
      // FIX (N-6): the original v77 dropped the whole
      // local_financial_sessions table before recreating it,
      // which destroyed every locally-created financial session, including
      // unsynced ones, on upgrade. We now rename-copy-drop so existing rows
      // survive the primary-key change.
      await db.transaction((txn) async {
        final existing = await txn.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='local_financial_sessions'");
        final hadTable = existing.isNotEmpty;

        if (hadTable) {
          await txn.execute(
              'ALTER TABLE local_financial_sessions RENAME TO local_financial_sessions_old');
        }

        await txn.execute('''
          CREATE TABLE local_financial_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            syear INTEGER NOT NULL,
            start_date INTEGER NOT NULL,
            end_date INTEGER NOT NULL,
            narration TEXT,
            in_use INTEGER DEFAULT 0,
            is_active INTEGER DEFAULT 1,
            organization_id INTEGER,
            is_synced INTEGER DEFAULT 1,
            is_closed INTEGER DEFAULT 0
          )
        ''');

        if (hadTable) {
          // Copy only columns that exist in the old table.
          final oldCols = (await txn
                  .rawQuery('PRAGMA table_info(local_financial_sessions_old)'))
              .map((r) => r['name'] as String)
              .toSet();
          const wanted = [
            'syear',
            'start_date',
            'end_date',
            'narration',
            'in_use',
            'is_active',
            'organization_id',
            'is_synced',
            'is_closed'
          ];
          final cols = wanted.where(oldCols.contains).toList();
          if (cols.isNotEmpty) {
            final list = cols.join(', ');
            await txn.execute(
                'INSERT INTO local_financial_sessions ($list) SELECT $list FROM local_financial_sessions_old');
          }
          await txn.execute('DROP TABLE local_financial_sessions_old');
        }

        await txn.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_fin_session_org_year ON local_financial_sessions(organization_id, syear)');
      });
      debugPrint('Database: v77 migration complete (rows preserved).');
    }
    if (oldVersion < 78) {
      // SECURITY (C-3): replace the plaintext `local_users.password` column
      // with a salted PBKDF2 hash. Existing plaintext values are converted
      // in place so offline login keeps working, then blanked.
      debugPrint('Database: Starting v78 migration (password hashing)...');
      try {
        final cols = (await db.rawQuery('PRAGMA table_info(local_users)'))
            .map((r) => r['name'] as String)
            .toSet();

        // PRAGMA returns an empty set when the table does not exist. That is a
        // legitimate state on some upgrade paths (and in migration tests that
        // seed only one table), so skip rather than fail.
        if (cols.isEmpty) {
          debugPrint(
              'Database: v78 skipped — local_users not present on this upgrade path.');
        } else {
        if (!cols.contains('password_hash')) {
          await db
              .execute('ALTER TABLE local_users ADD COLUMN password_hash TEXT');
        }

        if (cols.contains('password')) {
          final rows = await db.query('local_users',
              columns: ['email', 'password', 'password_hash']);
          for (final r in rows) {
            final legacy = r['password'] as String?;
            final existingHash = r['password_hash'] as String?;
            if (legacy != null &&
                legacy.isNotEmpty &&
                !PasswordHasher.isHashed(existingHash)) {
              await db.update(
                'local_users',
                {
                  'password_hash': PasswordHasher.hash(legacy),
                  'password': null,
                },
                where: 'email = ?',
                whereArgs: [r['email']],
              );
            }
          }
          // Blank any remaining plaintext (e.g. rows already hashed).
          await db.rawUpdate(
              'UPDATE local_users SET password = NULL WHERE password IS NOT NULL');
        }
        }
      } catch (e) {
        // Logged, not rethrown: a failure here must not brick the app on
        // startup. The offline-login path fails closed anyway — PasswordHasher
        // .verify returns false for a null/absent hash — so the security
        // property holds even if this conversion could not run.
        debugPrint('Database: v78 migration error: $e');
      }
      debugPrint('Database: v78 migration complete.');
    }
  }

  /// Test-only hook so migration behaviour can be exercised against an
  /// in-memory database (see test/migration_v77_v78_test.dart).
  @visibleForTesting
  Future<void> runMigrationsForTest(
          Database db, int oldVersion, int newVersion) =>
      _onUpgrade(db, oldVersion, newVersion);

  Future<void> _validateSchema(Database db) async {
    // Optional: Check highly critical tables
    final requiredTables = [
      'local_products',
      'local_orders',
      'local_businesspartners',
      'local_transactions'
    ];
    for (var table in requiredTables) {
      final result = await db.rawQuery(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", [table]);
      if (result.isEmpty) {
        debugPrint('CRITICAL: Missing required table: $table');
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Sync Queue Table (Always needed)
    await db.execute('''
      CREATE TABLE sync_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL, -- 'CREATE', 'UPDATE', 'DELETE'
        entity TEXT NOT NULL, -- 'CUSTOMER', 'ORDER', 'PRODUCT'
        payload TEXT NOT NULL, -- JSON String of the object
        timestamp INTEGER NOT NULL,
        status INTEGER DEFAULT 0 -- 0: Pending, 1: Processing, 2: Failed
      )
    ''');

    // Delegate the rest of schema creation to onUpgrade
    // passing 0 as oldVersion forces all migration steps to run
    // But first, create the BASE tables that onUpgrade assumes might exist (or are legacy base)

    // 5. Offline Sync Status (Track last pull time)
    await db.execute('''
      CREATE TABLE sync_metadata(
        entity TEXT PRIMARY KEY, -- 'products', 'customers'
        last_sync INTEGER
      )
    ''');

    // 6. Local Users (For Offline Login)
    await db.execute('''
      CREATE TABLE local_users(
        email TEXT PRIMARY KEY,
        id TEXT NOT NULL,
        password_hash TEXT, -- salted PBKDF2-HMAC-SHA256 (see PasswordHasher)
        full_name TEXT,
        role TEXT,
        organization_name TEXT,
        table_prefix TEXT,
        organization_id INTEGER,
        store_id INTEGER,
        phone TEXT
      )
    ''');

    await _onUpgrade(db, 0, version);
    await _validateSchema(db);
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
