import '../services/api_service.dart';

class AssetUploadRepository {
  final ApiService apiService;

  AssetUploadRepository(this.apiService);

  Future<ResponseResult<Map<String, dynamic>?>> assetUpload({
    required int auId,
    required int siteId,
    int? entityId,
    int? makerSelfieImageId,
    bool isActive = true,
    String? remarks,
    required List<AssetUploadItem> assetUploadItems,
  }) async {
    try {
      // Build the request data matching the curl structure
      final finalMakerSelfieImageId = makerSelfieImageId ?? 0;
      
      // Log the makerSelfieImageId value for debugging
      print('🔍 AssetUploadRepository: makerSelfieImageId = $finalMakerSelfieImageId (input: $makerSelfieImageId)');
      
      final requestData = <String, dynamic>{
        'auId': auId,
        'siteId': siteId,
        'entityId': entityId ?? 0,
        'makerSelfieImageId': finalMakerSelfieImageId,
        'isActive': isActive,
        'remarks': remarks ?? '',
        'assetUploadItems': assetUploadItems
            .map((item) => item.toJson())
            .toList(),
      };

      print('🔍 AssetUploadRepository: Request data - makerSelfieImageId: ${requestData['makerSelfieImageId']}');

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
  /// - [auId]: Asset Upload ID to retrieve
  ///
  /// Returns: ResponseResult with asset upload data
  Future<ResponseResult<Map<String, dynamic>?>> getUploadedAssets({
    required int auId,
  }) async {
    try {
      final result = await apiService.get<Map<String, dynamic>>(
        path: 'api/v1/mobile/assetUpload/$auId',
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
    );
  }
}

/// Model for Asset Upload Item Image
class AssetUploadItemImage {
  final int? auiiId;
  final int? photoId;
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
    return {
      'auiiId': auiiId ?? 0,
      'photoId': photoId ?? 0,
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
