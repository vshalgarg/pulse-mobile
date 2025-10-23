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
  static const int _databaseVersion = 7;

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

    await db.execute(
      'CREATE INDEX idx_raw_api_data_site_audit_sch_id ON raw_api_data(site_audit_sch_id)',
    );

    await db.execute(
      'CREATE INDEX idx_cm_sites_data_site_id ON cm_sites_data(site_id)',
    );

    await db.execute(
      'CREATE INDEX idx_gen_ins_checklist_data_site_id ON gen_ins_checklist_data(site_id)',
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
  }

  /// Clear all data
  Future<void> clearAllData() async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('raw_api_data');
    });

    Logger.debugLog('✅ All data cleared');
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
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      await db.insert('cm_sites_data', {
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
        'is_downloaded': 1,
        'downloaded_at': now,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      Logger.debugLog('✅ CM site data saved successfully');
      return true;
    } catch (e) {
      Logger.errorLog('❌ Error saving CM site data: $e');
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
      Logger.debugLog('🗑️ Cleared existing checklist data for site_id: $siteId');

      // Save each checklist item in a transaction
      Logger.debugLog('📝 Saving ${checklistData.length} checklist items to database');
      
      await db.transaction((txn) async {
        for (int i = 0; i < checklistData.length; i++) {
          final item = checklistData[i];
          try {
            Logger.debugLog('📝 Saving item ${i + 1}/${checklistData.length}: ${item.checklistDesc} (giclm_id: ${item.giclmId})');
            
            String? respTypeValueMapJson;
            if (item.respTypeValueMap != null) {
              try {
                // Try a simpler approach - just convert the value to string
                respTypeValueMapJson = item.respTypeValueMap!.value;
                Logger.debugLog('📝 resp_type_value_map (value only): $respTypeValueMapJson');
              } catch (jsonError) {
                Logger.errorLog('❌ JSON serialization error for item ${item.checklistDesc}: $jsonError');
                respTypeValueMapJson = null;
              }
            } else {
              Logger.debugLog('📝 resp_type_value_map: null');
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
              'activity_type': activityType,
              'is_downloaded': 1,
              'downloaded_at': now,
              'created_at': now,
              'updated_at': now,
            };
            
            Logger.debugLog('📝 Insert data for ${item.checklistDesc}: $insertData');
            
            final result = await txn.insert('gen_ins_checklist_data', insertData, conflictAlgorithm: ConflictAlgorithm.replace);
            
            Logger.debugLog('✅ Successfully saved item ${i + 1}: ${item.checklistDesc} (rowId: $result)');
          } catch (itemError) {
            Logger.errorLog('❌ Error saving item ${i + 1} (${item.checklistDesc}): $itemError');
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
      
      Logger.debugLog('🔍 Verification: ${savedItems.length} items saved to database for site_id: $siteId');
      for (final savedItem in savedItems) {
        Logger.debugLog('🔍 Saved: ${savedItem['checklist_desc']} (giclm_id: ${savedItem['giclm_id']}, cl_order: ${savedItem['cl_order']})');
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
        "SELECT name FROM sqlite_master WHERE type='table' AND name='gen_ins_checklist_data'"
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
      }
    } catch (e) {
      Logger.errorLog('❌ Error ensuring gen_ins_checklist_data table exists: $e');
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
              jsonDecode(map['resp_type_value_map']); // Validate it's valid JSON
              respTypeValueMap = {
                'type': 'string', // Default type
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
          });
          checklistItems.add(item);
        } catch (e) {
          Logger.errorLog('❌ Error parsing GI checklist item: $e');
          continue;
        }
      }

      Logger.debugLog('✅ Retrieved ${checklistItems.length} GI checklist items from SQLite');
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

  /// Get all downloaded CM sites
  Future<List<Map<String, dynamic>>> getAllDownloadedCMSites() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'cm_sites_data',
        where: 'is_downloaded = ?',
        whereArgs: [1],
        orderBy: 'downloaded_at DESC',
      );

      return maps;
    } catch (e) {
      Logger.errorLog('❌ Error getting all downloaded CM sites: $e');
      return [];
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
