import 'dart:convert';
import 'dart:io';
import 'package:app/enum/image_activity_type_enum.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/logger.dart';
import 'central_data_service.dart';
import 'central_api_service.dart';
import '../image_upload_service.dart';

class CentralAssetAuditService {
  static final CentralAssetAuditService _instance = CentralAssetAuditService._internal();
  factory CentralAssetAuditService() => _instance;
  CentralAssetAuditService._internal();

  late CentralAssetAuditDataService _dataService;
  late CentralAssetAuditApiService _apiService;
  late ImageUploadService _imageUploadService;
  bool _initialized = false;

  /// Initialize the service with API service
  void initialize(dynamic apiService) {
    if (_initialized) return;

    _dataService = CentralAssetAuditDataService();
    _apiService = CentralAssetAuditApiService(apiService: apiService);
    _imageUploadService = ImageUploadService(apiService: apiService);

    _initialized = true;
    Logger.debugLog('✅ CentralAssetAuditService initialized');
  }

  // ==================== MAIN ASSET AUDIT DATA ====================

  /// Get complete asset audit data (SQLite first, then API)
  Future<Map<String, dynamic>?> getAssetAuditData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    if (!_initialized) {
      Logger.errorLog('❌ Service not initialized. Call initialize() first.');
      return null;
    }

    try {

      Logger.debugLog('🔍 Getting asset audit data for site $siteAuditSchId');

      // First try to get from SQLite
      final rawApiData = await _dataService.getRawApiData(siteAuditSchId);
      if (rawApiData != null) {
        Logger.debugLog('✅ Found cached raw API data in SQLite');
        Logger.debugLog('📊 Raw API data keys: ${rawApiData.keys.toList()}');
        return rawApiData;
      }

      // If not found in SQLite, fetch from API
      Logger.debugLog('🌐 No cached data found, fetching from API');
      final apiData = await _apiService.fetchAssetAuditData(
        siteType: siteType,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
      );

      if (apiData != null) {
        // Save to SQLite
        await _saveAssetAuditDataToSQLite(siteAuditSchId, apiData);
        
        Logger.debugLog('✅ Asset audit data fetched and saved to SQLite');
        return apiData;
      } else {
        Logger.errorLog('❌ Failed to fetch asset audit data from API');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error getting asset audit data: $e');
      return null;
    }
  }

  /// Save asset audit data to SQLite
  Future<void> _saveAssetAuditDataToSQLite(String siteAuditSchId, Map<String, dynamic> apiData) async {
    try {
      Logger.debugLog('💾 Starting to save asset audit data to SQLite');
      Logger.debugLog('💾 API data keys: ${apiData.keys.toList()}');
      
      // Process images and replace server IDs with unique IDs
      final processedApiData = await _processImagesInApiData(apiData);
      
      // Save the processed API response
      await _dataService.saveRawApiData(
        siteAuditSchId: siteAuditSchId,
        apiData: processedApiData,
      );
      
      Logger.debugLog('✅ Raw API data saved successfully to SQLite');
    } catch (e) {
      Logger.errorLog('❌ Error saving asset audit data to SQLite: $e');
    }
  }

  /// Process images in API data by downloading and replacing server IDs with unique IDs
  Future<Map<String, dynamic>> _processImagesInApiData(Map<String, dynamic> apiData) async {
    try {
      Logger.debugLog('🖼️ Processing images in API data');
      
      // Create a deep copy of the API data to avoid modifying the original
      final processedData = Map<String, dynamic>.from(apiData);
      
      // Process the entire object recursively
      await _processObjectRecursively(processedData);
      
      Logger.debugLog('✅ Images processed successfully');
      return processedData;
    } catch (e) {
      Logger.errorLog('❌ Error processing images in API data: $e');
      return apiData; // Return original data if processing fails
    }
  }

