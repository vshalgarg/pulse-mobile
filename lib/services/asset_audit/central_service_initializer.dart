import 'central_asset_audit_service.dart';

class CentralAssetAuditServiceInitializer {
  static CentralAssetAuditService? _service;
  static bool _isInitialized = false;

  /// Initialize the service with API service
  static void initialize(dynamic apiService) {
    if (_isInitialized) {
      print('🔧 CentralAssetAuditService already initialized');
      return;
    }
    
    print('🔧 Initializing CentralAssetAuditService...');
    _isInitialized = true;
    print('✅ CentralAssetAuditService initialization completed');
  }

  /// Get the initialized service
  static CentralAssetAuditService getService() {
    print('🔍 Getting CentralAssetAuditService - Initialized: $_isInitialized, Service: ${_service != null}');
    if (!_isInitialized || _service == null) {
      print('❌ CentralAssetAuditService not initialized!');
      throw Exception('CentralAssetAuditService not initialized. Call initialize() first.');
    }
    print('✅ CentralAssetAuditService retrieved successfully');
    return _service!;
  }

  /// Check if service is initialized
  static bool get isInitialized => _isInitialized;

  /// Reset the service (for testing)
  static void reset() {
    _service = null;
    _isInitialized = false;
  }
}
