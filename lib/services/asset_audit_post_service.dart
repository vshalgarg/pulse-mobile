import 'package:app/enum/ImageActivityTypeEnum.dart';
import 'package:app/services/api_service.dart';
import 'package:app/services/image_upload_service.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/services/location_service.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/utils.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:geolocator/geolocator.dart';

/// Service for posting asset audit data with photo ID replacement
/// This service handles replacing local unique_id photo IDs with server_id
/// and adding photo_taken_ts using the images table's created_at timestamp
class AssetAuditPostService {
  final ApiService _apiService;
  final ImageUploadService _imageUploadService;

  AssetAuditPostService({
    required ApiService apiService,
    required ImageUploadService imageUploadService,
  }) : _apiService = apiService,
       _imageUploadService = imageUploadService;

  /// Post asset audit data with photo ID replacement
  /// This method replaces all photo_id values with server_id from images table
  /// and adds photo_taken_ts using the images table's created_at timestamp
  Future<void> postAssetAuditDataWithPhotoReplacement({
    required List<dynamic> requests,
  }) async {
    try {
      // Get current location with offline support
      Map<String, String>? finalLocation;

      try {
        // Try offline location first
        final location = await LocationService.getCurrentLocationOffline();

        if (location != null) {
          finalLocation = location;
        } else {
          // Try fresh GPS location
          final freshLocation = await LocationService.getCurrentLocation();

          if (freshLocation != null) {
            finalLocation = {
              'latitude': freshLocation.latitude.toString(),
              'longitude': freshLocation.longitude.toString(),
            };
          } else {}
        }
      } catch (e) {
        Logger.debugLog('❌ AssetAuditPostService: Error getting location: $e');
      }

      // Final check - if still no location, try direct geolocator
      if (finalLocation == null) {
        try {
          // Check permissions
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.deniedForever) {
            Logger.debugLog(
              '❌ AssetAuditPostService: Location permission permanently denied',
            );
          } else if (permission == LocationPermission.denied) {
            Logger.debugLog(
              '❌ AssetAuditPostService: Location permission denied',
            );
          } else {
            // Check if location services are enabled
            bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
            Logger.debugLog(
              '🔍 AssetAuditPostService: Location service enabled: $serviceEnabled',
            );

            if (serviceEnabled) {
              // Try to get current position
              Position position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              );

              finalLocation = {
                'latitude': position.latitude.toString(),
                'longitude': position.longitude.toString(),
              };
              Logger.debugLog(
                '✅ AssetAuditPostService: Direct geolocator success: $finalLocation',
              );
            } else {
              Logger.debugLog(
                '❌ AssetAuditPostService: Location services disabled',
              );
            }
          }
        } catch (e) {
          Logger.debugLog(
            '❌ AssetAuditPostService: Direct geolocator error: $e',
          );
        }
      }

      // Final final check
      if (finalLocation == null) {
        Logger.debugLog(
          '❌ AssetAuditPostService: No location available at all!',
        );
      } else {
        Logger.debugLog(
          '✅ AssetAuditPostService: Final location: $finalLocation',
        );
      }

      // Process each request to replace photo IDs and add timestamps
      final List<dynamic> processedRequests = [];

      for (int i = 0; i < requests.length; i++) {
        final processedRequest = await _processAssetAuditRequest(requests[i]);

        // Debug logging for location values
        Logger.debugLog(
          '🔍 AssetAuditPostService: Processing request ${i + 1}',
        );
        Logger.debugLog(
          '🔍 AssetAuditPostService: Final location: ${finalLocation?['longitude']}, ${finalLocation?['latitude']}',
        );
        Logger.debugLog(
          '🔍 AssetAuditPostService: Existing longitude: ${processedRequest['longitude']}',
        );
        Logger.debugLog(
          '🔍 AssetAuditPostService: Existing latitude: ${processedRequest['latitude']}',
        );

        // Add location data to each request
        // Use current GPS location first, then existing values, then null if no location available
        final finalLongitude =
            finalLocation?['longitude'] ?? processedRequest['longitude'];
        final finalLatitude =
            finalLocation?['latitude'] ?? processedRequest['latitude'];

        processedRequest['longitude'] = finalLongitude;
        processedRequest['latitude'] = finalLatitude;

        // Add auditSchId: 0 to every object
        processedRequest['auditSchId'] = 0;
        Logger.debugLog('🔍 AssetAuditPostService: Added auditSchId: 0 to request ${i + 1}');

        // Check if record_type is "Remarks" and add asset_Status: 'ok'
        if (processedRequest['record_type'] == 'Remarks') {
          processedRequest['asset_Status'] = 'ok';
          Logger.debugLog('🔍 AssetAuditPostService: Added asset_Status: ok for Remarks record ${i + 1}');
        }

        processedRequest['localCreatedDt'] =
            Utils.getCurrentDateTimeForAPICall();
        processedRequest['localModifiedDt'] =
            Utils.getCurrentDateTimeForAPICall();
        processedRequests.add(processedRequest);

        Logger.debugLog(
          '🔍 AssetAuditPostService: Final values - Lat: $finalLatitude, Lng: $finalLongitude',
        );

        // Check if we have valid location data
        if (finalLatitude == null || finalLongitude == null) {
          Logger.debugLog(
            '⚠️ AssetAuditPostService: No valid location data for request ${i + 1}',
          );
        } else {
          Logger.debugLog(
            '✅ AssetAuditPostService: Valid location data for request ${i + 1}',
          );
        }
      }

