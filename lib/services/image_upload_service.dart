import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/utils.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';
import '../utils/logger.dart';

class ImageUploadService {
  static Database? _database;
  static const String _tableName = 'images';
  static const String _databaseName = 'image_upload.db';
  static const int _databaseVersion = 2;
  
  final ApiService _apiService;
  final Uuid _uuid = const Uuid();

  ImageUploadService({required ApiService apiService}) : _apiService = apiService;

  /// Initialize the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);
      
      Logger.debugLog('🗄️ Initializing ImageUploadService database at: $path');
      
      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      Logger.errorLog('❌ Error initializing ImageUploadService database: $e');
      rethrow;
    }
  }

  /// Create the images table
  Future<void> _onCreate(Database db, int version) async {
    try {
      await db.execute('''
        CREATE TABLE $_tableName (
          unique_id TEXT PRIMARY KEY,
          server_id TEXT,
          image_data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      
      // Create index for server_id for faster lookups
      await db.execute('''
        CREATE INDEX idx_server_id ON $_tableName(server_id)
      ''');
      
      Logger.debugLog('✅ Images table created successfully');
    } catch (e) {
      Logger.errorLog('❌ Error creating images table: $e');
      rethrow;
    }
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.debugLog('🔄 Database upgrade from version $oldVersion to $newVersion');
    
    if (oldVersion < 2) {
      // Migrate from image_bytes BLOB to image_data TEXT
      Logger.debugLog('🔄 Migrating image_bytes column to image_data');
      
      // Create new table with TEXT column
      await db.execute('''
        CREATE TABLE ${_tableName}_new (
          unique_id TEXT PRIMARY KEY,
          server_id TEXT,
          image_data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      
      // Copy data from old table to new table
      await db.execute('''
        INSERT INTO ${_tableName}_new (unique_id, server_id, image_data, created_at, updated_at)
        SELECT unique_id, server_id, 
               CASE 
                 WHEN image_bytes IS NOT NULL THEN 'MIGRATED_BLOB_DATA'
                 ELSE 'NO_DATA'
               END as image_data,
               created_at, updated_at
        FROM $_tableName
      ''');
      
      // Drop old table
      await db.execute('DROP TABLE $_tableName');
      
      // Rename new table
      await db.execute('ALTER TABLE ${_tableName}_new RENAME TO $_tableName');
      
      // Recreate index
      await db.execute('''
        CREATE INDEX idx_server_id ON $_tableName(server_id)
      ''');
      
      Logger.debugLog('✅ Database migration completed');
    }
  }

  /// Generate a unique ID for local images
  String _generateUniqueId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _uuid.v4().substring(0, 8);
    return 'LOCAL_IMAGE_ID_${timestamp}_$random';
  }

  /// 1. Upload image - Save to SQLite and try to upload to server
  ///
  Future<String> uploadImage(String imageData, ActivityTypeEnum activityType, String siteSchId) async {
    try {
      final uniqueId = _generateUniqueId();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      Logger.debugLog('📤 Uploading image with unique ID: $uniqueId');
      Logger.debugLog('📤 Image data size: ${imageData.length} bytes');
      
      // Save image to SQLite first
      await _saveImageToSQLite(
        uniqueId: uniqueId,
        imageData: imageData,
        serverId: null,
        createdAt: now,
        updatedAt: now,
      );
      
      Logger.debugLog('✅ Image saved to SQLite with ID: $uniqueId');
      
      // Try to upload to server
      try {
        final serverId = await _uploadToServer(imageData, ActivityTypeEnum.assetAudit, siteSchId, false);
        if (serverId != null) {
          // Update server_id in SQLite
          await _updateServerId(uniqueId, serverId);
          Logger.debugLog('✅ Image uploaded to server with ID: $serverId');
        } else {
          Logger.debugLog('⚠️ Server upload failed, but image saved locally with ID: $uniqueId');
        }
      } catch (e) {
        Logger.errorLog('❌ Server upload failed: $e');
        Logger.debugLog('⚠️ Image saved locally with ID: $uniqueId');
      }
      
      return uniqueId;
    } catch (e) {
      Logger.errorLog('❌ Error in uploadImage: $e');
      rethrow;
    }
  }

  /// 1. Upload image - Save to SQLite and try to upload to server
  ///
  Future<String> uploadSelfie(String imageData, ActivityTypeEnum activityType, String siteSchId) async {
    try {
      final uniqueId = _generateUniqueId();
      final now = DateTime.now().millisecondsSinceEpoch;

      Logger.debugLog('📤 Uploading image with unique ID: $uniqueId');
      Logger.debugLog('📤 Image data size: ${imageData.length} bytes');

      // Save image to SQLite first
      await _saveImageToSQLite(
        uniqueId: uniqueId,
        imageData: imageData,
        serverId: null,
        createdAt: now,
        updatedAt: now,
      );

      Logger.debugLog('✅ Image saved to SQLite with ID: $uniqueId');

      // Try to upload to server
      try {
        final serverId = await _uploadToServer(imageData, ActivityTypeEnum.assetAudit, siteSchId, true);
        if (serverId != null) {
          // Update server_id in SQLite
          await _updateServerId(uniqueId, serverId);
          Logger.debugLog('✅ Image uploaded to server with ID: $serverId');
        } else {
          Logger.debugLog('⚠️ Server upload failed, but image saved locally with ID: $uniqueId');
        }
      } catch (e) {
        Logger.errorLog('❌ Server upload failed: $e');
        Logger.debugLog('⚠️ Image saved locally with ID: $uniqueId');
      }

      return uniqueId;
    } catch (e) {
      Logger.errorLog('❌ Error in uploadImage: $e');
      rethrow;
    }
  }

  /// 2. Get server ID - Check SQLite first, upload if needed
  Future<List<String>> getServerIdAndCreatedTime(String uniqueId, ActivityTypeEnum activityType, String siteSchId) async {
    try {
      Logger.debugLog('🔍 Getting server ID for unique ID: $uniqueId');
      List<String> response = [];
      // Check if server_id exists in SQLite
      final serverIdWithCreatedTime = await _getServerIdFromSQLite(uniqueId);
      if (serverIdWithCreatedTime.isNotEmpty) {
        return serverIdWithCreatedTime;
      }
      
      // Server ID not found, need to upload
      Logger.debugLog('🌐 Server ID not found in SQLite, uploading image to server');
      Logger.debugLog('🌐 Uploading for uniqueId: $uniqueId, activityType: ${activityType.value}, siteSchId: $siteSchId');
      
      // Get image data from SQLite
      final imageData = await _getImageDataFromSQLite(uniqueId);
      if (imageData == null) {
        Logger.errorLog('❌ Image data not found for unique ID: $uniqueId');
        return [];
      }
      
      Logger.debugLog('📸 Image data found, size: ${imageData.length} characters');
      
      // Upload to server
      final newServerId = await _uploadToServer(imageData, activityType, siteSchId, false);
      if (newServerId != null) {
        Logger.debugLog('✅ Upload successful, got server ID: $newServerId');
        
        // Update server_id in SQLite
        await _updateServerId(uniqueId, newServerId);
        Logger.debugLog('💾 Updated SQLite with server ID: $newServerId');
        
        final serverIdWithCreatedTime = await _getServerIdFromSQLite(uniqueId);
        if (serverIdWithCreatedTime.isNotEmpty) {
          Logger.debugLog('✅ Retrieved from SQLite: $serverIdWithCreatedTime');
          return serverIdWithCreatedTime;
        } else {
          Logger.errorLog('❌ Failed to retrieve server ID from SQLite after update');
        }
      } else {
        Logger.errorLog('❌ Failed to upload image to server - newServerId is null');
      }
    } catch (e) {
      Logger.errorLog('❌ Error in getServerId: $e');
    }
    return [];
  }

  /// 3. Download image using server ID
  Future<String?> downloadImageUsingServerId(String serverId) async {
    try {
      // Download image from server first
      final imageData = await _downloadFromServer(serverId);

      // Check if record with this server_id already exists
      final existingRecord = await _getRecordByServerId(serverId);
      if (existingRecord != null) {
        // Update existing record with new image data
        await _updateImageData(existingRecord['unique_id'], imageData);
        return existingRecord['unique_id'];
      } else {
        // Create new record
        final uniqueId = _generateUniqueId();
        final now = DateTime.now().millisecondsSinceEpoch;
        
        await _saveImageToSQLite(
          uniqueId: uniqueId,
          imageData: imageData,
          serverId: serverId,
          createdAt: now,
          updatedAt: now,
        );
        
        Logger.debugLog('✅ Image downloaded and saved with unique ID: $uniqueId');
        return uniqueId;
      }
    } catch (e) {
      Logger.errorLog('❌ Error in downloadImageUsingServerId: $e');
      return null;
    }
  }

  /// 4. Get image data using unique ID
  Future<String?> getImageUsingUniqueId(String uniqueId) async {
    try {
      Logger.debugLog('🔍 Getting image data for unique ID: $uniqueId');
      
      final imageData = await _getImageDataFromSQLite(uniqueId);
      if (imageData != null) {
        Logger.debugLog('✅ Image data retrieved successfully');
        return imageData;
      } else {
        Logger.errorLog('❌ Image data not found for unique ID: $uniqueId');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error in getImageUsingUniqueId: $e');
      return null;
    }
  }

  /// Save image to SQLite
  Future<void> _saveImageToSQLite({
    required String uniqueId,
    required String? imageData,
    required String? serverId,
    required int createdAt,
    required int updatedAt,
  }) async {
    final db = await database;
    await db.insert(
      _tableName,
      {
        'unique_id': uniqueId,
        'server_id': serverId,
        'image_data': imageData,
        'created_at': createdAt,
        'updated_at': updatedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get server ID from SQLite
  Future<List<String>> _getServerIdFromSQLite(String uniqueId) async {
    final db = await database;
    try {
      Logger.debugLog('🔍 SQLite lookup for uniqueId: $uniqueId');
      
      final result = await db.query(
        _tableName,
        columns: ['server_id', 'created_at'],
        where: 'unique_id = ?',
        whereArgs: [uniqueId],
        limit: 1,
      );
      
      Logger.debugLog('🔍 SQLite query result: $result');
      
      List<String> response = [];
      if (result.isNotEmpty) {
        String? serverId = result.first['server_id'] as String?;
        Logger.debugLog('🔍 Found server_id: $serverId');
        
        if (serverId != null) {
          response.add(serverId.toString());
        }
        int? createdTime = result.first['created_at'] as int?;
        String? createdTimeStr = Utils.getTmeFromMSForAPICall(
            createdTime);
        if (createdTimeStr != null) {
          response.add(createdTimeStr.toString());
        }
      }
      return response;
    } catch(e){
      return [];
    }
  }

  /// Get image data from SQLite
  Future<String?> _getImageDataFromSQLite(String uniqueId) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      columns: ['image_data'],
      where: 'unique_id = ?',
      whereArgs: [uniqueId],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return result.first['image_data'] as String?;
    }
    return null;
  }

  /// Get complete record by server ID
  Future<Map<String, dynamic>?> _getRecordByServerId(String serverId) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  /// Update image data for existing record
  Future<void> _updateImageData(String uniqueId, String? imageData) async {
    final db = await database;
    await db.update(
      _tableName,
      {
        'image_data': imageData,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'unique_id = ?',
      whereArgs: [uniqueId],
    );
  }

  /// Update server ID in SQLite
  Future<void> _updateServerId(String uniqueId, String serverId) async {
    final db = await database;
    Logger.debugLog('💾 Updating SQLite: uniqueId=$uniqueId, serverId=$serverId');
    
    final result = await db.update(
      _tableName,
      {
        'server_id': serverId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'unique_id = ?',
      whereArgs: [uniqueId],
    );
    
    Logger.debugLog('💾 SQLite update result: $result rows affected');
  }

  /// Upload image to server
  Future<String?> _uploadToServer(String imageData, ActivityTypeEnum activityType, String siteSchId, bool isSelfie) async {
    try {
      // Convert base64 string to bytes for file upload
      Uint8List imageBytes;
      if (imageData.startsWith('data:image/')) {
        // Remove data URL prefix
        final base64String = imageData.split(',')[1];
        imageBytes = base64Decode(base64String);
      } else {
        // Assume it's raw base64
        imageBytes = base64Decode(imageData);
      }
      
      // Create a temporary file for upload
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);
      
      // Create multipart file
      final multipartFile = await MultipartFile.fromFile(
        tempFile.path,
        filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final response;
      if(isSelfie) {
        response = await _apiService.post<Map<String, dynamic>>(
          path: "api/v1/mobile/uploadsSelfie",
          data: {
            'selfie': multipartFile,
            'imgId': '0',
            'SchId': siteSchId,
          },
          useFormDataFormat: true,
        );
      } else {
        // Upload to server
        response = await _apiService.post<Map<String, dynamic>>(
          path: 'api/v1/mobile/uploads',
          data: {
            'imgFile': multipartFile,
            'activityType': activityType.value,
            'schId': siteSchId
          },
          useFormDataFormat: true,
        );
      }
      
      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      if (response.isSuccess && response.data != null) {
        Logger.debugLog('📤 API Response: ${response.data}');
        
        final photoId = response.data!['imgId']?.toString() ?? 
                       response.data!['photoId']?.toString() ??
                       response.data!['id']?.toString();
        
        Logger.debugLog('🔍 Extracted photo ID: $photoId');
        
        if (photoId != null && photoId.isNotEmpty) {
          Logger.debugLog('✅ Image uploaded to server with ID: $photoId');
          return photoId;
        } else {
          Logger.errorLog('❌ No photo ID returned in response: ${response.data}');
          Logger.errorLog('❌ Tried keys: imgId, photoId, id');
          return null;
        }
      } else {
        Logger.errorLog('❌ Failed to upload image: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading to server: $e');
      return null;
    }
  }

  /// Download image from server
  Future<String?> _downloadFromServer(String serverId) async {
    try {
      final response = await _apiService.get<List<dynamic>>(
        path: '/api/v1/mobile/allImageList?imgIds=$serverId',
      );
      
      if (response.isSuccess && response.data != null) {
        final imageData = response.data?.first['imageData'] as String?;
        if (imageData != null && imageData.isNotEmpty) {
          // Return the base64 string directly
          Logger.debugLog('✅ Image downloaded from server as base64 string');
          return imageData;
        } else {
          Logger.errorLog('❌ Empty image data received from server');
          return null;
        }
      } else {
        Logger.errorLog('❌ Failed to download image: ${response.errorMessage}');
        return null;
      }
    } catch (e) {
      Logger.errorLog('❌ Error downloading from server: $e');
      return null;
    }
  }

  /// Get all images in the database
  Future<List<Map<String, dynamic>>> getAllImages() async {
    final db = await database;
    return await db.query(
      _tableName,
      orderBy: 'created_at DESC',
    );
  }

  /// Get images by server ID
  Future<List<Map<String, dynamic>>> getImagesByServerId(String serverId) async {
    final db = await database;
    return await db.query(
      _tableName,
      where: 'server_id = ?',
      whereArgs: [serverId],
      orderBy: 'created_at DESC',
    );
  }

  /// Delete image by unique ID
  Future<bool> deleteImage(String uniqueId) async {
    try {
      final db = await database;
      final result = await db.delete(
        _tableName,
        where: 'unique_id = ?',
        whereArgs: [uniqueId],
      );
      
      if (result > 0) {
        Logger.debugLog('✅ Image deleted with unique ID: $uniqueId');
        return true;
      } else {
        Logger.debugLog('⚠️ No image found with unique ID: $uniqueId');
        return false;
      }
    } catch (e) {
      Logger.errorLog('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Clear all images
  Future<void> clearAllImages() async {
    final db = await database;
    await db.delete(_tableName);
    Logger.debugLog('✅ All images cleared');
  }

  /// Drop and recreate database with all tables
  Future<void> dropAndRecreateDatabase() async {
    try {
      Logger.debugLog('🗑️ Dropping and recreating ImageUploadService database');
      
      // Close existing database connection
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // Get database path
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);
      
      // Delete the database file
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        Logger.debugLog('🗑️ ImageUploadService database file deleted');
      }
      
      // Recreate database by calling _initDatabase
      _database = await _initDatabase();
      Logger.debugLog('✅ ImageUploadService database recreated with all tables');
    } catch (e) {
      Logger.errorLog('❌ Error dropping and recreating ImageUploadService database: $e');
      // Reset database instance to force recreation on next access
      _database = null;
      rethrow;
    }
  }

  /// Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;
    final totalImages = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $_tableName')) ?? 0;
    final uploadedImages = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $_tableName WHERE server_id IS NOT NULL')) ?? 0;
    final localImages = totalImages - uploadedImages;
    
    return {
      'total_images': totalImages,
      'uploaded_images': uploadedImages,
      'local_images': localImages,
      'upload_percentage': totalImages > 0 ? (uploadedImages / totalImages * 100).toStringAsFixed(1) : '0.0',
    };
  }

  /// Close the database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      Logger.debugLog('✅ ImageUploadService database closed');
    }
  }
}
