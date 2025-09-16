import '../services/local_storage_db.dart';
import '../models/asset_audit_model.dart';

class OfflineDataHelper {
  /// Get offline AssetAuditModel data for a specific ticket
  static AssetAuditModel? getOfflineAssetAuditData(String siteAuditSchId) {
    try {
      final offlineTicket = LocalStorageDB.getOfflineTicket(siteAuditSchId);
      if (offlineTicket == null) return null;

      final completeTicketData = offlineTicket['completeTicketData'] as Map<String, dynamic>?;
      if (completeTicketData != null) {
        return AssetAuditModel.fromJson(completeTicketData);
      }
      return null;
    } catch (e) {
      print('OfflineDataHelper: Error getting offline asset audit data: $e');
      return null;
    }
  }

  /// Check if offline data exists for a specific ticket
  static bool hasOfflineData(String siteAuditSchId) {
    try {
      final offlineTicket = LocalStorageDB.getOfflineTicket(siteAuditSchId);
      return offlineTicket != null;
    } catch (e) {
      print('OfflineDataHelper: Error checking for offline data: $e');
      return false;
    }
  }
}
