import 'package:flutter/material.dart';
import 'package:app/commonWidgets/asset_upload_form_component.dart';
import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/location_model.dart';
import 'package:app/repositories/asset_upload_respository.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/services/asset_audit/central_asset_audit_service.dart';
import 'package:app/services/location_service.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter_svg/svg.dart';
import 'asset_type_mapper.dart';

class AUScanUploadScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final BuildContext? parentContext;
  final List<Map<String, dynamic>>? preloadedAssets;
  final String? preloadedSelfieImageId;
  final int? preloadedAuId;

  const AUScanUploadScreen({
    super.key,
    required this.siteData,
    this.parentContext,
    this.preloadedAssets,
    this.preloadedSelfieImageId,
    this.preloadedAuId,
  });

  @override
  State<AUScanUploadScreen> createState() => _AUScanUploadScreenState();
}

class _AUScanUploadScreenState extends State<AUScanUploadScreen> {
  // Map of asset type (display name) to list of assets
  final Map<String, List<Map<String, dynamic>>> _assetGroups = {};
  
  // Map of asset type to controller for each group
  final Map<String, TextEditingController> _serialControllers = {};
  
  // Map to track expanded/collapsed state of each section
  final Map<String, bool> _sectionExpandedState = {};
  
  // Set to track all scanned serial numbers (for duplicate prevention)
  final Set<String> _scannedSerialNumbers = {};
  
  // Total asset count
  int _totalAssetCount = 0;
  
  // Controller for the initial scan input section
  final TextEditingController _initialScanController = TextEditingController();
  
  // GlobalKey to access the initial scan component for editing  
  final GlobalKey _initialScanKey = GlobalKey();
  
  // Edit state - track which item is being edited
  Map<String, dynamic>? _editingItem;
  String? _editingAssetType;
  String? _editingOriginalSerial; // Store original serial to find and update the item

  // Selfie image ID - can be set directly if uploaded in this screen
  String? _currentSelfieImageId;

  // Repository and services
  late AssetUploadRepository _assetUploadRepository;
  late CentralAssetAuditService _assetAuditService;

  @override
  void initState() {
    super.initState();
    _assetUploadRepository = AssetUploadRepository(
      ServiceLocator().apiService,
    );
    _assetAuditService = ServiceLocator().centralAssetAuditService;
    _loadExistingAssets();
  }

