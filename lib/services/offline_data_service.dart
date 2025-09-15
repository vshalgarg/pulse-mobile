import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_location_service.dart';

class OfflineDataService {
  static const String _offlineDataKey = 'offline_submission_data';
  static const String _maxOfflineItems = 'max_offline_items';
  static const int _defaultMaxItems = 100;

  /// Store data for offline submission
  static Future<void> storeOfflineData({
    required String dataType, // 'asset_audit', 'pm', 'ccu', 'spv', etc.
    required Map<String, dynamic> data,
    required String screenName,
    String? siteId,
    String? auditSchId,
    String? siteAuditSchId,
  }) async {
    try {
      print('OfflineDataService: Storing offline data for $dataType - $screenName');
      
      // Get current location for offline submission
      final location = await OfflineLocationService.getCurrentLocationOffline();
      
      // Create offline data entry
      final offlineEntry = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'dataType': dataType,
        'screenName': screenName,
        'data': data,
        'location': location,
        'timestamp': DateTime.now().toIso8601String(),
        'siteId': siteId,
        'auditSchId': auditSchId,
        'siteAuditSchId': siteAuditSchId,
        'retryCount': 0,
        'status': 'pending', // pending, submitted, failed
      };
      
      // Get existing offline data
      final prefs = await SharedPreferences.getInstance();
      final existingDataJson = prefs.getString(_offlineDataKey);
      List<Map<String, dynamic>> offlineData = [];
      
      if (existingDataJson != null) {
        final List<dynamic> dataList = json.decode(existingDataJson);
        offlineData = dataList.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      
      // Add new entry
      offlineData.add(offlineEntry);
      
      // Limit the number of offline items to prevent storage overflow
      final maxItems = await _getMaxOfflineItems();
      if (offlineData.length > maxItems) {
        // Remove oldest items (keep the most recent ones)
        offlineData.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        offlineData = offlineData.take(maxItems).toList();
      }
      
      // Save back to storage
      await prefs.setString(_offlineDataKey, json.encode(offlineData));
      
      print('OfflineDataService: Successfully stored offline data. Total items: ${offlineData.length}');
      
    } catch (e) {
      print('OfflineDataService: Error storing offline data: $e');
    }
  }

  /// Get all pending offline data
  static Future<List<Map<String, dynamic>>> getPendingOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineDataJson = prefs.getString(_offlineDataKey);
      
      if (offlineDataJson == null) {
        return [];
      }
      
