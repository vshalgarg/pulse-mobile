import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/logger.dart';

class PendingRequestsService {
  static final PendingRequestsService _instance =
      PendingRequestsService._internal();
  factory PendingRequestsService() => _instance;
  PendingRequestsService._internal();
  static const int _databaseVersion = 2;
  static Database? _database;

  static final String _databaseName = 'pending_requests.db';

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path, version: _databaseVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Pending Requests table
    await db.execute('''
      CREATE TABLE pending_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        request_id TEXT UNIQUE NOT NULL,
        url TEXT NOT NULL,
        headers TEXT,
        request_data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        last_retry_at INTEGER,
        error_message TEXT
      )
    ''');
    Logger.debugLog('✅ PendingRequestsService: Database created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      // Drop existing tables
      await db.execute('DROP TABLE IF EXISTS pending_requests');
      // Recreate tables with current schema
      await _onCreate(db, newVersion);
      Logger.debugLog('✅ Database upgraded from version $oldVersion to $newVersion');
    }
  }

  /// Save a pending request to the database
  Future<bool> savePendingRequest({
    required String requestId,
    required String url,
    required Map<String, dynamic> headers,
    required String jsonEncodedRequestData,
  }) async {
    try {
      final db = await database;

      final pendingRequest = {
        'request_id': requestId,
        'url': url,
        'headers': jsonEncode(headers),
        'request_data': jsonEncodedRequestData,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'retry_count': 0,
        'status': 'pending',
        'last_retry_at': null,
        'error_message': null,
      };

      int result = await db.insert('pending_requests', pendingRequest);

      if (result > 0) {
        Logger.debugLog('Pending post data saved for requestId $requestId');
        return true;
      } else {
        Logger.debugLog('⚠️ Pending post data could not be saved for requestId $requestId');
        return false;
      }
    } catch (e) {
      Logger.errorLog(
        'PendingRequestsService: Error saving pending request: $e',
      );
      rethrow;
    }
  }

  /// Get all pending requests
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final db = await database;
      final result = await db.query(
        'pending_requests',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
      );

      Logger.debugLog(
        '📋 PendingRequestsService: Retrieved ${result.length} pending requests',
      );
      return result;
    } catch (e) {
      Logger.errorLog(
        '❌ PendingRequestsService: Error retrieving pending requests: $e',
      );
      return [];
    }
  }

  /// Update request status
  Future<void> updateRequestStatus({
    required String requestId,
    required String status,
    String? errorMessage,
  }) async {
    try {
      final db = await database;

      final updateData = {
        'status': status,
        'last_retry_at': DateTime.now().millisecondsSinceEpoch,
      };

      if (errorMessage != null) {
        updateData['error_message'] = errorMessage;
      }

      if (status == 'failed') {
        updateData['retry_count'] = await _incrementRetryCount(requestId);
      }

      await db.update(
        'pending_requests',
        updateData,
        where: 'request_id = ?',
        whereArgs: [requestId],
      );

      Logger.debugLog(
        '🔄 PendingRequestsService: Updated request $requestId status to $status',
      );
    } catch (e) {
      Logger.errorLog(
        '❌ PendingRequestsService: Error updating request status: $e',
      );
    }
  }

  /// Delete completed request
  Future<void> deleteRequest(String requestId) async {
    try {
      final db = await database;
      await db.delete(
        'pending_requests',
        where: 'request_id = ?',
        whereArgs: [requestId],
      );

      Logger.debugLog('🗑️ PendingRequestsService: Deleted request $requestId');
    } catch (e) {
      Logger.errorLog('❌ PendingRequestsService: Error deleting request: $e');
    }
  }

  /// Increment retry count for a request
  Future<int> _incrementRetryCount(String requestId) async {
    try {
      final db = await database;
      final result = await db.query(
        'pending_requests',
        columns: ['retry_count'],
        where: 'request_id = ?',
        whereArgs: [requestId],
      );

      if (result.isNotEmpty) {
        final currentCount = result.first['retry_count'] as int;
        final newCount = currentCount + 1;

        await db.update(
          'pending_requests',
          {'retry_count': newCount},
          where: 'request_id = ?',
          whereArgs: [requestId],
        );

        return newCount;
      }

      return 0;
    } catch (e) {
      Logger.errorLog(
        '❌ PendingRequestsService: Error incrementing retry count: $e',
      );
      return 0;
    }
  }

  /// Clear all data
  Future<void> clearAllData() async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('pending_requests');
    });

    Logger.debugLog('✅ All data cleared');
  }

  /// Drop and recreate database with all tables
  Future<void> dropAndRecreateDatabase() async {
    try {
      Logger.debugLog(
        '🗑️ Dropping and recreating ImageUploadService database',
      );

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
        Logger.debugLog('🗑️ ImageUploadService database file deleted');
      }

      // Recreate database by calling _initDatabase
      _database = await _initDatabase();
      Logger.debugLog(
        '✅ ImageUploadService database recreated with all tables',
      );
    } catch (e) {
      Logger.errorLog(
        '❌ Error dropping and recreating ImageUploadService database: $e',
      );
      // Reset database instance to force recreation on next access
      _database = null;
      rethrow;
    }
  }

  /// Increment retry count for a request (public method)
  Future<int> incrementRetryCount(String requestId) async {
    return await _incrementRetryCount(requestId);
  }

  /// Get request details for retry
  Future<Map<String, dynamic>?> getRequestForRetry(String requestId) async {
    try {
      final db = await database;
      final result = await db.query(
        'pending_requests',
        where: 'request_id = ? AND status = ?',
        whereArgs: [requestId, 'pending'],
      );

      if (result.isNotEmpty) {
        final request = result.first;
        return {
          'request_id': request['request_id'],
          'url': request['url'],
          'headers': jsonDecode(request['headers'] as String),
          'request_data': jsonDecode(request['request_data'] as String),
        };
      }

      return null;
    } catch (e) {
      Logger.errorLog(
        '❌ PendingRequestsService: Error getting request for retry: $e',
      );
      return null;
    }
  }

  /// Log all pending requests in the table
  Future<void> logPendingRequestsTable() async {
    try {
      final db = await database;
      final result = await db.query(
        'pending_requests',
        orderBy: 'created_at DESC',
      );

      if (result.isEmpty) {

      } else {
        for (int i = 0; i < result.length; i++) {
          final request = result[i];

          if (request['last_retry_at'] != null) {
          }
          if (request['error_message'] != null) {

          }

        }
      }

      Logger.infoLog(
        '📋 PendingRequestsService: Logged ${result.length} pending requests',
      );
    } catch (e) {
      Logger.errorLog(
        '❌ PendingRequestsService: Error logging pending requests table: $e',
      );

    }
  }

  /// Log table structure and stats
  Future<void> logTableInfo() async {
    try {
      final db = await database;

      // Get table info
      final tableInfo = await db.rawQuery(
        "PRAGMA table_info(pending_requests)",
      );

      for (final column in tableInfo) {

      }

      // Get row count
      final countResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM pending_requests",
      );
      final totalRows = countResult.first['count'] as int;

      // Get status breakdown
      final statusResult = await db.rawQuery(
        "SELECT status, COUNT(*) as count FROM pending_requests GROUP BY status",
      );

      for (final row in statusResult) {

      }

    } catch (e) {
      Logger.errorLog('❌ PendingRequestsService: Error logging table info: $e');

    }
  }

  /// Test method to verify service is working
  Future<void> testService() async {

    try {
      final db = await database;

      // Test insert
      final testRequest = {
        'request_id': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'url': '/test/endpoint',
        'headers': '{"Content-Type":"application/json"}',
        'request_data': '[{"test":"data"}]',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'retry_count': 0,
        'status': 'pending',
        'last_retry_at': null,
        'error_message': null,
      };

      await db.insert('pending_requests', testRequest);

      // Test query
      final result = await db.query('pending_requests');

      // Clean up test data
      await db.delete(
        'pending_requests',
        where: 'request_id LIKE ?',
        whereArgs: ['test_%'],
      );

    } catch (e) {

    }

  }

  /// Close the database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      Logger.debugLog('✅ PendingRequestsService database closed');
    }
  }

  /// Process offline request by converting photo_id to server_id
}
