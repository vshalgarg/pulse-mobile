import '../services/api_service.dart';

class AssetUploadRepository {
  final ApiService apiService;

  AssetUploadRepository(this.apiService);

  Future<ResponseResult<Map<String, dynamic>?>> assetUpload({
    required int auId,
    required int siteId,
    int? entityId,
    dynamic makerSelfieImageId, // Must be valid server ID (int > 0) when used for online POST
    bool isActive = true,
    String? remarks,
    required List<AssetUploadItem> assetUploadItems,
  }) async {
    try {
      // API requires valid server IDs only. Refuse to send if any value is null or LOCAL_IMAGE_ID.
      final selfieStr = makerSelfieImageId?.toString() ?? '';
      if (selfieStr.isEmpty ||
          selfieStr == '0' ||
          selfieStr.contains('LOCAL_IMAGE_ID')) {
        return ResponseResult.error(
          errorMessage:
              'Selfie is required (valid server ID). Cannot send null or LOCAL_IMAGE_ID.',
        );
      }
      final selfieInt = makerSelfieImageId is int
          ? makerSelfieImageId
          : int.tryParse(selfieStr);
      if (selfieInt == null || selfieInt <= 0) {
        return ResponseResult.error(
          errorMessage:
              'makerSelfieImageId must be a valid server ID (int > 0).',
        );
      }

      for (final item in assetUploadItems) {
        for (final img in item.assetUploadItemImages) {
          final pid = img.photoId;
          if (pid == null) {
            return ResponseResult.error(
              errorMessage:
                  'Each asset must have a valid photoId (cannot be null).',
            );
          }
          final pidStr = pid.toString();
          if (pidStr.contains('LOCAL_IMAGE_ID')) {
            return ResponseResult.error(
              errorMessage:
                  'Asset photoId cannot be LOCAL_IMAGE_ID. Replace with server ID before calling.',
            );
          }
          final pidInt = pid is int ? pid : int.tryParse(pidStr);
          if (pidInt == null || pidInt <= 0) {
            return ResponseResult.error(
              errorMessage:
                  'Each asset photoId must be a valid server ID (int > 0).',
            );
          }
        }
      }

      // Build the request data with validated values only
      final requestData = <String, dynamic>{
        'auId': auId,
        'siteId': siteId,
        'entityId': entityId ?? 0,
        'makerSelfieImageId': selfieInt,
        'isActive': isActive,
        'remarks': remarks ?? '',
        'assetUploadItems': assetUploadItems
            .map((item) => item.toJson())
            .toList(),
      };

      // Final safety: ensure no LOCAL_IMAGE_ID in item images (should already be validated above)
      final items = requestData['assetUploadItems'] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final images = item['assetUploadItemImages'] as List<dynamic>?;
            if (images != null) {
              for (final img in images) {
                if (img is Map<String, dynamic>) {
                  final pid = img['photoId'];
                  if (pid == null ||
                      pid.toString().contains('LOCAL_IMAGE_ID') ||
                      (pid is int ? pid <= 0 : (int.tryParse(pid.toString()) ?? 0) <= 0)) {
                    return ResponseResult.error(
                      errorMessage:
                          'Invalid asset photoId in request. Cannot send to API.',
                    );
                  }
                }
              }
            }
          }
        }
      }

      final result = await apiService.post<Map<String, dynamic>>(
        path: 'api/v1/mobile/assetUpload',
        data: requestData,
        useFormDataFormat: false, // Send as JSON
      );

      // Check if request was successful (status code 200-299)
      if (result.statusCode != null &&
          result.statusCode! >= 200 &&
          result.statusCode! < 300) {
        return ResponseResult.success(result.data, result.statusCode);
      } else {
        return ResponseResult.error(
          errorMessage: result.errorMessage ?? 'Failed to upload asset data',
          statusCode: result.statusCode,
        );
      }
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Error uploading asset data: ${e.toString()}',
      );
    }
  }

  /// Get uploaded asset data from the server
  ///
  /// Parameters:
  /// - [siteId]: Site ID to retrieve asset upload data for
  ///
  /// Returns: ResponseResult with asset upload data
  Future<ResponseResult<Map<String, dynamic>?>> getUploadedAssets({
    required int siteId,
  }) async {
    try {
      final result = await apiService.get<Map<String, dynamic>>(
        path: 'api/v1/mobile/assetUpload/$siteId',
      );

      // Check if request was successful (status code 200-299)
      if (result.statusCode != null && 
          result.statusCode! >= 200 && 
          result.statusCode! < 300) {
        return ResponseResult.success(result.data, result.statusCode);
      } else {
        return ResponseResult.error(
          errorMessage:
              result.errorMessage ?? 'Failed to get uploaded asset data',
          statusCode: result.statusCode,
        );
      }
    } catch (e) {
      return ResponseResult.error(
        errorMessage: 'Error getting uploaded asset data: ${e.toString()}',
      );
    }
  }
}