  @override
  void dispose() {
    // Dispose all controllers
    _initialScanController.dispose();
    for (var controller in _serialControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Load existing assets from storage or preloaded data
  Future<void> _loadExistingAssets() async {
    try {
      // If preloaded assets are provided, load them
      if (widget.preloadedAssets != null && widget.preloadedAssets!.isNotEmpty) {
        await _loadPreloadedAssets(widget.preloadedAssets!);
      } else {
        // TODO: Load from SQLite if needed
        // For now, start with empty state
        setState(() {});
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading existing assets: $e');
    }
  }

  /// Load and segregate preloaded assets by acronym
  Future<void> _loadPreloadedAssets(List<Map<String, dynamic>> assets) async {
    try {
      Logger.debugLog('📦 Loading ${assets.length} preloaded assets');

      for (final asset in assets) {
        // Get serial number from nexgen_serial_no or mfg_serial_no
        final nexgenSerialNo = asset['nexgen_serial_no']?.toString() ?? 
                              asset['mfg_serial_no']?.toString() ?? '';
        
        if (nexgenSerialNo.isEmpty) {
          Logger.errorLog('⚠️ Skipping asset with no serial number: $asset');
          continue;
        }

        // Parse the serial number to get asset type
        final parsed = _parseScannedCode(nexgenSerialNo);
        if (parsed == null) {
          Logger.errorLog('⚠️ Could not parse serial number: $nexgenSerialNo');
          continue;
        }

        final assetType = parsed['displayName']!;
        final acronym = parsed['acronym']!;
        final serialNum = parsed['serialNumber']!;
        final fullSerial = '$acronym-$serialNum';

        // Create asset group if it doesn't exist
        if (!_assetGroups.containsKey(assetType)) {
          setState(() {
            _assetGroups[assetType] = [];
            _sectionExpandedState[assetType] = true;
            _serialControllers[assetType] = TextEditingController();
          });
        }

        // Build asset item in the expected format
        final assetItem = <String, dynamic>{
          'mfg_serial_no': serialNum, // Just the serial part without acronym
          'full_scanned_code': nexgenSerialNo, // Full serial number
          'nexgen_serial_no': nexgenSerialNo,
          'item_id': asset['item_id'],
          'item_instance_id': asset['item_instance_id'],
          'latitude': asset['latitude']?.toString(),
          'longitude': asset['longitude']?.toString(),
          'aui_id': asset['aui_id'],
          'qr_code_scanned': true,
          'qr_code_scanned_ts': Utils.getCurrentDateTimeForAPICall(),
          'timestamp': Utils.getCurrentDateTimeForAPICall(),
        };

        // Handle photo data if available (check both snake_case and camelCase)
        final assetUploadItemImages = asset['asset_upload_item_images'] ?? 
                                     asset['assetUploadItemImages'];
        
        if (assetUploadItemImages != null && 
            assetUploadItemImages is List && 
            assetUploadItemImages.isNotEmpty) {
          // Convert to assetUploadItemImages format
          final List<Map<String, dynamic>> images = [];
          for (final img in assetUploadItemImages) {
            if (img is Map<String, dynamic>) {
              images.add({
                'auiiId': img['auii_id'] ?? img['auiiId'] ?? 0,
                'photoId': img['photo_id'] ?? img['photoId'] ?? 0,
                'photoTakenTs': (img['photo_taken_ts'] ?? img['photoTakenTs'])?.toString() ?? 
                              Utils.getCurrentDateTimeForAPICall(),
                'longitude': (img['longitude'] ?? '')?.toString() ?? '',
                'latitude': (img['latitude'] ?? '')?.toString() ?? '',
                'isActive': img['is_active'] ?? img['isActive'] ?? true,
                'remarks': (img['remarks'] ?? '')?.toString() ?? '',
              });
            }
          }
          if (images.isNotEmpty) {
            // Use the first image's photo_id as the primary photo_id
            final firstPhotoId = images.first['photoId'];
            if (firstPhotoId != null && firstPhotoId != 0) {
              assetItem['photo_id'] = firstPhotoId.toString();
            }
            assetItem['assetUploadItemImages'] = images;
          }
        }

        // Add to the appropriate group
        setState(() {
          _assetGroups[assetType]!.add(assetItem);
          _scannedSerialNumbers.add(fullSerial);
        });

        Logger.debugLog('✅ Loaded asset: $nexgenSerialNo -> $assetType');
      }

      _updateTotalCount();
      Logger.debugLog('✅ Successfully loaded ${_totalAssetCount} assets into ${_assetGroups.length} groups');
      
      setState(() {});
    } catch (e) {
      Logger.errorLog('❌ Error loading preloaded assets: $e');
    }
  }

  /// Validates and parses scanned code
  /// Format: NG-<ACRONYM>-<SERIAL_NUMBER>
  /// Returns: Map with 'acronym', 'serialNumber', 'displayName' or null if invalid
  Map<String, String>? _parseScannedCode(String scannedCode) {
    if (scannedCode.isEmpty) return null;

    // Remove any whitespace
    final code = scannedCode.trim().toUpperCase();

    // Check if it starts with "NG-"
    if (!code.startsWith('NG-')) {
      return null;
    }

    // Remove "NG-" prefix
    final withoutPrefix = code.substring(3);

    // Split by "-" to get acronym and serial number
    final parts = withoutPrefix.split('-');
    if (parts.length < 2) {
      return null;
    }

    // First part is acronym, rest is serial number
    final acronym = parts[0];
    final serialNumber = parts.sublist(1).join('-'); // Join in case serial has dashes

    if (acronym.isEmpty || serialNumber.isEmpty) {
      return null;
    }

    // Get display name for the acronym
    final displayName = AssetTypeMapper.getDisplayName(acronym);

    return {
      'acronym': acronym,
      'serialNumber': serialNumber,
      'displayName': displayName,
    };
  }

  /// Creates a validator function for a specific asset type
  bool Function(String, bool) _createValidatorForAssetType(String assetType) {
    return (String serialNumber, bool isScanned) {
      if (serialNumber.isEmpty) return false;

      // If scanned, validate the format
      if (isScanned) {
        final parsed = _parseScannedCode(serialNumber);
        if (parsed == null) {
          return false;
        }

        final scannedAssetType = parsed['displayName']!;
        final acronym = parsed['acronym']!;
        final serialNum = parsed['serialNumber']!;
        final fullSerial = '$acronym-$serialNum';

        // Check for duplicates
        if (_scannedSerialNumbers.contains(fullSerial)) {
          return false;
        }

        // If it matches this asset type, add to scanned set and allow
        if (scannedAssetType == assetType) {
          _scannedSerialNumbers.add(fullSerial);
          return true;
        }

        // If it's a different asset type, create that group if it doesn't exist
        if (!_assetGroups.containsKey(scannedAssetType)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _assetGroups[scannedAssetType] = [];
              _sectionExpandedState[scannedAssetType] = true;
              final controller = TextEditingController();
              controller.text = serialNum; // Set the serial number
              _serialControllers[scannedAssetType] = controller;
              _scannedSerialNumbers.add(fullSerial);
            });
          });
          // Return false to prevent adding to current component, but group is created
          return false;
        }

        // Different asset type that already exists - don't allow in this component
        return false;
      }

      // Manual entry - just check if not empty
      return serialNumber.isNotEmpty;
    };
  }

  /// Handles when an item is saved from AssetUploadFormComponent
  void _onItemSaved(String assetType, List<Map<String, dynamic>> items) {
    setState(() {
      // Normalize serial numbers to show only the serial part (not NG-ACRONYM-SERIAL)
      // But always preserve full_scanned_code for display
      // IMPORTANT: Preserve ALL fields including photo_id, photoPath, and assetUploadItemImages
      final normalizedItems = items.map((item) {
        final updatedItem = Map<String, dynamic>.from(item); // Copy all fields first (includes assetUploadItemImages)
        final serialNumber = item['mfg_serial_no']?.toString() ?? '';
        
        // Always ensure full_scanned_code is set - use existing or reconstruct if needed
        if (!updatedItem.containsKey('full_scanned_code') ||
            updatedItem['full_scanned_code'] == null ||
            updatedItem['full_scanned_code'].toString().isEmpty) {
          // If mfg_serial_no is already in full format, use it
          if (serialNumber.startsWith('NG-')) {
            updatedItem['full_scanned_code'] = serialNumber;
          } else {
            // Reconstruct from asset type
            final acronym = AssetTypeMapper.getAcronymForDisplayName(assetType);
            if (acronym != null && serialNumber.isNotEmpty) {
              updatedItem['full_scanned_code'] = 'NG-$acronym-$serialNumber';
            } else {
              updatedItem['full_scanned_code'] = serialNumber;
            }
          }
        }
        
        // If it's in NG-ACRONYM-SERIAL format, extract just the serial part for mfg_serial_no
        final parsed = _parseScannedCode(serialNumber);
        if (parsed != null) {
          updatedItem['mfg_serial_no'] = parsed['serialNumber']!;
        }
        
        // Ensure photo_id, photoPath, and assetUploadItemImages are preserved (should already be in item)
        // assetUploadItemImages is already copied from item in Map.from(item)
        // No need to modify them - they're already correct from the component
        
        return updatedItem;
      }).toList();
      
      _assetGroups[assetType] = normalizedItems;
      _updateTotalCount();
    });
  }

  /// Handles when an item is saved from the initial scan component
  void _onInitialItemSaved(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return;

    // Get the last saved item
    final lastItem = items.last;
    final fullSerialNumber = lastItem['mfg_serial_no']?.toString() ?? '';

    // If we're editing an existing item, update it instead of adding new
    if (_editingItem != null && _editingAssetType != null) {
      final parsed = _parseScannedCode(fullSerialNumber);
      if (parsed != null) {
        final assetType = parsed['displayName']!;
        final serialNum = parsed['serialNumber']!;

        // Remove the old item from the group - match by original serial number or full code
        final currentItems = List<Map<String, dynamic>>.from(_assetGroups[_editingAssetType!] ?? []);
        // Try to find the old item more accurately
        final oldItemIndex = currentItems.indexWhere((item) {
          final itemSerial = item['mfg_serial_no']?.toString() ?? '';
          final itemFullCode = item['full_scanned_code']?.toString() ?? '';
          final editingFullCode = _editingItem?['full_scanned_code']?.toString() ?? '';
          // Match by: normalized serial, full code, or if full code contains original serial
          return itemSerial == _editingOriginalSerial || 
                 itemFullCode == editingFullCode ||
                 (editingFullCode.isNotEmpty && itemFullCode == editingFullCode) ||
                 itemFullCode.contains(_editingOriginalSerial ?? '');
        });
        
        // Remove the old item if found
        if (oldItemIndex != -1) {
          currentItems.removeAt(oldItemIndex);
        } else {
          // If not found by exact match, try to remove by serial number match
          currentItems.removeWhere((item) {
            final itemSerial = item['mfg_serial_no']?.toString() ?? '';
            return itemSerial == _editingOriginalSerial || itemSerial == serialNum;
          });
        }

        // If asset type changed, remove from old group
        if (assetType != _editingAssetType) {
          _assetGroups[_editingAssetType!] = currentItems;
          
          // Add to new group
          if (!_assetGroups.containsKey(assetType)) {
            _assetGroups[assetType] = [];
            _sectionExpandedState[assetType] = true;
            _serialControllers[assetType] = TextEditingController();
          }
        }

        // Update the item with normalized serial and preserve ALL data including photo
        // Copy everything from lastItem first to preserve photo_id, photoPath, and all other fields
        final updatedItem = Map<String, dynamic>.from(lastItem);
        updatedItem['mfg_serial_no'] = serialNum;
        updatedItem['full_scanned_code'] = fullSerialNumber;
        // Explicitly preserve photo data from lastItem (should have updated photo if changed)
        if (lastItem['photo_id'] != null) {
          updatedItem['photo_id'] = lastItem['photo_id'];
        }
        if (lastItem['photoPath'] != null) {
          updatedItem['photoPath'] = lastItem['photoPath'];
        }
        // Preserve assetUploadItemImages array from lastItem (contains uploaded photo data)
        if (lastItem['assetUploadItemImages'] != null) {
          updatedItem['assetUploadItemImages'] = lastItem['assetUploadItemImages'];
        }
        // Preserve other fields that might be needed
        if (lastItem['qr_code_scanned'] != null) {
          updatedItem['qr_code_scanned'] = lastItem['qr_code_scanned'];
        }
        if (lastItem['qr_code_scanned_ts'] != null) {
          updatedItem['qr_code_scanned_ts'] = lastItem['qr_code_scanned_ts'];
        }
        if (lastItem['disabledFieldValue'] != null) {
          updatedItem['disabledFieldValue'] = lastItem['disabledFieldValue'];
        }
        if (lastItem['secondDisabledFieldValue'] != null) {
          updatedItem['secondDisabledFieldValue'] = lastItem['secondDisabledFieldValue'];
        }
        if (lastItem['timestamp'] != null) {
          updatedItem['timestamp'] = lastItem['timestamp'];
        }
        if (lastItem['capacity'] != null) {
          updatedItem['capacity'] = lastItem['capacity'];
        }
        if (lastItem['remarks'] != null) {
          updatedItem['remarks'] = lastItem['remarks'];
        }

        // Add/update in the appropriate group
        if (assetType == _editingAssetType) {
          // Add the updated item (old one was already removed)
          currentItems.add(updatedItem);
          _assetGroups[assetType] = currentItems;
        } else {
          _assetGroups[assetType]!.add(updatedItem);
        }

        setState(() {
          _editingItem = null;
          _editingAssetType = null;
          _editingOriginalSerial = null;
          _updateTotalCount();
        });

        _initialScanController.clear();
        showCustomToast(context, 'Asset updated successfully');
        return;
      }
    }

    // Try to parse the serial number to get asset type
    // If it's a scanned code, extract the asset type
    final parsed = _parseScannedCode(fullSerialNumber);
    if (parsed != null) {
      final assetType = parsed['displayName']!;
      final acronym = parsed['acronym']!;
      final serialNum = parsed['serialNumber']!;
      final fullSerial = '$acronym-$serialNum';

      // Check for duplicates
      if (_scannedSerialNumbers.contains(fullSerial)) {
        showCustomToast(context, 'This serial number has already been scanned');
        _initialScanController.clear();
        return;
      }

      // Create asset group if it doesn't exist
      if (!_assetGroups.containsKey(assetType)) {
        setState(() {
          _assetGroups[assetType] = [];
          _sectionExpandedState[assetType] = true;
          final controller = TextEditingController();
          _serialControllers[assetType] = controller;
        });
      }

      // Add the item to the appropriate group
      setState(() {
        // Update the serial number in the item to just the serial part (without NG-ACRONYM-)
        final updatedItem = Map<String, dynamic>.from(lastItem);
        updatedItem['mfg_serial_no'] = serialNum;
        // Preserve the full scanned code in a separate field for reference
        updatedItem['full_scanned_code'] = fullSerialNumber;
        // Ensure assetUploadItemImages is preserved from lastItem (created when saving individual item)
        if (lastItem['assetUploadItemImages'] != null) {
          updatedItem['assetUploadItemImages'] = lastItem['assetUploadItemImages'];
        }
        _assetGroups[assetType]!.add(updatedItem);
        _scannedSerialNumbers.add(fullSerial);
        _updateTotalCount();
      });

      // Clear the initial scan controller
      _initialScanController.clear();

      // Show success message
      showCustomToast(context, 'Asset added to $assetType group');
    } else {
      // If it's not a scanned code format, we can't determine asset type
      // Show error message
      showCustomToast(context, 'Invalid format. Expected: NG-<ACRONYM>-<SERIAL>');
      Logger.errorLog('⚠️ Could not parse serial number to determine asset type: $fullSerialNumber');
    }
  }

  /// Updates total asset count
  void _updateTotalCount() {
    _totalAssetCount = _assetGroups.values
        .fold(0, (sum, items) => sum + items.length);
  }

  /// Gets selfie image ID from preloaded data or storage
  Future<int?> _getSelfieImageId() async {
    try {
      // First check if we have a current selfie image ID (uploaded in this session)
      if (_currentSelfieImageId != null && _currentSelfieImageId!.isNotEmpty) {
        final currentId = _currentSelfieImageId!;
        Logger.debugLog('📸 Found current selfie image ID: $currentId');
        if (currentId != "0" && currentId != "null") {
          if (currentId.contains("LOCAL_IMAGE_ID")) {
            Logger.debugLog('⚠️ Current ID is LOCAL_IMAGE_ID, returning 0');
            return 0;
          }
          final parsedId = int.tryParse(currentId);
          if (parsedId != null && parsedId > 0) {
            Logger.debugLog('✅ Using current selfie image ID: $parsedId');
            return parsedId;
          }
        }
      }

      // Second check if preloaded selfie image ID is available
      if (widget.preloadedSelfieImageId != null && 
          widget.preloadedSelfieImageId!.isNotEmpty) {
        final preloadedId = widget.preloadedSelfieImageId!;
        Logger.debugLog('📸 Found preloaded selfie image ID: $preloadedId');
        if (preloadedId != "0" && preloadedId != "null") {
          // Convert to int, handling LOCAL_IMAGE_ID case
          if (preloadedId.contains("LOCAL_IMAGE_ID")) {
            Logger.debugLog('⚠️ Preloaded ID is LOCAL_IMAGE_ID, returning 0');
            return 0; // Will need to be replaced when uploading
          }
          final parsedId = int.tryParse(preloadedId);
          if (parsedId != null && parsedId > 0) {
            Logger.debugLog('✅ Using preloaded selfie image ID: $parsedId');
            return parsedId;
          } else {
            Logger.debugLog('⚠️ Failed to parse preloaded ID: $preloadedId');
          }
        } else {
          Logger.debugLog('⚠️ Preloaded ID is 0 or null: $preloadedId');
        }
      } else {
        Logger.debugLog('⚠️ No preloaded selfie image ID available');
      }

      // Fallback to storage if preloaded ID is not available
      Logger.debugLog('🔍 Checking database for selfie image ID...');
      Logger.debugLog('🔍 Using siteId: ${widget.siteData.siteId}');
      
      // Try to get from database using siteId
      final storedData = await _assetAuditService.getActualDataFromSqlite(
        siteAuditSchId: widget.siteData.siteId.toString(),
      );

      if (storedData != null) {
        Logger.debugLog('📦 Stored data found, keys: ${storedData.keys.toList()}');
        final pageHeaders = storedData['pageHeader'] as List<dynamic>?;
        final pageHeader = pageHeaders?.isNotEmpty == true
            ? pageHeaders!.first as Map<String, dynamic>?
            : null;

        if (pageHeader != null) {
          Logger.debugLog('📋 Page header found, checking for maker_selfie_image_id');
          Logger.debugLog('📋 Page header keys: ${pageHeader.keys.toList()}');
          Logger.debugLog('📋 Page header full data: $pageHeader');
          
          // Try both snake_case and camelCase
          final selfieImageIdValue = pageHeader['maker_selfie_image_id'] ?? 
                                    pageHeader['makerSelfieImageId'];
          
          if (selfieImageIdValue != null) {
            final selfieImageId = selfieImageIdValue.toString();
            Logger.debugLog('📸 Found selfie image ID in database: $selfieImageId (type: ${selfieImageIdValue.runtimeType})');
            
            if (selfieImageId.isNotEmpty && 
                selfieImageId != "0" && 
                selfieImageId != "null" &&
                selfieImageId.toLowerCase() != "null") {
              // Convert to int, handling LOCAL_IMAGE_ID case
              if (selfieImageId.contains("LOCAL_IMAGE_ID")) {
                Logger.debugLog('⚠️ Database ID is LOCAL_IMAGE_ID, returning 0');
                return 0; // Will need to be replaced when uploading
              }
              final parsedId = int.tryParse(selfieImageId);
              if (parsedId != null && parsedId > 0) {
                Logger.debugLog('✅ Using selfie image ID from database: $parsedId');
                return parsedId;
              } else {
                Logger.debugLog('⚠️ Failed to parse database ID: $selfieImageId');
                Logger.debugLog('⚠️ Attempted to parse as int but got null or 0');
              }
            } else {
              Logger.debugLog('⚠️ Database ID is empty, 0, or null: $selfieImageId');
            }
          } else {
            Logger.debugLog('⚠️ maker_selfie_image_id not found in page header');
            Logger.debugLog('⚠️ Available keys in pageHeader: ${pageHeader.keys.toList()}');
          }
        } else {
          Logger.debugLog('⚠️ Page header is null or empty');
          if (pageHeaders != null) {
            Logger.debugLog('⚠️ Page headers list length: ${pageHeaders.length}');
          }
        }
      } else {
        Logger.debugLog('⚠️ No stored data found in database for siteId: ${widget.siteData.siteId}');
      }
      
      Logger.debugLog('⚠️ No valid selfie image ID found, returning 0');
      return 0;
    } catch (e) {
      Logger.errorLog('❌ Error getting selfie image ID: $e');
      Logger.errorLog('❌ Stack trace: ${StackTrace.current}');
      return 0;
    }
  }

  /// Transforms assets from _assetGroups to AssetUploadItem format
  List<AssetUploadItem> _transformAssetsToApiFormat(
    LocationModel? location,
  ) {
    final List<AssetUploadItem> assetUploadItems = [];

    for (final entry in _assetGroups.entries) {
      final items = entry.value;

      for (final item in items) {
        // Get serial number (prefer full_scanned_code, fallback to mfg_serial_no)
        final nexgenSerialNo = item['full_scanned_code']?.toString() ?? 
                              item['mfg_serial_no']?.toString() ?? 
                              '';

        if (nexgenSerialNo.isEmpty) {
          continue; // Skip items without serial number
        }

        // Build assetUploadItemImages from photo data
        final List<AssetUploadItemImage> itemImages = [];
        
        // Check if assetUploadItemImages already exists (from individual save)
        if (item['assetUploadItemImages'] != null && 
            item['assetUploadItemImages'] is List) {
          final images = item['assetUploadItemImages'] as List<dynamic>;
          for (final img in images) {
            if (img is Map<String, dynamic>) {
              // Convert photoId to int, handling LOCAL_IMAGE_ID case
              int? photoIdInt;
              final photoIdValue = img['photoId'];
              if (photoIdValue != null) {
                if (photoIdValue is int) {
                  photoIdInt = photoIdValue;
                } else {
                  final photoIdStr = photoIdValue.toString();
                  if (photoIdStr.contains("LOCAL_IMAGE_ID")) {
                    photoIdInt = 0; // LOCAL_IMAGE_ID -> 0 for offline photos
                  } else {
                    photoIdInt = int.tryParse(photoIdStr) ?? 0;
                  }
                }
              }
              
              itemImages.add(AssetUploadItemImage(
                auiiId: img['auiiId'] as int?,
                photoId: photoIdInt ?? 0,
                photoTakenTs: Utils.normalizeDateForAPICall(
                  img['photoTakenTs']?.toString() ?? 
                  item['timestamp']?.toString() ??
                  item['qr_code_scanned_ts']?.toString(),
                ),
                longitude: img['longitude']?.toString() ?? 
                         location?.longitude.toString() ?? '',
                latitude: img['latitude']?.toString() ?? 
                        location?.latitude.toString() ?? '',
                isActive: img['isActive'] as bool? ?? true,
                remarks: img['remarks']?.toString() ?? '',
              ));
            }
          }
        } else if (item['photo_id'] != null && item['photo_id'].toString().isNotEmpty) {
          // Convert existing photo_id to AssetUploadItemImage format (fallback for old items)
          final photoId = item['photo_id'].toString();
          final photoIdInt = photoId.contains("LOCAL_IMAGE_ID") 
              ? 0 
              : (int.tryParse(photoId) ?? 0);
          
          // Only add if we have a valid photo ID (either server ID > 0 or LOCAL_IMAGE_ID)
          if (photoIdInt > 0 || photoId.contains("LOCAL_IMAGE_ID")) {
            itemImages.add(AssetUploadItemImage(
              auiiId: 0,
              photoId: photoIdInt,
              photoTakenTs: Utils.normalizeDateForAPICall(
                item['timestamp']?.toString() ?? 
                item['qr_code_scanned_ts']?.toString(),
              ),
              longitude: location?.longitude.toString() ?? '',
              latitude: location?.latitude.toString() ?? '',
              isActive: true,
              remarks: item['remarks']?.toString() ?? '',
            ));
          }
        }

        // Create AssetUploadItem
        assetUploadItems.add(AssetUploadItem(
          auiId: 0,
          auId: 0,
          nexgenSerialNo: nexgenSerialNo,
          itemId: 0,
          longitude: location?.longitude.toString() ?? '',
          latitude: location?.latitude.toString() ?? '',
          isActive: true,
          remarks: item['remarks']?.toString() ?? 
                   item['disabledFieldValue']?.toString() ?? '',
          assetUploadItemImages: itemImages,
        ));
      }
    }

    return assetUploadItems;
  }

  /// Handles Save Asset button click
  Future<void> _handleSaveAsset() async {
    // Check if there are any assets to save
    if (_assetGroups.isEmpty || _totalAssetCount == 0) {
      Toastbar.showErrorToastbar(
        'Please scan at least one asset before saving',
        context,
      );
      return;
    }

    try {
      // Show loading indicator
      LoaderWidget.showLoader(context);

      // Get selfie image ID from storage
      final selfieImageId = await _getSelfieImageId();
      Logger.debugLog('📸 Retrieved selfie image ID for asset upload: $selfieImageId');

      // Get current location
      LocationModel? location;
      try {
        location = await LocationService.getCurrentLocation();
      } catch (e) {
        LoaderWidget.hideLoader();
        Toastbar.showErrorToastbar(
          'Please enable location services to save assets',
          context,
        );
        return;
      }

      // Transform assets to API format
      final assetUploadItems = _transformAssetsToApiFormat(location);

      if (assetUploadItems.isEmpty) {
        LoaderWidget.hideLoader();
        Toastbar.showErrorToastbar(
          'No valid assets to save',
          context,
        );
        return;
      }

      // Call the assetUpload API
      final finalSelfieImageId = selfieImageId ?? 0;
      Logger.debugLog('📤 ========== ASSET UPLOAD REQUEST ==========');
      Logger.debugLog('📤 siteId: ${widget.siteData.siteId}');
      Logger.debugLog('📤 entityId: ${widget.siteData.entityId}');
      Logger.debugLog('📤 makerSelfieImageId: $finalSelfieImageId (type: ${finalSelfieImageId.runtimeType})');
      Logger.debugLog('📤 preloadedSelfieImageId: ${widget.preloadedSelfieImageId}');
      Logger.debugLog('📤 currentSelfieImageId: $_currentSelfieImageId');
      Logger.debugLog('📤 assetUploadItems count: ${assetUploadItems.length}');
      Logger.debugLog('📤 ===========================================');
      
      // Use preloaded auId if available (for updates), otherwise use 0 (for new uploads)
      final auId = widget.preloadedAuId ?? 0;
      Logger.debugLog('📤 Using auId: $auId (${auId == 0 ? "new upload" : "update"})');
      
      final result = await _assetUploadRepository.assetUpload(
        auId: auId,
        siteId: widget.siteData.siteId,
        entityId: widget.siteData.entityId,
        makerSelfieImageId: finalSelfieImageId,
        isActive: true,
        remarks: '',
        assetUploadItems: assetUploadItems,
      );

      LoaderWidget.hideLoader();

      // Handle response
      if (result.statusCode != null && 
          result.statusCode! >= 200 && 
          result.statusCode! < 300) {
        // Success
        Toastbar.showSuccessToastbar(
          'Assets saved successfully',
          context,
        );
        Logger.infoLog('✅ Assets uploaded successfully');
        
        // Navigate back or to home
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              navigateBackOrToHome(
                context,
                targetContext: widget.parentContext ?? context,
              );
            }
          });
        }
      } else {
        // Error
        final errorMessage = result.errorMessage ?? 'Failed to save assets';
        Toastbar.showErrorToastbar(
          errorMessage,
          context,
        );
        Logger.errorLog('❌ Failed to upload assets: $errorMessage');
      }
    } catch (e) {
      if (LoaderWidget.isShowing) {
        LoaderWidget.hideLoader();
      }
      
      Logger.errorLog('❌ Error saving assets: $e');
      if (mounted) {
        Toastbar.showErrorToastbar(
          'Error saving assets: ${e.toString()}',
          context,
        );
      }
    }
  }

  /// Handles editing an item from scanned assets table
  /// This will populate the initial scan section at the top for editing
  void _handleEditItemFromScannedAssets(Map<String, dynamic> item, String assetType) {
    // Prepare the item with full serial number for editing
    final itemForEditing = Map<String, dynamic>.from(item);
    
    // Get the original serial number (could be just serial or full scanned code)
    final originalSerial = item['mfg_serial_no']?.toString() ?? '';
    
    // If there's a full_scanned_code, use that; otherwise reconstruct it
    String fullSerialNumber;
    final fullScannedCode = item['full_scanned_code']?.toString();
    if (fullScannedCode != null && fullScannedCode.isNotEmpty) {
      fullSerialNumber = fullScannedCode;
    } else {
      // Reconstruct the full serial number (NG-ACRONYM-SERIAL)
      final acronym = AssetTypeMapper.getAcronymForDisplayName(assetType);
      if (acronym != null && acronym.isNotEmpty && originalSerial.isNotEmpty) {
        fullSerialNumber = 'NG-$acronym-$originalSerial';
      } else {
        fullSerialNumber = originalSerial;
      }
    }
    
    // Ensure full_scanned_code is set in the item for the component to use
    itemForEditing['full_scanned_code'] = fullSerialNumber;
    
    // Store editing information
    setState(() {
      _editingItem = itemForEditing;
      _editingAssetType = assetType;
      _editingOriginalSerial = originalSerial;
      
      // Set the serial number in the initial scan controller
      _initialScanController.text = fullSerialNumber;
    });
    
    // Trigger editing in the initial scan component
    // The component will handle loading the photo and other fields
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _initialScanKey.currentState;
      // Use dynamic type to access the startEditingItem method
      if (state != null && state is State<AssetUploadFormComponent>) {
        (state as dynamic).startEditingItem(itemForEditing);
      }
    });
  }

  /// Gets or creates controller for an asset type
  TextEditingController _getControllerForAssetType(String assetType) {
    if (!_serialControllers.containsKey(assetType)) {
      _serialControllers[assetType] = TextEditingController();
    }
    return _serialControllers[assetType]!;
  }

  /// Builds the initial scan section using AssetUploadFormComponent
  Widget _buildInitialScanSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AssetUploadFormComponent(
        key: _initialScanKey,
        componentId: 'initial_scan',
        serialLabel: 'Scan Asset',
        serialHintText: 'Serial Number',
        photoLabel: 'Add a Photo',
        serialController: _initialScanController,
        initialSavedItems: [],
        onItemSaved: _onInitialItemSaved,
        customValidator: (serialNumber, isScanned) {
          if (serialNumber.isEmpty) return false;

          // If scanned, validate the format
          if (isScanned) {
            final parsed = _parseScannedCode(serialNumber);
            if (parsed == null) {
              return false;
            }

            final acronym = parsed['acronym']!;
            final serialNum = parsed['serialNumber']!;
            final fullSerial = '$acronym-$serialNum';

            // Check for duplicates
            if (_scannedSerialNumbers.contains(fullSerial)) {
              return false;
            }

            // Valid scanned code
            return true;
          }

          // Manual entry - just check if not empty
          return serialNumber.isNotEmpty;
        },
        customValidationErrorMessage:
            'Invalid format. Expected: NG-<ACRONYM>-<SERIAL> or duplicate serial number',
        siteAuditSchId: widget.siteData.siteId.toString(),
        showTable: false, // Don't show table in initial scan section
        tableTitle: null,
      ),
    );
  }

  /// Builds the total assets summary
  Widget _buildTotalAssetsSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Assets',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          Text(
            '$_totalAssetCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a collapsible section for an asset type
  Widget _buildAssetTypeSection(String assetType, List<Map<String, dynamic>> items) {
    final isExpanded = _sectionExpandedState[assetType] ?? true;
    final itemCount = items.length;
    final controller = _getControllerForAssetType(assetType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          // Section header (collapsible)
          InkWell(
            onTap: () {
              setState(() {
                _sectionExpandedState[assetType] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$assetType ($itemCount)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          
          // Section content (shown when expanded)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              child: AssetUploadFormComponent(
                key: ValueKey('$assetType-${items.length}-${items.map((i) => i['photo_id']?.toString() ?? '').join('-')}'), // Force rebuild when items or photos change
                componentId: assetType,
                serialLabel: 'Scan Asset',
                serialHintText: 'Serial Number',
                photoLabel: 'Add a Photo',
                serialController: controller,
                initialSavedItems: items,
                onItemSaved: (savedItems) => _onItemSaved(assetType, savedItems),
                onEditItem: (item) => _handleEditItemFromScannedAssets(item, assetType),
                customValidator: _createValidatorForAssetType(assetType),
                customValidationErrorMessage:
                    'Invalid format, wrong asset type, or duplicate serial number',
                siteAuditSchId: widget.siteData.siteId.toString(),
                showTable: true,
                showForm: false, // Hide form section, only show table for scanned assets
                tableTitle: null, // No title needed as we have section header
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the scanned assets list
  Widget _buildScannedAssetsList() {
    if (_assetGroups.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.green7,
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Center(
          child: Text(
            'No assets scanned yet.\nScan a QR code to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Scanned Assets',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: fontFamilyMontserrat,
              ),
            ),
          ),
        ),
        ..._assetGroups.entries.map((entry) {
          return _buildAssetTypeSection(entry.key, entry.value);
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'Asset Upload',
        onClose: () {
          // If we can pop (came from asset_upload_detail_page), just pop
          // Otherwise use navigateBackOrToHome for other navigation paths
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            navigateBackOrToHome(
              context,
              targetContext: widget.parentContext ?? context,
            );
          }
        },
      ),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: SvgPicture.asset(
              AppImages.home,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildInitialScanSection(),
                        const SizedBox(height: 16),
                        _buildTotalAssetsSummary(),
                        _buildScannedAssetsList(),
                        const SizedBox(height: 100), // Space for bottom buttons
                      ],
                    ),
                  ),
                ),
                // Bottom buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // If we can pop (came from asset_upload_detail_page), just pop
                            // Otherwise use navigateBackOrToHome for other navigation paths
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              navigateBackOrToHome(
                                context,
                                targetContext: widget.parentContext ?? context,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: fontFamilyMontserrat,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleSaveAsset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: const Text(
                            'Save Asset',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: fontFamilyMontserrat,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

