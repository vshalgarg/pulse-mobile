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
      return [];
    }
    
    // Get the category data for this item type to find matching assetAuditSiteRespId
    dynamic categoryData = assetAuditData.responseData.categories[itemType];
    

    // Special handling for ACDB - it's nested under SMPS subcategories
    if (itemType == 'ACDB') {
      final smpsData = assetAuditData.responseData.categories['SMPS'];
      if (smpsData != null && smpsData.subCategories != null && smpsData.subCategories!['ACDB'] != null) {
        // Create a temporary CategoryData object with ACDB assets from SMPS subcategories
        final acdbAssets = smpsData.subCategories!['ACDB']!;
        final acdbRemarks = smpsData.remarks.where((remark) => remark.itemType == 'ACDB').toList();
        categoryData = CategoryData(
          assets: acdbAssets,
          remarks: acdbRemarks,
        );
      } else {
        categoryData = null;
      }
    }
    
      // Check if there are any other properties in the category
      try {
        if (categoryData.remarks != null && categoryData.remarks!.isNotEmpty) {
          for (int i = 0; i < categoryData.remarks!.length; i++) {
            final remark = categoryData.remarks![i];
          }
        }
      } catch (e) {
  }

    for (int i = 0; i < savedItems.length; i++) {
      final item = savedItems[i];
      
      try {
        // Find matching asset from API response to get assetAuditSiteRespId
        int? assetAuditSiteRespId = _findMatchingAssetId(
          savedItem: item,
          categoryData: categoryData,
          itemType: itemType,
          assetAuditData: assetAuditData,
        );
        
        // Handle QR code fields properly
        final bool isQRScanned = item['isQRCodeScanned'] ?? false;
        final String? qrCodeScannedTs = isQRScanned ? timestamp : null;
        
        // Get photo ID from the uploaded photo
        final int? photoId = _getPhotoIdForRequest(item);
        
        final request = AssetAuditPostRequest(
          assetAuditSiteRespId: assetAuditSiteRespId, // Use ID from GET API response
          auditSchId: auditSchId != null ? int.parse(auditSchId) : 0,
          siteAuditSchId: siteInfo.siteAuditSchId,
          siteId: siteInfo.siteId ?? 0,
          itemInstanceId: 0, // Will be assigned by backend
          nexgenSerialNo: item['serialNumber'] ?? item['nexgenSerialNo'] ?? '',
          itemTypeId: itemTypeId,
          qrCodeScanned: isQRScanned,
          qrCodeScannedTs: qrCodeScannedTs, // null for manual entry, timestamp for QR scan
          photoId: photoId, // Use uploaded photo ID
          photoTakenTs: item['photoTakenTs'] ?? timestamp,
          assetStatus: item['status'] ?? 'OK',
          longitude: location['longitude'] ?? item['longitude'], // Use current location if available
          latitude: location['latitude'] ?? item['latitude'], // Use current location if available
          itemTypeRemark: item['itemTypeRemark'] ?? item['remarks'],
          localAuditLogId: 0,
          localQrCodeScannedTs: timestamp,
          localCreatedDt: timestamp,
          localModifiedDt: timestamp,
          syncProcessId: 0,
          isActive: true,
          remarks: item['itemTypeRemark'] ?? item['remarks'],
        );
        
        requests.add(request);

        
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
    print('AssetAuditPostHelper: Current location for single item - Lat: ${location['latitude']}, Lng: ${location['longitude']}');
    
    // Get site info from assetAuditData
    final siteInfo = assetAuditData.pageHeader.isNotEmpty 
        ? assetAuditData.pageHeader.first 
        : null;
    
    if (siteInfo == null) {
      throw Exception('No site info available');
    }

    // Find matching asset ID from API response
    final itemType = _getItemTypeFromScreenName(screenName);
    final categoryData = assetAuditData.responseData.categories[itemType];
    final assetAuditSiteRespId = _findMatchingAssetId(
      savedItem: savedItem,
      categoryData: categoryData,
      itemType: itemType,
      assetAuditData: assetAuditData,
    );

    // Handle QR code fields properly
    final bool isQRScanned = savedItem['isQRCodeScanned'] ?? false;
    final String? qrCodeScannedTs = isQRScanned ? timestamp : null;

    final request = AssetAuditPostRequest(
      assetAuditSiteRespId: assetAuditSiteRespId, // Use ID from GET API response
      auditSchId: auditSchId != null ? int.parse(auditSchId) : 0,
      siteAuditSchId: siteInfo.siteAuditSchId,
      siteId: siteInfo.siteId ?? 0,
      itemInstanceId: 0, // Will be assigned by backend
      nexgenSerialNo: savedItem['serialNumber'] ?? savedItem['nexgenSerialNo'] ?? '',
      itemTypeId: itemTypeId,
      qrCodeScanned: isQRScanned,
      qrCodeScannedTs: qrCodeScannedTs,
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

  /// Find matching asset ID from API response based on serial number
  static int? _findMatchingAssetId({
    required Map<String, dynamic> savedItem,
    required dynamic categoryData,
    required String itemType,
    required AssetAuditModel assetAuditData,
  }) {
    // Check if this is a remarks entry
    final recordType = savedItem['recordType']?.toString().toLowerCase();
    if (recordType == 'remarks') {
      print('AssetAuditPostHelper: This is a remarks entry, getting remarks ID');
      return _getRemarksAssetAuditSiteRespId(
        assetAuditData: assetAuditData,
        itemType: itemType,
      );
    }

    // If the item already has an assetAuditSiteRespId, use it
    if (savedItem['assetAuditSiteRespId'] != null && savedItem['assetAuditSiteRespId'] > 0) {
      print('AssetAuditPostHelper: Using existing assetAuditSiteRespId from saved item: ${savedItem['assetAuditSiteRespId']}');
      return savedItem['assetAuditSiteRespId'];
    }

    // Check for serial number in multiple possible field names
    final savedSerialNumber = (savedItem['serialNumber'] ?? savedItem['nexgenSerialNo'] ?? '').toString().toLowerCase();
    
    // For Boundary items, serial number is optional and doesn't need to match existing data
    if (itemType == 'Boundary') {
      print('AssetAuditPostHelper: Boundary item - serial number validation skipped');
      print('AssetAuditPostHelper: categoryData is null: ${categoryData == null}');
      if (categoryData != null) {
        print('AssetAuditPostHelper: categoryData.assets is null: ${categoryData.assets == null}');
        print('AssetAuditPostHelper: categoryData.assets.length: ${categoryData.assets?.length ?? 0}');
      }
      
      // For Boundary, if there's an existing asset, use its ID regardless of serial number
      if (categoryData != null && categoryData.assets != null && categoryData.assets.isNotEmpty) {
        final asset = categoryData.assets.first;
        print('AssetAuditPostHelper: Using existing Boundary asset ID: ${asset.assetAuditSiteRespId}');
        return asset.assetAuditSiteRespId;
      }
      
      // Fallback: Try to find Boundary assets in any category
      print('AssetAuditPostHelper: No Boundary category found, searching all categories...');
      for (String categoryName in assetAuditData.responseData.categories.keys) {
        final category = assetAuditData.responseData.categories[categoryName];
        if (category != null && category.assets.isNotEmpty) {
          for (var asset in category.assets) {
            if (asset.itemType == 'Boundary' || asset.itemTypeGroup == 'Boundary') {
              print('AssetAuditPostHelper: Found Boundary asset in $categoryName category with ID: ${asset.assetAuditSiteRespId}');
              return asset.assetAuditSiteRespId;
            }
          }
        }
      }
      
      print('AssetAuditPostHelper: No existing Boundary asset found anywhere, will create new one');
      return null; // Let the backend assign a new ID
    }
    
    if (savedSerialNumber.isEmpty) {
      print('AssetAuditPostHelper: No serial number in saved item');
      print('AssetAuditPostHelper: Available fields: ${savedItem.keys.toList()}');
      return null;
    }

    // First, try to find in main category assets
    if (categoryData != null && categoryData.assets != null) {
      // Try to match by nexgen_serial_no first (for QR scanned items)
      if (savedItem['isQRCodeScanned'] == true) {
        for (var asset in categoryData.assets) {
          final apiNexgenSerial = asset.nexgenSerialNo?.toString().toLowerCase();
          if (apiNexgenSerial == savedSerialNumber) {
            print('AssetAuditPostHelper: Found matching asset by nexgen_serial_no: ${asset.assetAuditSiteRespId}');
            return asset.assetAuditSiteRespId;
          }
        }
      }

      // Try to match by mfg_serial_no (for manual entry items)
      for (var asset in categoryData.assets) {
        final apiMfgSerial = asset.mfgSerialNo?.toString().toLowerCase();
        if (apiMfgSerial == savedSerialNumber) {
          print('AssetAuditPostHelper: Found matching asset by mfg_serial_no: ${asset.assetAuditSiteRespId}');
          return asset.assetAuditSiteRespId;
        }
      }
      
      // Special case for Boundary: If there's only one asset and it has null serial numbers,
      // use that asset's ID (this means we're updating the existing empty Boundary item)
      if (itemType == 'Boundary' && categoryData.assets.length == 1) {
        final asset = categoryData.assets.first;
        print('AssetAuditPostHelper: Checking Boundary asset - nexgen: ${asset.nexgenSerialNo}, mfg: ${asset.mfgSerialNo}');
        if ((asset.nexgenSerialNo == null || asset.nexgenSerialNo!.isEmpty) && 
            (asset.mfgSerialNo == null || asset.mfgSerialNo!.isEmpty)) {
          print('AssetAuditPostHelper: Using existing Boundary asset ID for update: ${asset.assetAuditSiteRespId}');
          return asset.assetAuditSiteRespId;
        } else {
          print('AssetAuditPostHelper: Boundary asset has serial numbers, not using for update');
        }
      }
    }

    // If not found in main category, try to find in subcategories
    // For Fire Extinguisher screen, Flood Light and Sand Bucket are subcategories
    if (itemType == 'Flood Light' || itemType == 'Sand Bucket') {
      print('AssetAuditPostHelper: Looking for $itemType in subcategories');
      
      // Get the Fire Extinguisher category data
      final fireExtinguisherCategory = assetAuditData.responseData.categories['Fire Extinguisher'];
      if (fireExtinguisherCategory != null && fireExtinguisherCategory.subCategories != null) {
        final subCategoryData = fireExtinguisherCategory.subCategories![itemType];
        if (subCategoryData != null) {
          print('AssetAuditPostHelper: Found subcategory data for $itemType with ${subCategoryData.length} items');
          
          // Try to match by nexgen_serial_no first (for QR scanned items)
          if (savedItem['isQRCodeScanned'] == true) {
            for (var asset in subCategoryData) {
              final apiNexgenSerial = asset.nexgenSerialNo?.toString().toLowerCase();
              if (apiNexgenSerial == savedSerialNumber) {
                print('AssetAuditPostHelper: Found matching subcategory asset by nexgen_serial_no: ${asset.assetAuditSiteRespId}');
                return asset.assetAuditSiteRespId;
              }
            }
          }

          // Try to match by mfg_serial_no (for manual entry items)
          for (var asset in subCategoryData) {
            final apiMfgSerial = asset.mfgSerialNo?.toString().toLowerCase();
            if (apiMfgSerial == savedSerialNumber) {
              print('AssetAuditPostHelper: Found matching subcategory asset by mfg_serial_no: ${asset.assetAuditSiteRespId}');
              return asset.assetAuditSiteRespId;
            }
          }
        } else {
          print('AssetAuditPostHelper: No subcategory data found for $itemType');
        }
      } else {
        print('AssetAuditPostHelper: No subcategories found in Fire Extinguisher category');
      }
    }

    // If no exact match found, try to match by nexgen_serial_no as fallback (only if categoryData exists)
    if (categoryData != null && categoryData.assets != null) {
      for (var asset in categoryData.assets) {
        final apiNexgenSerial = asset.nexgenSerialNo?.toString().toLowerCase();
        if (apiNexgenSerial == savedSerialNumber) {
          print('AssetAuditPostHelper: Found matching asset by nexgen_serial_no (fallback): ${asset.assetAuditSiteRespId}');
          return asset.assetAuditSiteRespId;
        }
      }
    }

    print('AssetAuditPostHelper: No matching asset found for serial number: $savedSerialNumber');
    if (categoryData != null && categoryData.assets != null) {
      print('Available assets in API response:');
      for (var asset in categoryData.assets) {
        print('  - nexgen_serial_no: ${asset.nexgenSerialNo}, mfg_serial_no: ${asset.mfgSerialNo}, id: ${asset.assetAuditSiteRespId}');
      }
    }
    
    // For new items, return a temporary negative ID that backend will replace
    print('AssetAuditPostHelper: No matching asset found, using temporary ID for new item');
    print('AssetAuditPostHelper: itemType: $itemType, categoryData exists: ${categoryData != null}');
    return -1; // Temporary ID for new items
  }

  /// Get photoId for request, handling remarks vs assets differently
  static int? _getPhotoIdForRequest(Map<String, dynamic> item) {
    // For remarks entries, photoId is not required so return 0 (will be filtered out in toJson)
    final recordType = item['recordType']?.toString().toLowerCase();
    final itemType = item['itemType']?.toString().toLowerCase();
    
    if (recordType == 'remarks' || itemType?.contains('remarks') == true) {
      print('AssetAuditPostHelper: Using photoId null for remarks entry (not required)');
      return null; // PhotoId is not required for remarks
    }
    
    // For asset entries, use the photoId if available, otherwise return null
    // Check for photo ID in multiple possible field names
    final photoId = item['photoId'] ?? item['photo'];
    if (photoId == null || photoId == 0) {
      print('AssetAuditPostHelper: PhotoId is null/0, returning null for asset entry');
      print('AssetAuditPostHelper: Available fields: ${item.keys.toList()}');
      print('AssetAuditPostHelper: photoId field value: ${item['photoId']}');
      print('AssetAuditPostHelper: photo field value: ${item['photo']}');
      return null;
    }
    
    // Convert photoId to int (it might be a string from the upload response)
    print('AssetAuditPostHelper: Raw photoId value: $photoId (type: ${photoId.runtimeType})');
    final intPhotoId = photoId is int ? photoId : int.tryParse(photoId.toString()) ?? 0;
    print('AssetAuditPostHelper: Converted photoId: $intPhotoId for asset entry');
    return intPhotoId;
  }

  /// Get item type string from screen name
  static String _getItemTypeFromScreenName(String screenName) {
    switch (screenName.toLowerCase()) {
      case 'solar_spv':
        return 'SPV';
      case 'solar_mms':
        return 'MMS';
      case 'solar_dcba':
        return 'DCBA';
      case 'solar_pcu':
        return 'PCU';
      case 'solar_invertor':
        return 'Invertor';
      case 'solar_acdb':
        return 'ACDB';
      case 'solar_vcb':
        return 'VCB';
      case 'solar_wms':
        return 'WMS';
      case 'solar_scada':
        return 'SCADA';
      case 'solar_fire_extinguisher':
        return 'Fire Extinguisher';
      case 'cctv':
        return 'CCTV';
      case 'solar_boundary':
        return 'Boundary';
      case 'solar_ltdb':
        return 'LTDB';
      case 'solar_transformer':
        return 'Transformer';
      default:
        return screenName.toUpperCase();
    }
  }

  /// Get remarks assetAuditSiteRespId from existing backend data
  static int? _getRemarksAssetAuditSiteRespId({
    required AssetAuditModel assetAuditData,
    required String itemType,
  }) {
    print('=== AssetAuditPostHelper: Getting Remarks AssetAuditSiteRespId for $itemType ===');

    // Get the category data for this item type
    dynamic categoryData = assetAuditData.responseData.categories[itemType];
    
    // Special handling for ACDB - it's nested under SMPS subcategories
    if (itemType == 'ACDB') {
      final smpsData = assetAuditData.responseData.categories['SMPS'];
      if (smpsData != null) {
        // Get ACDB remarks from SMPS category
        final acdbRemarks = smpsData.remarks.where((remark) => remark.itemType == 'ACDB').toList();
        categoryData = CategoryData(
          assets: [],
          remarks: acdbRemarks,
        );
        print('AssetAuditPostHelper: Found ${acdbRemarks.length} ACDB remarks in SMPS category');
      } else {
        print('AssetAuditPostHelper: No SMPS data found for ACDB remarks');
        categoryData = null;
      }
    }
    
    if (categoryData == null) {
      print('No category data found for $itemType');
      return null;
    }

    // Check if there are remarks in the backend data
    final remarks = categoryData.remarks;
    if (remarks.isNotEmpty) {
      print('Found ${remarks.length} remarks in backend data for $itemType');

      // First try to find a general remarks entry for this item type
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            remark.itemType == itemType) {
          print('Using $itemType remarks ID: ${remark.assetAuditSiteRespId}');
          return remark.assetAuditSiteRespId;
        }
      }

      // Fallback: find any remarks entry with a valid ID for this category
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0) {
          print('Using fallback remarks ID: ${remark.assetAuditSiteRespId} for itemType: ${remark.itemType}');
          return remark.assetAuditSiteRespId;
        }
      }
    }

    // For remarks, if no backend ID is found, allow posting with null ID
    // The backend will assign a new ID for locally created remarks
    print('No valid remarks ID found in backend data for $itemType, allowing null ID for new remark');
    return null;

    print('No valid remarks ID found in backend data for $itemType');
    return null;
  }

  /// Get item type ID based on screen name
  static int getItemTypeId(String screenName) {
    print('AssetAuditPostHelper: getItemTypeId called with: "$screenName"');
    switch (screenName.toLowerCase()) {
      // Telecom asset types
      case 'ccu':
        return 1;
      case 'battery':
        return 2;
      case 'extinguisher':
        return 3;
      case 'fencing':
        return 6;
      case 'dg':
        return 7;
      
      // Solar asset types
      case 'solar plates':
      case 'spv':
        return 4;
      case 'cctv':
      case 'surveillance':
      case 'solar_survelliance':
        return 5;
      case 'smps':
        return 8;
      case 'dcdb':
      case 'dcba':
        return 9;
      case 'fire_extinguisher':
        print('AssetAuditPostHelper: Returning itemTypeId 10 for fire_extinguisher');
        return 10;
      case 'flood_light':
        print('AssetAuditPostHelper: Returning itemTypeId 21 for flood_light');
        return 21;
      case 'sand_bucket':
        print('AssetAuditPostHelper: Returning itemTypeId 22 for sand_bucket');
        return 22;
      case 'transformer':
        return 11;
      case 'vcb':
        return 12;
      case 'ltdb':
        return 13;
      case 'invertor':
        return 14;
      case 'wms':
        return 15;
      case 'boundary':
        return 16;
      case 'scada':
        return 17;
      case 'acdb':
        return 18;
      case 'pcu':
        return 19;
      case 'mms':
        return 20;
      
      // Selfie
      case 'selfie':
        return 999;
      
      default:
        print('AssetAuditPostHelper: No match found for "$screenName", returning 0');
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
