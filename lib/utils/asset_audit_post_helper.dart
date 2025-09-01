import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/asset_audit_post_model.dart';
import '../models/asset_audit_model.dart';
import '../bloc/selfie_upload_cubit.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:flutter/material.dart';

class AssetAuditPostHelper {
  /// Convert saved items from a screen to AssetAuditPostRequest format
  /// This is called when navigating to the next screen to save the current screen's data
  static Future<List<AssetAuditPostRequest>> convertSavedItemsToPostRequest({
    required List<Map<String, dynamic>> savedItems,
    required AssetAuditModel assetAuditData,
    required String itemType,
    required int itemTypeId,
    required String screenName,
    required BuildContext context,
    String? auditSchId,
  }) async {
    final List<AssetAuditPostRequest> requests = [];
    final now = DateTime.now();
    final timestamp = _formatDateTime(now);
    
    // Get current location
    final location = await getCurrentLocation();
    
    // Get site info from assetAuditData
    final siteInfo = assetAuditData.pageHeader.isNotEmpty 
        ? assetAuditData.pageHeader.first 
        : null;
    
    if (siteInfo == null) {
      print('AssetAuditPostHelper: No site info available');
      return [];
    }

    for (int i = 0; i < savedItems.length; i++) {
      final item = savedItems[i];
      
      try {
        // Handle QR code fields properly
        final bool isQRScanned = item['isQRCodeScanned'] ?? false;
        final String? qrCodeScannedTs = isQRScanned ? timestamp : null;
        

        
        final request = AssetAuditPostRequest(
          assetAuditSiteRespId: item['assetAuditSiteRespId'], // Use ID from GET API response if available
          auditSchId: auditSchId != null ? int.parse(auditSchId) : 0,
          siteAuditSchId: siteInfo.siteAuditSchId,
          siteId: siteInfo.siteId,
          itemInstanceId: 0, // Will be assigned by backend
          nexgenSerialNo: item['serialNumber'] ?? '',
          itemTypeId: itemTypeId,
          qrCodeScanned: isQRScanned,
          qrCodeScannedTs: qrCodeScannedTs, // null for manual entry, timestamp for QR scan
          photoId: _getPhotoIdForRequest(item), // Handle photoId properly for different record types
          photoTakenTs: item['photoTakenTs'] ?? timestamp,
          assetStatus: item['status'] ?? 'OK',
          longitude: location['longitude'] ?? item['longitude'], // Use current location if available
          latitude: location['latitude'] ?? item['latitude'], // Use current location if available
          itemTypeRemark: item['remarks'],
          localAuditLogId: 0,
          localQrCodeScannedTs: timestamp,
          localCreatedDt: timestamp,
          localModifiedDt: timestamp,
          syncProcessId: 0,
          isActive: true,
          remarks: item['remarks'],
        );
        
        requests.add(request);
        print('AssetAuditPostHelper: Created request for $screenName item ${i + 1}');
        print('AssetAuditPostHelper: Item ${i + 1} assetAuditSiteRespId: ${item['assetAuditSiteRespId']}');
        
      } catch (e) {
        print('AssetAuditPostHelper: Error creating request for item ${i + 1}: $e');
        print('Item data: $item');
      }
    }
    
    print('AssetAuditPostHelper: Created ${requests.length} requests for $screenName');
    return requests;
  }

  /// Convert a single saved item to AssetAuditPostRequest format
  static Future<AssetAuditPostRequest> convertSingleItemToPostRequest({
    required Map<String, dynamic> savedItem,
    required AssetAuditModel assetAuditData,
    required int itemTypeId,
    required String screenName,
    required BuildContext context,
    String? auditSchId,
  }) async {
    // Debug logging for remarks processing
    final recordType = savedItem['recordType']?.toString().toLowerCase();
    if (recordType == 'remarks') {
      print('=== ASSET AUDIT POST HELPER: PROCESSING REMARKS ===');
      print('Original savedItem: $savedItem');
      print('Remarks text: "${savedItem['remarks']}"');
      print('ItemType: ${savedItem['itemType']}');
      print('AssetAuditSiteRespId: ${savedItem['assetAuditSiteRespId']}');
    }
    
    final now = DateTime.now();
    final timestamp = _formatDateTime(now);
    
    // Get current location
    final location = await getCurrentLocation();
    
    // Get site info from assetAuditData
    final siteInfo = assetAuditData.pageHeader.isNotEmpty 
        ? assetAuditData.pageHeader.first 
        : null;
    
    if (siteInfo == null) {
      throw Exception('No site info available');
    }

    // Handle QR code fields properly
    final bool isQRScanned = savedItem['isQRCodeScanned'] ?? false;
    final String? qrCodeScannedTs = isQRScanned ? timestamp : null;



    final request = AssetAuditPostRequest(
      assetAuditSiteRespId: savedItem['assetAuditSiteRespId'], // Use ID from GET API response if available
      auditSchId: auditSchId != null ? int.parse(auditSchId) : 0,
      siteAuditSchId: siteInfo.siteAuditSchId,
      siteId: siteInfo.siteId,
      itemInstanceId: 0, // Will be assigned by backend
      nexgenSerialNo: savedItem['serialNumber'] ?? '',
      itemTypeId: itemTypeId,
      qrCodeScanned: isQRScanned,
      qrCodeScannedTs: qrCodeScannedTs, // null for manual entry, timestamp for QR scan
      photoId: _getPhotoIdForRequest(savedItem), // Handle photoId properly for different record types
      photoTakenTs: savedItem['photoTakenTs'] ?? timestamp,
      assetStatus: savedItem['status'] ?? 'OK',
      longitude: location['longitude'] ?? savedItem['longitude'], // Use current location if available
      latitude: location['latitude'] ?? savedItem['latitude'], // Use current location if available
      itemTypeRemark: savedItem['remarks'],
      localAuditLogId: 0,
      localQrCodeScannedTs: timestamp,
      localCreatedDt: timestamp,
      localModifiedDt: timestamp,
      syncProcessId: 0,
      isActive: true,
      remarks: savedItem['remarks'],
    );
    
    // Debug logging for remarks final request
    if (recordType == 'remarks') {
      print('=== FINAL ASSET AUDIT POST REQUEST FOR REMARKS ===');
      print('itemTypeRemark: "${request.itemTypeRemark}"');
      print('remarks: "${request.remarks}"');
      print('nexgenSerialNo: "${request.nexgenSerialNo}"');
      print('itemTypeId: ${request.itemTypeId}');
      print('assetAuditSiteRespId: ${request.assetAuditSiteRespId}');
      print('photoId: ${request.photoId}');
      print('assetStatus: ${request.assetStatus}');
      print('=== END FINAL REQUEST DEBUG ===');
    }
    
    return request;
  }

