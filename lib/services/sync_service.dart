import 'dart:convert';
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
//
// import '../models/offline_ticket_model.dart';
// import '../models/asset_audit_post_model.dart';
// import '../services/local_storage_db.dart';
// import '../services/local_storage_constants.dart';
// import '../services/connectivity_service.dart';
// import '../services/api_service.dart';
// import '../bloc/asset_audit_cubit.dart';
// import '../utils/asset_audit_post_helper.dart';
//
// class SyncService {
//   static final SyncService _instance = SyncService._internal();
//   factory SyncService() => _instance;
//   SyncService._internal();
//
//   final ConnectivityService _connectivityService = ConnectivityService();
//   ApiService? _apiService;
//   StreamSubscription<bool>? _connectivitySubscription;
//   Timer? _syncTimer;
//   bool _isSyncing = false;
//
//   /// Stream to listen to sync status changes
//   final StreamController<SyncStatus> _syncStatusController =
//       StreamController<SyncStatus>.broadcast();
//
//   Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
//
//   /// Initialize the sync service
//   Future<void> initialize(ApiService apiService) async {
//     _apiService = apiService;
//
//     // Listen to connectivity changes
//     _connectivitySubscription = _connectivityService.connectivityStream.listen(
//       _onConnectivityChanged,
//     );
//
//     // Start periodic sync check (every 30 seconds when online)
//     _startPeriodicSync();
//   }
//
//   /// Handle connectivity changes
//   void _onConnectivityChanged(bool isOnline) {
//     if (isOnline) {
//       _startPeriodicSync();
//       // Trigger immediate sync when coming back online
//       _syncPendingData();
//     } else {
//       _stopPeriodicSync();
//     }
//   }
//
//   /// Start periodic sync timer
//   void _startPeriodicSync() {
//     _stopPeriodicSync();
//     _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
//       if (_connectivityService.isOnline && !_isSyncing) {
//         _syncPendingData();
//       }
//     });
//   }
//
//   /// Stop periodic sync timer
//   void _stopPeriodicSync() {
//     _syncTimer?.cancel();
//     _syncTimer = null;
//   }
//
//   /// Sync all pending data
//   Future<void> _syncPendingData() async {
//     if (_isSyncing || !_connectivityService.isOnline) return;
//
//     _isSyncing = true;
//     _syncStatusController.add(SyncStatus.syncing);
//
//     try {
//       // Get all offline tickets with pending sync
//       final pendingTickets = await _getPendingSyncTickets();
//
//       if (pendingTickets.isEmpty) {
//         _syncStatusController.add(SyncStatus.idle);
//         return;
//       }
//
//       int syncedCount = 0;
//       int failedCount = 0;
//
//       for (final ticket in pendingTickets) {
//         try {
//           final success = await _syncTicket(ticket);
//           if (success) {
//             syncedCount++;
//           } else {
//             failedCount++;
//           }
//         } catch (e) {
//           failedCount++;
//         }
//       }
//
//       if (syncedCount > 0) {
//         _syncStatusController.add(SyncStatus.synced(syncedCount));
//       }
//
//       if (failedCount > 0) {
//         _syncStatusController.add(SyncStatus.failed(failedCount));
//       }
//
//     } catch (e) {
//       _syncStatusController.add(SyncStatus.error(e.toString()));
//     } finally {
//       _isSyncing = false;
//     }
//   }
//
//   /// Get all tickets that need to be synced
//   Future<List<OfflineTicket>> _getPendingSyncTickets() async {
//     try {
//       await HiveDB.openHiveDB(HiveConstant.offlineTickets);
//       final box = HiveDB.getHiveBox(HiveConstant.offlineTickets);
//
//       final pendingTickets = <OfflineTicket>[];
//
//       for (final key in box.keys) {
//         final ticketData = box.get(key);
//         if (ticketData != null) {
//           final ticket = OfflineTicket.fromJson(Map<String, dynamic>.from(ticketData));
//           if (ticket.isPendingSync) {
//             pendingTickets.add(ticket);
//           }
//         }
//       }
//
//       return pendingTickets;
//     } catch (e) {
//       return [];
//     }
//   }
//
//   /// Sync a single ticket
//   Future<bool> _syncTicket(OfflineTicket ticket) async {
//     try {
//       // Sync form data
//       await _syncFormData(ticket);
//
//       // Sync photos
//       await _syncPhotos(ticket);
//
//       // Sync remarks
//       await _syncRemarks(ticket);
//
//       // Mark ticket as synced
//       await _markTicketAsSynced(ticket);
//
//       return true;
//     } catch (e) {
//       await _incrementSyncRetryCount(ticket);
//       return false;
//     }
//   }
//
//   /// Sync form data for a ticket
//   Future<void> _syncFormData(OfflineTicket ticket) async {
//     for (final formData in ticket.formDataList) {
//       if (formData.isPendingSync) {
//         try {
//           // Convert form data to AssetAuditPostRequest
//           final postRequest = await AssetAuditPostHelper.convertSingleItemToPostRequest(
//             savedItem: formData.formData,
//             assetAuditData: _convertOfflineTicketToAssetAuditModel(ticket),
//             itemTypeId: AssetAuditPostHelper.getItemTypeId(formData.screenName),
//             screenName: formData.screenName,
//             context: _getCurrentContext(),
//             auditSchId: ticket.auditSchId,
//           );
//
//           // Post to API
//           final result = await _apiService!.post(
//             path: '/api/v1/mobile/AssetAuditSiteResp',
//             data: [postRequest.toJson()], // Wrap in array as expected by API
//           );
//
//           if (result.isSuccess) {
//             // Mark form data as synced
//             await _markFormDataAsSynced(ticket, formData);
//           } else {
//             throw Exception('API call failed: ${result.errorMessage}');
//           }
//         } catch (e) {
//           rethrow;
//         }
//       }
//     }
//   }
//
//   /// Sync photos for a ticket
//   Future<void> _syncPhotos(OfflineTicket ticket) async {
//     for (final photo in ticket.photos) {
//       if (photo.isPendingSync && !photo.isUploaded) {
//         try {
//           // Upload photo using existing photo upload service
//           // This would need to be implemented based on your existing photo upload logic
//           // For now, we'll mark it as uploaded
//           await _markPhotoAsSynced(ticket, photo);
//         } catch (e) {
//           rethrow;
//         }
//       }
//     }
//   }
//
//   /// Sync remarks for a ticket
//   Future<void> _syncRemarks(OfflineTicket ticket) async {
//     for (final remark in ticket.remarks) {
//       if (remark.isPendingSync) {
//         try {
//           // Convert remark to AssetAuditPostRequest
//           final postRequest = await AssetAuditPostHelper.convertSingleItemToPostRequest(
//             savedItem: {
//               'recordType': 'remarks',
//               'remarks': remark.remarkText,
//               'itemType': remark.itemType,
//               'assetAuditSiteRespId': remark.assetAuditSiteRespId,
//             },
//             assetAuditData: _convertOfflineTicketToAssetAuditModel(ticket),
//             itemTypeId: AssetAuditPostHelper.getItemTypeId(remark.screenName),
//             screenName: remark.screenName,
//             context: _getCurrentContext(),
//             auditSchId: ticket.auditSchId,
//           );
//
//           // Post to API
//           final result = await _apiService!.post(
//             path: '/api/v1/mobile/AssetAuditSiteResp',
//             data: [postRequest.toJson()], // Wrap in array as expected by API
//           );
//
//           if (result.isSuccess) {
//             // Mark remark as synced
//             await _markRemarkAsSynced(ticket, remark);
//           } else {
//             throw Exception('API call failed: ${result.errorMessage}');
//           }
//         } catch (e) {
//           rethrow;
//         }
//       }
//     }
//   }
//
//   /// Mark ticket as synced
//   Future<void> _markTicketAsSynced(OfflineTicket ticket) async {
//     final updatedTicket = ticket.copyWith(
//       isPendingSync: false,
//       lastSyncAttempt: DateTime.now(),
//       syncRetryCount: 0,
//     );
//
//     await HiveDB.saveOfflineTicket(updatedTicket);
//   }
//
//   /// Mark form data as synced
//   Future<void> _markFormDataAsSynced(OfflineTicket ticket, OfflineFormData formData) async {
//     final updatedFormData = formData.copyWith(isPendingSync: false);
//     final updatedFormDataList = ticket.formDataList
//         .map((fd) => fd.screenName == formData.screenName ? updatedFormData : fd)
//         .toList();
//
//     final updatedTicket = ticket.copyWith(
//       formDataList: updatedFormDataList,
//       lastModified: DateTime.now(),
//     );
//
//     await HiveDB.saveOfflineTicket(updatedTicket);
//   }
//
//   /// Mark photo as synced
//   Future<void> _markPhotoAsSynced(OfflineTicket ticket, OfflinePhoto photo) async {
//     final updatedPhoto = photo.copyWith(
//       isUploaded: true,
//       isPendingSync: false,
//     );
//
//     final updatedPhotos = ticket.photos
//         .map((p) => p.photoId == photo.photoId ? updatedPhoto : p)
//         .toList();
//
//     final updatedTicket = ticket.copyWith(
//       photos: updatedPhotos,
//       lastModified: DateTime.now(),
//     );
//
//     await HiveDB.saveOfflineTicket(updatedTicket);
//   }
//
//   /// Mark remark as synced
//   Future<void> _markRemarkAsSynced(OfflineTicket ticket, OfflineRemark remark) async {
//     final updatedRemark = remark.copyWith(isPendingSync: false);
//     final updatedRemarks = ticket.remarks
//         .map((r) => r.remarkId == remark.remarkId ? updatedRemark : r)
//         .toList();
//
//     final updatedTicket = ticket.copyWith(
//       remarks: updatedRemarks,
//       lastModified: DateTime.now(),
//     );
//
//     await HiveDB.saveOfflineTicket(updatedTicket);
//   }
//
//   /// Increment sync retry count
//   Future<void> _incrementSyncRetryCount(OfflineTicket ticket) async {
//     final updatedTicket = ticket.copyWith(
//       syncRetryCount: ticket.syncRetryCount + 1,
//       lastSyncAttempt: DateTime.now(),
//     );
//
//     await HiveDB.saveOfflineTicket(updatedTicket);
//   }
//
//   /// Convert OfflineTicket to AssetAuditModel (simplified)
//   dynamic _convertOfflineTicketToAssetAuditModel(OfflineTicket ticket) {
//     // This is a simplified conversion - you might need to adjust based on your actual AssetAuditModel structure
//     return {
//       'pageHeader': [
//         {
//           'siteId': int.tryParse(ticket.siteId) ?? 0,
//           'siteAuditSchId': int.tryParse(ticket.siteAuditSchId) ?? 0,
//         }
//       ],
//       'responseData': {
//         'categories': {},
//       },
//     };
//   }
//
//   /// Get current context (this is a placeholder - you might need to adjust this)
//   BuildContext _getCurrentContext() {
//     // This is a simplified approach - in a real app, you might need to pass context differently
//     throw UnimplementedError('Context needs to be provided from the calling widget');
//   }
//
//   /// Force sync all pending data
//   Future<void> forceSync() async {
//     await _syncPendingData();
//   }
//
//   /// Dispose resources
//   void dispose() {
//     _connectivitySubscription?.cancel();
//     _stopPeriodicSync();
//     _syncStatusController.close();
//   }
// }
//
// /// Sync status enum
// enum SyncStatusType {
//   idle,
//   syncing,
//   synced,
//   failed,
//   error,
// }
//
// class SyncStatus {
//   final SyncStatusType type;
//   final int? count;
//   final String? message;
//
//   SyncStatus._(this.type, {this.count, this.message});
//
//   static SyncStatus get idle => SyncStatus._(SyncStatusType.idle);
//   static SyncStatus get syncing => SyncStatus._(SyncStatusType.syncing);
//   static SyncStatus synced(int count) => SyncStatus._(SyncStatusType.synced, count: count);
//   static SyncStatus failed(int count) => SyncStatus._(SyncStatusType.failed, count: count);
//   static SyncStatus error(String message) => SyncStatus._(SyncStatusType.error, message: message);
// }