/// Model for Asset Upload Item
class AssetUploadItem {
  final int? auiId;
  final int? auId;
  final String nexgenSerialNo;
  final int? itemId;
  final String? longitude;
  final String? latitude;
  final bool isActive;
  final String? remarks;
  final List<AssetUploadItemImage> assetUploadItemImages;
  final bool? isModified;

  AssetUploadItem({
    this.auiId,
    this.auId,
    required this.nexgenSerialNo,
    this.itemId,
    this.longitude,
    this.latitude,
    this.isActive = true,
    this.remarks,
    required this.assetUploadItemImages,
    this.isModified,
  });

  Map<String, dynamic> toJson() {
    return {
      'auiId': auiId ?? 0,
      'auId': auId ?? 0,
      'nexgenSerialNo': nexgenSerialNo,
      'itemId': itemId ?? 0,
      'longitude': longitude ?? '',
      'latitude': latitude ?? '',
      'isActive': isActive,
      'remarks': remarks ?? '',
      'isModified': isModified ?? false, // Default to false if null
      'assetUploadItemImages': assetUploadItemImages
          .map((img) => img.toJson())
          .toList(),
    };
  }

  factory AssetUploadItem.fromJson(Map<String, dynamic> json) {
    return AssetUploadItem(
      auiId: json['auiId'] as int?,
      auId: json['auId'] as int?,
      nexgenSerialNo: json['nexgenSerialNo'] as String,
      itemId: json['itemId'] as int?,
      longitude: json['longitude'] as String?,
      latitude: json['latitude'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      remarks: json['remarks'] as String?,
      assetUploadItemImages:
          (json['assetUploadItemImages'] as List<dynamic>?)
              ?.map(
                (img) =>
                    AssetUploadItemImage.fromJson(img as Map<String, dynamic>),
              )
              .toList() ??
          [],
      isModified: json['isModified'] as bool? ?? false,
    );
  }
}

/// Model for Asset Upload Item Image
class AssetUploadItemImage {
  final int? auiiId;
  final dynamic photoId; // Can be int (server ID) or String (LOCAL_IMAGE_ID)
  final String? photoTakenTs;
  final String? longitude;
  final String? latitude;
  final bool isActive;
  final String? remarks;

  AssetUploadItemImage({
    this.auiiId,
    this.photoId,
    this.photoTakenTs,
    this.longitude,
    this.latitude,
    this.isActive = true,
    this.remarks,
  });

  Map<String, dynamic> toJson() {
    // Handle photoId - keep as string if LOCAL_IMAGE_ID (for offline payload), null if upload failed, otherwise int
    dynamic finalPhotoId;
    if (photoId == null) {
      finalPhotoId = null; // Send null when missing or when upload failed
    } else if (photoId is String && photoId.contains("LOCAL_IMAGE_ID")) {
      // Keep LOCAL_IMAGE_ID as string for offline mode
      finalPhotoId = photoId;
    } else {
      // Convert to int for server IDs
      finalPhotoId = photoId is int ? photoId : (int.tryParse(photoId.toString()) ?? 0);
    }

    return {
      'auiiId': auiiId ?? 0,
      'photoId': finalPhotoId,
      'photoTakenTs': photoTakenTs,
      'longitude': longitude ?? '',
      'latitude': latitude ?? '',
      'isActive': isActive,
      'remarks': remarks ?? '',
    };
  }

  factory AssetUploadItemImage.fromJson(Map<String, dynamic> json) {
    return AssetUploadItemImage(
      auiiId: json['auiiId'] as int?,
      photoId: json['photoId'] as int?,
      photoTakenTs: json['photoTakenTs'] as String?,
      longitude: json['longitude'] as String?,
      latitude: json['latitude'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      remarks: json['remarks'] as String?,
    );
  }
}
