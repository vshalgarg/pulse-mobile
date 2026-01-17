import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/logger.dart';

class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  // Database connections cache
  final Map<String, Database> _databases = {};
  final Map<String, int> _connectionCount = {};

  /// Get or create a database connection
  Future<Database> getDatabase(String dbName) async {
    if (_databases.containsKey(dbName)) {
      _connectionCount[dbName] = (_connectionCount[dbName] ?? 0) + 1;
      Logger.debugLog('📊 Reusing existing database connection for $dbName (count: ${_connectionCount[dbName]})');
      return _databases[dbName]!;
    }

    try {
      final dbPath = join(await getDatabasesPath(), '$dbName.db');
      final database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) {
          Logger.debugLog('📊 Creating database $dbName');
        },
        onOpen: (db) {
          Logger.debugLog('📊 Opening database $dbName');
        },
      );

      _databases[dbName] = database;
      _connectionCount[dbName] = 1;
      
      Logger.debugLog('✅ Database $dbName connected successfully');
      return database;
    } catch (e) {
      Logger.errorLog('❌ Error connecting to database $dbName: $e');
      rethrow;
    }
  }

  /// Close a database connection (only if no other references exist)
  Future<void> closeDatabase(String dbName) async {
    if (!_databases.containsKey(dbName)) {
      Logger.debugLog('⚠️ Database $dbName is not open');
      return;
    }

    _connectionCount[dbName] = (_connectionCount[dbName] ?? 1) - 1;
    
    if (_connectionCount[dbName]! <= 0) {
      await _databases[dbName]!.close();
      _databases.remove(dbName);
      _connectionCount.remove(dbName);
      Logger.debugLog('✅ Database $dbName closed and removed from cache');
    } else {
      Logger.debugLog('📊 Database $dbName connection count reduced to ${_connectionCount[dbName]}');
    }
  }

  /// Force close all database connections
  Future<void> closeAllDatabases() async {
    Logger.debugLog('🗑️ Closing all database connections');
    
    for (final dbName in _databases.keys.toList()) {
      await _databases[dbName]!.close();
      _databases.remove(dbName);
      _connectionCount.remove(dbName);
    }
    
    Logger.debugLog('✅ All database connections closed');
  }

  /// Get connection count for a database
  int getConnectionCount(String dbName) {
    return _connectionCount[dbName] ?? 0;
  }

  /// Check if a database is open
  bool isDatabaseOpen(String dbName) {
    return _databases.containsKey(dbName);
  }

  /// Get list of open databases
  List<String> getOpenDatabases() {
    return _databases.keys.toList();
  }
}
