import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/asset_audit_photo_upload_cubit.dart';

class AssetAuditPhotoUploadHelper {
  static Future<int?> uploadPhotoAndGetId({
    required File photoFile,
    String? schId,
    String? imgId,
    required BuildContext context,
  }) async {
    try {
      final photoUploadCubit = context.read<AssetAuditPhotoUploadCubit>();

      await photoUploadCubit.uploadPhoto(
        file: photoFile,
        imgId: imgId,
        schId: schId,
      );

      // Wait a bit for the state to update
      await Future.delayed(const Duration(milliseconds: 500));

      // Get the current state to check if upload was successful
      final state = photoUploadCubit.state;
      if (state is AssetAuditPhotoUploadSuccess) {
        final photoId = int.tryParse(state.response.imgId) ?? 0;
        print('AssetAuditPhotoUploadHelper: Photo uploaded successfully, photoId: $photoId');
        return photoId;
      } else if (state is AssetAuditPhotoUploadFailure) {
        print('AssetAuditPhotoUploadHelper: Failed to upload photo: ${state.errorMessage}');
        return null;
      } else {
        print('AssetAuditPhotoUploadHelper: Upload still in progress or unknown state');
        return null;
      }
    } catch (e) {
      print('AssetAuditPhotoUploadHelper: Error uploading photo: $e');
      return null;
    }
  }

  /// Check if photo upload is in progress
  static bool isUploading(BuildContext context) {
    final photoUploadCubit = context.read<AssetAuditPhotoUploadCubit>();
    return photoUploadCubit.state is AssetAuditPhotoUploadLoading;
  }

  /// Get the last error message from photo upload
  static String? getLastErrorMessage(BuildContext context) {
    final photoUploadCubit = context.read<AssetAuditPhotoUploadCubit>();
    final state = photoUploadCubit.state;
    if (state is AssetAuditPhotoUploadFailure) {
      return state.errorMessage;
    }
    return null;
  }

  /// Reset the photo upload cubit state
  static void resetState(BuildContext context) {
    final photoUploadCubit = context.read<AssetAuditPhotoUploadCubit>();
    photoUploadCubit.reset();
  }
}