  /// Get photoId for request, handling remarks vs assets differently
  static int _getPhotoIdForRequest(Map<String, dynamic> item) {
    // For remarks entries, photoId is not required so return 0 (will be filtered out in toJson)
    final recordType = item['recordType']?.toString().toLowerCase();
    final itemType = item['itemType']?.toString().toLowerCase();
    
    if (recordType == 'remarks' || itemType?.contains('remarks') == true) {
      print('AssetAuditPostHelper: Using photoId 0 for remarks entry (not required, will be filtered out)');
      return 0; // PhotoId is not required for remarks, will be filtered out in toJson
    }
    
    // For asset entries, use the photoId if available, otherwise use 0 (backend will handle)
    final photoId = item['photoId'];
    if (photoId == null || photoId == 0) {
      print('AssetAuditPostHelper: PhotoId is null/0, using 0 for asset entry');
      return 0;
    }
    
    return photoId is int ? photoId : int.tryParse(photoId.toString()) ?? 0;
  }

  /// Get item type ID based on screen name
  static int getItemTypeId(String screenName) {
    switch (screenName.toLowerCase()) {
      case 'ccu':
        return 1;
      case 'battery':
        return 2;
      case 'extinguisher':
        return 3;
      case 'solar plates':
        return 4;
      case 'cctv':
      case 'surveillance':
        return 5;
      case 'fencing':
        return 6;
      case 'dg':
        return 7;
      case 'smps':
        return 8;
      default:
        return 0;
    }
  }

  /// Format DateTime to the required format "dd-MM-yyyy HH:mm"
  static String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$day-$month-$year $hour:$minute';
  }

  /// Add additional data to saved items before posting
  static List<Map<String, dynamic>> enhanceSavedItems({
    required List<Map<String, dynamic>> savedItems,
    required String screenName,
  }) {
    final now = DateTime.now();
    final timestamp = _formatDateTime(now);
    
    return savedItems.map((item) {
      final enhancedItem = Map<String, dynamic>.from(item);
      
      // Add timestamp if not present
      if (!enhancedItem.containsKey('timestamp')) {
        enhancedItem['timestamp'] = timestamp;
      }
      
      // Add photo taken timestamp if not present
      if (!enhancedItem.containsKey('photoTakenTs')) {
        enhancedItem['photoTakenTs'] = timestamp;
      }
      
      // Add QR code scanned timestamp if not present
      if (!enhancedItem.containsKey('qrCodeScannedTs')) {
        enhancedItem['qrCodeScannedTs'] = timestamp;
      }
      
      // Add screen name for tracking
      enhancedItem['screenName'] = screenName;
      
      return enhancedItem;
    }).toList();
  }

  /// Get current user location
  static Future<Map<String, String?>> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('AssetAuditPostHelper: Location services are disabled');
        return {'latitude': null, 'longitude': null};
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('AssetAuditPostHelper: Location permissions are denied');
          return {'latitude': null, 'longitude': null};
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('AssetAuditPostHelper: Location permissions are permanently denied');
        return {'latitude': null, 'longitude': null};
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return {
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
      };
    } catch (e) {
      print('AssetAuditPostHelper: Error getting location: $e');
      return {'latitude': null, 'longitude': null};
    }
  }

  /// Upload photo and get photoId using existing selfie upload API
  /// Note: This method requires a BuildContext to access the SelfieUploadCubit
  static Future<int?> uploadPhotoAndGetId({
    required File photoFile,
    required String schId,
    String? imgId,
    required BuildContext context,
  }) async {
    try {
      // Get the existing SelfieUploadCubit from the context
      final selfieUploadCubit = context.read<SelfieUploadCubit>();
      
      // Upload photo using existing selfie upload API
      await selfieUploadCubit.uploadSelfie(
        file: photoFile,
        imgId: imgId ?? "0",
        schId: schId,
      );

      // Wait a bit for the state to update
      await Future.delayed(const Duration(milliseconds: 500));

      // Get the current state to check if upload was successful
      final state = selfieUploadCubit.state;
      if (state is SelfieUploadSuccess) {
        final photoId = int.tryParse(state.response.imgId) ?? 0;
        print('AssetAuditPostHelper: Photo uploaded successfully, photoId: $photoId');
        return photoId;
      } else if (state is SelfieUploadFailure) {
        print('AssetAuditPostHelper: Failed to upload photo: ${state.errorMessage}');
        return null;
      } else {
        print('AssetAuditPostHelper: Upload still in progress or unknown state');
        return null;
      }
    } catch (e) {
      print('AssetAuditPostHelper: Error uploading photo: $e');
      return null;
    }
  }
}
