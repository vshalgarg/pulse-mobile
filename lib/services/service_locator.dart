import 'package:app/services/api_service.dart';
import 'package:app/services/asset_audit/central_api_service.dart';
import 'package:app/services/asset_audit/central_asset_audit_service.dart';
import 'package:app/services/asset_audit/central_data_service.dart';
import 'package:app/services/asset_audit_post_service.dart';
import 'package:app/services/image_upload_service.dart';
import 'package:app/services/pending_requests_service.dart';
import 'package:app/utils/logger.dart';
import 'package:app/repositories/cm_repository.dart';
import 'package:app/repositories/sites.repository.dart';
import 'package:app/repositories/general_inspection_repository.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  bool _isInitialized = false;
  late CentralAssetAuditService _centralAssetAuditService;
  late ImageUploadService _imageUploadService;
  late AssetAuditPostService _assetAuditPostService;
  late PendingRequestsService _pendingRequestsService;
  late ApiService _apiService;
  late CentralAssetAuditDataService _centralAssetAuditDataService;
  late CentralApiService _centralApiService;
  late CMRepository _cmRepository;
  SitesRepository? _sitesRepository;
  late GeneralInspectionRepository _generalInspectionRepository;

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

      // Initialize Image Upload Service
      _imageUploadService = ImageUploadService(apiService: apiService);

      _pendingRequestsService = PendingRequestsService();

      _apiService = apiService;

      _assetAuditPostService = AssetAuditPostService();

      _centralAssetAuditDataService = CentralAssetAuditDataService();
      _centralApiService = CentralApiService(apiService: apiService);
      _cmRepository = CMRepository(apiService);
      _sitesRepository = SitesRepository(apiService);
      _generalInspectionRepository = GeneralInspectionRepository(apiService);

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
  CentralAssetAuditDataService get centralAssetAuditDataService {
    _ensureInitialized();
    return _centralAssetAuditDataService;
  }

  /// Get Image Upload Service (guaranteed to be initialized)
  ImageUploadService get imageUploadService {
    _ensureInitialized();
    return _imageUploadService;
  }

  PendingRequestsService get pendingRequestService {
    _ensureInitialized();
    return _pendingRequestsService;
  }

  CentralApiService get centralApiService {
    _ensureInitialized();
    return _centralApiService;
  }

  AssetAuditPostService get assetAuditPostService {
    _ensureInitialized();
    return _assetAuditPostService;
  }

  ApiService get apiService {
    _ensureInitialized();
    return _apiService;
  }

  /// Get CM Repository (guaranteed to be initialized)
  CMRepository get cmRepository {
    _ensureInitialized();
    return _cmRepository;
  }

  /// Get Sites Repository (guaranteed to be initialized)
  SitesRepository get sitesRepository {

    _ensureInitialized();
    if (_sitesRepository == null) {

      _sitesRepository = SitesRepository(_apiService);

    }

    return _sitesRepository!;
  }

  /// Get General Inspection Repository (guaranteed to be initialized)
  GeneralInspectionRepository get generalInspectionRepository {
    _ensureInitialized();
    return _generalInspectionRepository;
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
