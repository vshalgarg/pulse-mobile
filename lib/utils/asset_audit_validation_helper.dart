import '../../../models/asset_audit_model.dart';

class AssetAuditValidationHelper {
  /// Validates QR code scanned serial number against nexgen_serial_no
  /// Returns the matching asset item if found, null otherwise
  static AssetItem? validateQRCodeSerialNumber(
    String scannedSerialNumber,
    CategoryData? categoryData,
  ) {
    if (categoryData == null) return null;
    
    // Check in main assets
    for (var item in categoryData.assets) {
      if (item.nexgenSerialNo?.toLowerCase() == scannedSerialNumber.toLowerCase()) {
        return item;
      }
    }
    
    // Check in subcategories
    if (categoryData.subCategories != null) {
      for (var subCategory in categoryData.subCategories!.values) {
        for (var item in subCategory) {
          if (item.nexgenSerialNo?.toLowerCase() == scannedSerialNumber.toLowerCase()) {
            return item;
          }
        }
      }
    }
    
    return null;
  }
  
  /// Validates manually entered serial number against mfg_serial_no
  /// Returns the matching asset item if found, null otherwise
  static AssetItem? validateManualSerialNumber(
    String enteredSerialNumber,
    CategoryData? categoryData,
  ) {
    if (categoryData == null) return null;
    
    // Check in main assets
    for (var item in categoryData.assets) {
      if (item.mfgSerialNo?.toLowerCase() == enteredSerialNumber.toLowerCase()) {
        return item;
      }
    }
    
    // Check in subcategories
    if (categoryData.subCategories != null) {
      for (var subCategory in categoryData.subCategories!.values) {
        for (var item in subCategory) {
          if (item.mfgSerialNo?.toLowerCase() == enteredSerialNumber.toLowerCase()) {
            return item;
          }
        }
      }
    }
    
    return null;
  }
  
  /// Gets all available serial numbers for a category (for debugging)
  static List<String> getAllSerialNumbers(CategoryData? categoryData) {
    List<String> serialNumbers = [];
    
    if (categoryData == null) return serialNumbers;
    
    // Get from main assets
    for (var item in categoryData.assets) {
      if (item.nexgenSerialNo != null) {
        serialNumbers.add('NexGen: ${item.nexgenSerialNo}');
      }
      if (item.mfgSerialNo != null) {
        serialNumbers.add('MFG: ${item.mfgSerialNo}');
      }
    }
    
    // Get from subcategories
    if (categoryData.subCategories != null) {
      for (var subCategory in categoryData.subCategories!.values) {
        for (var item in subCategory) {
          if (item.nexgenSerialNo != null) {
            serialNumbers.add('NexGen: ${item.nexgenSerialNo}');
          }
          if (item.mfgSerialNo != null) {
            serialNumbers.add('MFG: ${item.mfgSerialNo}');
          }
        }
      }
    }
    
    return serialNumbers;
  }
}
