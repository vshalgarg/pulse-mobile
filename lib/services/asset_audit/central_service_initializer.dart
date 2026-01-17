import 'central_asset_audit_service.dart';

class CentralAssetAuditServiceInitializer {
  static CentralAssetAuditService? _service;
  static bool _isInitialized = false;

  /// Initialize the service with API service
  static void initialize(dynamic apiService) {
    if (_isInitialized) {

      return;
    }

    _isInitialized = true;

  }

  /// Get the initialized service
  static CentralAssetAuditService getService() {

    if (!_isInitialized || _service == null) {

      throw Exception('CentralAssetAuditService not initialized. Call initialize() first.');
    }

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
