import 'dart:convert';
import 'dart:io';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/gen_ins_checklist_model.dart';
import 'package:app/models/sqlite/raw_api_data_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../utils/logger.dart';

class CentralAssetAuditDataService {
  static Database? _database;
  static const String _databaseName = 'central_asset_audit.db';
  static const int _databaseVersion = 16;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Raw API data table
    await db.execute('''
      CREATE TABLE raw_api_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_audit_sch_id TEXT NOT NULL,
        site_type TEXT NOT NULL,
        audit_sch_id TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        pv_ticket_id TEXT NOT NULL,
        site_code TEXT NOT NULL,
        cluster TEXT NOT NULL,
        operator TEXT NOT NULL,
        raised_dt TEXT NOT NULL,
        due_dt TEXT NOT NULL,
        status TEXT NOT NULL,
        api_data TEXT NOT NULL,
        is_downloaded INTEGER DEFAULT 0,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // CM Sites table for downloaded CM site data
    await db.execute('''
      CREATE TABLE cm_sites_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id INTEGER NOT NULL,
        entity_id INTEGER NOT NULL,
        site_code TEXT NOT NULL,
        site_name TEXT NOT NULL,
        cluster_district_id INTEGER,
        cluster_district_name TEXT,
        circle_state_id INTEGER,
        circle_state_name TEXT,
        client_id INTEGER,
        client_name TEXT,
        oem TEXT,
        oem_id INTEGER,
        self TEXT,
        self_id INTEGER,
        activity_type TEXT NOT NULL,
        checklist_data TEXT,
        infra_district_engineer_name TEXT,
        infra_district_engineer_contact_no TEXT,
        owner_name TEXT,
        owner_contact_no TEXT,
        latitude TEXT,
        longitude TEXT,
        is_downloaded INTEGER DEFAULT 1,
        downloaded_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // SV Sites table for downloaded SV site data
    await db.execute('''
      CREATE TABLE sv_sites_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id INTEGER NOT NULL,
        entity_id INTEGER NOT NULL,
        site_code TEXT NOT NULL,
        site_name TEXT NOT NULL,
        cluster_district_id INTEGER,
        cluster_district_name TEXT,
        circle_state_id INTEGER,
        circle_state_name TEXT,
        client_id INTEGER,
        client_name TEXT,
        oem TEXT,
        oem_id INTEGER,
        self TEXT,
        self_id INTEGER,
        activity_type TEXT NOT NULL,
        checklist_data TEXT,
        infra_district_engineer_name TEXT,
        infra_district_engineer_contact_no TEXT,
        owner_name TEXT,
        owner_contact_no TEXT,
        latitude TEXT,
        longitude TEXT,
        is_downloaded INTEGER DEFAULT 1,
        downloaded_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // GI Sites table for downloaded GI site data
    await db.execute('''
      CREATE TABLE gi_sites_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id INTEGER NOT NULL,
        entity_id INTEGER NOT NULL,
        site_code TEXT NOT NULL,
        site_name TEXT NOT NULL,
        cluster_district_id INTEGER,
        cluster_district_name TEXT,
        circle_state_id INTEGER,
        circle_state_name TEXT,
        client_id INTEGER,
        client_name TEXT,
        oem TEXT,
        oem_id INTEGER,
        self TEXT,
        self_id INTEGER,
        activity_type TEXT NOT NULL,
        checklist_data TEXT,
        infra_district_engineer_name TEXT,
        infra_district_engineer_contact_no TEXT,
        owner_name TEXT,
        owner_contact_no TEXT,
        latitude TEXT,
        longitude TEXT,
        is_downloaded INTEGER DEFAULT 1,
        downloaded_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Incident Sites table for downloaded incident site data
    await db.execute('''
      CREATE TABLE incident_sites_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id INTEGER NOT NULL,
        entity_id INTEGER NOT NULL,
        site_code TEXT NOT NULL,
        site_name TEXT NOT NULL,
        cluster_district_id INTEGER,
        cluster_district_name TEXT,
        circle_state_id INTEGER,
        circle_state_name TEXT,
        client_id INTEGER,
        client_name TEXT,
        oem TEXT,
        oem_id INTEGER,
        self TEXT,
        self_id INTEGER,
        activity_type TEXT NOT NULL,
        checklist_data TEXT,
        infra_district_engineer_name TEXT,
        infra_district_engineer_contact_no TEXT,
        owner_name TEXT,
        owner_contact_no TEXT,
        latitude TEXT,
        longitude TEXT,
        is_downloaded INTEGER DEFAULT 1,
        downloaded_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Asset Upload Sites table for downloaded AU site data
    await db.execute('''
      CREATE TABLE au_sites_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id INTEGER NOT NULL,
        entity_id INTEGER NOT NULL,
        site_code TEXT NOT NULL,
        site_name TEXT NOT NULL,
        cluster_district_id INTEGER,
        cluster_district_name TEXT,
        circle_state_id INTEGER,
        circle_state_name TEXT,
        client_id INTEGER,
        client_name TEXT,
        oem TEXT,
        oem_id INTEGER,
        self TEXT,
        self_id INTEGER,
        activity_type TEXT NOT NULL,
        checklist_data TEXT,
        infra_district_engineer_name TEXT,
        infra_district_engineer_contact_no TEXT,
        owner_name TEXT,
        owner_contact_no TEXT,
        latitude TEXT,
        longitude TEXT,
        is_downloaded INTEGER DEFAULT 1,
        downloaded_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // General Inspection Checklist table for downloaded GI checklist data
    await db.execute('''
      CREATE TABLE gen_ins_checklist_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id INTEGER NOT NULL,
        site_code TEXT NOT NULL,
        site_name TEXT NOT NULL,
        giclm_id INTEGER NOT NULL,
        site_domain_id INTEGER NOT NULL,
        checklist_desc TEXT NOT NULL,
        resp_type TEXT NOT NULL,
        resp_type_value_map TEXT,
        is_mandatory INTEGER DEFAULT 0,
        cl_order INTEGER NOT NULL,
        activity_type TEXT NOT NULL,
        is_downloaded INTEGER DEFAULT 1,
        downloaded_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // CM Checklist table for downloaded CM checklist data
    await db.execute('''
      CREATE TABLE cm_checklist_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id INTEGER NOT NULL,
        entity_id INTEGER NOT NULL,
        site_code TEXT NOT NULL,
        site_name TEXT NOT NULL,
        checklist_desc TEXT NOT NULL,
        resp_type TEXT NOT NULL,
        resp_type_value_map TEXT,
        impacted_item_value_map TEXT,
        item_type_id INTEGER NOT NULL,
        item_type TEXT NOT NULL,
        check_list_group_id INTEGER,
        cm_check_list_mst_id INTEGER NOT NULL,
        is_mandatory INTEGER DEFAULT 0,
        childitem_data TEXT,
        dependent_elements TEXT,
        cl_order INTEGER NOT NULL,
        sub_item_type TEXT NOT NULL,
        activity_type TEXT NOT NULL,
        is_downloaded INTEGER DEFAULT 1,
        downloaded_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Incident Checklist table for downloaded incident checklist data
    await db.execute('''
      CREATE TABLE incident_checklist_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_id INTEGER NOT NULL,
        site_code TEXT NOT NULL,
        site_name TEXT NOT NULL,
        iclm_id INTEGER NOT NULL,
        incident_item_type TEXT NOT NULL,
        checklist_desc TEXT,
        resp_type TEXT NOT NULL,
        cl_order INTEGER NOT NULL,
        activity_type TEXT NOT NULL,
        is_downloaded INTEGER DEFAULT 1,
        downloaded_at TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_raw_api_data_site_audit_sch_id ON raw_api_data(site_audit_sch_id)',
    );

    await db.execute(
      'CREATE INDEX idx_cm_sites_data_site_id ON cm_sites_data(site_id)',
    );

    await db.execute(
      'CREATE INDEX idx_sv_sites_data_site_id ON sv_sites_data(site_id)',
    );

    await db.execute(
      'CREATE INDEX idx_gi_sites_data_site_id ON gi_sites_data(site_id)',
    );

    await db.execute(
      'CREATE INDEX idx_au_sites_data_site_id ON au_sites_data(site_id)',
    );

    await db.execute(
      'CREATE INDEX idx_gen_ins_checklist_data_site_id ON gen_ins_checklist_data(site_id)',
    );

    await db.execute(
      'CREATE INDEX idx_cm_checklist_data_site_id ON cm_checklist_data(site_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.debugLog(
      '🔄 Upgrading database from version $oldVersion to $newVersion',
    );

    if (oldVersion < 5) {
      // For version 5, we need to add new columns to existing table
      try {
        // Check if columns exist before adding them
        final tableInfo = await db.rawQuery("PRAGMA table_info(raw_api_data)");
        final existingColumns = tableInfo
            .map((col) => col['name'] as String)
            .toList();

        // Add missing columns if they don't exist
        if (!existingColumns.contains('pv_ticket_id')) {
          await db.execute(
            'ALTER TABLE raw_api_data ADD COLUMN pv_ticket_id TEXT NOT NULL DEFAULT ""',
          );
          Logger.debugLog('✅ Added pv_ticket_id column');
        }

        if (!existingColumns.contains('site_code')) {
          await db.execute(
            'ALTER TABLE raw_api_data ADD COLUMN site_code TEXT NOT NULL DEFAULT ""',
          );
          Logger.debugLog('✅ Added site_code column');
        }

        if (!existingColumns.contains('cluster')) {
          await db.execute(
            'ALTER TABLE raw_api_data ADD COLUMN cluster TEXT NOT NULL DEFAULT ""',
          );
          Logger.debugLog('✅ Added cluster column');
        }

        if (!existingColumns.contains('operator')) {
          await db.execute(
            'ALTER TABLE raw_api_data ADD COLUMN operator TEXT NOT NULL DEFAULT ""',
          );
          Logger.debugLog('✅ Added operator column');
        }

        if (!existingColumns.contains('raised_dt')) {
          await db.execute(
            'ALTER TABLE raw_api_data ADD COLUMN raised_dt TEXT NOT NULL DEFAULT ""',
          );
          Logger.debugLog('✅ Added raised_dt column');
        }

        if (!existingColumns.contains('due_dt')) {
          await db.execute(
            'ALTER TABLE raw_api_data ADD COLUMN due_dt TEXT NOT NULL DEFAULT ""',
          );
          Logger.debugLog('✅ Added due_dt column');
        }

        if (!existingColumns.contains('status')) {
          await db.execute(
            'ALTER TABLE raw_api_data ADD COLUMN status TEXT NOT NULL DEFAULT ""',
          );
          Logger.debugLog('✅ Added status column');
        }

        if (!existingColumns.contains('latitude')) {
          await db.execute(
            'ALTER TABLE raw_api_data ADD COLUMN latitude REAL NOT NULL DEFAULT 0.0',
          );
          Logger.debugLog('✅ Added latitude column');
        }

        if (!existingColumns.contains('longitude')) {
          await db.execute(
            'ALTER TABLE raw_api_data ADD COLUMN longitude REAL NOT NULL DEFAULT 0.0',
          );
          Logger.debugLog('✅ Added longitude column');
        }

        if (!existingColumns.contains('created_at')) {
          await db.execute(
            'ALTER TABLE raw_api_data ADD COLUMN created_at TEXT',
          );
          Logger.debugLog('✅ Added created_at column');
        }

        if (!existingColumns.contains('updated_at')) {
          await db.execute(
            'ALTER TABLE raw_api_data ADD COLUMN updated_at TEXT',
          );
          Logger.debugLog('✅ Added updated_at column');
        }

        Logger.debugLog(
          '✅ Database upgraded from version $oldVersion to $newVersion',
        );
      } catch (e) {
        Logger.errorLog('❌ Error upgrading database: $e');
        // If upgrade fails, recreate the table
        await db.execute('DROP TABLE IF EXISTS raw_api_data');
        await _onCreate(db, newVersion);
        Logger.debugLog('✅ Database recreated due to upgrade failure');
      }
    }

    if (oldVersion < 6) {
      // For version 6, create CM sites table
      try {
        await db.execute('''
          CREATE TABLE cm_sites_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            entity_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            cluster_district_id INTEGER,
            cluster_district_name TEXT,
            circle_state_id INTEGER,
            circle_state_name TEXT,
            client_id INTEGER,
            client_name TEXT,
            oem TEXT,
            oem_id INTEGER,
            self TEXT,
            self_id INTEGER,
            activity_type TEXT NOT NULL,
            checklist_data TEXT,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_cm_sites_data_site_id ON cm_sites_data(site_id)',
        );

        Logger.debugLog('✅ Successfully created cm_sites_data table');
      } catch (e) {
        Logger.errorLog('❌ Error creating cm_sites_data table: $e');
      }
    }

    if (oldVersion < 9) {
      // For version 9, add checklist_data column to cm_sites_data table
      try {
        // Check if column already exists
        final tableInfo = await db.rawQuery("PRAGMA table_info(cm_sites_data)");
        final existingColumns = tableInfo
            .map((col) => col['name'] as String)
            .toList();

        if (!existingColumns.contains('checklist_data')) {
          await db.execute(
            'ALTER TABLE cm_sites_data ADD COLUMN checklist_data TEXT',
          );
          Logger.debugLog(
            '✅ Added checklist_data column to cm_sites_data table',
          );
        }
      } catch (e) {
        Logger.errorLog('❌ Error adding checklist_data column: $e');
      }
    }

    if (oldVersion < 7) {
      // For version 7, create General Inspection checklist table
      try {
        await db.execute('''
          CREATE TABLE gen_ins_checklist_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            giclm_id INTEGER NOT NULL,
            site_domain_id INTEGER NOT NULL,
            checklist_desc TEXT NOT NULL,
            resp_type TEXT NOT NULL,
            resp_type_value_map TEXT,
            is_mandatory INTEGER DEFAULT 0,
            cl_order INTEGER NOT NULL,
            activity_type TEXT NOT NULL,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_gen_ins_checklist_data_site_id ON gen_ins_checklist_data(site_id)',
        );

        Logger.debugLog('✅ Successfully created gen_ins_checklist_data table');
      } catch (e) {
        Logger.errorLog('❌ Error creating gen_ins_checklist_data table: $e');
      }
    }

    if (oldVersion < 8) {
      // For version 8, create CM checklist table
      try {
        await db.execute('''
          CREATE TABLE cm_checklist_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            entity_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            checklist_desc TEXT NOT NULL,
            resp_type TEXT NOT NULL,
            resp_type_value_map TEXT,
            impacted_item_value_map TEXT,
            item_type_id INTEGER NOT NULL,
            item_type TEXT NOT NULL,
            check_list_group_id INTEGER,
            cm_check_list_mst_id INTEGER NOT NULL,
            is_mandatory INTEGER DEFAULT 0,
            childitem_data TEXT,
            cl_order INTEGER NOT NULL,
            sub_item_type TEXT NOT NULL,
            activity_type TEXT NOT NULL,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_cm_checklist_data_site_id ON cm_checklist_data(site_id)',
        );

        Logger.debugLog('✅ Successfully created cm_checklist_data table');
      } catch (e) {
        Logger.errorLog('❌ Error creating cm_checklist_data table: $e');
      }
    }

    if (oldVersion < 10) {
      // For version 10, create SV and GI sites tables
      try {
        await db.execute('''
          CREATE TABLE sv_sites_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            entity_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            cluster_district_id INTEGER,
            cluster_district_name TEXT,
            circle_state_id INTEGER,
            circle_state_name TEXT,
            client_id INTEGER,
            client_name TEXT,
            oem TEXT,
            oem_id INTEGER,
            self TEXT,
            self_id INTEGER,
            activity_type TEXT NOT NULL,
            checklist_data TEXT,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_sv_sites_data_site_id ON sv_sites_data(site_id)',
        );

        await db.execute('''
          CREATE TABLE gi_sites_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            entity_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            cluster_district_id INTEGER,
            cluster_district_name TEXT,
            circle_state_id INTEGER,
            circle_state_name TEXT,
            client_id INTEGER,
            client_name TEXT,
            oem TEXT,
            oem_id INTEGER,
            self TEXT,
            self_id INTEGER,
            activity_type TEXT NOT NULL,
            checklist_data TEXT,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_gi_sites_data_site_id ON gi_sites_data(site_id)',
        );

        Logger.debugLog(
          '✅ Successfully created sv_sites_data and gi_sites_data tables',
        );
      } catch (e) {
        Logger.errorLog(
          '❌ Error creating sv_sites_data and gi_sites_data tables: $e',
        );
      }
    }

    if (oldVersion < 11) {
      // For version 11, add infra engineer and owner columns to cm/sv/gi sites tables
      try {
        final tables = ['cm_sites_data', 'sv_sites_data', 'gi_sites_data', 'incident_sites_data'];
        final columns = [
          'infra_district_engineer_name',
          'infra_district_engineer_contact_no',
          'owner_name',
          'owner_contact_no',
        ];

        for (final tableName in tables) {
          // Check if table exists
          final tableInfo = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'",
          );

          if (tableInfo.isNotEmpty) {
            // Get existing columns
            final tableColumns = await db.rawQuery(
              "PRAGMA table_info($tableName)",
            );
            final existingColumns = tableColumns
                .map((col) => col['name'] as String)
                .toList();

            // Add missing columns
            for (final columnName in columns) {
              if (!existingColumns.contains(columnName)) {
                await db.execute(
                  'ALTER TABLE $tableName ADD COLUMN $columnName TEXT',
                );
                Logger.debugLog(
                  '✅ Added $columnName column to $tableName table',
                );
              }
            }
          }
        }

        Logger.debugLog(
          '✅ Successfully added infra engineer and owner columns to sites tables',
        );
      } catch (e) {
        Logger.errorLog('❌ Error adding infra engineer and owner columns: $e');
      }
    }

    if (oldVersion < 12) {
      // For version 12, create incident checklist table
      try {
        await db.execute('''
          CREATE TABLE incident_checklist_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            iclm_id INTEGER NOT NULL,
            incident_item_type TEXT NOT NULL,
            checklist_desc TEXT,
            resp_type TEXT NOT NULL,
            cl_order INTEGER NOT NULL,
            activity_type TEXT NOT NULL,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_incident_checklist_data_site_id ON incident_checklist_data(site_id)',
        );

        Logger.debugLog('✅ Successfully created incident_checklist_data table');
      } catch (e) {
        Logger.errorLog('❌ Error creating incident_checklist_data table: $e');
      }
    }

    if (oldVersion < 13) {
      // For version 13, create incident sites table
      try {
        await db.execute('''
          CREATE TABLE incident_sites_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            entity_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            cluster_district_id INTEGER,
            cluster_district_name TEXT,
            circle_state_id INTEGER,
            circle_state_name TEXT,
            client_id INTEGER,
            client_name TEXT,
            oem TEXT,
            oem_id INTEGER,
            self TEXT,
            self_id INTEGER,
            activity_type TEXT NOT NULL,
            checklist_data TEXT,
            infra_district_engineer_name TEXT,
            infra_district_engineer_contact_no TEXT,
            owner_name TEXT,
            owner_contact_no TEXT,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_incident_sites_data_site_id ON incident_sites_data(site_id)',
        );

        Logger.debugLog('✅ Successfully created incident_sites_data table');
      } catch (e) {
        Logger.errorLog('❌ Error creating incident_sites_data table: $e');
      }
    }

    if (oldVersion < 15) {
      // For version 15, add latitude and longitude columns to all site tables
      try {
        final tables = ['cm_sites_data', 'sv_sites_data', 'gi_sites_data', 'incident_sites_data', 'au_sites_data'];
        
        for (final tableName in tables) {
          // Check if table exists
          final tableInfo = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'",
          );

          if (tableInfo.isNotEmpty) {
            // Get existing columns
            final tableColumns = await db.rawQuery(
              "PRAGMA table_info($tableName)",
            );
            final existingColumns = tableColumns
                .map((col) => col['name'] as String)
                .toList();

            // Add latitude column if it doesn't exist
            if (!existingColumns.contains('latitude')) {
              await db.execute(
                'ALTER TABLE $tableName ADD COLUMN latitude TEXT',
              );
              Logger.debugLog(
                '✅ Added latitude column to $tableName table',
              );
            }

            // Add longitude column if it doesn't exist
            if (!existingColumns.contains('longitude')) {
              await db.execute(
                'ALTER TABLE $tableName ADD COLUMN longitude TEXT',
              );
              Logger.debugLog(
                '✅ Added longitude column to $tableName table',
              );
            }
          }
        }

        Logger.debugLog(
          '✅ Successfully added latitude and longitude columns to all site tables',
        );
      } catch (e) {
        Logger.errorLog('❌ Error adding latitude and longitude columns: $e');
      }
    }

