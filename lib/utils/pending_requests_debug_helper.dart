import 'dart:convert';
import 'package:app/services/pending_requests_service.dart';

/// Helper class to debug pending requests functionality
class PendingRequestsDebugHelper {
  static final PendingRequestsService _pendingRequestsService = PendingRequestsService();

  /// Manually trigger pending requests table logging
  static Future<void> logPendingRequestsTable() async {
    print('🔧 MANUAL TRIGGER: Logging pending requests table...');
    await _pendingRequestsService.logPendingRequestsTable();
  }

  /// Manually trigger table info logging
  static Future<void> logTableInfo() async {
    print('🔧 MANUAL TRIGGER: Logging table info...');
    await _pendingRequestsService.logTableInfo();
  }

  /// Test the pending requests service
  static Future<void> testService() async {
    print('🔧 MANUAL TRIGGER: Testing pending requests service...');
    await _pendingRequestsService.testService();
  }

  /// Add a test pending request
  static Future<void> addTestRequest() async {
    print('🔧 MANUAL TRIGGER: Adding test pending request...');
    try {
      await _pendingRequestsService.savePendingRequest(
        requestId: 'manual_test_${DateTime.now().millisecondsSinceEpoch}',
        url: '/test/manual/endpoint',
        headers: {'Content-Type': 'application/json'},
        jsonEncodedRequestData: jsonEncode([{'test': 'manual_data', 'timestamp': DateTime.now().toIso8601String()}]),
      );
      print('✅ Test request added successfully');
    } catch (e) {
      print('❌ Error adding test request: $e');
    }
  }

  /// Run all debug operations
  static Future<void> runAllDebugOperations() async {
    print('🔧 ===== RUNNING ALL PENDING REQUESTS DEBUG OPERATIONS =====');
    
    await testService();
    await addTestRequest();
    await logPendingRequestsTable();
    await logTableInfo();
    
    print('🔧 ===== COMPLETED ALL DEBUG OPERATIONS =====');
  }
}
