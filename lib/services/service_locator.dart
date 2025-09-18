import 'package:app/services/asset_audit/central_asset_audit_service.dart';
import 'package:app/services/image_upload_service.dart';
import 'package:app/utils/logger.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  bool _isInitialized = false;
  late CentralAssetAuditService _centralAssetAuditService;
  late ImageUploadService _imageUploadService;

  /// Initialize all services
  Future<void> initializeServices(dynamic apiService) async {
    if (_isInitialized) {
      Logger.debugLog('✅ Services already initialized');
      return;
    }

    try {
      Logger.debugLog('🚀 Initializing all services...');

      // Initialize Central Asset Audit Service
      _centralAssetAuditService = CentralAssetAuditService();
      _centralAssetAuditService.initialize(apiService);

      // Initialize Image Upload Service
      _imageUploadService = ImageUploadService(apiService: apiService);

      _isInitialized = true;
      Logger.debugLog('✅ All services initialized successfully');
    } catch (e) {
      Logger.errorLog('❌ Failed to initialize services: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Get Central Asset Audit Service (guaranteed to be initialized)
  CentralAssetAuditService get centralAssetAuditService {
    _ensureInitialized();
    return _centralAssetAuditService;
  }

  /// Get Image Upload Service (guaranteed to be initialized)
  ImageUploadService get imageUploadService {
    _ensureInitialized();
    return _imageUploadService;
  }

  /// Check if services are initialized
  bool get isInitialized => _isInitialized;

  /// Ensure services are initialized, throw error if not
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'Services not initialized! Call ServiceLocator().initializeServices(apiService) first.'
      );
    }
  }

  /// Reset services (for testing or re-initialization)
  void reset() {
    _isInitialized = false;
    Logger.debugLog('🔄 Services reset');
  }
}
