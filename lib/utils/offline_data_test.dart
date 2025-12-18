// import 'package:flutter/material.dart';
// import 'offline_data_helper.dart';
// import '../services/local_storage_db.dart';
//
// /// Test utility to verify offline data loading works correctly
// class OfflineDataTest {
//   static Future<void> testOfflineDataLoading(String siteAuditSchId) async {
//
//     // Test 1: Check if offline data exists
//     final hasOfflineData = OfflineDataHelper.hasOfflineData(siteAuditSchId);
//
//     if (hasOfflineData) {
//       // Test 2: Get offline ticket info
//       final ticketInfo = OfflineDataHelper.getOfflineTicketInfo(siteAuditSchId);
//
//       // Test 3: Get offline page header
//       final pageHeader = OfflineDataHelper.getOfflinePageHeader(siteAuditSchId);
//       if (pageHeader != null && pageHeader.isNotEmpty) {
//       }
//
//       // Test 4: Get offline CCU data
//       final ccuData = OfflineDataHelper.getOfflineResponseData(siteAuditSchId, 'ccu');
//       if (ccuData != null) {
//       }
//
//       // Test 5: Get offline battery data
//       final batteryData = OfflineDataHelper.getOfflineResponseData(siteAuditSchId, 'battery');
//
//       // Test 6: Get complete asset audit data
//       final assetAuditData = OfflineDataHelper.getOfflineAssetAuditData(siteAuditSchId);
//     } else {
//     }
//
//   }
//
//   /// Test method to simulate CCU screen data loading
//   static Future<void> testCCUScreenDataLoading(String siteAuditSchId) async {
//
//     // Simulate the CCU screen's _getCCUData() method
//     final ccuData = OfflineDataHelper.getOfflineResponseData(siteAuditSchId, 'ccu');
//
//     if (ccuData != null) {
//     } else {
//     }
//
//   }
// }