    if (oldVersion < 16) {
      // For version 16, create au_sites_data table
      try {
        await db.execute('''
          CREATE TABLE au_sites_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            entity_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            cluster_district_id INTEGER,
            cluster_district_name TEXT,
            circle_state_id INTEGER,
            circle_state_name TEXT,
            client_id INTEGER,
            client_name TEXT,
            oem TEXT,
            oem_id INTEGER,
            self TEXT,
            self_id INTEGER,
            activity_type TEXT NOT NULL,
            checklist_data TEXT,
            infra_district_engineer_name TEXT,
            infra_district_engineer_contact_no TEXT,
            owner_name TEXT,
            owner_contact_no TEXT,
            latitude TEXT,
            longitude TEXT,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_au_sites_data_site_id ON au_sites_data(site_id)',
        );

        Logger.debugLog('✅ Successfully created au_sites_data table');
      } catch (e) {
        Logger.errorLog('❌ Error creating au_sites_data table: $e');
      }
    }

    if (oldVersion < 14) {
      // For version 14, add dependent_elements column to cm_checklist_data table
      try {
        // Check if column already exists
        final tableInfo = await db.rawQuery("PRAGMA table_info(cm_checklist_data)");
        final existingColumns = tableInfo
            .map((col) => col['name'] as String)
            .toList();

        if (!existingColumns.contains('dependent_elements')) {
          await db.execute(
            'ALTER TABLE cm_checklist_data ADD COLUMN dependent_elements TEXT',
          );
          Logger.debugLog(
            '✅ Added dependent_elements column to cm_checklist_data table',
          );
        }
      } catch (e) {
        Logger.errorLog('❌ Error adding dependent_elements column: $e');
      }
    }
  }

  /// Clear all data
  Future<void> clearAllData() async {
    final db = await database;

    await db.transaction((txn) async {
      // Clear raw API data
      await txn.delete('raw_api_data');

      // Clear sites data tables
      await txn.delete('sv_sites_data');
      await txn.delete('gi_sites_data');
      await txn.delete('cm_sites_data');

      // Clear checklist data tables
      await txn.delete('gen_ins_checklist_data');
      await txn.delete('cm_checklist_data');
      await txn.delete('incident_checklist_data');
      await txn.delete('incident_sites_data');
      await txn.delete('au_sites_data');


    });

    Logger.debugLog(
      '✅ All data cleared (raw_api_data, sv_sites_data, gi_sites_data, cm_sites_data, gen_ins_checklist_data, cm_checklist_data)',
    );
  }

  /// Drop and recreate database with all tables
  Future<void> dropAndRecreateDatabase() async {
    try {
      Logger.debugLog('🗑️ Dropping and recreating database');

      // Close existing database connection
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Get database path
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);

      // Delete the database file
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        Logger.debugLog('🗑️ Database file deleted');
      }

      // Recreate database by calling _initDatabase
      _database = await _initDatabase();
      Logger.debugLog('✅ Database recreated with all tables');
    } catch (e) {
      Logger.errorLog('❌ Error dropping and recreating database: $e');
      // Reset database instance to force recreation on next access
      _database = null;
      rethrow;
    }
  }

  /// Save raw API data as-is
  Future<bool> saveRawApiData({
    required String siteAuditSchId,
    required String siteType,
    required String auditSchId,
    required String pvTicketId,
    required String siteCode,
    required String cluster,
    required String operator,
    required String raisedDt,
    required String dueDt,
    required String status,
    required ActivityTypeEnum activityType,
    bool isDownloaded = false,
    required double latitude,
    required double longitude,
    required Map<String, dynamic> apiData,
  }) async {
    try {
      final db = await database;

      await db.transaction((txn) async {
        // Clear existing data for this site
        await txn.delete(
          'raw_api_data',
          where: 'site_audit_sch_id = ?',
          whereArgs: [siteAuditSchId],
        );

        // Insert raw API data
        await txn.insert('raw_api_data', {
          'site_audit_sch_id': siteAuditSchId,
          'site_type': siteType,
          'audit_sch_id': auditSchId,
          'activity_type': activityType.value,
          'pv_ticket_id': pvTicketId,
          'site_code': siteCode,
          'cluster': cluster,
          'operator': operator,
          'raised_dt': raisedDt,
          'due_dt': dueDt,
          'status': status,
          'is_downloaded': isDownloaded ? 1 : 0,
          'latitude': latitude,
          'longitude': longitude,
          'api_data': jsonEncode(apiData),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      });

      Logger.debugLog('✅ Raw API data saved for site $siteAuditSchId');
      return true;
    } catch (e) {
      Logger.errorLog(
        "Exception while saving site data to sqlite $siteAuditSchId $e",
      );
      return false;
    }
  }

  /// Update raw API data as-is
  Future<bool> updateRawApiData({
    required String siteAuditSchId,
    required Map<String, dynamic> apiData,
  }) async {
    try {
      final db = await database;

      // Update only the api_data and updated_at fields for the given site_audit_sch_id
      final result = await db.update(
        'raw_api_data',
        {
          'api_data': jsonEncode(apiData),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'site_audit_sch_id = ?',
        whereArgs: [siteAuditSchId],
      );

      if (result > 0) {
        Logger.debugLog('✅ Raw API data updated for site $siteAuditSchId');
        return true;
      } else {
        Logger.debugLog(
          '⚠️ No record found to update for site $siteAuditSchId',
        );
        return false;
      }
    } catch (e) {
      Logger.errorLog(
        "Exception while updating site data to sqlite $siteAuditSchId $e",
      );
      return false;
    }
  }

  /// Update status field in raw_api_data table
  Future<bool> updateRawApiDataStatus({
    required String siteAuditSchId,
    required String status,
  }) async {
    try {
      final db = await database;

      // Update only the status and updated_at fields for the given site_audit_sch_id
      final result = await db.update(
        'raw_api_data',
        {'status': status, 'updated_at': DateTime.now().toIso8601String()},
        where: 'site_audit_sch_id = ?',
        whereArgs: [siteAuditSchId],
      );

      if (result > 0) {
        Logger.debugLog('✅ Status updated to $status for site $siteAuditSchId');
        return true;
      } else {
        Logger.debugLog(
          '⚠️ No record found to update status for site $siteAuditSchId',
        );
        return false;
      }
    } catch (e) {
      Logger.errorLog(
        "Exception while updating status in sqlite $siteAuditSchId $e",
      );
      return false;
    }
  }

  /// Get raw API data
  Future<RawApiDataModel?> getRawApiData(String siteAuditSchId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'raw_api_data',
        where: 'site_audit_sch_id = ?',
        whereArgs: [siteAuditSchId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final data = maps.first;
        return RawApiDataModel(
          siteAuditSchId: data['site_audit_sch_id'],
          siteType: data['site_type'],
          auditSchId: data['audit_sch_id'],
          activityType: ActivityTypeEnum.fromString(data['activity_type']),
          pvTicketId: data['pv_ticket_id'],
          siteCode: data['site_code'],
          cluster: data['cluster'],
          operator: data['operator'],
          raisedDt: data['raised_dt'],
          dueDt: data['due_dt'],
          status: data['status'],
          isDownloaded: data['is_downloaded'] == 1 ? true : false,
          latitude: data['latitude'],
          longitude: data['longitude'],
          apiData: jsonDecode(data['api_data']),
        );
      }
      return null;
    } catch (e) {
      Logger.errorLog(
        "Exception while saving site data to sqlite $siteAuditSchId $e",
      );
      return null;
    }
  }

  /// Get all downloaded tickets
  Future<List<RawApiDataModel>> getAllDownloadedTickets() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'raw_api_data',
        where: 'is_downloaded = ?',
        whereArgs: [1],
        orderBy: 'created_at DESC',
      );

      return maps
          .map(
            (data) => RawApiDataModel(
              siteAuditSchId: data['site_audit_sch_id'],
              siteType: data['site_type'],
              auditSchId: data['audit_sch_id'],
              activityType: ActivityTypeEnum.fromString(data['activity_type']),
              pvTicketId: data['pv_ticket_id'],
              siteCode: data['site_code'],
              cluster: data['cluster'],
              operator: data['operator'],
              raisedDt: data['raised_dt'],
              dueDt: data['due_dt'],
              status: data['status'],
              isDownloaded: data['is_downloaded'] == 1 ? true : false,
              latitude: data['latitude'],
              longitude: data['longitude'],
              apiData: jsonDecode(data['api_data']),
            ),
          )
          .toList();
    } catch (e) {
      Logger.errorLog("Exception while getting all downloaded tickets $e");
      return [];
    }
  }

  /// Save CM site data to SQLite with checklist data
  Future<bool> saveCMSiteDataWithChecklist({
    required int siteId,
    required int entityId,
    required String siteCode,
    required String siteName,
    required int? clusterDistrictId,
    required String? clusterDistrictName,
    required int? circleStateId,
    required String? circleStateName,
    required int? clientId,
    required String? clientName,
    required String? oem,
    required int? oemId,
    required String? self,
    required int? selfId,
    required String activityType,
    Map<String, dynamic>? checklistData,
    String? infraDistrictEngineerName,
    String? infraDistrictEngineerContactNo,
    String? ownerName,
    String? ownerContactNo,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      // Determine table name based on activity type
      String tableName;
      if (activityType.toLowerCase() == 'sv' ||
          activityType.toLowerCase().contains('sitevisit')) {
        tableName = 'sv_sites_data';
      } else if (activityType.toLowerCase() == 'gi' ||
          activityType.toLowerCase().contains('generalinspection')) {
        tableName = 'gi_sites_data';
      } else if (activityType.toLowerCase() == 'cm' ||
          activityType.toLowerCase().contains('correctivemaintenance')) {
        tableName = 'cm_sites_data';
      } else {
        tableName = 'cm_sites_data'; // Default fallback
      }

      // Convert checklist data to JSON string if provided
      String? checklistDataJson;
      if (checklistData != null && checklistData.isNotEmpty) {
        try {
          Logger.infoLog(
            '📝 Attempting to encode checklist data for site: $siteName',
          );
          Logger.infoLog(
            '📝 Checklist data keys: ${checklistData.keys.toList()}',
          );
          Logger.infoLog(
            '📝 Checklist data type: ${checklistData.runtimeType}',
          );

          checklistDataJson = jsonEncode(checklistData);

          Logger.infoLog(
            '✅ Successfully encoded checklist data (${checklistDataJson.length} characters)',
          );
        } catch (jsonError) {
          Logger.errorLog(
            '❌ Error encoding checklist data to JSON: $jsonError',
          );
          Logger.errorLog(
            '❌ Checklist data structure: ${checklistData.toString()}',
          );
          // Continue without checklist data rather than failing completely
          checklistDataJson = null;
        }
      }

      await db.insert(tableName, {
        'site_id': siteId,
        'entity_id': entityId,
        'site_code': siteCode,
        'site_name': siteName,
        'cluster_district_id': clusterDistrictId,
        'cluster_district_name': clusterDistrictName,
        'circle_state_id': circleStateId,
        'circle_state_name': circleStateName,
        'client_id': clientId,
        'client_name': clientName,
        'oem': oem,
        'oem_id': oemId,
        'self': self,
        'self_id': selfId,
        'activity_type': activityType,
        'checklist_data':
            checklistDataJson, // Store checklist data in the same table
        'infra_district_engineer_name': infraDistrictEngineerName,
        'infra_district_engineer_contact_no': infraDistrictEngineerContactNo,
        'owner_name': ownerName,
        'owner_contact_no': ownerContactNo,
        'is_downloaded': 1,
        'downloaded_at': now,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      Logger.debugLog(
        '✅ Site data saved successfully with checklist to $tableName',
      );
      return true;
    } catch (e) {
      Logger.errorLog('❌ Error saving site data: $e');
      Logger.errorLog('❌ Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Save CM site data to SQLite
  Future<bool> saveCMSiteData({
    required int siteId,
    required int entityId,
    required String siteCode,
    required String siteName,
    required int? clusterDistrictId,
    required String? clusterDistrictName,
    required int? circleStateId,
    required String? circleStateName,
    required int? clientId,
    required String? clientName,
    required String? oem,
    required int? oemId,
    required String? self,
    required int? selfId,
    required String activityType,
    String? infraDistrictEngineerName,
    String? infraDistrictEngineerContactNo,
    String? ownerName,
    String? ownerContactNo,
    String? latitude,
    String? longitude,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      // Determine table name based on activity type
      String tableName;
      if (activityType.toLowerCase() == 'sv' ||
          activityType.toLowerCase().contains('sitevisit')) {
        tableName = 'sv_sites_data';
      } else if (activityType.toLowerCase() == 'gi' ||
          activityType.toLowerCase().contains('generalinspection')) {
        tableName = 'gi_sites_data';
      } else if (activityType.toLowerCase() == 'cm' ||
          activityType.toLowerCase().contains('correctivemaintenance')) {
        tableName = 'cm_sites_data';
      } else if (activityType.toLowerCase() == 'incident' ||
          activityType.toLowerCase().contains('incident')) {
        tableName = 'incident_sites_data';
        // Ensure incident_sites_data table exists
        await _ensureIncidentSitesTableExists(db);
      } else if (activityType.toLowerCase() == 'au' ||
          activityType.toLowerCase().contains('assetupload') ||
          activityType.toLowerCase().contains('asset upload')) {
        tableName = 'au_sites_data';
        // Ensure au_sites_data table exists
        await _ensureAUSitesTableExists(db);
      } else {
        tableName = 'cm_sites_data'; // Default fallback
      }

      // Ensure latitude/longitude columns exist (safety check for migration)
      await _ensureLatitudeLongitudeColumns(db, tableName);

      final Map<String, dynamic> insertData = {
        'site_id': siteId,
        'entity_id': entityId,
        'site_code': siteCode,
        'site_name': siteName,
        'cluster_district_id': clusterDistrictId,
        'cluster_district_name': clusterDistrictName,
        'circle_state_id': circleStateId,
        'circle_state_name': circleStateName,
        'client_id': clientId,
        'client_name': clientName,
        'oem': oem,
        'oem_id': oemId,
        'self': self,
        'self_id': selfId,
        'activity_type': activityType,
        'infra_district_engineer_name': infraDistrictEngineerName,
        'infra_district_engineer_contact_no': infraDistrictEngineerContactNo,
        'owner_name': ownerName,
        'owner_contact_no': ownerContactNo,
        'is_downloaded': 1,
        'downloaded_at': now,
        'created_at': now,
        'updated_at': now,
      };

      // Only add latitude/longitude if columns exist (they should after _ensureLatitudeLongitudeColumns)
      final tableColumns = await db.rawQuery("PRAGMA table_info($tableName)");
      final existingColumns = tableColumns.map((col) => col['name'] as String).toList();
      
      if (existingColumns.contains('latitude')) {
        insertData['latitude'] = latitude;
      }
      if (existingColumns.contains('longitude')) {
        insertData['longitude'] = longitude;
      }

      await db.insert(tableName, insertData, conflictAlgorithm: ConflictAlgorithm.replace);

      Logger.debugLog('✅ Site data saved successfully to $tableName');
      return true;
    } catch (e) {
      Logger.errorLog('❌ Error saving site data: $e');
      return false;
    }
  }

  /// Save General Inspection checklist data to SQLite
  Future<bool> saveGenInsCheckListData({
    required int siteId,
    required String siteCode,
    required String siteName,
    required List<GenInsCheckListData> checklistData,
    required String activityType,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      // Check if table exists, if not create it
      await _ensureGenInsChecklistTableExists(db);

      // Clear existing data for this site to avoid conflicts
      await db.delete(
        'gen_ins_checklist_data',
        where: 'site_id = ?',
        whereArgs: [siteId],
      );
      Logger.debugLog(
        '🗑️ Cleared existing checklist data for site_id: $siteId',
      );

      // Save each checklist item in a transaction
      Logger.debugLog(
        '📝 Saving ${checklistData.length} checklist items to database',
      );

      await db.transaction((txn) async {
        for (int i = 0; i < checklistData.length; i++) {
          final item = checklistData[i];
          try {
            Logger.debugLog(
              '📝 Saving item ${i + 1}/${checklistData.length}: ${item.checklistDesc} (giclm_id: ${item.giclmId})',
            );

            String? respTypeValueMapJson;
            if (item.respTypeValueMap != null) {
              try {
                // Use valueAsString which handles both Map (encodes to JSON) and String (returns as-is) cases
                respTypeValueMapJson = item.respTypeValueMap!.valueAsString;
                Logger.debugLog(
                  '📝 resp_type_value_map (JSON string): $respTypeValueMapJson',
                );
              } catch (jsonError) {
                Logger.errorLog(
                  '❌ JSON serialization error for item ${item.checklistDesc}: $jsonError',
                );
                respTypeValueMapJson = null;
              }
            } else {
              Logger.debugLog('📝 resp_type_value_map: null');
            }

            // Encode dependent_elements to JSON string
            String? dependentElementsJson;
            if (item.dependentElements != null &&
                item.dependentElements!.isNotEmpty) {
              try {
                dependentElementsJson = jsonEncode(
                  item.dependentElements!.map((e) => e.toJson()).toList(),
                );
                Logger.debugLog(
                  '📝 dependent_elements (JSON string): $dependentElementsJson',
                );
              } catch (jsonError) {
                Logger.errorLog(
                  '❌ JSON serialization error for dependent_elements: $jsonError',
                );
                dependentElementsJson = null;
              }
            }

            final insertData = {
              'site_id': siteId,
              'site_code': siteCode,
              'site_name': siteName,
              'giclm_id': item.giclmId,
              'site_domain_id': item.siteDomainId,
              'checklist_desc': item.checklistDesc,
              'resp_type': item.respType,
              'resp_type_value_map': respTypeValueMapJson,
              'is_mandatory': item.isMandatory ? 1 : 0,
              'cl_order': item.clOrder,
              'flag': item.flag,
              'dependent_elements': dependentElementsJson,
              'activity_type': activityType,
              'is_downloaded': 1,
              'downloaded_at': now,
              'created_at': now,
              'updated_at': now,
            };

            Logger.debugLog(
              '📝 Insert data for ${item.checklistDesc}: $insertData',
            );

            final result = await txn.insert(
              'gen_ins_checklist_data',
              insertData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            Logger.debugLog(
              '✅ Successfully saved item ${i + 1}: ${item.checklistDesc} (rowId: $result)',
            );
          } catch (itemError) {
            Logger.errorLog(
              '❌ Error saving item ${i + 1} (${item.checklistDesc}): $itemError',
            );
            // Continue with other items even if one fails
          }
        }
      });

      // Verify what was actually saved
      final savedItems = await db.query(
        'gen_ins_checklist_data',
        where: 'site_id = ?',
        whereArgs: [siteId],
        orderBy: 'cl_order ASC',
      );

      Logger.debugLog(
        '🔍 Verification: ${savedItems.length} items saved to database for site_id: $siteId',
      );
      for (final savedItem in savedItems) {
        Logger.debugLog(
          '🔍 Saved: ${savedItem['checklist_desc']} (giclm_id: ${savedItem['giclm_id']}, cl_order: ${savedItem['cl_order']})',
        );
      }

      Logger.debugLog(
        '✅ General Inspection checklist data saved successfully to SQLite',
      );
      return true;
    } catch (e) {
      Logger.errorLog('❌ Error saving General Inspection checklist data: $e');
      return false;
    }
  }

  /// Ensure the gen_ins_checklist_data table exists
  Future<void> _ensureGenInsChecklistTableExists(Database db) async {
    try {
      // Check if table exists
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='gen_ins_checklist_data'",
      );

      if (result.isEmpty) {
        Logger.debugLog('Creating gen_ins_checklist_data table...');

        // Create the table
        await db.execute('''
          CREATE TABLE gen_ins_checklist_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            giclm_id INTEGER NOT NULL,
            site_domain_id INTEGER NOT NULL,
            checklist_desc TEXT NOT NULL,
            resp_type TEXT NOT NULL,
            resp_type_value_map TEXT,
            is_mandatory INTEGER DEFAULT 0,
            cl_order INTEGER NOT NULL,
            flag TEXT,
            dependent_elements TEXT,
            activity_type TEXT NOT NULL,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        // Create index
        await db.execute(
          'CREATE INDEX idx_gen_ins_checklist_data_site_id ON gen_ins_checklist_data(site_id)',
        );

        Logger.debugLog('✅ gen_ins_checklist_data table created successfully');
      } else {
        Logger.debugLog('✅ gen_ins_checklist_data table already exists');

        // Check if new columns exist and add them if missing (migration)
        final tableInfo = await db.rawQuery(
          "PRAGMA table_info(gen_ins_checklist_data)",
        );
        final columnNames = tableInfo
            .map((row) => row['name'] as String)
            .toList();

        // Add flag column if missing
        if (!columnNames.contains('flag')) {
          Logger.debugLog(
            'Adding flag column to gen_ins_checklist_data table...',
          );
          await db.execute(
            'ALTER TABLE gen_ins_checklist_data ADD COLUMN flag TEXT',
          );
        }

        // Add dependent_elements column if missing
        if (!columnNames.contains('dependent_elements')) {
          Logger.debugLog(
            'Adding dependent_elements column to gen_ins_checklist_data table...',
          );
          await db.execute(
            'ALTER TABLE gen_ins_checklist_data ADD COLUMN dependent_elements TEXT',
          );
        }
      }
    } catch (e) {
      Logger.errorLog(
        '❌ Error ensuring gen_ins_checklist_data table exists: $e',
      );
      rethrow;
    }
  }