  /// Recursively process an object to find and replace image server IDs
  Future<void> _processObjectRecursively(dynamic obj) async {
    if (obj == null) return;
    
    if (obj is Map<String, dynamic>) {
      // Process each key-value pair in the map
      for (final entry in obj.entries) {
        final key = entry.key;
        final value = entry.value;
        
        // Check if this is a photo_id or maker_selfie_image_id field
        if ((key == 'photo_id' || key == 'maker_selfie_image_id') && value != null) {
          final serverId = value.toString();
          if (serverId.isNotEmpty) {
            Logger.debugLog('🖼️ Found $key: $serverId');
            
            // Download image and get unique ID
            final uniqueId = await _downloadImageAndGetUniqueId(serverId);
            if (uniqueId != null) {
              // Replace server ID with unique ID
              obj[key] = uniqueId;
              Logger.debugLog('✅ Replaced $key $serverId with unique ID: $uniqueId');
            } else {
              Logger.errorLog('❌ Failed to download image for $key: $serverId');
            }
          }
        } else {
          // Recursively process nested objects
          await _processObjectRecursively(value);
        }
      }
    } else if (obj is List) {
      // Process each item in the list
      for (final item in obj) {
        await _processObjectRecursively(item);
      }
    }
  }

  /// Download image using server ID and return unique ID
  Future<String?> _downloadImageAndGetUniqueId(String serverId) async {
    try {
      Logger.debugLog('📥 Downloading image with server ID: $serverId');
      
      final uniqueId = await _imageUploadService.downloadImageUsingServerId(serverId);
      
      if (uniqueId != null) {
        Logger.debugLog('✅ Image downloaded successfully with unique ID: $uniqueId');
        return uniqueId;
      } else {
        Logger.errorLog('❌ Failed to download image with server ID: $serverId');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error downloading image with server ID $serverId: $e');
      return null;
    }
  }

  /// Update asset audit data in SQLite
  Future<bool> updateAssetAuditData({
    required String siteAuditSchId,
    required Map<String, dynamic> updatedData,
  }) async {
    if (!_initialized) {
      Logger.errorLog('❌ Service not initialized');
      return false;
    }

    try {
      Logger.debugLog('🔄 Updating asset audit data for site $siteAuditSchId');
      Logger.debugLog('🔄 Updated data keys: ${updatedData.keys.toList()}');

      // Update the raw API data in SQLite
      await _dataService.saveRawApiData(
        siteAuditSchId: siteAuditSchId,
        apiData: updatedData,
      );
      
      Logger.debugLog('✅ Asset audit data updated successfully');
      return true;
    } catch (e) {
      Logger.errorLog('❌ Error updating asset audit data: $e');
      return false;
    }
  }

  // ==================== IMAGE OPERATIONS ====================

  /// Get image as data URL
  Future<String?> getImageAsDataUrl(String imageId) async {
    if (!_initialized) {
      Logger.errorLog('❌ Service not initialized');
      return null;
    }

    try {
      final imageData = await _imageUploadService.getImageUsingUniqueId(imageId);
      if(imageData != null) {
        return imageData; // Already a base64 string
      }
      return null;
    } catch (e) {
      Logger.errorLog('❌ Error getting image: $e');
      return null;
    }
  }

  /// Pick image
  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    if (!_initialized) {
      Logger.errorLog('❌ Service not initialized');
      return null;
    }

    try {
      return await _pickImageFromCamera(source: source);
    } catch (e) {
      Logger.errorLog('❌ Error picking image: $e');
      return null;
    }
  }

  Future<File?> _pickImageFromCamera({ImageSource source = ImageSource.gallery}) async {
    try {
      Logger.debugLog('📷 Picking image from ${source == ImageSource.camera ? 'camera' : 'gallery'}');

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image != null) {
        Logger.debugLog('✅ Image picked successfully: ${image.path}');
        return File(image.path);
      } else {
        Logger.debugLog('❌ No image selected');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error picking image: $e');
      return null;
    }
  }