      Logger.debugLog(
        '📤 AssetAuditPostService: Posting processed requests to API',
      );

      // Transform to camelCase just before API call
      final transformedRequests = DataTransformationHelper.transformAssetAuditData(processedRequests);
      Logger.debugLog('🔄 AssetAuditPostService: Data transformed to camelCase before API call');

      // Post the processed requests to the API
      final response = await _apiService.post<List<dynamic>>(
        path: '/api/v1/mobile/AssetAuditSiteResp',
        data: transformedRequests,
      );

      if (response.isSuccess && response.data != null) {
        Logger.infoLog("Data posted successfully");
      } else {
        final errorMsg =
            response.errorMessage ?? 'Failed to post asset audit data';
        Logger.errorLog('❌ Asset Audit POST API Error: $errorMsg');
      }
    } catch (e) {
      Logger.errorLog(
        '❌ AssetAuditPostService: Exception while posting data: $e',
      );
      rethrow;
    }
  }

  /// Process a single asset audit request
  /// Replaces photo_id with server_id and adds photo_taken_ts
  Future<dynamic> _processAssetAuditRequest(dynamic request) async {
    dynamic updatedRequest = {...request as Map<String, dynamic>};
    try {
      Logger.debugLog('🔍 _processAssetAuditRequest called with: ${updatedRequest.keys}');
      Logger.debugLog('🔍 Request photo_id: ${updatedRequest['photo_id']}');
      Logger.debugLog('🔍 Request photoId: ${updatedRequest['photoId']}');
      
      // Check both snake_case and camelCase field names
      final photoId = updatedRequest['photo_id'] ?? updatedRequest['photoId'];
      
      // If no photo_id, return the request as-is
      if (photoId == null) {
        Logger.debugLog(
          '📝 No photo_id to process for request: ${updatedRequest['nexgen_serial_no']}',
        );
        return updatedRequest;
      }
      Logger.debugLog(
        '🔍 Processing photo_id: $photoId for serial: ${updatedRequest['nexgen_serial_no']}',
      );

      // Check if photo_id is a unique_id (starts with LOCAL_IMAGE_ID_)
      // Note: After camelCase transformation, this might be 'photoId' instead of 'photo_id'
      if (photoId.toString().startsWith('LOCAL_IMAGE_ID_')) {
        // This is a unique_id, get the server_id using ImageUploadService
        final serverIdWithCreatedTime = await _imageUploadService.getServerIdAndCreatedTime(
          photoId.toString(),
          ActivityTypeEnum.assetAudit,
          updatedRequest['site_audit_sch_id'].toString(),
        );ss
        Logger.debugLog(
          '🔍 Server ID response: $serverIdWithCreatedTime (length: ${serverIdWithCreatedTime.length})',
        );

        if (serverIdWithCreatedTime.isNotEmpty) {
          final serverId = serverIdWithCreatedTime.first;
          final timestamp = serverIdWithCreatedTime.length > 1 ? serverIdWithCreatedTime.elementAt(1) : null;
          
          Logger.debugLog(
            '🔄 BEFORE replacement - photo_id: ${updatedRequest['photo_id']}, photoId: ${updatedRequest['photoId']}',
          );
          
          // Update both snake_case and camelCase field names
          updatedRequest['photo_id'] = serverId;
          updatedRequest['photoId'] = serverId;
          if (timestamp != null) {
            updatedRequest['photo_taken_ts'] = timestamp;
            updatedRequest['photoTakenTs'] = timestamp;
          }

          Logger.debugLog(
            '✅ Successfully replaced LOCAL_IMAGE_ID with server_id: $serverId',
          );
          Logger.debugLog(
            '🔄 AFTER replacement - photo_id: ${updatedRequest['photo_id']}, photoId: ${updatedRequest['photoId']}',
          );
          if (timestamp != null) {
            Logger.debugLog('📅 Photo taken timestamp: $timestamp');
          }
        } else {
          Logger.errorLog('❌ FAILED to get server_id for LOCAL_IMAGE_ID: $photoId');
          Logger.errorLog('❌ This means the photo upload to api/v1/mobile/uploads failed!');
          Logger.errorLog('❌ OR the server_id was not stored in SQLite properly!');
          // Keep the original photo_id for now, but log the error
        }
      } else {
        // This is already a server_id, just add photo_taken_ts if not present
        if (updatedRequest['photo_taken_ts'] == null ||
            updatedRequest['photo_taken_ts'].toString().isEmpty) {
          final currentTime = Utils.getCurrentDateTimeForAPICall();
          updatedRequest['photo_taken_ts'] = currentTime;
          Logger.debugLog('📅 Added current timestamp for server_id: $photoId');
        }
        return updatedRequest;
      }
    } catch (e) {
      Logger.errorLog('❌ Error processing asset audit request: $e');
      return request;
    }
    return updatedRequest;
  }
}