  /// Get CM site data from SQLite
  Future<Map<String, dynamic>?> getCMSiteData(int siteId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'cm_sites_data',
        where: 'site_id = ?',
        whereArgs: [siteId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return maps.first;
      }
      return null;
    } catch (e) {
      Logger.errorLog('❌ Error getting CM site data: $e');
      return null;
    }
  }

  /// Get CM site data with checklist from SQLite
  Future<Map<String, dynamic>?> getCMSiteDataWithChecklist(int siteId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'cm_sites_data',
        where: 'site_id = ?',
        whereArgs: [siteId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final siteData = Map<String, dynamic>.from(maps.first);

        // Parse checklist_data from JSON string
        if (siteData['checklist_data'] != null) {
          try {
            final checklistData = jsonDecode(siteData['checklist_data']);
            siteData['checklist_items'] = checklistData;
          } catch (e) {
            Logger.errorLog('❌ Error parsing checklist_data: $e');
          }
        }

        return siteData;
      }
      return null;
    } catch (e) {
      Logger.errorLog('❌ Error getting CM site data with checklist: $e');
      return null;
    }
  }

  /// Get General Inspection checklist data from SQLite
  Future<List<GenInsCheckListData>> getGIChecklistData(int siteId) async {
    try {
      final db = await database;

      // Ensure table exists before querying
      await _ensureGenInsChecklistTableExists(db);

      final List<Map<String, dynamic>> maps = await db.query(
        'gen_ins_checklist_data',
        where: 'site_id = ?',
        whereArgs: [siteId],
        orderBy: 'cl_order ASC',
      );

      final List<GenInsCheckListData> checklistItems = [];
      for (final map in maps) {
        try {
          // Parse resp_type_value_map correctly
          Map<String, dynamic>? respTypeValueMap;
          if (map['resp_type_value_map'] != null) {
            try {
              // The resp_type_value_map is stored as a JSON string, so we need to parse it
              jsonDecode(
                map['resp_type_value_map'],
              ); // Validate it's valid JSON
              respTypeValueMap = {
                'type': 'jsonb', // Match API format
                'value': map['resp_type_value_map'], // The original JSON string
                'null': false,
              };
            } catch (e) {
              Logger.errorLog('❌ Error parsing resp_type_value_map: $e');
              respTypeValueMap = null;
            }
          }

          final item = GenInsCheckListData.fromJson({
            'giclm_id': map['giclm_id'],
            'site_domain_id': map['site_domain_id'],
            'checklist_desc': map['checklist_desc'],
            'resp_type': map['resp_type'],
            'resp_type_value_map': respTypeValueMap,
            'is_mandatory': map['is_mandatory'] == 1,
            'cl_order': map['cl_order'],
            'flag': map['flag'],
            'dependent_elements': map['dependent_elements'],
          });
          checklistItems.add(item);
        } catch (e) {
          Logger.errorLog('❌ Error parsing GI checklist item: $e');
          continue;
        }
      }

      Logger.debugLog(
        '✅ Retrieved ${checklistItems.length} GI checklist items from SQLite',
      );
      return checklistItems;
    } catch (e) {
      Logger.errorLog('❌ Error getting GI checklist data: $e');
      return [];
    }
  }

  /// Check if GI checklist is downloaded for a site
  Future<bool> isGIChecklistDownloaded(int siteId) async {
    try {
      final db = await database;

      // Ensure table exists before querying
      await _ensureGenInsChecklistTableExists(db);

      final List<Map<String, dynamic>> maps = await db.query(
        'gen_ins_checklist_data',
        where: 'site_id = ? AND is_downloaded = 1',
        whereArgs: [siteId],
        limit: 1,
      );

      return maps.isNotEmpty;
    } catch (e) {
      Logger.errorLog('❌ Error checking if GI checklist is downloaded: $e');
      return false;
    }
  }

  /// Save incident checklist data to SQLite
  Future<bool> saveIncidentChecklistData({
    required int siteId,
    required String siteCode,
    required String siteName,
    required Map<String, List<Map<String, dynamic>>> checklistData,
    required String activityType,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      // Check if table exists, if not create it
      await _ensureIncidentChecklistTableExists(db);

      // Clear existing data for this site to avoid conflicts
      await db.delete(
        'incident_checklist_data',
        where: 'site_id = ?',
        whereArgs: [siteId],
      );
      Logger.debugLog(
        '🗑️ Cleared existing incident checklist data for site_id: $siteId',
      );

      // Save each checklist item in a transaction
      int totalItems = 0;
      for (final entry in checklistData.entries) {
        totalItems += entry.value.length;
      }
      Logger.debugLog(
        '📝 Saving $totalItems incident checklist items to database',
      );
      print('📝 Saving $totalItems incident checklist items to database');
      print('📝 Checklist data keys: ${checklistData.keys.toList()}');

      if (totalItems == 0) {
        Logger.errorLog('❌ No checklist items to save!');
        print('❌ No checklist items to save!');
        return false;
      }

      await db.transaction((txn) async {
        int itemIndex = 0;
        for (final entry in checklistData.entries) {
          final incidentItemType = entry.key;
          final items = entry.value;
          print('📝 Processing item type: $incidentItemType with ${items.length} items');

          for (final item in items) {
            try {
              itemIndex++;
              // Try different possible key names
              final iclmId = item['iclm_id'] as int? ?? 
                           item['iclmId'] as int? ?? 0;
              final checklistDesc = item['checklist_desc']?.toString() ?? 
                                  item['checklistDesc']?.toString();
              final respType = item['resp_type']?.toString() ?? 
                             item['respType']?.toString() ?? 'CHECKBOX';
              final clOrder = item['cl_order'] as int? ?? 
                            item['clOrder'] as int? ?? 0;

              print('📝 Item $itemIndex: iclmId=$iclmId, desc=$checklistDesc, order=$clOrder');
              
              if (iclmId == 0) {
                Logger.errorLog('❌ Warning: iclm_id is 0 for item $itemIndex. Item data: $item');
                print('❌ Warning: iclm_id is 0 for item $itemIndex. Item data: $item');
              }

              Logger.debugLog(
                '📝 Saving item $itemIndex/$totalItems: $checklistDesc (iclm_id: $iclmId)',
              );

              final insertData = {
                'site_id': siteId,
                'site_code': siteCode,
                'site_name': siteName,
                'iclm_id': iclmId,
                'incident_item_type': incidentItemType,
                'checklist_desc': checklistDesc,
                'resp_type': respType,
                'cl_order': clOrder,
                'activity_type': activityType,
                'is_downloaded': 1,
                'downloaded_at': now,
                'created_at': now,
                'updated_at': now,
              };

              Logger.debugLog('📝 Insert data for $checklistDesc: $insertData');

              final result = await txn.insert(
                'incident_checklist_data',
                insertData,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              Logger.debugLog(
                '✅ Successfully saved item $itemIndex: $checklistDesc (rowId: $result)',
              );
            } catch (itemError) {
              Logger.errorLog(
                '❌ Error saving item $itemIndex (${item['checklist_desc']}): $itemError',
              );
              // Continue with other items even if one fails
            }
          }
        }
      });

      // Verify what was actually saved
      final savedItems = await db.query(
        'incident_checklist_data',
        where: 'site_id = ?',
        whereArgs: [siteId],
        orderBy: 'cl_order ASC',
      );

      Logger.debugLog(
        '🔍 Verification: ${savedItems.length} items saved to database for site_id: $siteId',
      );
      print('🔍 Verification: ${savedItems.length} items saved to database for site_id: $siteId');

      if (savedItems.isEmpty) {
        Logger.errorLog('❌ No items were saved to database for site_id: $siteId');
        print('❌ No items were saved to database for site_id: $siteId');
        Logger.errorLog('❌ Checklist data had ${checklistData.length} item types');
        print('❌ Checklist data had ${checklistData.length} item types');
      }

      return savedItems.isNotEmpty;
    } catch (e, stackTrace) {
      Logger.errorLog('❌ Error saving incident checklist data: $e');
      Logger.errorLog('❌ Stack trace: $stackTrace');
      print('❌ Error saving incident checklist data: $e');
      print('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get incident checklist data from SQLite
  Future<Map<String, List<Map<String, dynamic>>>> getIncidentChecklistData(
    int siteId,
  ) async {
    try {
      final db = await database;

      // Ensure table exists before querying
      await _ensureIncidentChecklistTableExists(db);

      final List<Map<String, dynamic>> maps = await db.query(
        'incident_checklist_data',
        where: 'site_id = ?',
        whereArgs: [siteId],
        orderBy: 'cl_order ASC',
      );

      final Map<String, List<Map<String, dynamic>>> checklistData = {};

      for (final map in maps) {
        try {
          final incidentItemType = map['incident_item_type'] as String;
          final item = {
            'iclm_id': map['iclm_id'],
            'incident_item_type': incidentItemType,
            'checklist_desc': map['checklist_desc'],
            'resp_type': map['resp_type'],
            'cl_order': map['cl_order'],
          };

          if (!checklistData.containsKey(incidentItemType)) {
            checklistData[incidentItemType] = [];
          }
          checklistData[incidentItemType]!.add(item);
        } catch (e) {
          Logger.errorLog('❌ Error parsing incident checklist item: $e');
          continue;
        }
      }

      Logger.debugLog(
        '✅ Retrieved ${maps.length} incident checklist items from SQLite',
      );
      return checklistData;
    } catch (e) {
      Logger.errorLog('❌ Error getting incident checklist data: $e');
      return {};
    }
  }

  /// Check if incident checklist is downloaded for a site
  Future<bool> isIncidentChecklistDownloaded(int siteId) async {
    try {
      final db = await database;

      // Ensure table exists before querying
      await _ensureIncidentChecklistTableExists(db);

      final List<Map<String, dynamic>> maps = await db.query(
        'incident_checklist_data',
        where: 'site_id = ? AND is_downloaded = 1',
        whereArgs: [siteId],
        limit: 1,
      );

      return maps.isNotEmpty;
    } catch (e) {
      Logger.errorLog(
        '❌ Error checking if incident checklist is downloaded: $e',
      );
      return false;
    }
  }

  /// Ensure incident checklist table exists
  Future<void> _ensureIncidentChecklistTableExists(Database db) async {
    try {
      // Check if table exists
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='incident_checklist_data'",
      );

      if (result.isEmpty) {
        Logger.debugLog('Creating incident_checklist_data table...');

        // Create the table
        await db.execute('''
          CREATE TABLE incident_checklist_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            iclm_id INTEGER NOT NULL,
            incident_item_type TEXT NOT NULL,
            checklist_desc TEXT,
            resp_type TEXT NOT NULL,
            cl_order INTEGER NOT NULL,
            activity_type TEXT NOT NULL,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_incident_checklist_data_site_id ON incident_checklist_data(site_id)',
        );

        Logger.debugLog('✅ Successfully created incident_checklist_data table');
      }
    } catch (e) {
      Logger.errorLog(
        '❌ Error ensuring incident_checklist_data table exists: $e',
      );
    }
  }

  /// Ensure latitude and longitude columns exist in a table
  Future<void> _ensureLatitudeLongitudeColumns(Database db, String tableName) async {
    try {
      // Check if table exists
      final tableInfo = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'",
      );

      if (tableInfo.isEmpty) {
        Logger.debugLog('⚠️ Table $tableName does not exist, skipping column check');
        return;
      }

      // Get existing columns
      final tableColumns = await db.rawQuery("PRAGMA table_info($tableName)");
      final existingColumns = tableColumns
          .map((col) => col['name'] as String)
          .toList();

      // Add latitude column if it doesn't exist
      if (!existingColumns.contains('latitude')) {
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN latitude TEXT',
        );
        Logger.debugLog('✅ Added latitude column to $tableName table');
      }

      // Add longitude column if it doesn't exist
      if (!existingColumns.contains('longitude')) {
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN longitude TEXT',
        );
        Logger.debugLog('✅ Added longitude column to $tableName table');
      }
    } catch (e) {
      Logger.errorLog('❌ Error ensuring latitude/longitude columns in $tableName: $e');
      // Don't throw - allow the insert to continue without these columns if migration fails
    }
  }

  /// Ensure Asset Upload sites table exists
  Future<void> _ensureAUSitesTableExists(Database db) async {
    try {
      // Check if table exists
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='au_sites_data'",
      );

      if (result.isEmpty) {
        Logger.debugLog('Creating au_sites_data table...');

        // Create the table
        await db.execute('''
          CREATE TABLE au_sites_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            entity_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            cluster_district_id INTEGER,
            cluster_district_name TEXT,
            circle_state_id INTEGER,
            circle_state_name TEXT,
            client_id INTEGER,
            client_name TEXT,
            oem TEXT,
            oem_id INTEGER,
            self TEXT,
            self_id INTEGER,
            activity_type TEXT NOT NULL,
            checklist_data TEXT,
            infra_district_engineer_name TEXT,
            infra_district_engineer_contact_no TEXT,
            owner_name TEXT,
            owner_contact_no TEXT,
            latitude TEXT,
            longitude TEXT,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_au_sites_data_site_id ON au_sites_data(site_id)',
        );

        Logger.debugLog('✅ Successfully created au_sites_data table');
      }
    } catch (e) {
      Logger.errorLog('❌ Error ensuring au_sites_data table exists: $e');
    }
  }

  /// Ensure incident sites table exists
  Future<void> _ensureIncidentSitesTableExists(Database db) async {
    try {
      // Check if table exists
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='incident_sites_data'",
      );

      if (result.isEmpty) {
        Logger.debugLog('Creating incident_sites_data table...');

        // Create the table
        await db.execute('''
          CREATE TABLE incident_sites_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id INTEGER NOT NULL,
            entity_id INTEGER NOT NULL,
            site_code TEXT NOT NULL,
            site_name TEXT NOT NULL,
            cluster_district_id INTEGER,
            cluster_district_name TEXT,
            circle_state_id INTEGER,
            circle_state_name TEXT,
            client_id INTEGER,
            client_name TEXT,
            oem TEXT,
            oem_id INTEGER,
            self TEXT,
            self_id INTEGER,
            activity_type TEXT NOT NULL,
            checklist_data TEXT,
            infra_district_engineer_name TEXT,
            infra_district_engineer_contact_no TEXT,
            owner_name TEXT,
            owner_contact_no TEXT,
            is_downloaded INTEGER DEFAULT 1,
            downloaded_at TEXT,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_incident_sites_data_site_id ON incident_sites_data(site_id)',
        );

        Logger.debugLog('✅ Successfully created incident_sites_data table');
      }
    } catch (e) {
      Logger.errorLog('❌ Error ensuring incident_sites_data table exists: $e');
    }
  }

  /// Check if CM site is downloaded
  Future<bool> isCMSiteDownloaded(int siteId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'cm_sites_data',
        columns: ['is_downloaded'],
        where: 'site_id = ?',
        whereArgs: [siteId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return maps.first['is_downloaded'] == 1;
      }
      return false;
    } catch (e) {
      Logger.errorLog('❌ Error checking CM site download status: $e');
      return false;
    }
  }

  /// Check if incident site is downloaded
  Future<bool> isIncidentSiteDownloaded(int siteId) async {
    try {
      final db = await database;
      
      // Check if incident_sites_data table exists
      final tableInfo = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='incident_sites_data'",
      );
      
      if (tableInfo.isEmpty) {
        // Table doesn't exist yet, return false
        return false;
      }
      
      final List<Map<String, dynamic>> maps = await db.query(
        'incident_sites_data',
        columns: ['is_downloaded'],
        where: 'site_id = ?',
        whereArgs: [siteId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return maps.first['is_downloaded'] == 1;
      }
      return false;
    } catch (e) {
      print('Error checking incident site download status: $e');
      Logger.errorLog('❌ Error checking incident site download status: $e');
      return false;
    }
  }

  /// Get all downloaded CM sites
  Future<List<Map<String, dynamic>>> getAllDownloadedCMSites() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> allSites = [];

      // Query all site tables and combine results
      final List<Map<String, dynamic>> cmMaps = await db.query(
        'cm_sites_data',
        where: 'is_downloaded = ?',
        whereArgs: [1],
        orderBy: 'downloaded_at DESC',
      );

      final List<Map<String, dynamic>> svMaps = await db.query(
        'sv_sites_data',
        where: 'is_downloaded = ?',
        whereArgs: [1],
        orderBy: 'downloaded_at DESC',
      );

      final List<Map<String, dynamic>> giMaps = await db.query(
        'gi_sites_data',
        where: 'is_downloaded = ?',
        whereArgs: [1],
        orderBy: 'downloaded_at DESC',
      );

      // Query Asset Upload sites table
      List<Map<String, dynamic>> auMaps = [];
      try {
        // Check if au_sites_data table exists
        final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='au_sites_data'",
        );
        if (tableCheck.isNotEmpty) {
          auMaps = await db.query(
            'au_sites_data',
            where: 'is_downloaded = ?',
            whereArgs: [1],
            orderBy: 'downloaded_at DESC',
          );
          Logger.debugLog('📊 Found ${auMaps.length} Asset Upload sites in database');
        }
      } catch (e) {
        Logger.errorLog('❌ Error querying au_sites_data: $e');
      }

      // Query incident sites table - only get sites with activity_type = 'Incident' (exact match)
      List<Map<String, dynamic>> incidentMaps = [];
      try {
        // Check if incident_sites_data table exists
        final tableCheck = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='incident_sites_data'",
        );
        if (tableCheck.isNotEmpty) {
          // Only get sites with activity_type exactly matching 'Incident' (the enum value)
          incidentMaps = await db.query(
            'incident_sites_data',
            where: 'is_downloaded = ? AND activity_type = ?',
            whereArgs: [1, 'Incident'],
            orderBy: 'downloaded_at DESC',
          );
          Logger.debugLog('📊 Found ${incidentMaps.length} incident sites in database');
        }
      } catch (e) {
        Logger.errorLog('❌ Error querying incident_sites_data: $e');
      }

      allSites.addAll(cmMaps);
      allSites.addAll(svMaps);
      allSites.addAll(giMaps);
      allSites.addAll(incidentMaps);
      allSites.addAll(auMaps);

      // Sort by downloaded_at descending
      allSites.sort((a, b) {
        final aDate = a['downloaded_at']?.toString() ?? '';
        final bDate = b['downloaded_at']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });

      return allSites;
    } catch (e) {
      Logger.errorLog('❌ Error getting all downloaded sites: $e');
      return [];
    }
  }

  /// Save CM checklist data to SQLite
  Future<bool> saveCMChecklistData({
    required int siteId,
    required int entityId,
    required String siteCode,
    required String siteName,
    required Map<String, List<Map<String, dynamic>>> checklistData,
    required String activityType,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      // Clear existing data for this site to avoid conflicts
      await db.delete(
        'cm_checklist_data',
        where: 'site_id = ?',
        whereArgs: [siteId],
      );
      Logger.debugLog(
        '🗑️ Cleared existing CM checklist data for site_id: $siteId',
      );

      // Save each checklist item in a transaction
      int totalItems = 0;
      for (final entry in checklistData.entries) {
        totalItems += entry.value.length;
      }

      Logger.debugLog('📝 Saving $totalItems CM checklist items to database');

      await db.transaction((txn) async {
        int itemIndex = 0;
        for (final entry in checklistData.entries) {
          final itemType = entry.key;
          final items = entry.value;

          for (int i = 0; i < items.length; i++) {
            final item = items[i];
            itemIndex++;

            try {
              // Handle impacted_item_check_list (replaces childitemData) - can be List or already JSON string
              String? childitemDataJson;
              if (item['impacted_item_check_list'] != null) {
                if (item['impacted_item_check_list'] is List) {
                  childitemDataJson = jsonEncode(item['impacted_item_check_list']);
                } else if (item['impacted_item_check_list'] is String) {
                  childitemDataJson = item['impacted_item_check_list'];
                }
              } else if (item['childitemData'] != null &&
                  item['childitemData'] is List) {
                // Fallback to childitemData for backward compatibility
                childitemDataJson = jsonEncode(item['childitemData']);
              }

              // Handle dependent_elements - can be List or already JSON string
              String? dependentElementsJson;
              if (item['dependent_elements'] != null) {
                if (item['dependent_elements'] is List) {
                  dependentElementsJson = jsonEncode(item['dependent_elements']);
                } else if (item['dependent_elements'] is String) {
                  dependentElementsJson = item['dependent_elements'];
                }
              } else if (item['dependentElements'] != null) {
                // Try camelCase version
                if (item['dependentElements'] is List) {
                  dependentElementsJson = jsonEncode(item['dependentElements']);
                } else if (item['dependentElements'] is String) {
                  dependentElementsJson = item['dependentElements'];
                }
              }

              final insertData = {
                'site_id': siteId,
                'entity_id': entityId,
                'site_code': siteCode,
                'site_name': siteName,
                'checklist_desc': item['checklist_desc']?.toString() ?? '',
                'resp_type': item['resp_type']?.toString() ?? '',
                'resp_type_value_map': item['resp_type_value_map']?.toString(),
                'impacted_item_value_map': item['impacted_item_value_map']
                    ?.toString(),
                'item_type_id': item['item_type_id'] ?? 0,
                'item_type': itemType,
                'check_list_group_id': item['check_list_group_id'],
                'cm_check_list_mst_id': item['cm_check_list_mst_id'] ?? 0,
                'is_mandatory': (item['is_mandatory'] ?? false) ? 1 : 0,
                'childitem_data': childitemDataJson,
                'dependent_elements': dependentElementsJson,
                'cl_order': item['cl_order'] ?? 0,
                'sub_item_type': item['sub_item_type']?.toString() ?? '',
                'activity_type': activityType,
                'is_downloaded': 1,
                'downloaded_at': now,
                'created_at': now,
                'updated_at': now,
              };

              await txn.insert(
                'cm_checklist_data',
                insertData,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (itemError) {
              Logger.errorLog(
                '❌ Error saving CM checklist item $itemIndex: $itemError',
              );
              // Continue with other items even if one fails
            }
          }
        }
      });

      Logger.debugLog('✅ CM checklist data saved successfully to SQLite');
      return true;
    } catch (e) {
      Logger.errorLog('❌ Error saving CM checklist data: $e');
      return false;
    }
  }

  /// Get CM checklist data from SQLite
  Future<Map<String, List<Map<String, dynamic>>>> getCMChecklistData(
    int siteId,
  ) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'cm_checklist_data',
        where: 'site_id = ?',
        whereArgs: [siteId],
        orderBy: 'cl_order ASC',
      );

      final Map<String, List<Map<String, dynamic>>> checklistByType = {};

      for (final map in maps) {
        final itemType = map['item_type'] as String;

        if (!checklistByType.containsKey(itemType)) {
          checklistByType[itemType] = [];
        }

        List<dynamic> childitemData = [];
        if (map['childitem_data'] != null) {
          try {
            childitemData = jsonDecode(map['childitem_data']);
          } catch (e) {
            Logger.errorLog('❌ Error parsing childitem_data: $e');
          }
        }

        // Parse dependent_elements from JSON string
        List<dynamic>? dependentElements;
        if (map['dependent_elements'] != null) {
          try {
            final parsed = jsonDecode(map['dependent_elements']);
            if (parsed is List) {
              dependentElements = parsed;
            }
          } catch (e) {
            Logger.errorLog('❌ Error parsing dependent_elements: $e');
          }
        }

        final itemData = {
          'checklist_desc': map['checklist_desc'],
          'resp_type': map['resp_type'],
          'resp_type_value_map': map['resp_type_value_map'],
          'impacted_item_value_map': map['impacted_item_value_map'],
          'item_type_id': map['item_type_id'],
          'item_type': map['item_type'],
          'check_list_group_id': map['check_list_group_id'],
          'cm_check_list_mst_id': map['cm_check_list_mst_id'],
          'is_mandatory': map['is_mandatory'] == 1,
          'childitemData': childitemData, // Keep for backward compatibility
          'impacted_item_check_list': childitemData, // New field name
          'cl_order': map['cl_order'],
          'sub_item_type': map['sub_item_type'],
        };

        // Add dependent_elements if it exists
        if (dependentElements != null) {
          itemData['dependent_elements'] = dependentElements;
        }

        checklistByType[itemType]!.add(itemData);
      }

      Logger.debugLog(
        '✅ Retrieved CM checklist data from SQLite with ${checklistByType.length} item types',
      );
      return checklistByType;
    } catch (e) {
      Logger.errorLog('❌ Error getting CM checklist data: $e');
      return {};
    }
  }

  /// Check if CM checklist is downloaded for a site
  Future<bool> isCMChecklistDownloaded(int siteId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'cm_checklist_data',
        where: 'site_id = ? AND is_downloaded = 1',
        whereArgs: [siteId],
        limit: 1,
      );

      return maps.isNotEmpty;
    } catch (e) {
      Logger.errorLog('❌ Error checking if CM checklist is downloaded: $e');
      return false;
    }
  }

  /// Close the database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      Logger.debugLog('✅ CentralAssetAuditDataService database closed');
    }
  }
}