  /// Upload image
  Future<String?> uploadImage({
    required String siteAuditSchId,
    required File imageFile,
  }) async {
    if (!_initialized) {
      Logger.errorLog('❌ Service not initialized');
      return null;
    }

    try {
      // Read file as bytes and convert to base64 string
      final imageBytes = await imageFile.readAsBytes();
      final imageData = base64Encode(imageBytes);
      
      // Upload using ImageUploadService
      return await _imageUploadService.uploadImage(
        imageData, 
        ImageActivityTypeEnum.assetAudit, 
        siteAuditSchId
      );
    } catch (e) {
      Logger.errorLog('❌ Error uploading image: $e');
      return null;
    }
  }
  // ==================== POST OPERATIONS ====================

  /// Post form data for any screen
  Future<bool> postFormData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required String screenType,
    required Map<String, dynamic> formData,
  }) async {
    if (!_initialized) {
      Logger.errorLog('❌ Service not initialized');
      return false;
    }

    try {
      return await _apiService.postFormData(
        siteType: siteType,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
        screenType: screenType,
        formData: formData,
      );
    } catch (e) {
      Logger.errorLog('❌ Error posting form data: $e');
      return false;
    }
  }

  /// Post SPV data
  Future<bool> postSPVData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
    required Map<String, dynamic> formData,
  }) async {
    return await postFormData(
      siteType: siteType,
      auditSchId: auditSchId,
      siteAuditSchId: siteAuditSchId,
      screenType: 'spv',
      formData: formData,
    );
  }

  /// Clear all data
  Future<void> clearAllData() async {
    if (!_initialized) {
      Logger.errorLog('❌ Service not initialized');
      return;
    }

    try {
      await _imageUploadService.clearAllImages();
      await _dataService.clearAllData();
      Logger.debugLog('✅ All data cleared');
    } catch (e) {
      Logger.errorLog('❌ Error clearing all data: $e');
    }
  }

  /// Drop and recreate all databases with all tables
  Future<void> dropAndRecreateAllDatabases() async {
    if (!_initialized) {
      Logger.errorLog('❌ Service not initialized');
      return;
    }

    try {
      Logger.debugLog('🗑️ Dropping and recreating all databases');
      
      // Drop and recreate both databases
      await Future.wait([
        _dataService.dropAndRecreateDatabase(),
        _imageUploadService.dropAndRecreateDatabase(),
      ]);
      
      Logger.debugLog('✅ All databases dropped and recreated successfully');
    } catch (e) {
      Logger.errorLog('❌ Error dropping and recreating databases: $e');
      rethrow;
    }
  }

  /// Convert API response page header to expected format
  Map<String, dynamic> _convertPageHeaderFromApi(Map<String, dynamic> apiPageHeader) {
    try {
      Logger.debugLog('🔄 Converting page header from API format');
      Logger.debugLog('🔄 API page header keys: ${apiPageHeader.keys.toList()}');
      Logger.debugLog('🔄 API page header data: $apiPageHeader');
      
      final converted = {
        'siteType': apiPageHeader['site_domain_name'] ?? apiPageHeader['site_type'],
        'auditSchId': apiPageHeader['audit_sch_id'],
        'siteCode': apiPageHeader['site_code'],
        'siteName': apiPageHeader['site_name'],
        'clientName': apiPageHeader['client_name'],
        'district': apiPageHeader['district'],
        'solarState': apiPageHeader['solar_state'],
        'solarDistrict': apiPageHeader['solar_district'],
        'siteTypeName': apiPageHeader['site_type_name'],
        'status': apiPageHeader['status'],
        'auditDueDt': apiPageHeader['audit_due_dt'],
        'makerSelfieImageId': apiPageHeader['maker_selfie_image_id'],
      };
      
      Logger.debugLog('🔄 Converted page header: $converted');
      return converted;
    } catch (e) {
      Logger.errorLog('❌ Error converting page header: $e');
      Logger.errorLog('❌ API page header that caused error: $apiPageHeader');
      rethrow;
    }
  }


  /// Check if service is initialized
  bool get isInitialized => _initialized;
}