      final List<dynamic> dataList = json.decode(offlineDataJson);
      final List<Map<String, dynamic>> offlineData = dataList
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      
      // Filter only pending items
      return offlineData.where((item) => item['status'] == 'pending').toList();
      
    } catch (e) {
      print('OfflineDataService: Error getting pending offline data: $e');
      return [];
    }
  }

  /// Get offline data by type
  static Future<List<Map<String, dynamic>>> getOfflineDataByType(String dataType) async {
    try {
      final allData = await getPendingOfflineData();
      return allData.where((item) => item['dataType'] == dataType).toList();
    } catch (e) {
      print('OfflineDataService: Error getting offline data by type: $e');
      return [];
    }
  }

  /// Mark offline data as submitted
  static Future<void> markAsSubmitted(String dataId) async {
    try {
      await _updateDataStatus(dataId, 'submitted');
    } catch (e) {
      print('OfflineDataService: Error marking data as submitted: $e');
    }
  }

  /// Mark offline data as failed
  static Future<void> markAsFailed(String dataId, {int? retryCount}) async {
    try {
      await _updateDataStatus(dataId, 'failed', retryCount: retryCount);
    } catch (e) {
      print('OfflineDataService: Error marking data as failed: $e');
    }
  }

  /// Update data status
  static Future<void> _updateDataStatus(String dataId, String status, {int? retryCount}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineDataJson = prefs.getString(_offlineDataKey);
      
      if (offlineDataJson == null) return;
      
      final List<dynamic> dataList = json.decode(offlineDataJson);
      final List<Map<String, dynamic>> offlineData = dataList
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      
      // Find and update the specific item
      for (int i = 0; i < offlineData.length; i++) {
        if (offlineData[i]['id'] == dataId) {
          offlineData[i]['status'] = status;
          if (retryCount != null) {
            offlineData[i]['retryCount'] = retryCount;
          }
          break;
        }
      }
      
      // Save back to storage
      await prefs.setString(_offlineDataKey, json.encode(offlineData));
      
    } catch (e) {
      print('OfflineDataService: Error updating data status: $e');
    }
  }

  /// Clear submitted data (cleanup)
  static Future<void> clearSubmittedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineDataJson = prefs.getString(_offlineDataKey);
      
      if (offlineDataJson == null) return;
      
      final List<dynamic> dataList = json.decode(offlineDataJson);
      final List<Map<String, dynamic>> offlineData = dataList
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      
      // Keep only pending and failed items
      final filteredData = offlineData.where((item) => 
          item['status'] == 'pending' || item['status'] == 'failed').toList();
      
      await prefs.setString(_offlineDataKey, json.encode(filteredData));
      
      print('OfflineDataService: Cleared submitted data. Remaining items: ${filteredData.length}');
      
    } catch (e) {
      print('OfflineDataService: Error clearing submitted data: $e');
    }
  }

  /// Check if device is online
  static Future<bool> isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('OfflineDataService: Error checking connectivity: $e');
      return false; // Assume offline if check fails
    }
  }

  /// Get offline data statistics
  static Future<Map<String, int>> getOfflineDataStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineDataJson = prefs.getString(_offlineDataKey);
      
      if (offlineDataJson == null) {
        return {'total': 0, 'pending': 0, 'submitted': 0, 'failed': 0};
      }
      
      final List<dynamic> dataList = json.decode(offlineDataJson);
      final List<Map<String, dynamic>> offlineData = dataList
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      
      int pending = 0;
      int submitted = 0;
      int failed = 0;
      
      for (var item in offlineData) {
        switch (item['status']) {
          case 'pending':
            pending++;
            break;
          case 'submitted':
            submitted++;
            break;
          case 'failed':
            failed++;
            break;
        }
      }
      
      return {
        'total': offlineData.length,
        'pending': pending,
        'submitted': submitted,
        'failed': failed,
      };
      
    } catch (e) {
      print('OfflineDataService: Error getting offline data stats: $e');
      return {'total': 0, 'pending': 0, 'submitted': 0, 'failed': 0};
    }
  }

  /// Get max offline items setting
  static Future<int> _getMaxOfflineItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_maxOfflineItems) ?? _defaultMaxItems;
    } catch (e) {
      return _defaultMaxItems;
    }
  }

  /// Set max offline items
  static Future<void> setMaxOfflineItems(int maxItems) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_maxOfflineItems, maxItems);
    } catch (e) {
      print('OfflineDataService: Error setting max offline items: $e');
    }
  }

  /// Clear all offline data
  static Future<void> clearAllOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineDataKey);
      print('OfflineDataService: Cleared all offline data');
    } catch (e) {
      print('OfflineDataService: Error clearing all offline data: $e');
    }
  }

  /// Get offline data for specific screen
  static Future<List<Map<String, dynamic>>> getOfflineDataForScreen(String screenName) async {
    try {
      final allData = await getPendingOfflineData();
      return allData.where((item) => item['screenName'] == screenName).toList();
    } catch (e) {
      print('OfflineDataService: Error getting offline data for screen: $e');
      return [];
    }
  }

  /// Retry failed submissions
  static Future<List<Map<String, dynamic>>> getFailedDataForRetry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineDataJson = prefs.getString(_offlineDataKey);
      
      if (offlineDataJson == null) {
        return [];
      }
      
      final List<dynamic> dataList = json.decode(offlineDataJson);
      final List<Map<String, dynamic>> offlineData = dataList
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      
      // Filter failed items that haven't exceeded retry limit
      return offlineData.where((item) => 
          item['status'] == 'failed' && 
          (item['retryCount'] ?? 0) < 3).toList();
      
    } catch (e) {
      print('OfflineDataService: Error getting failed data for retry: $e');
      return [];
    }
  }
}
