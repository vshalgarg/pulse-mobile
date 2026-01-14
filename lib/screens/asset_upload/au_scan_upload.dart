import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:app/commonWidgets/asset_upload_form_component.dart';
import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
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
import 'package:app/utils/connectivity_helper.dart';
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
  final CMScreenModeEnum mode;

  const AUScanUploadScreen({
    super.key,
    required this.siteData,
    this.parentContext,
    this.preloadedAssets,
    this.preloadedSelfieImageId,
    this.preloadedAuId,
    this.mode = CMScreenModeEnum.create,
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
  String?
  _editingOriginalSerial; // Store original serial to find and update the item

  // Selfie image ID - can be set directly if uploaded in this screen
  String? _currentSelfieImageId;

  // Repository and services
  late AssetUploadRepository _assetUploadRepository;
  late CentralAssetAuditService _assetAuditService;

  // Actual mode - override to edit if au_id is not null
  late CMScreenModeEnum _actualMode;

  @override
  void initState() {
    super.initState();

    // If preloadedAuId is not null, treat as edit mode even if mode is create
    _actualMode = (widget.preloadedAuId != null && widget.preloadedAuId! > 0)
        ? CMScreenModeEnum.edit
        : widget.mode;

    Logger.debugLog(
      '📋 AUScanUploadScreen - Mode: ${widget.mode}, Actual Mode: $_actualMode, preloadedAuId: ${widget.preloadedAuId}',
    );
    print(
      '📋 AUScanUploadScreen - Mode: ${widget.mode}, Actual Mode: $_actualMode, preloadedAuId: ${widget.preloadedAuId}',
    );
    _assetUploadRepository = AssetUploadRepository(ServiceLocator().apiService);
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
      Logger.debugLog('📦 Loading existing assets...');
      Logger.debugLog(
        '📦 preloadedAssets: ${widget.preloadedAssets != null ? widget.preloadedAssets!.length : "null"}',
      );
      Logger.debugLog('📦 preloadedAuId: ${widget.preloadedAuId}');
      Logger.debugLog(
        '📦 preloadedSelfieImageId: ${widget.preloadedSelfieImageId}',
      );

      // If preloaded assets are provided, load them
      if (widget.preloadedAssets != null &&
          widget.preloadedAssets!.isNotEmpty) {
        Logger.debugLog(
          '📦 Loading ${widget.preloadedAssets!.length} preloaded assets',
        );
        await _loadPreloadedAssets(widget.preloadedAssets!);
      } else {
        Logger.debugLog(
          '⚠️ No preloaded assets provided, starting with empty state',
        );
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
        final nexgenSerialNo =
            asset['nexgen_serial_no']?.toString() ??
            asset['mfg_serial_no']?.toString() ??
            '';

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
          // In edit mode, preloaded assets are not modified yet
          // In create mode, new assets are not modified
          'isModified': false,
        };

        // Handle photo data if available (check both snake_case and camelCase)
        final assetUploadItemImages =
            asset['asset_upload_item_images'] ?? asset['assetUploadItemImages'];

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
                'photoTakenTs':
                    (img['photo_taken_ts'] ?? img['photoTakenTs'])
                        ?.toString() ??
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
      Logger.debugLog(
        '✅ Successfully loaded ${_totalAssetCount} assets into ${_assetGroups.length} groups',
      );

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
    final serialNumber = parts
        .sublist(1)
        .join('-'); // Join in case serial has dashes

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
        final fullSerialWithPrefix = 'NG-$fullSerial';

        // Check if this serial number belongs to an existing item in the current asset group
        // If it does, allow it (user is editing the same item)
        final currentItems = _assetGroups[assetType] ?? [];
        final isExistingItemInGroup = currentItems.any((item) {
          final itemFullCode = item['full_scanned_code']?.toString() ?? '';
          final itemSerial = item['mfg_serial_no']?.toString() ?? '';
          final itemNexgenSerial = item['nexgen_serial_no']?.toString() ?? '';

          // Normalize all formats for comparison
          final normalizedSerialNumber = serialNumber.trim().toUpperCase();
          final normalizedItemFullCode = itemFullCode.trim().toUpperCase();
          final normalizedItemNexgen = itemNexgenSerial.trim().toUpperCase();
          final normalizedFullSerial = fullSerial.trim().toUpperCase();
          final normalizedFullSerialWithPrefix = fullSerialWithPrefix
              .trim()
              .toUpperCase();

          // Match by various formats
          if (normalizedItemFullCode == normalizedSerialNumber ||
              normalizedItemFullCode == normalizedFullSerial ||
              normalizedItemFullCode == normalizedFullSerialWithPrefix) {
            return true;
          }

          if (normalizedItemNexgen == normalizedSerialNumber ||
              normalizedItemNexgen == normalizedFullSerial ||
              normalizedItemNexgen == normalizedFullSerialWithPrefix) {
            return true;
          }

          // Also check if we can reconstruct the full code from item
          if (itemSerial.isNotEmpty) {
            final reconstructed = 'NG-$acronym-$itemSerial'.toUpperCase();
            if (reconstructed == normalizedSerialNumber ||
                reconstructed == normalizedFullSerial ||
                reconstructed == normalizedFullSerialWithPrefix) {
              return true;
            }
          }

          // Check if serial number contains the item serial or vice versa
          if (normalizedSerialNumber.contains(itemSerial.toUpperCase()) ||
              normalizedItemFullCode.contains(serialNum.toUpperCase())) {
            return true;
          }

          return false;
        });

        // If it's an existing item in the current group, allow it (editing same item)
        if (isExistingItemInGroup) {
          return true;
        }

        // Check for duplicates (only if not editing existing item)
        // Check both formats: with and without NG- prefix
        if (_scannedSerialNumbers.contains(fullSerial) ||
            _scannedSerialNumbers.contains(fullSerialWithPrefix) ||
            _scannedSerialNumbers.contains(serialNumber.trim().toUpperCase())) {
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
      // Get existing items to check if items were modified
      final existingItems = _assetGroups[assetType] ?? [];

      // Normalize serial numbers to show only the serial part (not NG-ACRONYM-SERIAL)
      // But always preserve full_scanned_code for display
      // IMPORTANT: Preserve ALL fields including photo_id, photoPath, and assetUploadItemImages
      final normalizedItems = items.map((item) {
        final updatedItem = Map<String, dynamic>.from(
          item,
        ); // Copy all fields first (includes assetUploadItemImages)
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

        // Handle isModified flag based on mode and whether item existed
        if (_actualMode == CMScreenModeEnum.edit) {
          // In edit mode, check if this item already existed (has aui_id or item_id)
          final hasExistingId =
              updatedItem['aui_id'] != null &&
              updatedItem['aui_id'] != 0 &&
              updatedItem['aui_id'].toString() != '0';

          // Check if item exists in existing items by matching identifiers
          final itemExists = existingItems.any((existing) {
            final existingAuiId = existing['aui_id'];
            final existingFullCode =
                existing['full_scanned_code']?.toString() ?? '';
            final currentFullCode =
                updatedItem['full_scanned_code']?.toString() ?? '';

            // Match by aui_id if available, or by full_scanned_code
            if (hasExistingId && existingAuiId != null) {
              return existingAuiId.toString() ==
                  updatedItem['aui_id'].toString();
            }
            return existingFullCode == currentFullCode &&
                existingFullCode.isNotEmpty;
          });

          if (itemExists) {
            // Existing item was edited - mark as modified
            updatedItem['isModified'] = true;
            Logger.debugLog(
              '📝 Asset marked as modified: ${updatedItem['full_scanned_code']}',
            );
            print(
              '📝 Asset marked as modified: ${updatedItem['full_scanned_code']}',
            );
          } else {
            // New item added in edit mode - not modified (it's new)
            updatedItem['isModified'] = false;
          }
        } else {
          // Create mode - new items are not modified
          updatedItem['isModified'] = false;
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
        final currentItems = List<Map<String, dynamic>>.from(
          _assetGroups[_editingAssetType!] ?? [],
        );
        // Try to find the old item more accurately
        final oldItemIndex = currentItems.indexWhere((item) {
          final itemSerial = item['mfg_serial_no']?.toString() ?? '';
          final itemFullCode = item['full_scanned_code']?.toString() ?? '';
          final editingFullCode =
              _editingItem?['full_scanned_code']?.toString() ?? '';
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
            return itemSerial == _editingOriginalSerial ||
                itemSerial == serialNum;
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
          updatedItem['assetUploadItemImages'] =
              lastItem['assetUploadItemImages'];
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
          updatedItem['secondDisabledFieldValue'] =
              lastItem['secondDisabledFieldValue'];
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

        // In edit mode, if we're editing an existing item, mark it as modified
        if (_actualMode == CMScreenModeEnum.edit) {
          // Check if the original item had an ID (indicating it existed)
          final originalHasId =
              _editingItem?['aui_id'] != null &&
              _editingItem!['aui_id'] != 0 &&
              _editingItem!['aui_id'].toString() != '0';

          if (originalHasId) {
            // Existing item was edited - mark as modified
            updatedItem['isModified'] = true;
            Logger.debugLog(
              '📝 Asset marked as modified (from edit): ${updatedItem['full_scanned_code']}',
            );
            print(
              '📝 Asset marked as modified (from edit): ${updatedItem['full_scanned_code']}',
            );
          } else {
            // New item added in edit mode - not modified (it's new)
            updatedItem['isModified'] = false;
          }
        } else {
          // Create mode - new items are not modified
          updatedItem['isModified'] = false;
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
          updatedItem['assetUploadItemImages'] =
              lastItem['assetUploadItemImages'];
        }
        // New items are not modified (whether in create or edit mode)
        updatedItem['isModified'] = false;
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
      showCustomToast(
        context,
        'Invalid format. Expected: NG-<ACRONYM>-<SERIAL>',
      );
      Logger.errorLog(
        '⚠️ Could not parse serial number to determine asset type: $fullSerialNumber',
      );
    }
  }

  /// Updates total asset count
  void _updateTotalCount() {
    _totalAssetCount = _assetGroups.values.fold(
      0,
      (sum, items) => sum + items.length,
    );
  }

  /// Gets selfie image ID from preloaded data or storage
  /// Returns String? - can be server ID as string or LOCAL_IMAGE_ID string
  Future<String?> _getSelfieImageId() async {
    try {
      // First check if we have a current selfie image ID (uploaded in this session)
      if (_currentSelfieImageId != null && _currentSelfieImageId!.isNotEmpty) {
        final currentId = _currentSelfieImageId!;
        Logger.debugLog('📸 Found current selfie image ID: $currentId');
        if (currentId != "0" && currentId != "null") {
          if (currentId.contains("LOCAL_IMAGE_ID")) {
            Logger.debugLog(
              '📸 Current ID is LOCAL_IMAGE_ID, returning: $currentId',
            );
            return currentId; // Return LOCAL_IMAGE_ID string
          }
          final parsedId = int.tryParse(currentId);
          if (parsedId != null && parsedId > 0) {
            Logger.debugLog('✅ Using current selfie image ID: $parsedId');
            return currentId; // Return as string to preserve format
          }
        }
      }

      // Second check if preloaded selfie image ID is available
      if (widget.preloadedSelfieImageId != null &&
          widget.preloadedSelfieImageId!.isNotEmpty) {
        final preloadedId = widget.preloadedSelfieImageId!;
        Logger.debugLog('📸 Found preloaded selfie image ID: $preloadedId');
        if (preloadedId != "0" && preloadedId != "null") {
          // Keep LOCAL_IMAGE_ID as string
          if (preloadedId.contains("LOCAL_IMAGE_ID")) {
            Logger.debugLog(
              '📸 Preloaded ID is LOCAL_IMAGE_ID, returning: $preloadedId',
            );
            return preloadedId; // Return LOCAL_IMAGE_ID string
          }
          final parsedId = int.tryParse(preloadedId);
          if (parsedId != null && parsedId > 0) {
            Logger.debugLog('✅ Using preloaded selfie image ID: $parsedId');
            return preloadedId; // Return as string to preserve format
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
        Logger.debugLog(
          '📦 Stored data found, keys: ${storedData.keys.toList()}',
        );
        final pageHeaders = storedData['pageHeader'] as List<dynamic>?;
        final pageHeader = pageHeaders?.isNotEmpty == true
            ? pageHeaders!.first as Map<String, dynamic>?
            : null;

        if (pageHeader != null) {
          Logger.debugLog(
            '📋 Page header found, checking for maker_selfie_image_id',
          );
          Logger.debugLog('📋 Page header keys: ${pageHeader.keys.toList()}');
          Logger.debugLog('📋 Page header full data: $pageHeader');

          // Try both snake_case and camelCase
          final selfieImageIdValue =
              pageHeader['maker_selfie_image_id'] ??
              pageHeader['makerSelfieImageId'];

          if (selfieImageIdValue != null) {
            final selfieImageId = selfieImageIdValue.toString();
            Logger.debugLog(
              '📸 Found selfie image ID in database: $selfieImageId (type: ${selfieImageIdValue.runtimeType})',
            );

            if (selfieImageId.isNotEmpty &&
                selfieImageId != "0" &&
                selfieImageId != "null" &&
                selfieImageId.toLowerCase() != "null") {
              // Keep LOCAL_IMAGE_ID as string
              if (selfieImageId.contains("LOCAL_IMAGE_ID")) {
                Logger.debugLog(
                  '📸 Database ID is LOCAL_IMAGE_ID, returning: $selfieImageId',
                );
                return selfieImageId; // Return LOCAL_IMAGE_ID string
              }
              final parsedId = int.tryParse(selfieImageId);
              if (parsedId != null && parsedId > 0) {
                Logger.debugLog(
                  '✅ Using selfie image ID from database: $parsedId',
                );
                return selfieImageId; // Return as string to preserve format
              } else {
                Logger.debugLog(
                  '⚠️ Failed to parse database ID: $selfieImageId',
                );
                Logger.debugLog(
                  '⚠️ Attempted to parse as int but got null or 0',
                );
              }
            } else {
              Logger.debugLog(
                '⚠️ Database ID is empty, 0, or null: $selfieImageId',
              );
            }
          } else {
            Logger.debugLog(
              '⚠️ maker_selfie_image_id not found in page header',
            );
            Logger.debugLog(
              '⚠️ Available keys in pageHeader: ${pageHeader.keys.toList()}',
            );
          }
        } else {
          Logger.debugLog('⚠️ Page header is null or empty');
          if (pageHeaders != null) {
            Logger.debugLog(
              '⚠️ Page headers list length: ${pageHeaders.length}',
            );
          }
        }
      } else {
        Logger.debugLog(
          '⚠️ No stored data found in database for siteId: ${widget.siteData.siteId}',
        );
      }

      Logger.debugLog('⚠️ No valid selfie image ID found, returning null');
      return null;
    } catch (e) {
      Logger.errorLog('❌ Error getting selfie image ID: $e');
      Logger.errorLog('❌ Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Transforms assets from _assetGroups to AssetUploadItem format
  List<AssetUploadItem> _transformAssetsToApiFormat(LocationModel? location) {
    final List<AssetUploadItem> assetUploadItems = [];

    for (final entry in _assetGroups.entries) {
      final items = entry.value;

      for (final item in items) {
        // Get serial number (prefer full_scanned_code, fallback to mfg_serial_no)
        final nexgenSerialNo =
            item['full_scanned_code']?.toString() ??
            item['mfg_serial_no']?.toString() ??
            '';

        if (nexgenSerialNo.isEmpty) {
          continue; // Skip items without serial number
        }

        // Debug: Log item data to see what's stored
        Logger.debugLog('📦 Item data for $nexgenSerialNo:');
        Logger.debugLog('  - photo_id: ${item['photo_id']}');
        Logger.debugLog(
          '  - assetUploadItemImages: ${item['assetUploadItemImages']}',
        );
        print('📦 Item data for $nexgenSerialNo:');
        print('  - photo_id: ${item['photo_id']}');
        print('  - assetUploadItemImages: ${item['assetUploadItemImages']}');

        // Build assetUploadItemImages from photo data
        final List<AssetUploadItemImage> itemImages = [];

        // Check if assetUploadItemImages already exists (from individual save)
        if (item['assetUploadItemImages'] != null &&
            item['assetUploadItemImages'] is List) {
          final images = item['assetUploadItemImages'] as List<dynamic>;
          Logger.debugLog(
            '📦 Processing ${images.length} images from assetUploadItemImages',
          );
          print(
            '📦 Processing ${images.length} images from assetUploadItemImages',
          );
          for (final img in images) {
            if (img is Map<String, dynamic>) {
              // Handle photoId - can be int (server ID) or string (LOCAL_IMAGE_ID)
              dynamic photoIdValue;
              final photoIdRaw = img['photoId'];
              Logger.debugLog(
                '📸 Raw photoId from img: $photoIdRaw (type: ${photoIdRaw.runtimeType})',
              );
              print(
                '📸 Raw photoId from img: $photoIdRaw (type: ${photoIdRaw.runtimeType})',
              );

              if (photoIdRaw != null) {
                // If it's already a string with LOCAL_IMAGE_ID, use it directly
                if (photoIdRaw is String &&
                    photoIdRaw.contains("LOCAL_IMAGE_ID")) {
                  photoIdValue = photoIdRaw;
                  Logger.debugLog(
                    '📸 Keeping LOCAL_IMAGE_ID as string: $photoIdValue',
                  );
                  print('📸 Keeping LOCAL_IMAGE_ID as string: $photoIdValue');
                } else {
                  // Convert to string first to check
                  final photoIdStr = photoIdRaw.toString();
                  if (photoIdStr.contains("LOCAL_IMAGE_ID")) {
                    // Keep LOCAL_IMAGE_ID as string for offline mode
                    photoIdValue = photoIdStr;
                    Logger.debugLog(
                      '📸 Keeping LOCAL_IMAGE_ID for asset image: $photoIdValue',
                    );
                    print(
                      '📸 Keeping LOCAL_IMAGE_ID for asset image: $photoIdValue',
                    );
                  } else if (photoIdStr == "0" ||
                      photoIdStr == "null" ||
                      photoIdStr.isEmpty ||
                      (photoIdRaw is int && photoIdRaw == 0)) {
                    // Check if we have photo_id in the item as fallback
                    final itemPhotoId = item['photo_id']?.toString();
                    Logger.debugLog(
                      '📸 photoIdRaw is 0/null, checking item photo_id: $itemPhotoId',
                    );
                    print(
                      '📸 photoIdRaw is 0/null, checking item photo_id: $itemPhotoId',
                    );
                    if (itemPhotoId != null &&
                        itemPhotoId.isNotEmpty &&
                        itemPhotoId != "0" &&
                        itemPhotoId != "null" &&
                        itemPhotoId.contains("LOCAL_IMAGE_ID")) {
                      photoIdValue = itemPhotoId;
                      Logger.debugLog(
                        '✅ Using LOCAL_IMAGE_ID from item photo_id: $photoIdValue',
                      );
                      print(
                        '✅ Using LOCAL_IMAGE_ID from item photo_id: $photoIdValue',
                      );
                    } else {
                      photoIdValue = 0;
                      Logger.debugLog(
                        '⚠️ photoId is 0/null/empty, no LOCAL_IMAGE_ID found in item photo_id either',
                      );
                      print(
                        '⚠️ photoId is 0/null/empty, no LOCAL_IMAGE_ID found in item photo_id either',
                      );
                    }
                  } else {
                    // Convert to int for server IDs
                    photoIdValue = int.tryParse(photoIdStr) ?? 0;
                    Logger.debugLog(
                      '📸 Using server ID for asset image: $photoIdValue',
                    );
                  }
                }
              } else {
                // Check if we have photo_id in the item as fallback
                final itemPhotoId = item['photo_id']?.toString();
                Logger.debugLog(
                  '📸 photoIdRaw is null, checking item photo_id: $itemPhotoId',
                );
                print(
                  '📸 photoIdRaw is null, checking item photo_id: $itemPhotoId',
                );
                if (itemPhotoId != null &&
                    itemPhotoId.isNotEmpty &&
                    itemPhotoId != "0" &&
                    itemPhotoId != "null" &&
                    itemPhotoId.contains("LOCAL_IMAGE_ID")) {
                  photoIdValue = itemPhotoId;
                  Logger.debugLog(
                    '✅ Using LOCAL_IMAGE_ID from item photo_id (photoIdRaw was null): $photoIdValue',
                  );
                  print(
                    '✅ Using LOCAL_IMAGE_ID from item photo_id (photoIdRaw was null): $photoIdValue',
                  );
                } else {
                  photoIdValue = 0;
                  Logger.debugLog(
                    '⚠️ No photoId found in image data and no LOCAL_IMAGE_ID in item photo_id',
                  );
                }
              }

              itemImages.add(
                AssetUploadItemImage(
                  auiiId: img['auiiId'] as int?,
                  photoId: photoIdValue,
                  photoTakenTs: Utils.normalizeDateForAPICall(
                    img['photoTakenTs']?.toString() ??
                        item['timestamp']?.toString() ??
                        item['qr_code_scanned_ts']?.toString(),
                  ),
                  longitude:
                      img['longitude']?.toString() ??
                      location?.longitude.toString() ??
                      '',
                  latitude:
                      img['latitude']?.toString() ??
                      location?.latitude.toString() ??
                      '',
                  isActive: img['isActive'] as bool? ?? true,
                  remarks: img['remarks']?.toString() ?? '',
                ),
              );
            }
          }
        } else if (item['photo_id'] != null &&
            item['photo_id'].toString().isNotEmpty) {
          // Convert existing photo_id to AssetUploadItemImage format (fallback for old items)
          final photoId = item['photo_id'].toString();
          dynamic photoIdValue;
          if (photoId.contains("LOCAL_IMAGE_ID")) {
            // Keep LOCAL_IMAGE_ID as string for offline mode
            photoIdValue = photoId;
            Logger.debugLog(
              '📸 Keeping LOCAL_IMAGE_ID from photo_id: $photoIdValue',
            );
            print('📸 Keeping LOCAL_IMAGE_ID from photo_id: $photoIdValue');
          } else {
            // Convert to int for server IDs
            photoIdValue = int.tryParse(photoId) ?? 0;
            Logger.debugLog('📸 Using server ID from photo_id: $photoIdValue');
          }

          // Only add if we have a valid photo ID (either server ID > 0 or LOCAL_IMAGE_ID)
          if ((photoIdValue is int && photoIdValue > 0) ||
              photoId.contains("LOCAL_IMAGE_ID")) {
            itemImages.add(
              AssetUploadItemImage(
                auiiId: 0,
                photoId: photoIdValue,
                photoTakenTs: Utils.normalizeDateForAPICall(
                  item['timestamp']?.toString() ??
                      item['qr_code_scanned_ts']?.toString(),
                ),
                longitude: location?.longitude.toString() ?? '',
                latitude: location?.latitude.toString() ?? '',
                isActive: true,
                remarks: item['remarks']?.toString() ?? '',
              ),
            );
          }
        }

        // Get isModified from item, default to false if not set
        final isModified = item['isModified'] as bool? ?? false;
        Logger.debugLog(
          '📦 Creating AssetUploadItem - Serial: $nexgenSerialNo, isModified: $isModified',
        );
        print(
          '📦 Creating AssetUploadItem - Serial: $nexgenSerialNo, isModified: $isModified',
        );

        // Create AssetUploadItem
        assetUploadItems.add(
          AssetUploadItem(
            auiId: item['aui_id'] != null
                ? (item['aui_id'] is int
                      ? item['aui_id']
                      : int.tryParse(item['aui_id'].toString()))
                : 0,
            auId: 0,
            nexgenSerialNo: nexgenSerialNo,
            itemId: item['item_id'] != null
                ? (item['item_id'] is int
                      ? item['item_id']
                      : int.tryParse(item['item_id'].toString()))
                : 0,
            longitude: location?.longitude.toString() ?? '',
            latitude: location?.latitude.toString() ?? '',
            isActive: true,
            remarks:
                item['remarks']?.toString() ??
                item['disabledFieldValue']?.toString() ??
                '',
            assetUploadItemImages: itemImages,
            isModified: isModified, // Pass isModified flag
          ),
        );
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
      Logger.debugLog(
        '📸 Retrieved selfie image ID for asset upload: $selfieImageId',
      );

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

      // Check connectivity to handle LOCAL_IMAGE_ID properly
      final isConnected = await ConnectivityHelper.isConnected();

      // Transform assets to API format
      final assetUploadItems = _transformAssetsToApiFormat(location);

      if (assetUploadItems.isEmpty) {
        LoaderWidget.hideLoader();
        Toastbar.showErrorToastbar('No valid assets to save', context);
        return;
      }

      // Process LOCAL_IMAGE_ID in assetUploadItemImages if online
      // Note: photoId is already handled in _transformAssetsToApiFormat to keep LOCAL_IMAGE_ID as string
      // The repository's toJson() will handle converting it properly

      // Handle makerSelfieImageId - keep LOCAL_IMAGE_ID as string if offline
      dynamic finalSelfieImageId;
      if (selfieImageId == null || selfieImageId.isEmpty) {
        finalSelfieImageId = 0;
      } else if (selfieImageId.contains("LOCAL_IMAGE_ID")) {
        if (isConnected) {
          // Online: try to upload and get server ID
          try {
            final imageModel = await ServiceLocator().imageUploadService
                .getServerIdFromUniqueIdTryUploading(selfieImageId);
            if (imageModel != null && imageModel.serverId != null) {
              finalSelfieImageId =
                  int.tryParse(imageModel.serverId.toString()) ?? 0;
              Logger.debugLog(
                '✅ Converted LOCAL_IMAGE_ID to server ID for selfie: $finalSelfieImageId',
              );
            } else {
              // Keep as LOCAL_IMAGE_ID string if upload fails
              finalSelfieImageId = selfieImageId;
              Logger.debugLog(
                '⚠️ Failed to upload selfie, keeping LOCAL_IMAGE_ID',
              );
            }
          } catch (e) {
            Logger.errorLog('❌ Error uploading selfie: $e');
            finalSelfieImageId = selfieImageId;
          }
        } else {
          // Offline: keep as LOCAL_IMAGE_ID string
          finalSelfieImageId = selfieImageId;
          Logger.debugLog(
            '📸 Offline mode: Keeping LOCAL_IMAGE_ID for selfie: $finalSelfieImageId',
          );
        }
      } else {
        // Already a server ID string - convert to int
        finalSelfieImageId = int.tryParse(selfieImageId) ?? 0;
        Logger.debugLog('📸 Using server ID for selfie: $finalSelfieImageId');
      }

      Logger.debugLog('📤 ========== ASSET UPLOAD REQUEST ==========');
      Logger.debugLog('📤 siteId: ${widget.siteData.siteId}');
      Logger.debugLog('📤 entityId: ${widget.siteData.entityId}');
      Logger.debugLog(
        '📤 makerSelfieImageId: $finalSelfieImageId (type: ${finalSelfieImageId.runtimeType})',
      );
      Logger.debugLog('📤 isConnected: $isConnected');
      Logger.debugLog(
        '📤 preloadedSelfieImageId: ${widget.preloadedSelfieImageId}',
      );
      Logger.debugLog('📤 currentSelfieImageId: $_currentSelfieImageId');
      Logger.debugLog('📤 assetUploadItems count: ${assetUploadItems.length}');
      Logger.debugLog('📤 ===========================================');

      // Use preloaded auId if available (for updates), otherwise use 0 (for new uploads)
      final auId = widget.preloadedAuId ?? 0;
      Logger.debugLog(
        '📤 Using auId: $auId (${auId == 0 ? "new upload" : "update"})',
      );

      // Check if offline - if so, save to local storage
      if (!isConnected) {
        await _saveOffline(
          auId: auId,
          siteId: widget.siteData.siteId,
          entityId: widget.siteData.entityId,
          makerSelfieImageId: finalSelfieImageId,
          assetUploadItems: assetUploadItems,
        );
        return;
      }

      // Online - submit to API
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
        Toastbar.showSuccessToastbar('Assets saved successfully', context);
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
        Toastbar.showErrorToastbar(errorMessage, context);
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

  /// Saves asset upload data to local storage when offline
  Future<void> _saveOffline({
    required int auId,
    required int siteId,
    required int entityId,
    required dynamic makerSelfieImageId,
    required List<AssetUploadItem> assetUploadItems,
  }) async {
    try {
      Logger.debugLog('💾 Saving asset upload data to offline storage...');

      // Build request data matching the API format
      final requestData = <String, dynamic>{
        'auId': auId,
        'siteId': siteId,
        'entityId': entityId,
        'makerSelfieImageId': makerSelfieImageId,
        'isActive': true,
        'remarks': '',
        'assetUploadItems': assetUploadItems
            .map((item) => item.toJson())
            .toList(),
      };

      // Create a unique request ID for this asset upload submission
      final requestId =
          'asset_upload_${siteId}_${DateTime.now().millisecondsSinceEpoch}';

      // Convert request to JSON and wrap in list (as expected by sync service)
      final requestList = [requestData];

      // Save to pending requests for sync when online
      final url = 'api/v1/mobile/assetUpload';
      final isSaved = await ServiceLocator().pendingRequestService
          .savePendingRequest(
            requestId: requestId,
            url: url,
            headers: {},
            jsonEncodedRequestData: jsonEncode(requestList),
          );

      LoaderWidget.hideLoader();

      if (isSaved && mounted) {
        Logger.infoLog('✅ Asset upload data saved to offline storage');
        Toastbar.showSuccessToastbar(
          'Data saved offline. Will sync when online.',
          context,
        );

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
      } else if (!isSaved) {
        throw Exception('Failed to save asset upload data to offline storage');
      }
    } catch (e) {
      LoaderWidget.hideLoader();
      Logger.errorLog('❌ Error saving asset upload data offline: $e');
      if (mounted) {
        Toastbar.showErrorToastbar(
          'Failed to save data offline: ${e.toString()}',
          context,
        );
      }
    }
  }

  /// Handles editing an item from scanned assets table
  /// This will populate the initial scan section at the top for editing
  void _handleEditItemFromScannedAssets(
    Map<String, dynamic> item,
    String assetType,
  ) {
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
        color: Colors.white.withOpacity(0.1),
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
  Widget _buildAssetTypeSection(
    String assetType,
    List<Map<String, dynamic>> items,
  ) {
    final isExpanded = _sectionExpandedState[assetType] ?? true;
    final itemCount = items.length;
    final controller = _getControllerForAssetType(assetType);

    return Column(
      children: [
        // Section header (collapsible) - outside the box
        InkWell(
          onTap: () {
            setState(() {
              // If opening this section, close all others
              if (!isExpanded) {
                // Close all other sections
                for (final key in _sectionExpandedState.keys) {
                  if (key != assetType) {
                    _sectionExpandedState[key] = false;
                  }
                }
              }
              // Toggle current section
              _sectionExpandedState[assetType] = !isExpanded;
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),

        // Section content (shown when expanded) - table in transparent box
        if (isExpanded)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AssetUploadFormComponent(
                key: ValueKey(
                  '$assetType-${items.length}-${items.map((i) => i['photo_id']?.toString() ?? '').join('-')}',
                ), // Force rebuild when items or photos change
                componentId: assetType,
                serialLabel: 'Scan Asset',
                serialHintText: 'Serial Number',
                photoLabel: 'Add a Photo',
                serialController: controller,
                initialSavedItems: items,
                onItemSaved: (savedItems) =>
                    _onItemSaved(assetType, savedItems),
                onEditItem: (item) =>
                    _handleEditItemFromScannedAssets(item, assetType),
                customValidator: _createValidatorForAssetType(assetType),
                customValidationErrorMessage:
                    'Invalid format, wrong asset type, or duplicate serial number',
                siteAuditSchId: widget.siteData.siteId.toString(),
                showTable: true,
                showForm:
                    false, // Hide form section, only show table for scanned assets
                tableTitle: null, // No title needed as we have section header
              ),
            ),
          ),
      ],
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
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(color: Colors.white, thickness: 0.5, height: 1),
        ),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(color: Colors.white, thickness: 0.5, height: 1),
        ),
        const SizedBox(height: 8),
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
                  decoration: BoxDecoration(color: Colors.transparent),
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
                            backgroundColor: AppColors.dashboardIconBoxColor,
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
                              color: AppColors.buttonColorSite,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleSaveAsset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dashboardIconBoxColor,
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
                              color: AppColors.buttonColorSite,
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
