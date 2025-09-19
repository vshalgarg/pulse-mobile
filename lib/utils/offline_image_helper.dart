import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/local_storage_db.dart';
import '../services/local_storage_constants.dart';
import '../services/local_storage_service.dart';

class OfflineImageHelper {
  /// Save image data to local storage and return local path
  static Future<String?> saveImageLocally({
    required String photoId,
    required String imageData,
    required String siteAuditSchId,
    String? category,
  }) async {
    try {
      // Create directory for offline images
      final directory = await getApplicationDocumentsDirectory();
      final offlineImagesDir = Directory('${directory.path}/offline_images/$siteAuditSchId');
      if (!await offlineImagesDir.exists()) {
        await offlineImagesDir.create(recursive: true);
      }

      // Generate filename
      final categoryPrefix = category != null ? '${category}_' : '';
      final filename = '${categoryPrefix}${photoId}.jpg';
      final filePath = '${offlineImagesDir.path}/$filename';

      // Decode base64 image data and save to file
      final bytes = base64Decode(imageData);
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Save image metadata to Hive
      await _saveImageMetadata(
        siteAuditSchId: siteAuditSchId,
        photoId: photoId,
        localPath: filePath,
        category: category,
      );

      print('OfflineImageHelper: Saved image locally: $filePath');
      return filePath;
    } catch (e) {
      print('OfflineImageHelper: Error saving image locally: $e');
      return null;
    }
  }

  /// Save image metadata to Hive
  static Future<void> _saveImageMetadata({
    required String siteAuditSchId,
    required String photoId,
    required String localPath,
    String? category,
  }) async {
    try {
      // Using SharedPreferences now
      final key = 'offline_image_${siteAuditSchId}_$photoId';
      
      await LocalStorageService.setJson(key, {
        'photoId': photoId,
        'localPath': localPath,
        'category': category,
        'siteAuditSchId': siteAuditSchId,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      print('OfflineImageHelper: Saved image metadata for photoId: $photoId');
    } catch (e) {
      print('OfflineImageHelper: Error saving image metadata: $e');
    }
  }

  /// Get local image path for a photo ID
  static String? getLocalImagePath(String siteAuditSchId, String photoId) {
    try {
      print('OfflineImageHelper: getLocalImagePath - siteAuditSchId: $siteAuditSchId, photoId: $photoId');
      final key = 'offline_image_${siteAuditSchId}_$photoId';
      print('OfflineImageHelper: Looking for key: $key');
      final data = LocalStorageService.getJson(key);
      print('OfflineImageHelper: Data found: ${data != null}');
      
      if (data != null) {
        final metadata = Map<String, dynamic>.from(data);
        final localPath = metadata['localPath'] as String?;
        print('OfflineImageHelper: Local path: $localPath');
        
        // Check if file still exists
        if (localPath != null && File(localPath).existsSync()) {
          print('OfflineImageHelper: File exists, returning path');
          return localPath;
        } else {
          print('OfflineImageHelper: File does not exist at path: $localPath');
        }
      } else {
        print('OfflineImageHelper: No metadata found for key: $key');
      }
      return null;
    } catch (e) {
      print('OfflineImageHelper: Error getting local image path: $e');
      return null;
    }
  }

  /// Get all saved images for a site
  static List<Map<String, dynamic>> getSavedImages(String siteAuditSchId) {
    try {
      final List<Map<String, dynamic>> images = [];
      final keys = LocalStorageService.getKeys();
      
      print('OfflineImageHelper: getSavedImages - siteAuditSchId: $siteAuditSchId');
      print('OfflineImageHelper: Total keys: ${keys.length}');
      
      for (final key in keys) {
        print('OfflineImageHelper: Checking key: $key');
        if (key.startsWith('offline_image_${siteAuditSchId}_')) {
          print('OfflineImageHelper: Found matching key: $key');
          final data = LocalStorageService.getJson(key);
          if (data != null) {
            print('OfflineImageHelper: Metadata: $data');
            if (data['localPath'] != null && File(data['localPath']).existsSync()) {
              images.add(data);
              print('OfflineImageHelper: Added image: ${data['photoId']}');
            }
          }
        }
      }
      
      print('OfflineImageHelper: Found ${images.length} images for site $siteAuditSchId');
      return images;
    } catch (e) {
      print('OfflineImageHelper: Error getting saved images: $e');
      return [];
    }
  }

  /// Clear all images for a site
  static Future<void> clearImagesForSite(String siteAuditSchId) async {
    try {
      final keysToDelete = <String>[];
      final keys = LocalStorageService.getKeys();
      
      for (final key in keys) {
        if (key.startsWith('offline_image_${siteAuditSchId}_')) {
          keysToDelete.add(key);
        }
      }
      
      for (final key in keysToDelete) {
        await LocalStorageService.remove(key);
      }
      
      // Also delete the physical files
      final directory = await getApplicationDocumentsDirectory();
      final offlineImagesDir = Directory('${directory.path}/offline_images/$siteAuditSchId');
      if (await offlineImagesDir.exists()) {
        await offlineImagesDir.delete(recursive: true);
      }
      
      print('OfflineImageHelper: Cleared all images for site $siteAuditSchId');
    } catch (e) {
      print('OfflineImageHelper: Error clearing images: $e');
    }
  }
}
