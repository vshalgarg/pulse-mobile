import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/asset_audit_model.dart';
import '../utils/logger.dart';

class AssetAuditDatabase {
  static final AssetAuditDatabase _instance = AssetAuditDatabase._internal();
  factory AssetAuditDatabase() => _instance;
  AssetAuditDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'asset_audit.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Page Header table
    await db.execute('''
      CREATE TABLE page_headers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_audit_sch_id INTEGER UNIQUE NOT NULL,
        circle TEXT,
        cluster TEXT,
        indoor_outdoor TEXT,
        eb_non_eb TEXT,
        op1_name TEXT,
        op2_name TEXT,
        site_id INTEGER,
        solar_state TEXT,
        solar_district TEXT,
        audit_due_dt TEXT,
        site_domain_name TEXT,
        status TEXT,
        district TEXT,
        client_name TEXT NOT NULL,
        site_code TEXT NOT NULL,
        site_name TEXT NOT NULL,
        site_type_name TEXT NOT NULL,
        maker_selfie_image_id INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Asset Items table
    await db.execute('''
      CREATE TABLE asset_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_audit_site_resp_id INTEGER NOT NULL,
        site_audit_sch_id INTEGER NOT NULL,
        item_instance_id INTEGER,
        item_type TEXT,
        oem_name TEXT,
        nexgen_serial_no TEXT,
        mfg_serial_no TEXT,
        qr_code_scanned INTEGER,
        qr_code_scanned_ts TEXT,
        photo_id INTEGER,
        image_name TEXT,
        longitude TEXT,
        latitude TEXT,
        asset_status TEXT,
        capacity TEXT,
        item_type_group TEXT,
        record_type TEXT,
        item_type_remark TEXT,
        category_name TEXT NOT NULL,
        subcategory_name TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_audit_sch_id INTEGER NOT NULL,
        category_name TEXT NOT NULL,
        subcategory_name TEXT,
        data_type TEXT NOT NULL,
        data_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(site_audit_sch_id, category_name, subcategory_name)
      )
    ''');

    // Cached Images table
    await db.execute('''
      CREATE TABLE cached_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_id INTEGER UNIQUE NOT NULL,
        image_data TEXT NOT NULL,
        image_type TEXT,
        site_audit_sch_id INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Form Data table for screen-specific data
    await db.execute('''
      CREATE TABLE form_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        site_audit_sch_id INTEGER NOT NULL,
        screen_name TEXT NOT NULL,
        form_data_json TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(site_audit_sch_id, screen_name)
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_page_headers_site_audit_sch_id ON page_headers(site_audit_sch_id)');
    await db.execute('CREATE INDEX idx_asset_items_site_audit_sch_id ON asset_items(site_audit_sch_id)');
    await db.execute('CREATE INDEX idx_categories_site_audit_sch_id ON categories(site_audit_sch_id)');
    await db.execute('CREATE INDEX idx_cached_images_image_id ON cached_images(image_id)');
    await db.execute('CREATE INDEX idx_form_data_site_audit_sch_id ON form_data(site_audit_sch_id)');
  }

  // Page Header operations
  Future<void> insertPageHeader(PageHeader pageHeader) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert(
      'page_headers',
      {
        'site_audit_sch_id': pageHeader.siteAuditSchId,
        'circle': pageHeader.circle,
        'cluster': pageHeader.cluster,
        'indoor_outdoor': pageHeader.indoorOutdoor,
        'eb_non_eb': pageHeader.ebNonEb,
        'op1_name': pageHeader.op1Name,
        'op2_name': pageHeader.op2Name,
        'site_id': pageHeader.siteId,
        'solar_state': pageHeader.solarState,
        'solar_district': pageHeader.solarDistrict,
        'audit_due_dt': pageHeader.auditDueDt,
        'site_domain_name': pageHeader.siteDomainName,
        'status': pageHeader.status,
        'district': pageHeader.district,
        'client_name': pageHeader.clientName,
        'site_code': pageHeader.siteCode,
        'site_name': pageHeader.siteName,
        'site_type_name': pageHeader.siteTypeName,
        'maker_selfie_image_id': pageHeader.makerSelfieImageId,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<PageHeader?> getPageHeader(int siteAuditSchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'page_headers',
      where: 'site_audit_sch_id = ?',
      whereArgs: [siteAuditSchId],
    );

    if (maps.isNotEmpty) {
      return PageHeader.fromJson(maps.first);
    }
    return null;
  }

  // Asset Items operations
  Future<void> insertAssetItems(List<AssetItem> assetItems, String categoryName, {String? subcategoryName}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final batch = db.batch();
    
    for (final item in assetItems) {
      batch.insert(
        'asset_items',
        {
          'asset_audit_site_resp_id': item.assetAuditSiteRespId,
          'site_audit_sch_id': item.siteAuditSchId,
          'item_instance_id': item.itemInstanceId,
          'item_type': item.itemType,
          'oem_name': item.oemName,
          'nexgen_serial_no': item.nexgenSerialNo,
          'mfg_serial_no': item.mfgSerialNo,
          'qr_code_scanned': item.qrCodeScanned == true ? 1 : 0,
          'qr_code_scanned_ts': item.qrCodeScannedTs,
          'photo_id': item.photoId,
          'image_name': item.imageName,
          'longitude': item.longitude,
          'latitude': item.latitude,
          'asset_status': item.assetStatus,
          'capacity': item.capacity,
          'item_type_group': item.itemTypeGroup,
          'record_type': item.recordType,
          'item_type_remark': item.itemTypeRemark,
          'category_name': categoryName,
          'subcategory_name': subcategoryName,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
  }

  Future<List<AssetItem>> getAssetItems(int siteAuditSchId, {String? categoryName, String? subcategoryName}) async {
    final db = await database;
    String whereClause = 'site_audit_sch_id = ?';
    List<dynamic> whereArgs = [siteAuditSchId];
    
    if (categoryName != null) {
      whereClause += ' AND category_name = ?';
      whereArgs.add(categoryName);
    }
    
    if (subcategoryName != null) {
      whereClause += ' AND subcategory_name = ?';
      whereArgs.add(subcategoryName);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'asset_items',
      where: whereClause,
      whereArgs: whereArgs,
    );

    return maps.map((map) => AssetItem.fromJson(map)).toList();
  }

  // Categories operations
  Future<void> insertCategoryData(int siteAuditSchId, String categoryName, Map<String, dynamic> data, {String? subcategoryName}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert(
      'categories',
      {
        'site_audit_sch_id': siteAuditSchId,
        'category_name': categoryName,
        'subcategory_name': subcategoryName,
        'data_type': 'json',
        'data_json': json.encode(data),
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCategoryData(int siteAuditSchId, String categoryName, {String? subcategoryName}) async {
    final db = await database;
    String whereClause = 'site_audit_sch_id = ? AND category_name = ?';
    List<dynamic> whereArgs = [siteAuditSchId, categoryName];
    
    if (subcategoryName != null) {
      whereClause += ' AND subcategory_name = ?';
      whereArgs.add(subcategoryName);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: whereClause,
      whereArgs: whereArgs,
    );

    if (maps.isNotEmpty) {
      return json.decode(maps.first['data_json']);
    }
    return null;
  }

  // Cached Images operations
  Future<void> insertCachedImage(int imageId, String imageData, {String? imageType, int? siteAuditSchId}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert(
      'cached_images',
      {
        'image_id': imageId,
        'image_data': imageData,
        'image_type': imageType,
        'site_audit_sch_id': siteAuditSchId,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getCachedImage(int imageId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cached_images',
      where: 'image_id = ?',
      whereArgs: [imageId],
    );

    if (maps.isNotEmpty) {
      return maps.first['image_data'] as String;
    }
    return null;
  }

  Future<bool> isImageCached(int imageId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cached_images',
      where: 'image_id = ?',
      whereArgs: [imageId],
      limit: 1,
    );

    return maps.isNotEmpty;
  }

  Future<List<int>> getCachedImageIds(int siteAuditSchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'cached_images',
      columns: ['image_id'],
      where: 'site_audit_sch_id = ?',
      whereArgs: [siteAuditSchId],
    );

    return maps.map((map) => map['image_id'] as int).toList();
  }

  // Form Data operations
  Future<void> saveFormData(int siteAuditSchId, String screenName, Map<String, dynamic> formData) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.insert(
      'form_data',
      {
        'site_audit_sch_id': siteAuditSchId,
        'screen_name': screenName,
        'form_data_json': json.encode(formData),
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getFormData(int siteAuditSchId, String screenName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'form_data',
      where: 'site_audit_sch_id = ? AND screen_name = ?',
      whereArgs: [siteAuditSchId, screenName],
    );

    if (maps.isNotEmpty) {
      return json.decode(maps.first['form_data_json']);
    }
    return null;
  }

  // Complete Asset Audit Data operations
  Future<void> saveAssetAuditData(AssetAuditModel assetAuditData) async {
    try {
      final db = await database;
      final siteAuditSchId = assetAuditData.pageHeader.first.siteAuditSchId;
      
      Logger.debugLog('💾 Starting to save asset audit data for site $siteAuditSchId');
      
      // Use transaction for atomicity
      await db.transaction((txn) async {
        Logger.debugLog('🔄 Transaction started for site $siteAuditSchId');
        
        // Clear existing data for this site first
        await txn.delete('page_headers', where: 'site_audit_sch_id = ?', whereArgs: [siteAuditSchId]);
        await txn.delete('asset_items', where: 'site_audit_sch_id = ?', whereArgs: [siteAuditSchId]);
        await txn.delete('categories', where: 'site_audit_sch_id = ?', whereArgs: [siteAuditSchId]);
        
        Logger.debugLog('🗑️ Cleared existing data for site $siteAuditSchId');
        
        // Save page header directly in transaction
        if (assetAuditData.pageHeader.isNotEmpty) {
          final pageHeader = assetAuditData.pageHeader.first;
          await txn.insert('page_headers', pageHeader.toJson());
          Logger.debugLog('📄 Inserted page header');
        }
        
        // Save categories and their data directly in transaction
        for (final entry in assetAuditData.responseData.categories.entries) {
          final categoryName = entry.key;
          final categoryData = entry.value;
          
          // Save main category data directly
          final now = DateTime.now().millisecondsSinceEpoch;
          await txn.insert(
            'categories',
            {
              'site_audit_sch_id': siteAuditSchId,
              'category_name': categoryName,
              'subcategory_name': null,
              'data_type': 'json',
              'data_json': json.encode(categoryData.toJson()),
              'created_at': now,
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          
          // Save assets directly
          if (categoryData.assets.isNotEmpty) {
            for (final asset in categoryData.assets) {
              await txn.insert('asset_items', {
                'site_audit_sch_id': siteAuditSchId,
                'asset_audit_site_resp_id': asset.assetAuditSiteRespId,
                'asset_name': asset.itemType ?? 'Unknown',
                'category_name': categoryName,
                'subcategory_name': null,
                'asset_data': json.encode(asset.toJson()),
                'created_at': now,
                'updated_at': now,
              });
            }
            Logger.debugLog('🔧 Inserted ${categoryData.assets.length} assets for category $categoryName');
          }
          
          // Save subcategories directly
          if (categoryData.subCategories != null) {
            for (final subEntry in categoryData.subCategories!.entries) {
              final subcategoryName = subEntry.key;
              final subcategoryItems = subEntry.value;
              
              // Save subcategory data
              await txn.insert(
                'categories',
                {
                  'site_audit_sch_id': siteAuditSchId,
                  'category_name': categoryName,
                  'subcategory_name': subcategoryName,
                  'data_type': 'json',
                  'data_json': json.encode({'items': subcategoryItems.map((item) => item.toJson()).toList()}),
                  'created_at': now,
                  'updated_at': now,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              
              // Save subcategory assets
              for (final asset in subcategoryItems) {
                await txn.insert('asset_items', {
                  'site_audit_sch_id': siteAuditSchId,
                  'asset_audit_site_resp_id': asset.assetAuditSiteRespId,
                  'asset_name': asset.itemType ?? 'Unknown',
                  'category_name': categoryName,
                  'subcategory_name': subcategoryName,
                  'asset_data': json.encode(asset.toJson()),
                  'created_at': now,
                  'updated_at': now,
                });
              }
              Logger.debugLog('🔧 Inserted ${subcategoryItems.length} assets for subcategory $subcategoryName');
            }
          }
        }
        
        Logger.debugLog('✅ Transaction completed for site $siteAuditSchId');
      });
      
      Logger.debugLog('✅ Asset audit data saved to SQLite successfully for site $siteAuditSchId');
    } catch (e) {
      Logger.errorLog('❌ Error saving asset audit data to SQLite: $e');
      rethrow;
    }
  }

  Future<AssetAuditModel?> getAssetAuditData(int siteAuditSchId) async {
    final pageHeader = await getPageHeader(siteAuditSchId);
    if (pageHeader == null) return null;
    
    // Get all categories for this site
    final db = await database;
    final List<Map<String, dynamic>> categoryMaps = await db.query(
      'categories',
      where: 'site_audit_sch_id = ? AND subcategory_name IS NULL',
      whereArgs: [siteAuditSchId],
    );
    
    Map<String, CategoryData> categories = {};
    
    for (final categoryMap in categoryMaps) {
      final categoryName = categoryMap['category_name'] as String;
      final dataJson = categoryMap['data_json'] as String;
      final data = json.decode(dataJson);
      
      // Get assets for this category
      final assets = await getAssetItems(siteAuditSchId, categoryName: categoryName);
      
      // Get subcategories for this category
      final List<Map<String, dynamic>> subcategoryMaps = await db.query(
        'categories',
        where: 'site_audit_sch_id = ? AND category_name = ? AND subcategory_name IS NOT NULL',
        whereArgs: [siteAuditSchId, categoryName],
      );
      
      Map<String, List<AssetItem>>? subCategories;
      if (subcategoryMaps.isNotEmpty) {
        subCategories = {};
        for (final subMap in subcategoryMaps) {
          final subcategoryName = subMap['subcategory_name'] as String;
          final subcategoryItems = await getAssetItems(
            siteAuditSchId,
            categoryName: categoryName,
            subcategoryName: subcategoryName,
          );
          subCategories[subcategoryName] = subcategoryItems;
        }
      }
      
      categories[categoryName] = CategoryData(
        assets: assets,
        remarks: [], // TODO: Implement remarks if needed
        subCategories: subCategories,
      );
    }
    
    return AssetAuditModel(
      pageHeader: [pageHeader],
      responseData: ResponseData(categories: categories),
    );
  }

  // Clear data for a specific site
  Future<void> clearAssetAuditData(int siteAuditSchId) async {
    final db = await database;
    
    await db.transaction((txn) async {
      await txn.delete('page_headers', where: 'site_audit_sch_id = ?', whereArgs: [siteAuditSchId]);
      await txn.delete('asset_items', where: 'site_audit_sch_id = ?', whereArgs: [siteAuditSchId]);
      await txn.delete('categories', where: 'site_audit_sch_id = ?', whereArgs: [siteAuditSchId]);
      await txn.delete('form_data', where: 'site_audit_sch_id = ?', whereArgs: [siteAuditSchId]);
    });
  }

  // Clear all data
  Future<void> clearAllData() async {
    final db = await database;
    
    await db.transaction((txn) async {
      await txn.delete('page_headers');
      await txn.delete('asset_items');
      await txn.delete('categories');
      await txn.delete('cached_images');
      await txn.delete('form_data');
    });
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
