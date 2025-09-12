// import 'dart:async';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:equatable/equatable.dart';
//
// import '../models/offline_ticket_model.dart';
// import '../services/connectivity_service.dart';
// import '../services/sync_service.dart';
// import '../hive_local_database/hive_db.dart';
// import '../hive_local_database/hive_constant.dart';
//
// // States
// abstract class OfflineModeState extends Equatable {
//   const OfflineModeState();
//
//   @override
//   List<Object?> get props => [];
// }
//
// class OfflineModeInitial extends OfflineModeState {}
//
// class OfflineModeLoading extends OfflineModeState {}
//
// class OfflineModeOnline extends OfflineModeState {
//   final bool hasPendingSync;
//
//   const OfflineModeOnline({this.hasPendingSync = false});
//
//   @override
//   List<Object?> get props => [hasPendingSync];
// }
//
// class OfflineModeOffline extends OfflineModeState {
//   final int offlineTicketsCount;
//   final int pendingSyncCount;
//
//   const OfflineModeOffline({
//     this.offlineTicketsCount = 0,
//     this.pendingSyncCount = 0,
//   });
//
//   @override
//   List<Object?> get props => [offlineTicketsCount, pendingSyncCount];
// }
//
// class OfflineModeError extends OfflineModeState {
//   final String message;
//
//   const OfflineModeError(this.message);
//
//   @override
//   List<Object?> get props => [message];
// }
//
// // Cubit
// class OfflineModeCubit extends Cubit<OfflineModeState> {
//   final ConnectivityService _connectivityService = ConnectivityService();
//   final SyncService _syncService = SyncService();
//
//   StreamSubscription<bool>? _connectivitySubscription;
//   StreamSubscription<SyncStatus>? _syncSubscription;
//
//   OfflineModeCubit() : super(OfflineModeInitial()) {
//     _initialize();
//   }
//
//   void _initialize() {
//     // Listen to connectivity changes
//     _connectivitySubscription = _connectivityService.connectivityStream.listen(
//       _onConnectivityChanged,
//     );
//
//     // Listen to sync status changes
//     _syncSubscription = _syncService.syncStatusStream.listen(
//       _onSyncStatusChanged,
//     );
//
//     // Check initial state
//     _checkInitialState();
//   }
//
//   void _checkInitialState() async {
//     emit(OfflineModeLoading());
//
//     try {
//       final isOnline = _connectivityService.isOnline;
//       if (isOnline) {
//         final hasPendingSync = await _hasPendingSyncData();
//         emit(OfflineModeOnline(hasPendingSync: hasPendingSync));
//       } else {
//         final offlineData = await _getOfflineDataCounts();
//         emit(OfflineModeOffline(
//           offlineTicketsCount: offlineData['tickets'] ?? 0,
//           pendingSyncCount: offlineData['pendingSync'] ?? 0,
//         ));
//       }
//     } catch (e) {
//       emit(OfflineModeError('Failed to check offline mode status: $e'));
//     }
//   }
//
//   void _onConnectivityChanged(bool isOnline) async {
//     try {
//       if (isOnline) {
//         final hasPendingSync = await _hasPendingSyncData();
//         emit(OfflineModeOnline(hasPendingSync: hasPendingSync));
//       } else {
//         final offlineData = await _getOfflineDataCounts();
//         emit(OfflineModeOffline(
//           offlineTicketsCount: offlineData['tickets'] ?? 0,
//           pendingSyncCount: offlineData['pendingSync'] ?? 0,
//         ));
//       }
//     } catch (e) {
//       emit(OfflineModeError('Failed to handle connectivity change: $e'));
//     }
//   }
//
//   void _onSyncStatusChanged(SyncStatus syncStatus) async {
//     final currentState = state;
//     if (currentState is OfflineModeOnline) {
//       final hasPendingSync = await _hasPendingSyncData();
//       emit(OfflineModeOnline(hasPendingSync: hasPendingSync));
//     }
//   }
//
//   /// Check if there's pending sync data
//   Future<bool> _hasPendingSyncData() async {
//     try {
//       await HiveDB.openHiveDB(HiveConstant.offlineTickets);
//       final box = HiveDB.getHiveBox(HiveConstant.offlineTickets);
//
//       for (final key in box.keys) {
//         final ticketData = box.get(key);
//         if (ticketData != null) {
//           final ticket = OfflineTicket.fromJson(Map<String, dynamic>.from(ticketData));
//           if (ticket.isPendingSync) {
//             return true;
//           }
//         }
//       }
//       return false;
//     } catch (e) {
//       print('OfflineModeCubit: Error checking pending sync data: $e');
//       return false;
//     }
//   }
//
//   /// Get offline data counts
//   Future<Map<String, int>> _getOfflineDataCounts() async {
//     try {
//       await HiveDB.openHiveDB(HiveConstant.offlineTickets);
//       final box = HiveDB.getHiveBox(HiveConstant.offlineTickets);
//
//       int ticketsCount = 0;
//       int pendingSyncCount = 0;
//
//       for (final key in box.keys) {
//         final ticketData = box.get(key);
//         if (ticketData != null) {
//           final ticket = OfflineTicket.fromJson(Map<String, dynamic>.from(ticketData));
//           ticketsCount++;
//           if (ticket.isPendingSync) {
//             pendingSyncCount++;
//           }
//         }
//       }
//
//       return {
//         'tickets': ticketsCount,
//         'pendingSync': pendingSyncCount,
//       };
//     } catch (e) {
//       print('OfflineModeCubit: Error getting offline data counts: $e');
//       return {'tickets': 0, 'pendingSync': 0};
//     }
//   }
//
//   /// Download ticket for offline use
//   Future<bool> downloadTicket({
//     required String ticketId,
//     required Map<String, dynamic> apiResponse,
//   }) async {
//     try {
//       emit(OfflineModeLoading());
//
//       // Extract ticket metadata from pageHeader
//       final pageHeader = apiResponse['pageHeader'] as List?;
//       final firstPageHeader = pageHeader?.isNotEmpty == true ? pageHeader!.first as Map<String, dynamic> : <String, dynamic>{};
//
//       // Create offline ticket with API response stored directly
//       final offlineTicket = OfflineTicket(
//         ticketId: ticketId,
//         siteAuditSchId: firstPageHeader['site_audit_sch_id']?.toString() ?? '',
//         siteId: firstPageHeader['site_id']?.toString() ?? '',
//         auditSchId: firstPageHeader['site_audit_sch_id']?.toString() ?? '',
//         activityType: 'AA', // Asset Audit
//         ticketType: 'OPEN', // Default ticket type
//         companyName: firstPageHeader['client_name'] ?? '',
//         siteName: firstPageHeader['site_name'] ?? '',
//         siteAddress: '', // Not available in pageHeader
//         scheduledDate: firstPageHeader['audit_due_dt'] ?? '',
//         dueDate: firstPageHeader['audit_due_dt'] ?? '',
//         status: firstPageHeader['status'] ?? 'OPEN',
//         priority: 'MEDIUM', // Default priority
//         isDownloaded: true,
//         isOfflineAvailable: true,
//         downloadedAt: DateTime.now(),
//         lastModified: DateTime.now(),
//         completeTicketData: apiResponse, // Store the original API response directly
//         isPendingSync: false,
//       );
//
//       // Debug: Log what we're storing
//       print('OfflineModeCubit: Storing API response with keys: ${apiResponse.keys.toList()}');
//       print('OfflineModeCubit: Has pageHeader: ${apiResponse.containsKey('pageHeader')}');
//       print('OfflineModeCubit: Has responseData: ${apiResponse.containsKey('responseData')}');
//
//       // Clear any existing offline data for this ticket first
//       await HiveDB.deleteOfflineTicket(firstPageHeader['site_audit_sch_id']?.toString() ?? '');
//
//       // Save to Hive
//       await HiveDB.saveOfflineTicket(offlineTicket);
//
//       // Update state
//       _checkInitialState();
//
//       return true;
//     } catch (e) {
//       emit(OfflineModeError('Failed to download ticket: $e'));
//       return false;
//     }
//   }
//
//   /// Save form data for offline use
//   Future<bool> saveFormData({
//     required String ticketId,
//     required String screenName,
//     required String itemType,
//     required Map<String, dynamic> formData,
//   }) async {
//     try {
//       // Get existing offline ticket
//       final offlineTicket = await HiveDB.getOfflineTicket(ticketId);
//       if (offlineTicket == null) {
//         emit(OfflineModeError('Ticket not found for offline use'));
//         return false;
//       }
//
//       // Create or update form data
//       final existingFormDataIndex = offlineTicket.formDataList
//           .indexWhere((fd) => fd.screenName == screenName);
//
//       final newFormData = OfflineFormData(
//         screenName: screenName,
//         itemType: itemType,
//         formData: formData,
//         lastModified: DateTime.now(),
//         isPendingSync: true,
//       );
//
//       List<OfflineFormData> updatedFormDataList;
//       if (existingFormDataIndex >= 0) {
//         updatedFormDataList = List.from(offlineTicket.formDataList);
//         updatedFormDataList[existingFormDataIndex] = newFormData;
//       } else {
//         updatedFormDataList = [...offlineTicket.formDataList, newFormData];
//       }
//
//       // Update ticket
//       final updatedTicket = offlineTicket.copyWith(
//         formDataList: updatedFormDataList,
//         lastModified: DateTime.now(),
//         isPendingSync: true,
//       );
//
//       // Save to Hive
//       await HiveDB.saveOfflineTicket(updatedTicket);
//
//       // Update state
//       _checkInitialState();
//
//       return true;
//     } catch (e) {
//       emit(OfflineModeError('Failed to save form data: $e'));
//       return false;
//     }
//   }
//
//   /// Save photo for offline use
//   Future<bool> savePhoto({
//     required String ticketId,
//     required String photoId,
//     required String photoPath,
//     required String screenName,
//     required String itemType,
//     String? base64Data,
//   }) async {
//     try {
//       // Get existing offline ticket
//       final offlineTicket = await HiveDB.getOfflineTicket(ticketId);
//       if (offlineTicket == null) {
//         emit(OfflineModeError('Ticket not found for offline use'));
//         return false;
//       }
//
//       // Create new photo
//       final newPhoto = OfflinePhoto(
//         photoId: photoId,
//         photoPath: photoPath,
//         base64Data: base64Data,
//         screenName: screenName,
//         itemType: itemType,
//         takenAt: DateTime.now(),
//         isPendingSync: true,
//       );
//
//       // Update ticket
//       final updatedPhotos = [...offlineTicket.photos, newPhoto];
//       final updatedTicket = offlineTicket.copyWith(
//         photos: updatedPhotos,
//         lastModified: DateTime.now(),
//         isPendingSync: true,
//       );
//
//       // Save to Hive
//       await HiveDB.saveOfflineTicket(updatedTicket);
//
//       // Update state
//       _checkInitialState();
//
//       return true;
//     } catch (e) {
//       emit(OfflineModeError('Failed to save photo: $e'));
//       return false;
//     }
//   }
//
//   /// Save remark for offline use
//   Future<bool> saveRemark({
//     required String ticketId,
//     required String remarkId,
//     required String screenName,
//     required String itemType,
//     required String remarkText,
//     String? assetAuditSiteRespId,
//   }) async {
//     try {
//       // Get existing offline ticket
//       final offlineTicket = await HiveDB.getOfflineTicket(ticketId);
//       if (offlineTicket == null) {
//         emit(OfflineModeError('Ticket not found for offline use'));
//         return false;
//       }
//
//       // Create new remark
//       final newRemark = OfflineRemark(
//         remarkId: remarkId,
//         screenName: screenName,
//         itemType: itemType,
//         remarkText: remarkText,
//         createdAt: DateTime.now(),
//         isPendingSync: true,
//         assetAuditSiteRespId: assetAuditSiteRespId,
//       );
//
//       // Update ticket
//       final updatedRemarks = [...offlineTicket.remarks, newRemark];
//       final updatedTicket = offlineTicket.copyWith(
//         remarks: updatedRemarks,
//         lastModified: DateTime.now(),
//         isPendingSync: true,
//       );
//
//       // Save to Hive
//       await HiveDB.saveOfflineTicket(updatedTicket);
//
//       // Update state
//       _checkInitialState();
//
//       return true;
//     } catch (e) {
//       emit(OfflineModeError('Failed to save remark: $e'));
//       return false;
//     }
//   }
//
//   /// Get offline ticket data
//   Future<OfflineTicket?> getOfflineTicket(String ticketId) async {
//     try {
//       return await HiveDB.getOfflineTicket(ticketId);
//     } catch (e) {
//       emit(OfflineModeError('Failed to get offline ticket: $e'));
//       return null;
//     }
//   }
//
//   /// Check if ticket is available offline
//   Future<bool> isTicketAvailableOffline(String ticketId) async {
//     try {
//       final ticket = await HiveDB.getOfflineTicket(ticketId);
//       return ticket?.isOfflineAvailable ?? false;
//     } catch (e) {
//       return false;
//     }
//   }
//
//   /// Force sync pending data
//   Future<void> forceSync() async {
//     try {
//       await _syncService.forceSync();
//       _checkInitialState();
//     } catch (e) {
//       emit(OfflineModeError('Failed to sync data: $e'));
//     }
//   }
//
//   /// Refresh offline mode status
//   Future<void> refresh() async {
//     _checkInitialState();
//   }
//
//   @override
//   Future<void> close() {
//     _connectivitySubscription?.cancel();
//     _syncSubscription?.cancel();
//     return super.close();
//   }
// }
