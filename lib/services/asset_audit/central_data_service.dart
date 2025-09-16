import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../utils/logger.dart';

class CentralAssetAuditDataService {
  static Database? _database;
  static const String _databaseName = 'central_asset_audit.db';
  static const int _databaseVersion = 2;

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
    // Form data table (for all screens)
    await db.execute('''
      CREATE TABLE form_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_audit_sch_id TEXT NOT NULL,
        screen_name TEXT NOT NULL,
        form_data TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Raw API data table
    await db.execute('''
      CREATE TABLE raw_api_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_audit_sch_id TEXT NOT NULL,
        api_data TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Create indexes for better performance
    await db.execute(
        'CREATE INDEX idx_form_data_site_audit_sch_id ON form_data(site_audit_sch_id)');
    await db.execute(
        'CREATE INDEX idx_raw_api_data_site_audit_sch_id ON raw_api_data(site_audit_sch_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.debugLog('🔄 Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 2) {
      // Add raw_api_data table for version 2
      await db.execute('''
        CREATE TABLE raw_api_data (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          site_audit_sch_id TEXT NOT NULL,
          api_data TEXT NOT NULL,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
      
      // Add index for raw_api_data table
      await db.execute('CREATE INDEX idx_raw_api_data_site_audit_sch_id ON raw_api_data(site_audit_sch_id)');
      
      Logger.debugLog('✅ Added raw_api_data table and index');
    }
  }

  /// Clear all data
  Future<void> clearAllData() async {
    final db = await database;
    
    await db.transaction((txn) async {
      await txn.delete('page_headers');
      await txn.delete('categories');
      await txn.delete('asset_items');
      await txn.delete('form_data');
      await txn.delete('cached_images');
      await txn.delete('spv_items');
      await txn.delete('pcu_items');
      await txn.delete('inverter_items');
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
  Future<void> saveRawApiData({
    required String siteAuditSchId,
    required Map<String, dynamic> apiData,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      // Clear existing data for this site
      await txn.delete('raw_api_data', where: 'site_audit_sch_id = ?', whereArgs: [siteAuditSchId]);

      // Insert raw API data
      await txn.insert('raw_api_data', {
        'site_audit_sch_id': siteAuditSchId,
        'api_data': jsonEncode(apiData),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    });

    Logger.debugLog('✅ Raw API data saved for site $siteAuditSchId');
  }

  /// Get raw API data
  Future<Map<String, dynamic>?> getRawApiData(String siteAuditSchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'raw_api_data',
      where: 'site_audit_sch_id = ?',
      whereArgs: [siteAuditSchId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return jsonDecode(maps.first['api_data']);
    }
    return null;
  }
}
