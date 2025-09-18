import 'dart:async';
import 'package:app/bloc/asset_audit_cubit.dart';
import 'package:app/bloc/asset_audit_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/bloc/asset_audit_photo_upload_cubit.dart';

/// Generic photo upload utility that can be used across different asset audit screens
/// Returns the image ID from the server after successful upload
class GenericPhotoUploadHelper {
  
  /// Uploads a photo file and returns the image ID from server
  /// 
  /// [context] - BuildContext for accessing cubit
  /// [file] - File to upload
  /// [schId] - Site audit schedule ID (optional, will be fetched from cubit if not provided)
  /// [imgIdToUse] - Image ID to use for upload (defaults to "0" for new uploads)
  /// 
  /// Returns [String?] - The image ID returned from server, or null if upload failed
  static Future<String?> uploadPhoto({
    required BuildContext context,
    required File file,
    String? schId,
    String imgIdToUse = "0",
  }) async {
    try {
      // Get asset audit state to extract schId if not provided
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        final finalSchId = schId ?? assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();
        final completer = Completer<String?>();
        late StreamSubscription subscription;

        // Listen to photo upload state changes
        subscription = context.read<AssetAuditPhotoUploadCubit>().stream.listen((state) {
          if (state is AssetAuditPhotoUploadSuccess) {
            subscription.cancel();
            completer.complete(state.response.imgId);
          } else if (state is AssetAuditPhotoUploadFailure) {
            subscription.cancel();
            completer.complete(null);
          }
        });

        // Start the upload
        context.read<AssetAuditPhotoUploadCubit>().uploadPhoto(
          file: file,
          schId: finalSchId,
          imgId: imgIdToUse,
        );

        // Wait for upload to complete (with timeout)
        final result = await completer.future.timeout(
          const Duration(minutes: 2), // 2 minute timeout
          onTimeout: () {
            subscription.cancel();
            return null;
          },
        );

        if (result != null && result.isNotEmpty && result != "0") {
          return result;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Uploads a photo from file path and returns the image ID from server
  /// 
  /// [context] - BuildContext for accessing cubit
  /// [filePath] - Path to the file to upload
  /// [schId] - Site audit schedule ID (optional, will be fetched from cubit if not provided)
  /// [imgIdToUse] - Image ID to use for upload (defaults to "0" for new uploads)
  /// 
  /// Returns [String?] - The image ID returned from server, or null if upload failed
  static Future<String?> uploadPhotoFromPath({
    required BuildContext context,
    required String filePath,
    String? schId,
    String imgIdToUse = "0",
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      
      return await uploadPhoto(
        context: context,
        file: file,
        schId: schId,
        imgIdToUse: imgIdToUse,
      );
    } catch (e) {
      return null;
    }
  }

  /// Validates if a file is a valid image file
  /// 
  /// [file] - File to validate
  /// 
  /// Returns [bool] - True if file is a valid image, false otherwise
  static bool isValidImageFile(File file) {
    try {
      final extension = file.path.toLowerCase().split('.').last;
      const validExtensions = ['jpg', 'jpeg', 'png', 'bmp', 'gif'];
      return validExtensions.contains(extension);
    } catch (e) {
      return false;
    }
  }

  /// Validates if a file path points to a valid image file
  /// 
  /// [filePath] - File path to validate
  /// 
  /// Returns [bool] - True if file path is a valid image, false otherwise
  static bool isValidImagePath(String filePath) {
    try {
      final file = File(filePath);
      return isValidImageFile(file);
    } catch (e) {
      return false;
    }
  }

  /// Gets file size in bytes
  /// 
  /// [file] - File to get size for
  /// 
  /// Returns [int] - File size in bytes, or 0 if error
  static Future<int> getFileSize(File file) async {
    try {
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  /// Gets file size from file path
  /// 
  /// [filePath] - File path to get size for
  /// 
  /// Returns [int] - File size in bytes, or 0 if error
  static Future<int> getFileSizeFromPath(String filePath) async {
    try {
      final file = File(filePath);
      return await getFileSize(file);
    } catch (e) {
      return 0;
    }
  }

  /// Formats file size for display
  /// 
  /// [bytes] - File size in bytes
  /// 
  /// Returns [String] - Formatted file size (e.g., "1.5 MB")
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
