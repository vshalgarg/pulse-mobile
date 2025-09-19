import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/logger.dart';

class PendingRequestsService {
  static final PendingRequestsService _instance = PendingRequestsService._internal();
  factory PendingRequestsService() => _instance;
  PendingRequestsService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'pending_requests.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
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

  /// Save a pending request to the database
  Future<void> savePendingRequest({
    required String requestId,
    required String url,
    required Map<String, dynamic> headers,
    required List<dynamic> requestData,
  }) async {
    try {
      final db = await database;
      
      final pendingRequest = {
        'request_id': requestId,
        'url': url,
        'headers': jsonEncode(headers),
        'request_data': jsonEncode(requestData),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'retry_count': 0,
        'status': 'pending',
        'last_retry_at': null,
        'error_message': null,
      };

      await db.insert('pending_requests', pendingRequest);
      
      Logger.infoLog('💾 PendingRequestsService: Saved pending request with ID: $requestId');
      Logger.infoLog('📝 Request URL: $url');
      Logger.infoLog('📝 Request Headers: ${headers.toString()}');
      Logger.infoLog('📝 Request Data: ${requestData.toString()}');
      
      // Also print to console for immediate visibility
      print('💾 PENDING REQUEST SAVED: $requestId');
      print('📝 URL: $url');
      print('📝 Headers: ${headers.toString()}');
      print('📝 Data: ${requestData.toString()}');
      
      // Log the complete table contents after saving
      await logPendingRequestsTable();
      
    } catch (e) {
      Logger.errorLog('❌ PendingRequestsService: Error saving pending request: $e');
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
      
      Logger.debugLog('📋 PendingRequestsService: Retrieved ${result.length} pending requests');
      return result;
    } catch (e) {
      Logger.errorLog('❌ PendingRequestsService: Error retrieving pending requests: $e');
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
      
      Logger.debugLog('🔄 PendingRequestsService: Updated request $requestId status to $status');
    } catch (e) {
      Logger.errorLog('❌ PendingRequestsService: Error updating request status: $e');
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
      Logger.errorLog('❌ PendingRequestsService: Error incrementing retry count: $e');
      return 0;
    }
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
      Logger.errorLog('❌ PendingRequestsService: Error getting request for retry: $e');
      return null;
    }
  }

  /// Log all pending requests in the table
  Future<void> logPendingRequestsTable() async {
    try {
      final db = await database;
      final result = await db.query('pending_requests', orderBy: 'created_at DESC');
      
      print('📋 ===== PENDING REQUESTS TABLE =====');
      print('📊 Total Records: ${result.length}');
      
      if (result.isEmpty) {
        print('📝 No pending requests found in the table');
      } else {
        for (int i = 0; i < result.length; i++) {
          final request = result[i];
          print('📝 --- Request ${i + 1} ---');
          print('   ID: ${request['id']}');
          print('   Request ID: ${request['request_id']}');
          print('   URL: ${request['url']}');
          print('   Status: ${request['status']}');
          print('   Retry Count: ${request['retry_count']}');
          print('   Created At: ${DateTime.fromMillisecondsSinceEpoch(request['created_at'] as int)}');
          if (request['last_retry_at'] != null) {
            print('   Last Retry: ${DateTime.fromMillisecondsSinceEpoch(request['last_retry_at'] as int)}');
          }
          if (request['error_message'] != null) {
            print('   Error: ${request['error_message']}');
          }
          print('   Headers: ${request['headers']}');
          print('   Data Length: ${(request['request_data'] as String).length} characters');
        }
      }
      
      print('📋 ===== END PENDING REQUESTS TABLE =====');
      
      Logger.infoLog('📋 PendingRequestsService: Logged ${result.length} pending requests');
      
    } catch (e) {
      Logger.errorLog('❌ PendingRequestsService: Error logging pending requests table: $e');
      print('❌ ERROR LOGGING PENDING REQUESTS TABLE: $e');
    }
  }

  /// Log table structure and stats
  Future<void> logTableInfo() async {
    try {
      final db = await database;
      
      print('🗄️ ===== PENDING REQUESTS TABLE INFO =====');
      
      // Get table info
      final tableInfo = await db.rawQuery("PRAGMA table_info(pending_requests)");
      print('📊 Table Structure:');
      for (final column in tableInfo) {
        print('   - ${column['name']}: ${column['type']} ${column['notnull'] == 1 ? 'NOT NULL' : ''}');
      }
      
      // Get row count
      final countResult = await db.rawQuery("SELECT COUNT(*) as count FROM pending_requests");
      final totalRows = countResult.first['count'] as int;
      print('📊 Total Rows: $totalRows');
      
      // Get status breakdown
      final statusResult = await db.rawQuery(
        "SELECT status, COUNT(*) as count FROM pending_requests GROUP BY status"
      );
      print('📊 Status Breakdown:');
      for (final row in statusResult) {
        print('   - ${row['status']}: ${row['count']}');
      }
      
      print('🗄️ ===== END TABLE INFO =====');
      
    } catch (e) {
      Logger.errorLog('❌ PendingRequestsService: Error logging table info: $e');
      print('❌ ERROR LOGGING TABLE INFO: $e');
    }
  }

  /// Test method to verify service is working
  Future<void> testService() async {
    print('🧪 ===== TESTING PENDING REQUESTS SERVICE =====');
    try {
      final db = await database;
      print('✅ Database connection successful');
      
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
      print('✅ Test insert successful');
      
      // Test query
      final result = await db.query('pending_requests');
      print('✅ Test query successful - Found ${result.length} records');
      
      // Clean up test data
      await db.delete('pending_requests', where: 'request_id LIKE ?', whereArgs: ['test_%']);
      print('✅ Test cleanup successful');
      
    } catch (e) {
      print('❌ TEST FAILED: $e');
    }
    print('🧪 ===== END TEST =====');
  }
}
