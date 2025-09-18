import 'dart:convert';
import 'dart:io';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/sqlite/raw_api_data_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../utils/logger.dart';

class CentralAssetAuditDataService {
  static Database? _database;
  static const String _databaseName = 'central_asset_audit.db';
  static const int _databaseVersion = 4;

  Future<Database> get database async {
    if (_database != null) return _database!;
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
        api_data TEXT NOT NULL,
        is_downloaded INTEGER DEFAULT 0,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

   await db.execute(
        'CREATE INDEX idx_raw_api_data_site_audit_sch_id ON raw_api_data(site_audit_sch_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.debugLog('🔄 Upgrading database from version $oldVersion to $newVersion');
    
    // For any version upgrade, recreate all tables to ensure consistency
    if (oldVersion < newVersion) {
      // Drop existing tables
      await db.execute('DROP TABLE IF EXISTS raw_api_data');
      
      // Recreate tables with current schema
      await _onCreate(db, newVersion);
      Logger.debugLog('✅ Database upgraded from version $oldVersion to $newVersion');
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
        await txn.delete('raw_api_data', where: 'site_audit_sch_id = ?',
            whereArgs: [siteAuditSchId]);

        // Insert raw API data
        await txn.insert('raw_api_data', {
          'site_audit_sch_id': siteAuditSchId,
          'site_type': siteType,
          'audit_sch_id': auditSchId,
          'activity_type': activityType.value,
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
    } catch(e) {
      Logger.errorLog("Exception while saving site data to sqlite $siteAuditSchId $e");
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
        Logger.debugLog('⚠️ No record found to update for site $siteAuditSchId');
        return false;
      }
    } catch(e) {
      Logger.errorLog("Exception while updating site data to sqlite $siteAuditSchId $e");
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
            isDownloaded: data['is_downloaded'] == 1 ? true : false,
            latitude: data['latitude'],
            longitude: data['longitude'],
            apiData: jsonDecode(data['api_data']));
      }
      return null;
    } catch(e) {
      Logger.errorLog("Exception while saving site data to sqlite $siteAuditSchId $e");
      return null;
    }
  }
}
