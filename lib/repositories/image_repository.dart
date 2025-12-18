import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/api_provider.dart';
import '../utils/connectivity_helper.dart';

class ImageRepository {
  final ApiService _apiService;

  ImageRepository(ApiProvider apiProvider) : _apiService = ApiService(apiProvider);
  Future<Map<int, String>> fetchImagesByIds(List<int> imageIds) async {
    if (imageIds.isEmpty) return {};

    try {
      // Check connectivity before making API call
      final isOnline = await ConnectivityHelper.isConnected();
      if (!isOnline) {
        debugPrint('No internet connection - cannot fetch images');
        return {};
      }

      final imageIdsParam = imageIds.join(',');
      final result = await _apiService.get(
        path: '/api/v1/mobile/allImageList',
        queryParameters: {'imgIds': imageIdsParam},
      );

      if (result.isSuccess && result.data != null) {
        final List<dynamic> images = result.data;
        final Map<int, String> imageMap = {};
        
        for (var image in images) {
          if (image['imageId'] != null && image['imageData'] != null) {
            imageMap[image['imageId']] = image['imageData'];
          }
        }
        
        return imageMap;
      } else {
        debugPrint('Failed to fetch images: ${result.errorMessage}');
        return {};
      }
    } catch (e) {
      debugPrint('Error fetching images: $e');
      return {};
    }
  }

  Future<String?> fetchImageById(int imageId) async {
    final result = await fetchImagesByIds([imageId]);
    return result[imageId];
  }

  Uint8List? base64ToBytes(String base64Data) {
    try {
      final cleanBase64 = base64Data.contains(',') 
          ? base64Data.split(',').last 
          : base64Data;
      
      return base64Decode(cleanBase64);
    } catch (e) {
      debugPrint('Error converting base64 to bytes: $e');
      return null;
    }
  }

  /// Check if the image data is valid base64
  bool isValidBase64Image(String imageData) {
    try {
      if (!imageData.startsWith('data:image/')) return false;
      
      final cleanBase64 = imageData.split(',').last;
      base64Decode(cleanBase64);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get image by imgId using the working allImageList endpoint
  Future<ResponseResult<String?>> getImage({
    required String imgId,
    String? schId, // Keep for compatibility but not used
  }) async {
    try {
      // Check connectivity before making API call
      final isOnline = await ConnectivityHelper.isConnected();
      if (!isOnline) {
        return ResponseResult.error(errorMessage: 'No internet connection - cannot fetch image');
      }
      
      final result = await _apiService.get(
        path: '/api/v1/mobile/allImageList',
        queryParameters: {
          'imgIds': imgId, // Use imgIds parameter like the working endpoint
        },
      );

      if (result.isSuccess && result.data != null) {
        final List<dynamic> images = result.data;
        
        // Find the image with matching imgId and return the image data
        for (var image in images) {
          if (image['imageId']?.toString() == imgId) {
            // Return the actual image data (base64 string)
            final imageData = image['imageData'];
            if (imageData != null) {
              return ResponseResult.success(imageData, result.statusCode);
            }
          }
        }
        
        return ResponseResult.error(errorMessage: 'Image not found');
      } else {
        return ResponseResult.error(errorMessage: result.errorMessage ?? 'Failed to get image');
      }
    } catch (e) {
      return ResponseResult.error(errorMessage: 'Error getting image: $e');
    }
  }
}
