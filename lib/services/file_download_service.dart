import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/logger.dart';

/// Common file download service that handles:
/// - Storage permission requests
/// - Getting Downloads directory (with fallbacks)
/// - Saving files to Downloads folder
class FileDownloadService {
  /// Requests storage permission based on platform
  /// Returns true if permission is granted, false otherwise
  static Future<bool> requestStoragePermission() async {
    try {
      PermissionStatus permissionStatus;

      if (Platform.isAndroid) {
        // Check Android version and request appropriate permissions
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        Logger.infoLog('[FileDownloadService] Android SDK: ${androidInfo.version.sdkInt}');

        if (androidInfo.version.sdkInt >= 30) {
          // Android 11+ - request manage external storage for public Downloads access
          permissionStatus = await Permission.manageExternalStorage.request();
          Logger.infoLog('[FileDownloadService] Manage external storage status: $permissionStatus');

          if (permissionStatus != PermissionStatus.granted) {
            // Fallback to storage permission
            permissionStatus = await Permission.storage.request();
            Logger.infoLog('[FileDownloadService] Storage permission status: $permissionStatus');
          }
        } else {
          // Android 10 and below - use storage permission
          permissionStatus = await Permission.storage.request();
          Logger.infoLog('[FileDownloadService] Storage permission status: $permissionStatus');
        }
      } else {
        // iOS - request storage permission
        permissionStatus = await Permission.storage.request();
        Logger.infoLog('[FileDownloadService] Storage permission status: $permissionStatus');
      }

      if (permissionStatus != PermissionStatus.granted) {
        Logger.errorLog('[FileDownloadService] Storage permission denied');
        return false;
      }

      return true;
    } catch (e) {
      Logger.errorLog('[FileDownloadService] Error requesting storage permission: $e');
      return false;
    }
  }

