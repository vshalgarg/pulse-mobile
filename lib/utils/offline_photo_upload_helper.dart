import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import '../bloc/asset_audit_photo_upload_cubit.dart';
// import '../services/connectivity_service.dart';
// import '../services/local_storage_db.dart';
// import 'photo_id_adapter.dart';
//
// class OfflinePhotoUploadHelper {
//   static final ConnectivityService _connectivityService = ConnectivityService();
//
//   /// Convert photo ID to String (handles both int and String inputs)
//   static String? photoIdToString(dynamic photoId) {
//     if (photoId == null) return null;
//     if (photoId is String) return photoId;
//     if (photoId is int) return photoId.toString();
//     return photoId.toString();
//   }
//
//   /// Convert photo ID to int (for API compatibility)
//   static int? photoIdToInt(dynamic photoId) {
//     if (photoId == null) return null;
//     if (photoId is int) return photoId;
//     if (photoId is String) return int.tryParse(photoId);
//     return null;
//   }
//
//   /// Upload photo with offline-first approach
//   /// Returns photoId as String (converts int from server to String)
//   static Future<String?> uploadPhotoOfflineFirst({
//     required File photoFile,
//     String? schId,
//     String? imgId,
//     required BuildContext context,
//   }) async {
//     try {
//       // Check if we're online
//       if (_connectivityService.isOnline) {
//         // Online: Try to upload to server
//         try {
//           final photoId = await _uploadToServer(
//             photoFile: photoFile,
//             schId: schId,
//             imgId: imgId,
//             context: context,
//           );
//
//           if (photoId != null) {
//             return photoId;
//           }
//         } catch (e) {
//         }
//       }
//
//       // Offline or server upload failed: Save locally
//       return await _savePhotoOffline(photoFile, schId);
//
//     } catch (e) {
//       return null;
//     }
//   }
//
//   /// Upload photo with offline-first approach - API Compatible Version
//   /// Returns photoId as int (for existing API-compatible code)
//   static Future<int?> uploadPhotoOfflineFirstApiCompatible({
//     required File photoFile,
//     String? schId,
//     String? imgId,
//     required BuildContext context,
//   }) async {
//     try {
//       // Get the String photo ID from the main method
//       final stringPhotoId = await uploadPhotoOfflineFirst(
//         photoFile: photoFile,
//         schId: schId,
//         imgId: imgId,
//         context: context,
//       );
//
//       // Convert to int for API compatibility
//       return PhotoIdAdapter.toApiInt(stringPhotoId);
//
//     } catch (e) {
//       return null;
//     }
//   }
//
//   /// Upload photo to server (online mode)
//   static Future<String?> _uploadToServer({
//     required File photoFile,
//     String? schId,
//     String? imgId,
//     required BuildContext context,
//   }) async {
//     try {
//       final photoUploadCubit = context.read<AssetAuditPhotoUploadCubit>();
//
//       await photoUploadCubit.uploadPhoto(
//         file: photoFile,
//         imgId: imgId,
//         schId: schId,
//       );
//
//       // Wait for the state to update
//       await Future.delayed(const Duration(milliseconds: 500));
//
//       // Get the current state to check if upload was successful
//       final state = photoUploadCubit.state;
//       if (state is AssetAuditPhotoUploadSuccess) {
//         // Convert server photo ID (int) to String for consistency
//         final photoId = state.response.imgId;
//         return photoId; // imgId is already a String from the response
//       } else if (state is AssetAuditPhotoUploadFailure) {
//         return null;
//       } else {
//         return null;
//       }
//     } catch (e) {
//       return null;
//     }
//   }
//
//   /// Save photo offline (offline mode)
//   static Future<String?> _savePhotoOffline(File photoFile, String? schId) async {
//     try {
//       // Generate a unique local photo ID
//       final timestamp = DateTime.now().millisecondsSinceEpoch;
//       final localPhotoId = 'local_${timestamp}_${photoFile.path.split('/').last}';
//
//       // Convert file to base64 for storage
//       final bytes = await photoFile.readAsBytes();
//       final base64String = base64Encode(bytes);
//
//       // Save to Hive with local photo ID
//       await HiveDB.saveOfflinePhoto(
//         photoId: localPhotoId,
//         filePath: photoFile.path,
//         base64Data: base64String,
//         schId: schId ?? 'unknown',
//       );
//
//       return localPhotoId;
//
//     } catch (e) {
//       return null;
//     }
//   }
//
//   /// Get photo from offline storage or server
//   static Future<File?> getPhoto({
//     required String photoId,
//     String? schId,
//     required BuildContext context,
//   }) async {
//     try {
//       // Check if it's a local photo ID
//       if (photoId.startsWith('local_')) {
//         return await _getOfflinePhoto(photoId);
//       } else {
//         // It's a server photo ID, try to get from server
//         if (_connectivityService.isOnline) {
//           return await _getServerPhoto(photoId, context);
//         } else {
//           // Offline and server photo ID - return null
//           return null;
//         }
//       }
//     } catch (e) {
//       return null;
//     }
//   }
//
//   /// Get photo from offline storage
//   static Future<File?> _getOfflinePhoto(String localPhotoId) async {
//     try {
//       final photoData = await HiveDB.getOfflinePhoto(localPhotoId);
//       if (photoData != null && photoData['filePath'] != null) {
//         final file = File(photoData['filePath']);
//         if (await file.exists()) {
//           return file;
//         }
//       }
//       return null;
//     } catch (e) {
//       return null;
//     }
//   }
//
//   /// Get photo from server (placeholder - would need to implement)
//   static Future<File?> _getServerPhoto(String photoId, BuildContext context) async {
//     // This would need to be implemented based on your server API
//     // For now, return null
//     return null;
//   }
//
//   /// Sync offline photos to server when online
//   static Future<void> syncOfflinePhotos() async {
//     try {
//       if (!_connectivityService.isOnline) {
//         return;
//       }
//
//       // Get all offline photos
//       final offlinePhotos = await HiveDB.getAllOfflinePhotos();
//
//       for (final photoData in offlinePhotos) {
//         try {
//           final localPhotoId = photoData['photoId'] as String;
//           final filePath = photoData['filePath'] as String;
//           final schId = photoData['schId'] as String;
//
//           final file = File(filePath);
//           if (await file.exists()) {
//             // Try to upload to server
//             // This would need to be implemented based on your upload logic
//
//             // After successful upload, remove from offline storage
//             // await HiveDB.deleteOfflinePhoto(localPhotoId);
//           }
//         } catch (e) {
//         }
//       }
//     } catch (e) {
//     }
//   }
// }
