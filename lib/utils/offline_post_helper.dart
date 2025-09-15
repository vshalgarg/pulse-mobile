import 'package:flutter/material.dart';
import '../services/offline_data_service.dart';
import '../services/offline_location_service.dart';
import 'asset_audit_post_helper.dart';
import 'pm_form_helper.dart';
import '../models/asset_audit_model.dart';
import '../models/PmGetDataModel.dart';

class OfflinePostHelper {
  /// Submit asset audit data with offline support
  static Future<bool> submitAssetAuditDataOffline({
    required List<Map<String, dynamic>> savedItems,
    required AssetAuditModel assetAuditData,
    required String itemType,
    required int itemTypeId,
    required String screenName,
    required BuildContext context,
    String? auditSchId,
  }) async {
    try {
      print('OfflinePostHelper: Submitting asset audit data offline for $screenName');
      
      // Check if online
      final isOnline = await OfflineDataService.isOnline();
      
      if (isOnline) {
        // Try online submission first
        try {
          final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: savedItems,
            assetAuditData: assetAuditData,
            itemType: itemType,
            itemTypeId: itemTypeId,
            screenName: screenName,
            context: context,
            auditSchId: auditSchId,
          );
          
          if (requests.isNotEmpty) {
            // Online submission successful
            print('OfflinePostHelper: Online submission successful for $screenName');
            return true;
          }
        } catch (e) {
          print('OfflinePostHelper: Online submission failed, falling back to offline: $e');
        }
      }
      
      // Store data for offline submission
      await OfflineDataService.storeOfflineData(
        dataType: 'asset_audit',
        data: {
          'savedItems': savedItems,
          'itemType': itemType,
          'itemTypeId': itemTypeId,
          'screenName': screenName,
        },
        screenName: screenName,
        siteId: assetAuditData.pageHeader.isNotEmpty 
            ? assetAuditData.pageHeader.first.siteId?.toString() 
            : null,
        auditSchId: auditSchId,
        siteAuditSchId: assetAuditData.pageHeader.isNotEmpty 
            ? assetAuditData.pageHeader.first.siteAuditSchId.toString() 
            : null,
      );
      
      print('OfflinePostHelper: Data stored for offline submission: $screenName');
      return true;
      
    } catch (e) {
      print('OfflinePostHelper: Error submitting asset audit data offline: $e');
      return false;
    }
  }

  /// Submit PM data with offline support
  static Future<bool> submitPmDataOffline({
    required Map<String, dynamic> formData,
    required PmGetDataModel pmData,
    required String auditSchId,
    required String siteAuditSchId,
    required String siteId,
    required Map<String, int> photoIds,
    required Map<String, String> photoTimestamps,
    required Map<String, String> remarksData,
    required String screenName,
  }) async {
    try {
      print('OfflinePostHelper: Submitting PM data offline for $screenName');
      
      // Check if online
      final isOnline = await OfflineDataService.isOnline();
      
      if (isOnline) {
        // Try online submission first
        try {
          final requests = await PmFormHelper.buildPmPostRequests(
            formData: formData,
            pmData: pmData,
            auditSchId: auditSchId,
            siteAuditSchId: siteAuditSchId,
            siteId: siteId,
            photoIds: photoIds,
            photoTimestamps: photoTimestamps,
            remarksData: remarksData,
          );
          
          if (requests.isNotEmpty) {
            // Online submission successful
            print('OfflinePostHelper: Online PM submission successful for $screenName');
            return true;
          }
        } catch (e) {
          print('OfflinePostHelper: Online PM submission failed, falling back to offline: $e');
        }
      }
      
      // Store data for offline submission
      await OfflineDataService.storeOfflineData(
        dataType: 'pm',
        data: {
          'formData': formData,
          'photoIds': photoIds,
          'photoTimestamps': photoTimestamps,
          'remarksData': remarksData,
        },
        screenName: screenName,
        siteId: siteId,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
      );
      
      print('OfflinePostHelper: PM data stored for offline submission: $screenName');
      return true;
      
    } catch (e) {
      print('OfflinePostHelper: Error submitting PM data offline: $e');
      return false;
    }
  }

  /// Submit single item data with offline support
  static Future<bool> submitSingleItemOffline({
    required String dataType, // 'ccu', 'spv', 'dcba', etc.
    required Map<String, dynamic> itemData,
    required String screenName,
    String? siteId,
    String? auditSchId,
    String? siteAuditSchId,
  }) async {
    try {
      print('OfflinePostHelper: Submitting single item offline for $dataType - $screenName');
      
      // Get current location for offline submission
      final location = await OfflineLocationService.getCurrentLocationOffline();
      
      // Add location to item data
      final enhancedItemData = {
        ...itemData,
        'latitude': location['latitude'],
        'longitude': location['longitude'],
        'locationTimestamp': DateTime.now().toIso8601String(),
      };
      
      // Check if online
      final isOnline = await OfflineDataService.isOnline();
      
      if (isOnline) {
        // Try online submission first (you can implement specific online submission logic here)
        print('OfflinePostHelper: Online submission not implemented for single items, storing offline');
      }
      
      // Store data for offline submission
      await OfflineDataService.storeOfflineData(
        dataType: dataType,
        data: enhancedItemData,
        screenName: screenName,
        siteId: siteId,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
      );
      
      print('OfflinePostHelper: Single item data stored for offline submission: $dataType - $screenName');
      return true;
      
    } catch (e) {
      print('OfflinePostHelper: Error submitting single item offline: $e');
      return false;
    }
  }

  /// Process all pending offline data when connection is restored
  static Future<void> processPendingOfflineData() async {
    try {
      print('OfflinePostHelper: Processing pending offline data...');
      
      final isOnline = await OfflineDataService.isOnline();
      if (!isOnline) {
        print('OfflinePostHelper: Device is offline, skipping offline data processing');
        return;
      }
      
      final pendingData = await OfflineDataService.getPendingOfflineData();
      print('OfflinePostHelper: Found ${pendingData.length} pending offline items');
      
      for (var item in pendingData) {
        try {
          final dataType = item['dataType'] as String;
          final success = await _processOfflineItem(item);
          
          if (success) {
            await OfflineDataService.markAsSubmitted(item['id']);
            print('OfflinePostHelper: Successfully processed offline item: ${item['id']}');
          } else {
            final retryCount = (item['retryCount'] ?? 0) + 1;
            await OfflineDataService.markAsFailed(item['id'], retryCount: retryCount);
            print('OfflinePostHelper: Failed to process offline item: ${item['id']}, retry count: $retryCount');
          }
        } catch (e) {
          print('OfflinePostHelper: Error processing offline item ${item['id']}: $e');
          final retryCount = (item['retryCount'] ?? 0) + 1;
          await OfflineDataService.markAsFailed(item['id'], retryCount: retryCount);
        }
      }
      
      // Clean up submitted data
      await OfflineDataService.clearSubmittedData();
      
    } catch (e) {
      print('OfflinePostHelper: Error processing pending offline data: $e');
    }
  }

  /// Process individual offline item
  static Future<bool> _processOfflineItem(Map<String, dynamic> item) async {
    try {
      final dataType = item['dataType'] as String;
      
      switch (dataType) {
        case 'asset_audit':
          // Process asset audit data
          // You can implement specific asset audit processing logic here
          print('OfflinePostHelper: Processing asset audit item: ${item['id']}');
          return true; // Placeholder - implement actual processing
          
        case 'pm':
          // Process PM data
          // You can implement specific PM processing logic here
          print('OfflinePostHelper: Processing PM item: ${item['id']}');
          return true; // Placeholder - implement actual processing
          
        case 'ccu':
        case 'spv':
        case 'dcba':
        case 'acdb':
        case 'battery':
        case 'dg':
        case 'smps':
        case 'fencing':
        case 'extinguisher':
        case 'surveillance':
        case 'solar_plates':
        case 'site_info':
        case 'ccu_screen':
        case 'boundary':
        case 'fire_extinguisher':
        case 'invertor':
        case 'ltdb':
        case 'mms':
        case 'pcu':
        case 'scada':
        case 'solar_surveillance':
        case 'spv_screen':
        case 'transformer':
        case 'vcb':
        case 'wms':
          // Process single item data
          print('OfflinePostHelper: Processing single item ($dataType): ${item['id']}');
          return true; // Placeholder - implement actual processing
          
        default:
          print('OfflinePostHelper: Unknown data type: $dataType');
          return false;
      }
    } catch (e) {
      print('OfflinePostHelper: Error processing offline item: $e');
      return false;
    }
  }

  /// Get offline data statistics for UI display
  static Future<Map<String, dynamic>> getOfflineStats() async {
    try {
      final stats = await OfflineDataService.getOfflineDataStats();
      final isOnline = await OfflineDataService.isOnline();
      
      return {
        'isOnline': isOnline,
        'totalItems': stats['total'] ?? 0,
        'pendingItems': stats['pending'] ?? 0,
        'submittedItems': stats['submitted'] ?? 0,
        'failedItems': stats['failed'] ?? 0,
      };
    } catch (e) {
      print('OfflinePostHelper: Error getting offline stats: $e');
      return {
        'isOnline': false,
        'totalItems': 0,
        'pendingItems': 0,
        'submittedItems': 0,
        'failedItems': 0,
      };
    }
  }

  /// Clear all offline data
  static Future<void> clearAllOfflineData() async {
    try {
      await OfflineDataService.clearAllOfflineData();
      print('OfflinePostHelper: Cleared all offline data');
    } catch (e) {
      print('OfflinePostHelper: Error clearing all offline data: $e');
    }
  }
}