  /// Gets the Downloads directory with fallback strategies
  /// Returns the directory path that can be written to
  static Future<Directory> getDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        final externalStorage = await getExternalStorageDirectory();
        if (externalStorage != null) {
          // Get the root of external storage (remove the app-specific path)
          final rootPath = externalStorage.path.split('/Android')[0];
          Directory downloadsPath = Directory('$rootPath/Download');

          // Test if we can write to public Downloads
          try {
            if (!await downloadsPath.exists()) {
              await downloadsPath.create(recursive: true);
            }
            // Test write access
            final testFile = File('${downloadsPath.path}/test_write.tmp');
            await testFile.writeAsString('test');
            await testFile.delete();
            Logger.infoLog('[FileDownloadService] Using public Downloads: ${downloadsPath.path}');
            return downloadsPath;
          } catch (e) {
            Logger.infoLog('[FileDownloadService] Cannot write to public Downloads, trying alternative: $e');
            // Try alternative public Downloads path
            downloadsPath = Directory('/storage/emulated/0/Download');

            try {
              if (!await downloadsPath.exists()) {
                await downloadsPath.create(recursive: true);
              }
              // Test write access
              final testFile = File('${downloadsPath.path}/test_write.tmp');
              await testFile.writeAsString('test');
              await testFile.delete();
              Logger.infoLog('[FileDownloadService] Using alternative public Downloads: ${downloadsPath.path}');
              return downloadsPath;
            } catch (e2) {
              Logger.infoLog('[FileDownloadService] Using app external storage Downloads: $e2');
              // Final fallback to app's external storage
              downloadsPath = Directory('${externalStorage.path}/Downloads');
              return downloadsPath;
            }
          }
        } else {
          throw Exception('Could not access external storage');
        }
      } else {
        // For iOS, use documents directory
        return await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      Logger.errorLog('[FileDownloadService] Error getting Downloads directory: $e');
      // Final fallback to app documents directory
      final fallbackDir = await getApplicationDocumentsDirectory();
      Logger.infoLog('[FileDownloadService] Using fallback directory: ${fallbackDir.path}');
      return fallbackDir;
    }
  }

  /// Downloads file from binary data and saves to Downloads folder
  /// 
  /// Parameters:
  /// - [data]: The binary data to save
  /// - [fileName]: The filename to save as (should include extension, e.g., "file.pdf" or "image.jpg")
  /// - [requirePermission]: Whether to request storage permission first (default: true)
  /// 
  /// Returns the file path where the file was saved
  /// 
  /// Throws exception if download fails
  static Future<String> downloadFileFromBytes({
    required Uint8List data,
    required String fileName,
    bool requirePermission = true,
  }) async {
    try {
      Logger.infoLog('[FileDownloadService] 🔄 Downloading file: $fileName (${data.length} bytes)');

      // Request permission if required
      if (requirePermission) {
        final hasPermission = await requestStoragePermission();
        if (!hasPermission) {
          throw Exception('Storage permission denied');
        }
      }

      // Get Downloads directory
      final downloadsPath = await getDownloadsDirectory();

      // Create downloads folder if it doesn't exist
      if (!await downloadsPath.exists()) {
        await downloadsPath.create(recursive: true);
      }

      // Sanitize filename - remove invalid characters but preserve extension
      final lastDotIndex = fileName.lastIndexOf('.');
      String nameWithoutExt = lastDotIndex > 0
          ? fileName.substring(0, lastDotIndex)
          : fileName;
      String extension = lastDotIndex > 0 && lastDotIndex < fileName.length - 1
          ? fileName.substring(lastDotIndex)
          : '';

      // Sanitize the name part (without extension)
      nameWithoutExt = nameWithoutExt.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      // Reconstruct filename
      final sanitizedFileName = extension.isNotEmpty
          ? '$nameWithoutExt$extension'
          : nameWithoutExt;

      // Save file to Downloads; if denied, fallback to app documents directory.
      String filePath = '${downloadsPath.path}/$sanitizedFileName';
      File file = File(filePath);
      try {
        await file.writeAsBytes(data);
      } on FileSystemException catch (e) {
        Logger.errorLog(
          '[FileDownloadService] Write failed at $filePath, falling back to app storage: $e',
        );
        final fallbackDir = await getApplicationDocumentsDirectory();
        filePath = '${fallbackDir.path}/$sanitizedFileName';
        file = File(filePath);
        await file.writeAsBytes(data);
      }

      Logger.infoLog('[FileDownloadService] ✅ File saved to: $filePath');
      return filePath;
    } catch (e) {
      Logger.errorLog('[FileDownloadService] ❌ Exception in downloadFileFromBytes: $e');
      Logger.errorLog('[FileDownloadService] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Shows a dialog to request storage permission if needed
  /// 
  /// Parameters:
  /// - [context]: BuildContext for showing dialog
  /// - [onSettingsPressed]: Optional callback when user presses "Open Settings"
  /// 
  /// Returns true if permission is granted, false otherwise
  static Future<bool> requestStoragePermissionWithDialog({
    required BuildContext context,
    VoidCallback? onSettingsPressed,
  }) async {
    try {
      final hasPermission = await requestStoragePermission();
      if (!context.mounted) return hasPermission;
      
      if (!hasPermission) {
        final shouldShowRationale = await Permission.storage.shouldShowRequestRationale;
        final status = await Permission.storage.status;
        if (!context.mounted) return hasPermission;
        
        if (shouldShowRationale || status.isPermanentlyDenied) {
          // Show dialog to request permission
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Storage Permission Required'),
              content: const Text(
                'This app needs storage permission to download files. Please grant permission in settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (onSettingsPressed != null) {
                      onSettingsPressed();
                    } else {
                      openAppSettings();
                    }
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
      }
      
      return hasPermission;
    } catch (e) {
      Logger.errorLog('[FileDownloadService] Error in requestStoragePermissionWithDialog: $e');
      return false;
    }
  }
}

