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

      return filePath;
    } catch (e) {

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

    } catch (e) {

    }
  }

  /// Get local image path for a photo ID
  static String? getLocalImagePath(String siteAuditSchId, String photoId) {
    try {

      final key = 'offline_image_${siteAuditSchId}_$photoId';

      final data = LocalStorageService.getJson(key);

      if (data != null) {
        final metadata = Map<String, dynamic>.from(data);
        final localPath = metadata['localPath'] as String?;

        // Check if file still exists
        if (localPath != null && File(localPath).existsSync()) {

          return localPath;
        } else {

        }
      } else {

      }
      return null;
    } catch (e) {

      return null;
    }
  }

  /// Get all saved images for a site
  static List<Map<String, dynamic>> getSavedImages(String siteAuditSchId) {
    try {
      final List<Map<String, dynamic>> images = [];
      final keys = LocalStorageService.getKeys();

      for (final key in keys) {

        if (key.startsWith('offline_image_${siteAuditSchId}_')) {

          final data = LocalStorageService.getJson(key);
          if (data != null) {

            if (data['localPath'] != null && File(data['localPath']).existsSync()) {
              images.add(data);

            }
          }
        }
      }

      return images;
    } catch (e) {

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

    } catch (e) {

    }
  }
}
