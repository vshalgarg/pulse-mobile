import 'dart:async';
import 'dart:convert';
import 'package:app/database/asset_audit_database.dart';
import 'package:app/repositories/image_repository.dart';
import 'package:app/services/api_provider.dart';
import 'package:app/models/asset_audit_model.dart';
import 'package:app/utils/logger.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final AssetAuditDatabase _database = AssetAuditDatabase();
  ImageRepository? _imageRepository;
  final Set<int> _downloadingImages = <int>{};
  final Map<int, Completer<String?>> _downloadCompleters = {};

  void _initializeImageRepository(ApiProvider apiProvider) {
    _imageRepository ??= ImageRepository(apiProvider);
  }

  /// Proactively download and cache all images for a site
  Future<void> cacheImagesForSite(int siteAuditSchId, List<int> imageIds, {ApiProvider? apiProvider}) async {
    if (apiProvider != null) {
      _initializeImageRepository(apiProvider);
    }
    
    if (_imageRepository == null) {
      Logger.errorLog('ImageRepository not initialized. Cannot cache images.');
      return;
    }
    Logger.debugLog('=== ImageCacheService: Starting image caching for site $siteAuditSchId ===');
    Logger.debugLog('Image IDs to cache: $imageIds');
    
    if (imageIds.isEmpty) {
      Logger.debugLog('No images to cache for site $siteAuditSchId');
      return;
    }

    // Filter out already cached images
    final List<int> imagesToDownload = [];
    for (final imageId in imageIds) {
      final cachedImage = await _database.getCachedImage(imageId);
      if (cachedImage == null) {
        imagesToDownload.add(imageId);
      } else {
        Logger.debugLog('Image $imageId already cached, skipping');
      }
    }

    if (imagesToDownload.isEmpty) {
      Logger.debugLog('All images already cached for site $siteAuditSchId');
      return;
    }

    Logger.debugLog('Images to download: $imagesToDownload');

    // Download images in batches to avoid overwhelming the API
    const int batchSize = 5;
    for (int i = 0; i < imagesToDownload.length; i += batchSize) {
      final batch = imagesToDownload.skip(i).take(batchSize).toList();
      await _downloadImageBatch(siteAuditSchId, batch);
    }

    Logger.debugLog('=== ImageCacheService: Completed image caching for site $siteAuditSchId ===');
  }

  /// Download a batch of images
  Future<void> _downloadImageBatch(int siteAuditSchId, List<int> imageIds) async {
    Logger.debugLog('Downloading batch: $imageIds');
    
    final List<Future<void>> downloadTasks = imageIds.map((imageId) => 
      _downloadSingleImage(siteAuditSchId, imageId)
    ).toList();
    
    await Future.wait(downloadTasks);
  }

  /// Download a single image
  Future<void> _downloadSingleImage(int siteAuditSchId, int imageId) async {
    if (_imageRepository == null) {
      Logger.errorLog('ImageRepository not initialized. Cannot download image.');
      return;
    }
    
    if (_downloadingImages.contains(imageId)) {
      Logger.debugLog('Image $imageId is already being downloaded, waiting...');
      // Wait for the existing download to complete
      if (_downloadCompleters.containsKey(imageId)) {
        await _downloadCompleters[imageId]!.future;
      }
      return;
    }

    _downloadingImages.add(imageId);
    final completer = Completer<String?>();
    _downloadCompleters[imageId] = completer;

    try {
      // Check if image is already cached
      final isCached = await _database.isImageCached(imageId);
      if (isCached) {
        Logger.debugLog('Image $imageId already cached, skipping download');
        completer.complete('cached');
        return;
      }
      
      Logger.debugLog('Downloading image $imageId...');
      final result = await _imageRepository!.getImage(imgId: imageId.toString());
      
      if (result.isSuccess && result.data != null) {
        await _database.insertCachedImage(
          imageId,
          result.data!,
          imageType: 'asset_audit',
          siteAuditSchId: siteAuditSchId,
        );
        Logger.debugLog('✅ Successfully cached image $imageId');
        completer.complete(result.data);
      } else {
        Logger.errorLog('❌ Failed to download image $imageId: ${result.errorMessage}');
        completer.complete(null);
      }
    } catch (e) {
      Logger.errorLog('❌ Exception downloading image $imageId: $e');
      completer.complete(null);
    } finally {
      _downloadingImages.remove(imageId);
      _downloadCompleters.remove(imageId);
    }
  }

  /// Get cached image data
  Future<String?> getCachedImage(int imageId) async {
    return await _database.getCachedImage(imageId);
  }

  /// Check if image is cached
  Future<bool> isImageCached(int imageId) async {
    final cachedImage = await _database.getCachedImage(imageId);
    return cachedImage != null;
  }

  /// Get all cached image IDs for a site
  Future<List<int>> getCachedImageIds(int siteAuditSchId) async {
    return await _database.getCachedImageIds(siteAuditSchId);
  }

  /// Extract image IDs from asset audit data
  List<int> extractImageIds(AssetAuditModel assetAuditData) {
    final List<int> imageIds = [];
    
    // Extract from page header
    if (assetAuditData.pageHeader.isNotEmpty) {
      final pageHeader = assetAuditData.pageHeader.first;
      if (pageHeader.makerSelfieImageId != null && pageHeader.makerSelfieImageId! > 0) {
        imageIds.add(pageHeader.makerSelfieImageId!);
      }
    }
    
    // Extract from asset items
    for (final category in assetAuditData.responseData.categories.values) {
      for (final asset in category.assets) {
        if (asset.photoId != null && asset.photoId! > 0) {
          imageIds.add(asset.photoId!);
        }
      }
      
      // Extract from subcategories
      if (category.subCategories != null) {
        for (final subcategoryItems in category.subCategories!.values) {
          for (final asset in subcategoryItems) {
            if (asset.photoId != null && asset.photoId! > 0) {
              imageIds.add(asset.photoId!);
            }
          }
        }
      }
    }
    
    // Remove duplicates
    return imageIds.toSet().toList();
  }

  /// Clear cached images for a specific site
  Future<void> clearCachedImagesForSite(int siteAuditSchId) async {
    Logger.debugLog('Clearing cached images for site $siteAuditSchId');
    // Note: This would require adding a method to the database to delete by site
    // For now, we'll keep all images cached as requested
  }

  /// Clear all cached images
  Future<void> clearAllCachedImages() async {
    Logger.debugLog('Clearing all cached images');
    // Note: This would require adding a method to the database to delete all images
    // For now, we'll keep all images cached as requested
  }
}
