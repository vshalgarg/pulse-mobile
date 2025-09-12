/// Photo ID Adapter - Bridges offline String photo IDs with API int photo IDs
/// This allows the existing API-compatible code to work unchanged
class PhotoIdAdapter {
  /// Convert any photo ID to String for internal storage
  static String? toInternalString(dynamic photoId) {
    if (photoId == null) return null;
    if (photoId is String) return photoId;
    if (photoId is int) return photoId.toString();
    return photoId.toString();
  }

  /// Convert any photo ID to int for API compatibility
  static int? toApiInt(dynamic photoId) {
    if (photoId == null) return null;
    if (photoId is int) return photoId;
    if (photoId is String) {
      // Check if it's a local photo ID
      if (photoId.startsWith('local_')) {
        return 0; // Use 0 for local photos during sync
      }
      return int.tryParse(photoId);
    }
    return null;
  }

  /// Check if a photo ID is from local storage
  static bool isLocalPhotoId(dynamic photoId) {
    if (photoId == null) return false;
    return photoId.toString().startsWith('local_');
  }

  /// Get display string for photo ID (for debugging)
  static String getDisplayString(dynamic photoId) {
    if (photoId == null) return 'null';
    if (isLocalPhotoId(photoId)) return 'local_photo';
    return photoId.toString();
  }
}
