import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'offline_image_helper.dart';
import 'connectivity_helper.dart';
import '../bloc/asset_audit_get_image_cubit.dart';
import '../constants/app_colors.dart';

class ImageDisplayHelper {
  /// Get image widget for display (local or network)
  static Widget getImageWidget({
    required String? photoId,
    required String? imageName,
    required String siteAuditSchId,
    String? category,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (photoId == null || photoId.isEmpty) {
      return _buildPlaceholder(width, height);
    }

    // First try to get local image
    final localPath = OfflineImageHelper.getLocalImagePath(siteAuditSchId, photoId);
    if (localPath != null) {
      return _buildLocalImage(localPath, width, height, fit);
    }

    // If no local image, check connectivity and decide
    return _buildConnectivityAwareImage(photoId, siteAuditSchId, width, height, fit);
  }

  /// Build connectivity-aware image widget
  static Widget _buildConnectivityAwareImage(String photoId, String siteAuditSchId, double? width, double? height, BoxFit fit) {
    return FutureBuilder<bool>(
      future: ConnectivityHelper.isConnected(),
      builder: (context, connectivitySnapshot) {
        if (connectivitySnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingPlaceholder(width, height);
        }

        final isOnline = connectivitySnapshot.data ?? false;
        
        if (!isOnline) {
          // Offline - show placeholder since no local image found
          return _buildPlaceholder(width, height);
        }

        // Online - use BlocBuilder for API call
        return BlocBuilder<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          builder: (context, state) {
            if (state is AssetAuditGetImageLoading) {
              return _buildLoadingPlaceholder(width, height);
            } else if (state is AssetAuditGetImageSuccess) {
              if (state.imageData.isNotEmpty) {
                // Save to local storage after successful download
                OfflineImageHelper.saveImageLocally(
                  photoId: photoId,
                  imageData: state.imageData,
                  siteAuditSchId: siteAuditSchId,
                  category: 'unknown',
                );
                return _buildNetworkImageFromData(state.imageData, width, height, fit);
              }
            } else if (state is AssetAuditGetImageFailure) {
              return _buildPlaceholder(width, height);
            }

            // If image not loaded yet, trigger load
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<AssetAuditGetImageCubit>().getImage(imgId: photoId);
            });

            return _buildLoadingPlaceholder(width, height);
          },
        );
      },
    );
  }

  /// Build local image widget
  static Widget _buildLocalImage(String localPath, double? width, double? height, BoxFit fit) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(
          image: FileImage(File(localPath)),
          fit: fit,
        ),
      ),
    );
  }

  /// Build network image from data
  static Widget _buildNetworkImageFromData(String imageData, double? width, double? height, BoxFit fit) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageData.startsWith('data:image/')
            ? Image.memory(
                base64Decode(imageData.split(',').last),
                fit: fit,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder(width, height);
                },
              )
            : Image.memory(
                base64Decode(imageData),
                fit: fit,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder(width, height);
                },
              ),
      ),
    );
  }

  /// Build loading placeholder widget
  static Widget _buildLoadingPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: AppColors.greyColor,
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }

  /// Build placeholder widget
  static Widget _buildPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[300],
      ),
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[600],
        size: (width != null && height != null) ? 
          (width < height ? width * 0.5 : height * 0.5) : 24,
      ),
    );
  }

  /// Check if image exists locally
  static bool hasLocalImage(String siteAuditSchId, String photoId) {
    return OfflineImageHelper.getLocalImagePath(siteAuditSchId, photoId) != null;
  }

  /// Get all local images for a site
  static List<Map<String, dynamic>> getLocalImages(String siteAuditSchId) {
    return OfflineImageHelper.getSavedImages(siteAuditSchId);
  }
}
