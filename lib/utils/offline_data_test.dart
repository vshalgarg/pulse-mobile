// import 'package:flutter/material.dart';
// import 'offline_data_helper.dart';
// import '../services/local_storage_db.dart';
//
// /// Test utility to verify offline data loading works correctly
// class OfflineDataTest {
//   static Future<void> testOfflineDataLoading(String siteAuditSchId) async {
//     print('=== OFFLINE DATA TEST ===');
//     print('Testing siteAuditSchId: $siteAuditSchId');
//
//     // Test 1: Check if offline data exists
//     final hasOfflineData = OfflineDataHelper.hasOfflineData(siteAuditSchId);
//     print('1. Has offline data: $hasOfflineData');
//
//     if (hasOfflineData) {
//       // Test 2: Get offline ticket info
//       final ticketInfo = OfflineDataHelper.getOfflineTicketInfo(siteAuditSchId);
//       print('2. Ticket info: $ticketInfo');
//
//       // Test 3: Get offline page header
//       final pageHeader = OfflineDataHelper.getOfflinePageHeader(siteAuditSchId);
//       print('3. Page header count: ${pageHeader?.length ?? 0}');
//       if (pageHeader != null && pageHeader.isNotEmpty) {
//         print('   - First page header site name: ${pageHeader.first.siteName}');
//       }
//
//       // Test 4: Get offline CCU data
//       final ccuData = OfflineDataHelper.getOfflineResponseData(siteAuditSchId, 'ccu');
//       print('4. CCU data: ${ccuData != null ? "Found" : "Not found"}');
//       if (ccuData != null) {
//         print('   - CCU rectifiers count: ${ccuData.ccuRectifiers?.length ?? 0}');
//         print('   - CCU MPPT count: ${ccuData.ccuMppt?.length ?? 0}');
//         print('   - CCU cabinet count: ${ccuData.ccuCabinet?.length ?? 0}');
//         print('   - CCU assets count: ${ccuData.assets.length}');
//       }
//
//       // Test 5: Get offline battery data
//       final batteryData = OfflineDataHelper.getOfflineResponseData(siteAuditSchId, 'battery');
//       print('5. Battery data: ${batteryData != null ? "Found" : "Not found"}');
//
//       // Test 6: Get complete asset audit data
//       final assetAuditData = OfflineDataHelper.getOfflineAssetAuditData(siteAuditSchId);
//       print('6. Complete asset audit data: ${assetAuditData != null ? "Found" : "Not found"}');
//     } else {
//       print('No offline data found for this ticket');
//     }
//
//     print('=== END OFFLINE DATA TEST ===');
//   }
//
//   /// Test method to simulate CCU screen data loading
//   static Future<void> testCCUScreenDataLoading(String siteAuditSchId) async {
//     print('=== CCU SCREEN DATA LOADING TEST ===');
//
//     // Simulate the CCU screen's _getCCUData() method
//     final ccuData = OfflineDataHelper.getOfflineResponseData(siteAuditSchId, 'ccu');
//
//     if (ccuData != null) {
//       print('✅ CCU data loaded successfully from offline source');
//       print('   - Rectifiers: ${ccuData.ccuRectifiers?.length ?? 0} items');
//       print('   - MPPT: ${ccuData.ccuMppt?.length ?? 0} items');
//       print('   - Cabinet: ${ccuData.ccuCabinet?.length ?? 0} items');
//       print('   - Assets: ${ccuData.assets.length} items');
//       print('   - Remarks: ${ccuData.remarks.length} items');
//     } else {
//       print('❌ No CCU data found in offline storage');
//     }
//
//     print('=== END CCU SCREEN TEST ===');
//   }
// }
