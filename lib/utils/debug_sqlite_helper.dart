import 'package:app/database/asset_audit_database.dart';
import 'package:app/utils/logger.dart';

class DebugSQLiteHelper {
  static final AssetAuditDatabase _database = AssetAuditDatabase();

  /// Print all data in SQLite database for debugging
  static Future<void> printAllData() async {
    Logger.debugLog('=== DEBUG: SQLite Database Contents ===');
    
    try {
      final db = await _database.database;
      
      // Check page headers
      final pageHeaders = await db.query('page_headers');
      Logger.debugLog('📄 Page Headers (${pageHeaders.length}):');
      for (final header in pageHeaders) {
        Logger.debugLog('  - Site ID: ${header['site_audit_sch_id']}, Site Name: ${header['site_name']}, Selfie ID: ${header['maker_selfie_image_id']}');
      }
      
      // Check asset items
      final assetItems = await db.query('asset_items');
      Logger.debugLog('🔧 Asset Items (${assetItems.length}):');
      for (final item in assetItems.take(5)) { // Show first 5
        Logger.debugLog('  - Asset ID: ${item['asset_audit_site_resp_id']}, Category: ${item['category_name']}, Photo ID: ${item['photo_id']}');
      }
      
      // Check categories
      final categories = await db.query('categories');
      Logger.debugLog('📁 Categories (${categories.length}):');
      for (final category in categories) {
        Logger.debugLog('  - Site ID: ${category['site_audit_sch_id']}, Category: ${category['category_name']}, Subcategory: ${category['subcategory_name']}');
      }
      
      // Check cached images
      final cachedImages = await db.query('cached_images');
      Logger.debugLog('🖼️ Cached Images (${cachedImages.length}):');
      for (final image in cachedImages) {
        Logger.debugLog('  - Image ID: ${image['image_id']}, Data Length: ${(image['image_data'] as String?)?.length ?? 0}');
      }
      
      // Check form data
      final formData = await db.query('form_data');
      Logger.debugLog('📝 Form Data (${formData.length}):');
      for (final form in formData) {
        Logger.debugLog('  - Site ID: ${form['site_audit_sch_id']}, Screen: ${form['screen_name']}, Data Length: ${(form['form_data_json'] as String?)?.length ?? 0}');
      }
      
    } catch (e) {
      Logger.errorLog('❌ Error reading database: $e');
    }
  }

  /// Check specific site data
  static Future<void> printSiteData(int siteAuditSchId) async {
    Logger.debugLog('=== DEBUG: Site Data for ID $siteAuditSchId ===');
    
    try {
      final db = await _database.database;
      
      // Check page header for this site
      final pageHeaders = await db.query(
        'page_headers',
        where: 'site_audit_sch_id = ?',
        whereArgs: [siteAuditSchId],
      );
      
      if (pageHeaders.isNotEmpty) {
        final header = pageHeaders.first;
        Logger.debugLog('✅ Page Header Found:');
        Logger.debugLog('  - Site Name: ${header['site_name']}');
        Logger.debugLog('  - Site Code: ${header['site_code']}');
        Logger.debugLog('  - Client Name: ${header['client_name']}');
        Logger.debugLog('  - Selfie Image ID: ${header['maker_selfie_image_id']}');
        Logger.debugLog('  - Created: ${DateTime.fromMillisecondsSinceEpoch(header['created_at'] as int)}');
      } else {
        Logger.debugLog('❌ No page header found for site $siteAuditSchId');
      }
      
      // Check asset items for this site
      final assetItems = await db.query(
        'asset_items',
        where: 'site_audit_sch_id = ?',
        whereArgs: [siteAuditSchId],
      );
      Logger.debugLog('🔧 Asset Items for this site: ${assetItems.length}');
      
      // Check categories for this site
      final categories = await db.query(
        'categories',
        where: 'site_audit_sch_id = ?',
        whereArgs: [siteAuditSchId],
      );
      Logger.debugLog('📁 Categories for this site: ${categories.length}');
      
      // Check form data for this site
      final formData = await db.query(
        'form_data',
        where: 'site_audit_sch_id = ?',
        whereArgs: [siteAuditSchId],
      );
      Logger.debugLog('📝 Form Data for this site: ${formData.length}');
      
    } catch (e) {
      Logger.errorLog('❌ Error reading site data: $e');
    }
  }

  /// Check if AssetAuditModel can be reconstructed from database
  static Future<void> testAssetAuditModelReconstruction(int siteAuditSchId) async {
    Logger.debugLog('=== DEBUG: Testing AssetAuditModel Reconstruction for Site $siteAuditSchId ===');
    
    try {
      final assetAuditData = await _database.getAssetAuditData(siteAuditSchId);
      
      if (assetAuditData != null) {
        Logger.debugLog('✅ AssetAuditModel successfully reconstructed:');
        Logger.debugLog('  - Page Headers: ${assetAuditData.pageHeader.length}');
        Logger.debugLog('  - Categories: ${assetAuditData.responseData.categories.length}');
        
        if (assetAuditData.pageHeader.isNotEmpty) {
          final pageHeader = assetAuditData.pageHeader.first;
          Logger.debugLog('  - Site Name: ${pageHeader.siteName}');
          Logger.debugLog('  - Selfie Image ID: ${pageHeader.makerSelfieImageId}');
        }
        
        // Check categories
        for (final entry in assetAuditData.responseData.categories.entries) {
          Logger.debugLog('  - Category: ${entry.key}, Assets: ${entry.value.assets.length}');
        }
      } else {
        Logger.debugLog('❌ Failed to reconstruct AssetAuditModel for site $siteAuditSchId');
      }
    } catch (e) {
      Logger.errorLog('❌ Error reconstructing AssetAuditModel: $e');
    }
  }

  /// Clear all data for debugging
  static Future<void> clearAllData() async {
    Logger.debugLog('=== DEBUG: Clearing all SQLite data ===');
    try {
      await _database.clearAllData();
      Logger.debugLog('✅ All data cleared successfully');
    } catch (e) {
      Logger.errorLog('❌ Error clearing data: $e');
    }
  }

  /// Clear specific site data
  static Future<void> clearSiteData(int siteAuditSchId) async {
    Logger.debugLog('=== DEBUG: Clearing data for site $siteAuditSchId ===');
    try {
      await _database.clearAssetAuditData(siteAuditSchId);
      Logger.debugLog('✅ Site data cleared successfully');
    } catch (e) {
      Logger.errorLog('❌ Error clearing site data: $e');
    }
  }
}
