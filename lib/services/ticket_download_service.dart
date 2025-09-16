import '../services/local_storage_db.dart';
import '../repositories/asset_audit_repository.dart';
import '../models/asset_audit_model.dart';
import '../utils/offline_image_helper.dart';
import '../utils/connectivity_helper.dart';
import '../services/api_service.dart';

class TicketDownloadService {
  final AssetAuditRepository _assetAuditRepository;
  final ApiService _apiService;

  TicketDownloadService({
    required AssetAuditRepository assetAuditRepository,
    required ApiService apiService,
  }) : _assetAuditRepository = assetAuditRepository,
       _apiService = apiService;

  /// Download and save asset audit data for offline use
  Future<bool> downloadAssetAuditData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    try {
      print('TicketDownloadService: Starting download for site $siteAuditSchId');
      print('TicketDownloadService: siteType: $siteType, auditSchId: $auditSchId');
      
      // Check connectivity first
      final isOnline = await ConnectivityHelper.isConnected();
      if (!isOnline) {
        print('TicketDownloadService: No internet connection - cannot download data');
        return false;
      }
      print('TicketDownloadService: Internet connection available, proceeding with download');
      
      // Call the asset audit API to get complete data
      final AssetAuditModel assetAuditData = await _assetAuditRepository.getAssetAuditData(
        siteType: siteType,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
      );

      print('TicketDownloadService: Received asset audit data');
      print('TicketDownloadService: PageHeader count: ${assetAuditData.pageHeader.length}');
      print('TicketDownloadService: ResponseData categories: ${assetAuditData.responseData.categories.keys}');

      // Convert the complete data to JSON for storage
      final completeTicketData = assetAuditData.toJson();

      // Save to local storage
      await LocalStorageDB.saveOfflineTicket(
        siteAuditSchId: siteAuditSchId,
        completeTicketData: completeTicketData,
      );

      // Save all images locally (only if still online)
      final isStillOnline = await ConnectivityHelper.isConnected();
      if (isStillOnline) {
        print('TicketDownloadService: Still online, proceeding with image download');
        await _saveAllImagesLocally(assetAuditData, siteAuditSchId);
      } else {
        print('TicketDownloadService: Lost connection - skipping image download');
      }

      print('TicketDownloadService: Successfully downloaded and saved data for site $siteAuditSchId');
      return true;
    } catch (e) {
      print('TicketDownloadService: Error downloading data for site $siteAuditSchId: $e');
      return false;
    }
  }

  /// Check if a ticket is already downloaded
  bool isTicketDownloaded(String siteAuditSchId) {
    return LocalStorageDB.isTicketDownloaded(siteAuditSchId);
  }

  /// Get downloaded ticket data
  Map<String, dynamic>? getDownloadedTicketData(String siteAuditSchId) {
    return LocalStorageDB.getOfflineTicket(siteAuditSchId);
  }

  /// Delete downloaded ticket data
  Future<void> deleteDownloadedTicket(String siteAuditSchId) async {
    await LocalStorageDB.deleteOfflineTicket(siteAuditSchId);
  }

  /// Get all downloaded tickets
  List<Map<String, dynamic>> getAllDownloadedTickets() {
    return LocalStorageDB.getAllOfflineTickets();
  }

  /// Save all images from asset audit data locally
  Future<void> _saveAllImagesLocally(AssetAuditModel assetAuditData, String siteAuditSchId) async {
    try {
      print('TicketDownloadService: Starting to save images locally for site $siteAuditSchId');
      print('TicketDownloadService: Asset audit data categories: ${assetAuditData.responseData.categories.keys}');
      
      // Collect all photo IDs first
      List<String> allPhotoIds = [];
      Map<String, String> photoIdToCategory = {};
      
      // Collect photo IDs from all categories
      for (final categoryEntry in assetAuditData.responseData.categories.entries) {
        final categoryName = categoryEntry.key;
        final categoryData = categoryEntry.value;
        
        print('TicketDownloadService: Processing category: $categoryName with ${categoryData.assets.length} assets');
        
        // Collect from assets
        for (final asset in categoryData.assets) {
          print('TicketDownloadService: Asset - photoId: ${asset.photoId}, imageName: ${asset.imageName}');
          if (asset.photoId != null && asset.imageName != null) {
            final photoId = asset.photoId.toString();
            allPhotoIds.add(photoId);
            photoIdToCategory[photoId] = categoryName;
            print('TicketDownloadService: Added photoId $photoId for category $categoryName');
          }
        }
        
        // Collect from subcategories
        if (categoryData.subCategories != null) {
          for (final subCategoryEntry in categoryData.subCategories!.entries) {
            final subCategoryName = subCategoryEntry.key;
            for (final asset in subCategoryEntry.value) {
              if (asset.photoId != null && asset.imageName != null) {
                final photoId = asset.photoId.toString();
                allPhotoIds.add(photoId);
                photoIdToCategory[photoId] = '$categoryName/$subCategoryName';
              }
            }
          }
        }
      }
      
      if (allPhotoIds.isEmpty) {
        print('TicketDownloadService: No images to download for site $siteAuditSchId');
        print('TicketDownloadService: This means no assets have photoId values');
        return;
      }
      
      print('TicketDownloadService: Found ${allPhotoIds.length} images to download: $allPhotoIds');
      print('TicketDownloadService: Photo ID to category mapping: $photoIdToCategory');
      
      // Download all images in a single batch request
      await _downloadAllImagesBatch(
        siteAuditSchId: siteAuditSchId,
        photoIds: allPhotoIds,
        photoIdToCategory: photoIdToCategory,
      );
      
      print('TicketDownloadService: Finished saving images locally for site $siteAuditSchId');
    } catch (e) {
      print('TicketDownloadService: Error saving images locally: $e');
    }
  }

  /// Download all images in a single batch request
  Future<void> _downloadAllImagesBatch({
    required String siteAuditSchId,
    required List<String> photoIds,
    required Map<String, String> photoIdToCategory,
  }) async {
    try {
      print('TicketDownloadService: Downloading ${photoIds.length} images in batch');
      
      // Check connectivity before making API call
      final isOnline = await ConnectivityHelper.isConnected();
      if (!isOnline) {
        print('TicketDownloadService: No internet connection - skipping image download');
        return;
      }
      
      // Join all photo IDs with comma
      final imgIdsParam = photoIds.join(',');
      
      final result = await _apiService.get(
        path: '/api/v1/mobile/allImageList',
        queryParameters: {
          'imgIds': imgIdsParam,
        },
      );

      if (result.isSuccess && result.data != null) {
        print('TicketDownloadService: API response type: ${result.data.runtimeType}');
        print('TicketDownloadService: API response data: ${result.data}');
        
        // The API returns a list of image objects, not a map
        final List<dynamic> imagesList = result.data as List<dynamic>;
        final Map<String, dynamic> imagesData = {};
        
        // Convert list to map using imageId as key
        for (var image in imagesList) {
          if (image is Map<String, dynamic>) {
            final imageId = image['imageId']?.toString();
            final imageData = image['imageData']?.toString();
            if (imageId != null && imageData != null) {
              imagesData[imageId] = imageData;
            }
          }
        }
        
        print('TicketDownloadService: Converted to map with ${imagesData.length} images');
        
        // Save each image locally
        for (final entry in imagesData.entries) {
          final photoId = entry.key;
          final imageData = entry.value as String?;
          
          print('TicketDownloadService: Processing image $photoId, data length: ${imageData?.length ?? 0}');
          
          if (imageData != null && imageData.isNotEmpty) {
            final category = photoIdToCategory[photoId] ?? 'unknown';
            print('TicketDownloadService: Saving image $photoId with category $category');
            final savedPath = await OfflineImageHelper.saveImageLocally(
              photoId: photoId,
              imageData: imageData,
              siteAuditSchId: siteAuditSchId,
              category: category,
            );
            print('TicketDownloadService: Saved image $photoId locally at: $savedPath');
          } else {
            print('TicketDownloadService: No data for image $photoId');
          }
        }
      } else {
        print('TicketDownloadService: API error downloading images: ${result.errorMessage}');
      }
    } catch (e) {
      print('TicketDownloadService: Exception downloading images batch: $e');
    }
  }

  /// Save a single image from API (kept for compatibility)
  Future<void> _saveImageFromApi({
    required String siteAuditSchId,
    required String photoId,
    String? category,
  }) async {
    try {
      print('TicketDownloadService: Downloading single image $photoId for category $category');
      
      // Download image from API
      final imageData = await _downloadImageFromApi(photoId);
      if (imageData != null && imageData.isNotEmpty) {
        await OfflineImageHelper.saveImageLocally(
          photoId: photoId,
          imageData: imageData,
          siteAuditSchId: siteAuditSchId,
          category: category,
        );
        print('TicketDownloadService: Successfully saved image $photoId locally');
      } else {
        print('TicketDownloadService: Failed to download image $photoId - no data received');
      }
    } catch (e) {
      print('TicketDownloadService: Error saving image $photoId: $e');
    }
  }

  /// Download single image from API (kept for compatibility)
  Future<String?> _downloadImageFromApi(String photoId) async {
    try {
      // Check connectivity before making API call
      final isOnline = await ConnectivityHelper.isConnected();
      if (!isOnline) {
        print('TicketDownloadService: No internet connection - cannot download image $photoId');
        return null;
      }
      
      final result = await _apiService.get(
        path: '/api/v1/mobile/allImageList',
        queryParameters: {
          'imgIds': photoId,
        },
      );

      if (result.isSuccess && result.data != null) {
        // The API returns base64 image data
        return result.data as String?;
      } else {
        print('TicketDownloadService: API error downloading image $photoId: ${result.errorMessage}');
        return null;
      }
    } catch (e) {
      print('TicketDownloadService: Exception downloading image $photoId: $e');
      return null;
    }
  }
}