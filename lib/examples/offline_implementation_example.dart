// This file shows how to implement offline functionality in your screens
// Example for CCU, SPV, and other asset audit screens

import 'package:flutter/material.dart';
import '../utils/offline_post_helper.dart';
import '../services/offline_location_service.dart';
import '../services/offline_data_service.dart';

class OfflineImplementationExample {
  
  /// Example: How to implement offline submission in CCU Screen
  static Future<void> submitCcuDataOffline({
    required BuildContext context,
    required Map<String, dynamic> ccuData,
    required String screenName,
    String? siteId,
    String? auditSchId,
    String? siteAuditSchId,
  }) async {
    try {
      print('CCU Screen: Submitting data with offline support...');
      
      // Use the offline post helper for single item submission
      final success = await OfflinePostHelper.submitSingleItemOffline(
        dataType: 'ccu',
        itemData: ccuData,
        screenName: screenName,
        siteId: siteId,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
      );
      
      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data saved successfully (offline mode)'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('CCU Screen: Error submitting data offline: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Example: How to implement offline submission in SPV Screen
  static Future<void> submitSpvDataOffline({
    required BuildContext context,
    required Map<String, dynamic> spvData,
    required String screenName,
    String? siteId,
    String? auditSchId,
    String? siteAuditSchId,
  }) async {
    try {
      print('SPV Screen: Submitting data with offline support...');
      
      // Use the offline post helper for single item submission
      final success = await OfflinePostHelper.submitSingleItemOffline(
        dataType: 'spv',
        itemData: spvData,
        screenName: screenName,
        siteId: siteId,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
      );
      
      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SPV data saved successfully (offline mode)'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save SPV data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('SPV Screen: Error submitting data offline: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Example: How to get current location with offline support
  static Future<Map<String, String?>> getCurrentLocationForSubmission() async {
    try {
      // This will work offline and provide fallback mechanisms
      final location = await OfflineLocationService.getCurrentLocationOffline();
      
      print('Location obtained: ${location['latitude']}, ${location['longitude']}');
      return location;
    } catch (e) {
      print('Error getting location: $e');
      return {'latitude': null, 'longitude': null};
    }
  }

  /// Example: How to check offline data status
  static Future<void> checkOfflineDataStatus(BuildContext context) async {
    try {
      final stats = await OfflinePostHelper.getOfflineStats();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Offline Data Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connection: ${stats['isOnline'] ? 'Online' : 'Offline'}'),
              Text('Total Items: ${stats['totalItems']}'),
              Text('Pending: ${stats['pendingItems']}'),
              Text('Submitted: ${stats['submittedItems']}'),
              Text('Failed: ${stats['failedItems']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            if (stats['isOnline'] && stats['pendingItems'] > 0)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await OfflinePostHelper.processPendingOfflineData();
                },
                child: const Text('Sync Now'),
              ),
          ],
        ),
      );
    } catch (e) {
      print('Error checking offline data status: $e');
    }
  }

  /// Example: How to implement in your screen's submit method
  static Future<void> exampleScreenSubmitMethod({
    required BuildContext context,
    required Map<String, dynamic> formData,
    required String screenName,
    String? siteId,
    String? auditSchId,
    String? siteAuditSchId,
  }) async {
    try {
      // Get current location (works offline)
      final location = await getCurrentLocationForSubmission();
      
      // Add location to your form data
      final dataWithLocation = {
        ...formData,
        'latitude': location['latitude'],
        'longitude': location['longitude'],
        'locationTimestamp': DateTime.now().toIso8601String(),
      };
      
      // Submit with offline support
      final success = await OfflinePostHelper.submitSingleItemOffline(
        dataType: screenName.toLowerCase(), // e.g., 'ccu', 'spv', 'dcba'
        itemData: dataWithLocation,
        screenName: screenName,
        siteId: siteId,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$screenName data saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save $screenName data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error in screen submit method: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Example: How to add offline status indicator to your app bar
  static Widget buildOfflineStatusIndicator() {
    return FutureBuilder<Map<String, dynamic>>(
      future: OfflinePostHelper.getOfflineStats(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final stats = snapshot.data!;
          final isOnline = stats['isOnline'] as bool;
          final pendingItems = stats['pendingItems'] as int;
          
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                color: isOnline ? Colors.green : Colors.red,
                size: 16,
              ),
              if (pendingItems > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$pendingItems',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// Example: How to process pending data when app starts
  static Future<void> initializeOfflineProcessing() async {
    try {
      print('Initializing offline data processing...');
      
      // Process any pending offline data
      await OfflinePostHelper.processPendingOfflineData();
      
      // Set up periodic processing (optional)
      // Timer.periodic(const Duration(minutes: 5), (timer) async {
      //   await OfflinePostHelper.processPendingOfflineData();
      // });
      
    } catch (e) {
      print('Error initializing offline processing: $e');
    }
  }
}

/// Example widget showing how to integrate offline functionality
class OfflineEnabledScreen extends StatefulWidget {
  final String screenName;
  final String? siteId;
  final String? auditSchId;
  final String? siteAuditSchId;

  const OfflineEnabledScreen({
    Key? key,
    required this.screenName,
    this.siteId,
    this.auditSchId,
    this.siteAuditSchId,
  }) : super(key: key);

  @override
  State<OfflineEnabledScreen> createState() => _OfflineEnabledScreenState();
}

class _OfflineEnabledScreenState extends State<OfflineEnabledScreen> {
  final Map<String, dynamic> _formData = {};

  @override
  void initState() {
    super.initState();
    // Initialize offline processing
    OfflineImplementationExample.initializeOfflineProcessing();
  }

  Future<void> _submitData() async {
    await OfflineImplementationExample.exampleScreenSubmitMethod(
      context: context,
      formData: _formData,
      screenName: widget.screenName,
      siteId: widget.siteId,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.screenName),
        actions: [
          OfflineImplementationExample.buildOfflineStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => OfflineImplementationExample.checkOfflineDataStatus(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Your form content here
          Expanded(
            child: Center(
              child: Text('${widget.screenName} Form Content'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitData,
                    child: const Text('Submit (Offline Enabled)'),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => OfflineImplementationExample.checkOfflineDataStatus(context),
                  child: const Text('Check Status'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
