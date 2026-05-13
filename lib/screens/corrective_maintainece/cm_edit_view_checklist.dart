// checklist calling in view mode

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';
import '../../commonWidgets/custom_form_field.dart'
    show CustomFormField, InputType;
import '../../commonWidgets/custom_image_upload_field.dart';
import '../../services/service_locator.dart';
import '../../utils/connectivity_helper.dart';
import '../../utils/logger.dart';
import '../../enum/activity_type_enum.dart';

class CMEditViewChecklistWidget extends StatefulWidget {
  final String equipmentType;
  final List<dynamic> checklistItemsByApi;
  final String? entityId;
  final Function(List<dynamic>)? onChecklistDataChanged;
  final Function(List<Map<String, dynamic>>) onImpactedItemListChanged;
  final List<Map<String, dynamic>> cmImpactedItemList;
  final Map<String, dynamic> originalCmImpactedItemMap;
  final Function(List<Map<String, dynamic>>, String)
      onMultiDynamicDropdownValueChanged;
  final bool isEditMode; // true for edit, false for view

  const CMEditViewChecklistWidget({
    super.key,
    required this.equipmentType,
    required this.checklistItemsByApi,
    this.entityId,
    this.onChecklistDataChanged,
    required this.onImpactedItemListChanged,
    required this.cmImpactedItemList,
    required this.originalCmImpactedItemMap,
    required this.onMultiDynamicDropdownValueChanged,
    this.isEditMode = false, // Default to view mode
  });

  @override
  State<CMEditViewChecklistWidget> createState() =>
      _CMEditViewChecklistWidgetState();
}

class _CMEditViewChecklistWidgetState
    extends State<CMEditViewChecklistWidget> {
  static const TextStyle _sectionLabelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    fontFamily: fontFamilyMontserrat,
  );
  static const TextStyle _fieldValueStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.color555555,
    fontFamily: fontFamilyMontserrat,
  );
  static const TextStyle _impactedTableHeaderStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    fontFamily: fontFamilyMontserrat,
  );
  static const TextStyle _impactedTableCellStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.color555555,
    fontFamily: fontFamilyMontserrat,
  );

  late List<Map<String, dynamic>> _checklistItems;
  Map<String, String?> _loadedImages =
      {}; // Store loaded image data by checklist ID or impacted item ID
  Map<String, Map<String, String?>> _impactedItemImages =
      {}; // Store images for impacted items: serialNo -> {checklistId -> imageData}

  /// Serial numbers often contain `-` (e.g. NG-BATT-770644); composite keys must not use `-`.
  static const String _impactedImageKeySep = '@@';

  String _makeImpactedImageKey(String serialNo, String checklistId) =>
      '$serialNo$_impactedImageKeySep$checklistId';

  void _storeImpactedImageFromCompositeKey(String compositeKey, String imageData) {
    final i = compositeKey.indexOf(_impactedImageKeySep);
    if (i <= 0 || i + _impactedImageKeySep.length >= compositeKey.length) {
      return;
    }
    final serialNo = compositeKey.substring(0, i);
    final checklistId = compositeKey.substring(i + _impactedImageKeySep.length);
    _impactedItemImages[serialNo] ??= {};
    _impactedItemImages[serialNo]![checklistId] = imageData;
  }

  @override
  void initState() {
    super.initState();
    _initializeChecklistData(); // Call async function without await in initState
  }

  @override
  void didUpdateWidget(CMEditViewChecklistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checklistItemsByApi != widget.checklistItemsByApi ||
        oldWidget.equipmentType != widget.equipmentType) {
      _initializeChecklistData(); // Call async function without await in didUpdateWidget
    }
  }

  Future<void> _initializeChecklistData() async {
    try {
      final data = widget.checklistItemsByApi;

      Logger.infoLog('[CM EditView] Initializing checklist data, received ${data.length} items');
      
      // Convert the data to the format expected for rendering
      _checklistItems = data.map((item) {
        final Map<String, dynamic> checklistItem =
            Map<String, dynamic>.from(item);

        // Preserve all response data from API
        // resp, cmCheckListSiteRespImagesList, cmImpactedItemList, etc.
        // These come from the merged API response
        
        // Explicitly preserve cmImpactedItemList if it exists
        if (item['cmImpactedItemList'] != null) {
          checklistItem['cmImpactedItemList'] = item['cmImpactedItemList'];
        }
        if (item['cm_impacted_item_list'] != null) {
          checklistItem['cm_impacted_item_list'] = item['cm_impacted_item_list'];
        }
        
        // Debug: Log the resp value for each item
        final resp = checklistItem['resp'];
        final respType = checklistItem['respType']?.toString() ?? 
                        checklistItem['resp_type']?.toString() ?? '';
        final checklistDesc = checklistItem['checklistDesc']?.toString() ?? 
                             checklistItem['checklist_desc']?.toString() ?? '';
        final hasImpactedItems = checklistItem['cmImpactedItemList'] != null || 
                                checklistItem['cm_impacted_item_list'] != null;
        Logger.infoLog('[CM EditView] Item: $checklistDesc, respType: $respType, resp: $resp, hasImpactedItems: $hasImpactedItems');
        
        if (respType == 'DYNAMIC_DROPDOWN' ||
            respType == 'MULTI_DYNAMIC_DROPDOWN' ||
            hasImpactedItems) {
          final impactedList = checklistItem['cmImpactedItemList'] ??
              checklistItem['cm_impacted_item_list'] ??
              [];
          Logger.infoLog(
              '[CM EditView] Impacted-item checklist in init - $checklistDesc, respType: $respType, impactedList type: ${impactedList.runtimeType}, isList: ${impactedList is List}, length: ${impactedList is List ? impactedList.length : "N/A"}');
        }

        return checklistItem;
      }).toList();

      // Sort by cl_order
      _checklistItems.sort((a, b) {
        final orderA = a['cl_order'] as int? ?? a['clOrder'] as int? ?? 0;
        final orderB = b['cl_order'] as int? ?? b['clOrder'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

      Logger.infoLog('[CM EditView] Processed ${_checklistItems.length} checklist items after sorting');

      // Load images for items that have cmCheckListSiteRespImagesList
      await _loadImagesForChecklistItems();
      
      // Load images for impacted items (any row with cmImpactedItemList)
      await _loadImagesForImpactedItems();
    } catch (e) {
      Logger.errorLog('[CM EditView] Error initializing checklist data: $e');
    }
  }

  Future<void> _loadImagesForChecklistItems() async {
    for (var item in _checklistItems) {
      final imagesList = item['cmCheckListSiteRespImagesList'] ??
          item['cm_check_list_site_resp_images_list'];

      // Check if imagesList is not null and has items
      if (imagesList != null && imagesList is List && imagesList.isNotEmpty) {
        final checklistId = item['cmCheckListMstId']?.toString() ??
            item['cm_check_list_mst_id']?.toString() ??
            item['cmCheckListSiteRespId']?.toString() ??
            item['cm_check_list_site_resp_id'] ??
            '';
        
        final respType = item['respType']?.toString() ?? 
                        item['resp_type']?.toString() ?? '';
        final checklistDesc = item['checklistDesc']?.toString() ?? 
                             item['checklist_desc']?.toString() ?? '';
        
        Logger.infoLog('[CM EditView] Loading images for item: $checklistDesc, respType: $respType, checklistId: $checklistId, imagesCount: ${imagesList.length}');

        for (var imageData in imagesList) {
          if (imageData is Map<String, dynamic>) {
            final photoId = imageData['photoId'] ?? imageData['photo_id'];
            if (photoId != null && checklistId.isNotEmpty) {
              // Use unique key for each image: checklistId-photoId
              final imageKey = '$checklistId-${photoId.toString()}';
              Logger.infoLog('[CM EditView] Loading image with photoId: $photoId, imageKey: $imageKey, checklistId: $checklistId');
              await _loadImageForItem(
                photoId.toString(),
                imageKey, // Use unique key instead of just checklistId
              );
              
              // Log after loading to verify
              final loadedImageAfter = _loadedImages[imageKey];
              Logger.infoLog('[CM EditView] After loading - imageKey: $imageKey, loaded: ${loadedImageAfter != null ? "YES (${loadedImageAfter.length} chars)" : "NO"}');
            }
          }
        }
      }
    }
    
    Logger.infoLog('[CM EditView] Finished loading images. Total loaded: ${_loadedImages.length}');
  }

  Future<void> _loadImagesForImpactedItems() async {
    for (var item in _checklistItems) {
      final impactedItems = item['cmImpactedItemList'] ??
          item['cm_impacted_item_list'] ??
          [];

      if (impactedItems is List && impactedItems.isNotEmpty) {
        for (var impactedItem in impactedItems) {
          if (impactedItem is Map<String, dynamic>) {
            final mfgSerialNo = impactedItem['mfgSerialNo']?.toString() ??
                impactedItem['mfg_serial_no']?.toString() ??
                '';
            final imagesList = impactedItem['cmCheckListSiteRespImagesList'] ??
                impactedItem['cm_check_list_site_resp_images_list'] ??
                [];

            if (mfgSerialNo.isNotEmpty && imagesList is List && imagesList.isNotEmpty) {
              for (var imageData in imagesList) {
                if (imageData is Map<String, dynamic>) {
                  final photoId = imageData['photoId'] ?? imageData['photo_id'];
                  final cmCheckListMstId = impactedItem['cmCheckListMstId']?.toString() ??
                      impactedItem['cm_check_list_mst_id']?.toString() ??
                      '';

                  if (photoId != null && cmCheckListMstId.isNotEmpty) {
                    final imageKey =
                        _makeImpactedImageKey(mfgSerialNo, cmCheckListMstId);
                    await _loadImageForImpactedItem(
                      photoId.toString(),
                      imageKey,
                    );
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Future<void> _loadImageForItem(String photoId, String checklistId) async {
    try {
      Logger.infoLog('[CM EditView] Starting to load image - photoId: $photoId, checklistId: $checklistId');
      
      final imageService = ServiceLocator().imageUploadService;
      final cachedBase64 =
          await imageService.resolveImageBase64ForPhotoRef(photoId);

      if (cachedBase64 != null && cachedBase64.isNotEmpty && mounted) {
        Logger.infoLog('[CM EditView] Image loaded from local cache - photoId: $photoId, checklistId: $checklistId, imageData length: ${cachedBase64.length}');
        setState(() {
          _loadedImages[checklistId] = cachedBase64;
        });
        return;
      }

      // Try to download if online
      final isOnline = await ConnectivityHelper.isConnected();
      if (isOnline) {
        Logger.infoLog('[CM EditView] Image not in cache, downloading from server - photoId: $photoId');
        
        // Download image from server and save to SQLite (downloadImageUsingServerId does both)
        final uniqueId = await ServiceLocator().imageUploadService
            .downloadImageUsingServerId(
          photoId,
          ActivityTypeEnum.correctiveMaintenance,
          widget.entityId ?? '',
        );

        if (uniqueId != null) {
          Logger.infoLog('[CM EditView] Image downloaded and saved to SQLite - photoId: $photoId, uniqueId: $uniqueId, retrieving base64 data...');
          
          // Retrieve base64 image data from SQLite using uniqueId
          final imageData = await ServiceLocator().imageUploadService
              .getImageUsingUniqueId(uniqueId);

          if (imageData != null && imageData.isNotEmpty && mounted) {
            Logger.infoLog('[CM EditView] ✅ Image loaded successfully - photoId: $photoId, checklistId: $checklistId, imageData length: ${imageData.length}, first 50 chars: ${imageData.substring(0, imageData.length > 50 ? 50 : imageData.length)}');
            setState(() {
              _loadedImages[checklistId] = imageData;
            });
          } else {
            Logger.errorLog('[CM EditView] ❌ Image data is null or empty after download - photoId: $photoId, checklistId: $checklistId, uniqueId: $uniqueId, imageData: ${imageData != null ? "EXISTS but empty" : "NULL"}, mounted: $mounted');
          }
        } else {
          Logger.errorLog('[CM EditView] ❌ Failed to download image - photoId: $photoId, downloadImageUsingServerId returned null');
        }
      } else {
        Logger.infoLog('[CM EditView] ⚠️ No internet connection, cannot download image - photoId: $photoId');
      }
    } catch (e, stackTrace) {
      Logger.errorLog('[CM EditView] ❌ Error loading image $photoId: $e');
      Logger.errorLog('[CM EditView] Stack trace: $stackTrace');
    }
  }

  /// Load image for impacted item and return the image data directly
  Future<String?> _loadImageForImpactedItem(String photoId, String imageKey) async {
    try {
      Logger.infoLog('[CM EditView] Starting to load impacted item image - photoId: $photoId, imageKey: $imageKey');
      
      final imageService = ServiceLocator().imageUploadService;
      final cachedBase64 =
          await imageService.resolveImageBase64ForPhotoRef(photoId);

      if (cachedBase64 != null && cachedBase64.isNotEmpty) {
        Logger.infoLog('[CM EditView] Impacted item image loaded from local cache - photoId: $photoId, imageKey: $imageKey, imageData length: ${cachedBase64.length}');
        if (mounted) {
          setState(() {
            _storeImpactedImageFromCompositeKey(imageKey, cachedBase64);
          });
        }
        return cachedBase64;
      }

      // Try to download if online
      final isOnline = await ConnectivityHelper.isConnected();
      if (isOnline) {
        Logger.infoLog('[CM EditView] Impacted item image not in cache, downloading from server - photoId: $photoId');
        
        // Download image from server and save to SQLite (downloadImageUsingServerId does both)
        final uniqueId = await ServiceLocator().imageUploadService
            .downloadImageUsingServerId(
          photoId,
          ActivityTypeEnum.correctiveMaintenance,
          widget.entityId ?? '',
        );

        if (uniqueId != null) {
          Logger.infoLog('[CM EditView] Impacted item image downloaded and saved to SQLite - photoId: $photoId, uniqueId: $uniqueId, retrieving base64 data...');
          
          // Retrieve base64 image data from SQLite using uniqueId
          final imageData = await ServiceLocator().imageUploadService
              .getImageUsingUniqueId(uniqueId);

          if (imageData != null && imageData.isNotEmpty && mounted) {
            Logger.infoLog('[CM EditView] ✅ Impacted item image loaded successfully - photoId: $photoId, imageKey: $imageKey, imageData length: ${imageData.length}');
            setState(() {
              _storeImpactedImageFromCompositeKey(imageKey, imageData);
            });
            return imageData;
          } else {
            Logger.errorLog('[CM EditView] ❌ Impacted item image data is null or empty after download - photoId: $photoId, imageKey: $imageKey, uniqueId: $uniqueId, imageData: ${imageData != null ? "EXISTS but empty" : "NULL"}, mounted: $mounted');
            return null;
          }
        } else {
          Logger.errorLog('[CM EditView] ❌ Failed to download impacted item image - photoId: $photoId, downloadImageUsingServerId returned null');
          return null;
        }
      } else {
        Logger.infoLog('[CM EditView] ⚠️ No internet connection, cannot download impacted item image - photoId: $photoId');
        return null;
      }
    } catch (e, stackTrace) {
      Logger.errorLog('[CM EditView] ❌ Error loading impacted item image $photoId: $e');
      Logger.errorLog('[CM EditView] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Load image for impacted item on demand (when camera icon is clicked) and return the image data
  Future<String?> _loadImageForImpactedItemOnDemand(
    String photoId,
    String serialNo,
    String checklistId,
  ) async {
    final imageKey = _makeImpactedImageKey(serialNo, checklistId);

    // Check if already loaded
    String? existingImageData = _impactedItemImages[serialNo]?[checklistId];
    if (existingImageData != null && existingImageData.isNotEmpty) {
      Logger.infoLog('[CM EditView] Image already loaded for impacted item - photoId: $photoId, imageKey: $imageKey');
      return existingImageData;
    }
    
    // Load the image and get the returned image data directly
    final loadedImageData = await _loadImageForImpactedItem(photoId, imageKey);
    
    if (loadedImageData != null && loadedImageData.isNotEmpty) {
      Logger.infoLog('[CM EditView] Successfully loaded impacted item image on demand - photoId: $photoId, imageKey: $imageKey, length: ${loadedImageData.length}');
      return loadedImageData;
    } else {
      Logger.errorLog('[CM EditView] Failed to load impacted item image on demand - photoId: $photoId, imageKey: $imageKey');
      return null;
    }
  }

  /// Load and show image for impacted item when camera icon is clicked
  Future<void> _loadAndShowImageForImpactedItem(
    BuildContext context,
    String serialNo,
    String checklistId,
    Map<String, dynamic> childResponse,
  ) async {
    final imagesList = childResponse['cmCheckListSiteRespImagesList'] ??
        childResponse['cm_check_list_site_resp_images_list'];
    
    if (imagesList != null && imagesList is List && imagesList.isNotEmpty) {
      final firstImage = imagesList.first;
      if (firstImage is Map<String, dynamic>) {
        final photoId = firstImage['photoId'] ?? firstImage['photo_id'];
        if (photoId != null) {
          // Try to load the image (returns image data if successful)
          final imageData = await _loadImageForImpactedItemOnDemand(
            photoId.toString(),
            serialNo,
            checklistId,
          );
          
          // Show image viewer
          if (imageData != null && imageData.isNotEmpty && context.mounted) {
            _showPhotoViewer(context, imageData);
          } else if (context.mounted) {
            // Show loading or error message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image is loading, please try again in a moment.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    }
  }

  bool _isLocalImageFilePath(String s) {
    final t = s.trim();
    if (t.startsWith('file://')) return true;
    if (t.startsWith('/data/') || t.startsWith('/storage/')) return true;
    if (t.contains('LOCAL_IMAGE_ID')) return true;
    return false;
  }

  String _normalizeLocalImagePath(String s) {
    final t = s.trim();
    if (t.startsWith('file://')) {
      return Uri.parse(t).toFilePath();
    }
    return t;
  }

  /// Build image widget from base64 data or local file path (cached images).
  Widget _buildImageWidget(String? imageData, {double? height, double? width}) {
    if (imageData == null || imageData.isEmpty) {
      return Container(
        height: height ?? 150,
        width: width,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.image, color: Colors.grey),
        ),
      );
    }

    if (_isLocalImageFilePath(imageData)) {
      final path = _normalizeLocalImagePath(imageData);
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            height: height ?? 150,
            width: width,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: height ?? 150,
                width: width,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              );
            },
          ),
        );
      }
    }

    try {
      // Handle data URL format
      String base64String = imageData;
      if (imageData.startsWith('data:image')) {
        final parts = imageData.split(',');
        if (parts.length >= 2) {
          base64String = parts[1];
        }
      }

      final bytes = base64Decode(base64String);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          height: height ?? 150,
          width: width,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: height ?? 150,
              width: width,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            );
          },
        ),
      );
    } catch (e) {
      Logger.errorLog('[CM EditView] Error building image widget: $e');
      return Container(
        height: height ?? 150,
        width: width,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    }
  }

  /// Shows photo viewer dialog (base64 / data URL, or on-disk path from image cache).
  Future<void> _showPhotoViewer(BuildContext context, String? imageData) async {
    if (imageData == null || imageData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No photo available to view.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final trimmed = imageData.trim();

    late final Widget imageWidget;

    if (_isLocalImageFilePath(trimmed)) {
      final path = _normalizeLocalImagePath(trimmed);
      final file = File(path);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image file not found on device.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      imageWidget = Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Text(
              'Failed to load image',
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );
    } else {
      String base64Payload = trimmed;
      if (trimmed.startsWith('data:image')) {
        final parts = trimmed.split(',');
        if (parts.length >= 2) {
          base64Payload = parts.sublist(1).join(',');
        }
      }

      try {
        imageWidget = Image.memory(
          base64Decode(base64Payload),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Text(
                'Failed to load image',
                style: TextStyle(color: Colors.white),
              ),
            );
          },
        );
      } catch (e) {
        Logger.errorLog('[CM EditView] _showPhotoViewer decode error: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open image data.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
                  maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
                ),
                child: imageWidget,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get all unique child items from impacted_item_check_list (for column headers)
  List<Map<String, dynamic>> _getAllChildItems(Map<String, dynamic> item) {
    // Try to get from originalCmImpactedItemMap first (template data)
    final parentId = item['cmCheckListMstId'] ?? item['cm_check_list_mst_id'];
    final templateData = widget.originalCmImpactedItemMap[parentId?.toString()] ??
        widget.originalCmImpactedItemMap[parentId];
    
    List<dynamic> childItems = [];
    if (templateData is Map<String, dynamic>) {
      childItems = templateData['impacted_item_check_list'] ??
          templateData['impactedItemCheckList'] ??
          [];
    }
    
    // Fallback: try to get from item itself
    if (childItems.isEmpty) {
      childItems = item['impacted_item_check_list'] ??
          item['impactedItemCheckList'] ??
          [];
    }
    
    // If still empty, extract unique child items from cmImpactedItemList
    // This handles cases where the API response doesn't include impacted_item_check_list
    // but has cmImpactedItemList with the actual data
    if (childItems.isEmpty) {
      final impactedItems = item['cmImpactedItemList'] ??
          item['cm_impacted_item_list'] ??
          [];
      
      if (impactedItems is List && impactedItems.isNotEmpty) {
        // Extract unique child items by cmCheckListMstId
        final Map<int, Map<String, dynamic>> uniqueChildItems = {};
        for (var impactedItem in impactedItems) {
          if (impactedItem is Map<String, dynamic>) {
            final childId = impactedItem['cmCheckListMstId'] as int? ??
                impactedItem['cm_check_list_mst_id'] as int? ??
                0;
            
            if (childId > 0 && !uniqueChildItems.containsKey(childId)) {
              // Create a child item map from the impacted item
              uniqueChildItems[childId] = {
                'cm_check_list_mst_id': childId,
                'cmCheckListMstId': childId,
                'checklist_desc': impactedItem['checklistDesc']?.toString() ??
                    impactedItem['checklist_desc']?.toString() ?? '',
                'checklistDesc': impactedItem['checklistDesc']?.toString() ??
                    impactedItem['checklist_desc']?.toString() ?? '',
                'resp_type': impactedItem['respType']?.toString() ??
                    impactedItem['resp_type']?.toString() ?? '',
                'respType': impactedItem['respType']?.toString() ??
                    impactedItem['resp_type']?.toString() ?? '',
                'cl_order': impactedItem['clOrder'] as int? ??
                    impactedItem['cl_order'] as int? ?? 0,
                'clOrder': impactedItem['clOrder'] as int? ??
                    impactedItem['cl_order'] as int? ?? 0,
              };
            }
          }
        }
        childItems = uniqueChildItems.values.toList();
        Logger.infoLog('[CM EditView] Extracted ${childItems.length} unique child items from cmImpactedItemList');
      }
    }
    
    final result = <Map<String, dynamic>>[];
    for (var childItem in childItems) {
      if (childItem is Map<String, dynamic>) {
        final checklistDesc = childItem['checklist_desc']?.toString() ??
            childItem['checklistDesc']?.toString() ?? '';
        if (checklistDesc.isNotEmpty) {
          result.add(Map<String, dynamic>.from(childItem));
        }
      }
    }
    
    // Sort by cl_order
    result.sort((a, b) {
      final orderA = a['cl_order'] as int? ?? a['clOrder'] as int? ?? 0;
      final orderB = b['cl_order'] as int? ?? b['clOrder'] as int? ?? 0;
      return orderA.compareTo(orderB);
    });
    
    Logger.infoLog('[CM EditView] _getAllChildItems returning ${result.length} child items');
    return _enrichChildItemsFromTemplate(item, result);
  }

  /// Merge checklist template fields (e.g. impacted_item_value_map) into column defs.
  List<Map<String, dynamic>> _enrichChildItemsFromTemplate(
    Map<String, dynamic> parentItem,
    List<Map<String, dynamic>> childItems,
  ) {
    if (childItems.isEmpty) return childItems;

    final parentId =
        parentItem['cmCheckListMstId'] ?? parentItem['cm_check_list_mst_id'];
    final templateData = widget.originalCmImpactedItemMap[parentId?.toString()] ??
        widget.originalCmImpactedItemMap[parentId];

    List<dynamic> templateList = [];
    if (templateData is Map<String, dynamic>) {
      templateList = templateData['impacted_item_check_list'] ??
          templateData['impactedItemCheckList'] ??
          [];
    }
    if (templateList.isEmpty) {
      templateList = parentItem['impacted_item_check_list'] ??
          parentItem['impactedItemCheckList'] ??
          [];
    }

    final templateById = <int, Map<String, dynamic>>{};
    for (final t in templateList) {
      if (t is Map<String, dynamic>) {
        final id = t['cm_check_list_mst_id'] as int? ??
            t['cmCheckListMstId'] as int? ??
            0;
        if (id > 0) templateById[id] = t;
      }
    }

    if (templateById.isEmpty) return childItems;

    return childItems.map((child) {
      final id = child['cm_check_list_mst_id'] as int? ??
          child['cmCheckListMstId'] as int? ??
          0;
      final template = templateById[id];
      if (template == null) return child;
      final merged = Map<String, dynamic>.from(template);
      merged.addAll(child);
      return merged;
    }).toList();
  }

  bool _isSerialImpactedValueMap(String key) {
    final k = key.trim().toLowerCase().replaceAll('_', '');
    return k == 'mfgserialno' ||
        k == 'nexgenserialno' ||
        k.contains('serialno') ||
        k == 'mfgserial' ||
        k == 'nexgenserial';
  }

  bool _isSerialNumberColumn(Map<String, dynamic> childItem) {
    final valueMap = childItem['impacted_item_value_map']?.toString() ??
        childItem['impactedItemValueMap']?.toString() ??
        '';
    if (valueMap.isNotEmpty && _isSerialImpactedValueMap(valueMap)) {
      return true;
    }
    final desc = childItem['checklist_desc']?.toString() ??
        childItem['checklistDesc']?.toString() ??
        '';
    return desc.toLowerCase().contains('s.no');
  }

  String _readImpactedItemField(Map<String, dynamic> data, String fieldKey) {
    if (fieldKey.isEmpty) return '';
    final direct = data[fieldKey];
    if (direct != null && direct.toString().isNotEmpty) {
      return direct.toString();
    }
    if (fieldKey == 'mfg_serial_no' || fieldKey == 'mfgSerialNo') {
      return data['mfgSerialNo']?.toString() ??
          data['mfg_serial_no']?.toString() ??
          '';
    }
    if (fieldKey == 'nexgen_serial_no' || fieldKey == 'nexgenSerialNo') {
      return data['nexgenSerialNo']?.toString() ??
          data['nexgen_serial_no']?.toString() ??
          '';
    }
    return data[fieldKey]?.toString() ?? '';
  }

  /// Value for a child column; null => use respType-based logic.
  String? _resolveImpactedCellValue({
    required Map<String, dynamic> childItem,
    required String serialNo,
    required Map<int, Map<String, dynamic>> childResponses,
    required int childId,
  }) {
    final valueMap = childItem['impacted_item_value_map']?.toString() ??
        childItem['impactedItemValueMap']?.toString() ??
        '';
    final isSerialColumn = _isSerialNumberColumn(childItem);

    if (valueMap.isNotEmpty || isSerialColumn) {
      final response = childResponses[childId];
      if (valueMap.isNotEmpty && response != null) {
        final fromField = _readImpactedItemField(response, valueMap);
        if (fromField.isNotEmpty) return fromField;
      }
      if (isSerialColumn || _isSerialImpactedValueMap(valueMap)) {
        return serialNo;
      }
      return response?['resp']?.toString() ?? '';
    }
    return null;
  }

  /// Build impacted-items table (same layout as DYNAMIC_DROPDOWN).
  /// When nested under a CHECKBOX_NUMERIC parent row, pass [showChecklistTitle]: false to avoid duplicating the parent question title.
  Widget _buildDynamicDropdownTable(
    Map<String, dynamic> item, {
    bool showChecklistTitle = true,
  }) {
    final checklistDesc = item['checklistDesc']?.toString() ??
        item['checklist_desc']?.toString() ??
        '';
    final impactedItems = item['cmImpactedItemList'] ??
        item['cm_impacted_item_list'] ??
        [];
    
    Logger.infoLog('[CM EditView] _buildDynamicDropdownTable called for: $checklistDesc');
    Logger.infoLog('[CM EditView] impactedItems type: ${impactedItems.runtimeType}, isEmpty: ${impactedItems is List ? (impactedItems as List).isEmpty : "not a list"}');
    Logger.infoLog('[CM EditView] impactedItems count: ${impactedItems is List ? (impactedItems as List).length : 0}');
    
    if (impactedItems is! List || impactedItems.isEmpty) {
      Logger.errorLog('[CM EditView] No impacted items found for DYNAMIC_DROPDOWN: $checklistDesc');
      return Text(
        'No data available',
        style: const TextStyle(color: Colors.grey),
      );
    }
    
    // Get all child items for column headers
    final childItems = _getAllChildItems(item);
    Logger.infoLog('[CM EditView] DYNAMIC_DROPDOWN - childItems count: ${childItems.length}');
    
    // If childItems is empty, extract from impactedItems directly
    List<Map<String, dynamic>> finalChildItems = childItems;
    if (childItems.isEmpty && impactedItems is List) {
      Logger.infoLog('[CM EditView] DYNAMIC_DROPDOWN - childItems is empty, extracting from impactedItems');
      final Map<int, Map<String, dynamic>> uniqueChildItems = {};
      for (var impactedItem in impactedItems) {
        if (impactedItem is Map<String, dynamic>) {
          final childId = impactedItem['cmCheckListMstId'] as int? ??
              impactedItem['cm_check_list_mst_id'] as int? ??
              0;
          
          if (childId > 0 && !uniqueChildItems.containsKey(childId)) {
            uniqueChildItems[childId] = {
              'cm_check_list_mst_id': childId,
              'cmCheckListMstId': childId,
              'checklist_desc': impactedItem['checklistDesc']?.toString() ??
                  impactedItem['checklist_desc']?.toString() ?? '',
              'checklistDesc': impactedItem['checklistDesc']?.toString() ??
                  impactedItem['checklist_desc']?.toString() ?? '',
              'resp_type': impactedItem['respType']?.toString() ??
                  impactedItem['resp_type']?.toString() ?? '',
              'respType': impactedItem['respType']?.toString() ??
                  impactedItem['resp_type']?.toString() ?? '',
              'cl_order': impactedItem['clOrder'] as int? ??
                  impactedItem['cl_order'] as int? ?? 0,
              'clOrder': impactedItem['clOrder'] as int? ??
                  impactedItem['cl_order'] as int? ?? 0,
            };
          }
        }
      }
      finalChildItems = uniqueChildItems.values.toList();
      // Sort by cl_order
      finalChildItems.sort((a, b) {
        final orderA = a['cl_order'] as int? ?? a['clOrder'] as int? ?? 0;
        final orderB = b['cl_order'] as int? ?? b['clOrder'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });
      Logger.infoLog('[CM EditView] DYNAMIC_DROPDOWN - Extracted ${finalChildItems.length} child items from impactedItems');
    }

    finalChildItems = _enrichChildItemsFromTemplate(item, finalChildItems);
    
    if (finalChildItems.isEmpty) {
      Logger.errorLog('[CM EditView] DYNAMIC_DROPDOWN - No child items found for table columns');
      return Text(
        'No child items found for table',
        style: const TextStyle(color: Colors.grey),
      );
    }
    
    // Group impacted items by mfgSerialNo
    final Map<String, List<Map<String, dynamic>>> groupedBySerial = {};
    for (var impactedItem in impactedItems) {
      if (impactedItem is Map<String, dynamic>) {
        final mfgSerialNo = impactedItem['mfgSerialNo']?.toString() ??
            impactedItem['mfg_serial_no']?.toString() ??
            '';
        Logger.infoLog('[CM EditView] DYNAMIC_DROPDOWN - impactedItem mfgSerialNo: $mfgSerialNo');
        if (mfgSerialNo.isNotEmpty) {
          groupedBySerial[mfgSerialNo] ??= [];
          groupedBySerial[mfgSerialNo]!.add(Map<String, dynamic>.from(impactedItem));
        } else {
          Logger.errorLog('[CM EditView] DYNAMIC_DROPDOWN - mfgSerialNo is empty for impactedItem');
        }
      }
    }
    
    Logger.infoLog('[CM EditView] DYNAMIC_DROPDOWN - groupedBySerial keys: ${groupedBySerial.keys.toList()}, count: ${groupedBySerial.length}');
    
    if (groupedBySerial.isEmpty) {
      Logger.errorLog('[CM EditView] DYNAMIC_DROPDOWN - No serial numbers found after grouping');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            checklistDesc,
            style: _sectionLabelStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'No serial numbers found',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      );
    }
    
    // Create a map for quick lookup: serialNo -> {childId -> response}
    final serialToChildResponses = <String, Map<int, Map<String, dynamic>>>{};
    for (var entry in groupedBySerial.entries) {
      final serialNo = entry.key;
      final items = entry.value;
      serialToChildResponses[serialNo] = {};
      
      for (var impactedItem in items) {
        final childId = impactedItem['cmCheckListMstId'] as int? ??
            impactedItem['cm_check_list_mst_id'] as int? ??
            0;
        if (childId > 0) {
          serialToChildResponses[serialNo]![childId] = impactedItem;
        }
      }
    }
    
    Logger.infoLog('[CM EditView] DYNAMIC_DROPDOWN - Building card list with ${finalChildItems.length} columns and ${groupedBySerial.length} rows');

    final serialKeys = groupedBySerial.keys.toList()..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final mq = MediaQuery.sizeOf(context).width;
        final viewportW = (constraints.maxWidth.isFinite && constraints.maxWidth > 0)
            ? constraints.maxWidth
            : mq;

        const double minDataColW = 118;
        final int nData = finalChildItems.length;
        final double intrinsicMin = nData * minDataColW + 32;
        final double contentMinW = math.max(intrinsicMin, viewportW * 1.08);

        const headerStyle = _impactedTableHeaderStyle;
        const cellTextStyle = _impactedTableCellStyle;

        Widget headerRow() {
          return Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...finalChildItems.map((childItem) {
                  final title = childItem['checklist_desc']?.toString() ??
                      childItem['checklistDesc']?.toString() ??
                      '';
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        title,
                        style: headerStyle,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }

        Widget rowCard(String serialNo) {
          final childResponses = serialToChildResponses[serialNo] ?? {};

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              elevation: 1,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ...finalChildItems.map((childItem) {
                        final childId =
                            childItem['cm_check_list_mst_id'] as int? ??
                                childItem['cmCheckListMstId'] as int? ??
                                0;
                        final childRespType =
                            childItem['resp_type']?.toString() ??
                                childItem['respType']?.toString() ??
                                '';

                        final childResponse = childResponses[childId];
                        String? cellValue;
                        String? imageData;

                        final mappedValue = _resolveImpactedCellValue(
                          childItem: childItem,
                          serialNo: serialNo,
                          childResponses: childResponses,
                          childId: childId,
                        );

                        if (mappedValue != null) {
                          cellValue = mappedValue;
                        } else if (childResponse != null) {
                          final resp = childResponse['resp'];

                          if (childRespType == 'CHECKBOX') {
                            cellValue = (resp == 'true' ||
                                    resp == true ||
                                    resp == 'True' ||
                                    resp == 'TRUE')
                                ? 'Yes'
                                : 'No';
                          } else if (childRespType == 'CHECKBOX_NUMERIC' ||
                              childRespType == 'CHECKBOX_TEXT') {
                            final numericValue = childResponse['numeric_value']
                                    ?.toString() ??
                                childResponse['numericValue']?.toString() ??
                                childResponse['resp_numeric']?.toString() ??
                                childResponse['respNumeric']?.toString() ??
                                '';
                            final respStr = resp?.toString() ?? '';
                            if (respStr == '0' ||
                                respStr.isEmpty ||
                                resp == false ||
                                respStr.toLowerCase() == 'false') {
                              cellValue = 'No';
                            } else {
                              cellValue = numericValue.isNotEmpty
                                  ? numericValue
                                  : respStr;
                            }
                          } else {
                            cellValue = resp?.toString() ?? '';
                          }

                          final imagesList = childResponse[
                                  'cmCheckListSiteRespImagesList'] ??
                              childResponse[
                                  'cm_check_list_site_resp_images_list'];
                          if (imagesList != null &&
                              imagesList is List &&
                              imagesList.isNotEmpty) {
                            imageData = _impactedItemImages[serialNo]
                                ?[childId.toString()];
                          }
                        }

                        final imagesListForCell = childResponse != null
                            ? (childResponse[
                                    'cmCheckListSiteRespImagesList'] ??
                                childResponse[
                                    'cm_check_list_site_resp_images_list'])
                            : null;
                        final hasImagesForCell = imagesListForCell != null &&
                            imagesListForCell is List &&
                            imagesListForCell.isNotEmpty;

                        final cellChild = _buildImpactedCardCell(
                          context: context,
                          childRespType: childRespType,
                          cellValue: cellValue,
                          childResponse: childResponse,
                          serialNo: serialNo,
                          childId: childId,
                          imageData: imageData,
                          hasImagesForCell: hasImagesForCell,
                          cellTextStyle: cellTextStyle,
                        );

                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            child: Center(child: cellChild),
                          ),
                        );
                      }),
                    ],
                  ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showChecklistTitle) ...[
              Text(
                checklistDesc,
                style: _sectionLabelStyle,
              ),
              const SizedBox(height: 16),
            ],
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.45),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: contentMinW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      headerRow(),
                      ...serialKeys.map(rowCard),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Single cell inside impacted-item card row (checkbox icon vs text vs photo).
  Widget _buildImpactedCardCell({
    required BuildContext context,
    required String childRespType,
    required String? cellValue,
    required Map<String, dynamic>? childResponse,
    required String serialNo,
    required int childId,
    required String? imageData,
    required bool hasImagesForCell,
    required TextStyle cellTextStyle,
  }) {
    final accentGreen = const Color(0xFF2E7D32);

    Widget photoThumbnail() {
      return GestureDetector(
        onTap: () {
          if (imageData != null) {
            _showPhotoViewer(context, imageData);
          } else if (childResponse != null) {
            _loadAndShowImageForImpactedItem(
              context,
              serialNo,
              childId.toString(),
              childResponse,
            );
          }
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: imageData != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _buildImageWidget(
                    imageData,
                    height: 36,
                    width: 36,
                  ),
                )
              : Icon(Icons.photo_outlined, size: 18, color: Colors.grey.shade500),
        ),
      );
    }

    if (childRespType == 'CHECKBOX') {
      final isYes = cellValue == 'Yes';
      final checkIcon = isYes
          ? Icon(Icons.check_circle, color: accentGreen, size: 26)
          : Icon(Icons.remove_circle_outline, color: Colors.grey.shade400, size: 22);

      if (hasImagesForCell && childResponse != null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            checkIcon,
            const SizedBox(width: 8),
            photoThumbnail(),
          ],
        );
      }
      return checkIcon;
    }

    Widget textPart = Text(
      cellValue ?? '—',
      style: cellTextStyle,
      textAlign: TextAlign.center,
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );

    if (hasImagesForCell && childResponse != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 92),
            child: textPart,
          ),
          const SizedBox(width: 6),
          photoThumbnail(),
        ],
      );
    }

    return textPart;
  }
  
  /// Parent CHECKBOX_NUMERIC / CHECKBOX_TEXT: checked when resp is a non-empty, non-zero value (API often sends count in resp).
  bool _isCheckboxNumericParentChecked(dynamic resp) {
    if (resp == null) return false;
    final s = resp.toString();
    if (s.isEmpty || s == '0') return false;
    if (s.toLowerCase() == 'false') return false;
    return true;
  }

  String _checkboxNumericParentDisplayValue(Map<String, dynamic> item, dynamic resp) {
    final nv = item['numeric_value'] ??
        item['numericValue'] ??
        item['resp_numeric'] ??
        item['respNumeric'];
    if (nv != null && nv.toString().isNotEmpty) {
      return nv.toString();
    }
    return resp?.toString() ?? '';
  }

  // Debug method to log item structure
  void _logItemStructure(Map<String, dynamic> item, String context) {
    Logger.infoLog('[CM EditView] $context - Item keys: ${item.keys.toList()}');
    Logger.infoLog('[CM EditView] $context - respType: ${item['respType'] ?? item['resp_type']}');
    Logger.infoLog('[CM EditView] $context - cmImpactedItemList: ${item['cmImpactedItemList'] != null ? "EXISTS" : "NULL"}');
    if (item['cmImpactedItemList'] != null) {
      final impacted = item['cmImpactedItemList'];
      Logger.infoLog('[CM EditView] $context - cmImpactedItemList type: ${impacted.runtimeType}, isList: ${impacted is List}, length: ${impacted is List ? impacted.length : "N/A"}');
    }
  }

  Widget _buildChecklistItem(Map<String, dynamic> item, int index) {
    final respType =
        item['respType']?.toString() ?? item['resp_type']?.toString() ?? '';
    final checklistDesc = item['checklistDesc']?.toString() ??
        item['checklist_desc']?.toString() ??
        '';
    final resp = item['resp'];
    final imagesList = item['cmCheckListSiteRespImagesList'] ??
        item['cm_check_list_site_resp_images_list'] ??
        item['response_images']; // Also check response_images from merge
    
    // Check if imagesList is not null (can be empty list or null)
    final hasImages = imagesList != null && 
                     imagesList is List && 
                     imagesList.isNotEmpty;

    final checklistId = item['cmCheckListMstId']?.toString() ??
        item['cm_check_list_mst_id']?.toString() ??
        item['cmCheckListSiteRespId']?.toString() ??
        item['cm_check_list_site_resp_id']?.toString() ??
        index.toString();
    
    // Check for cmImpactedItemList
    final impactedItems = item['cmImpactedItemList'] ??
        item['cm_impacted_item_list'] ??
        [];
    final hasImpactedItems = impactedItems is List && impactedItems.isNotEmpty;
    
    // Debug logging
    Logger.infoLog('[CM EditView] Building item: $checklistDesc, respType: $respType, resp: $resp, hasImages: $hasImages, hasImpactedItems: $hasImpactedItems, impactedItemsCount: ${impactedItems is List ? impactedItems.length : 0}, checklistId: $checklistId');
    
    if (respType == 'DYNAMIC_DROPDOWN' ||
        respType == 'MULTI_DYNAMIC_DROPDOWN' ||
        hasImpactedItems) {
      Logger.infoLog(
          '[CM EditView] Impacted-item table candidate - checklistDesc: $checklistDesc, respType: $respType, hasImpactedItems: $hasImpactedItems, impactedItems: ${impactedItems is List ? impactedItems.length : "not a list"}');
      _logItemStructure(item, 'impacted-items');
      if (impactedItems is List) {
        Logger.infoLog(
            '[CM EditView] Impacted items details: ${impactedItems.map((i) => i is Map ? '${i['mfgSerialNo'] ?? i['mfg_serial_no']} (${i['checklistDesc'] ?? i['checklist_desc']})' : 'not a map').join(", ")}');
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Render field based on respType - FULLY DYNAMIC
          if (respType == 'NUMERIC' ||
              respType == 'TEXT' ||
              respType == 'DYNAMIC_NUMERIC') ...[
            // Show resp value in text box
            CustomFormField(
              label: checklistDesc,
              initialValue: resp?.toString() ?? '',
              isEditable: false, // Non-editable in both edit and view mode
              inputType: respType == 'NUMERIC' || respType == 'DYNAMIC_NUMERIC'
                  ? InputType.number
                  : InputType.text,
            ),

            // Show images if cmCheckListSiteRespImagesList is not null and has items - use ImageUploadField
            if (hasImages) ...[
              const SizedBox(height: 16),
              ...(imagesList as List).asMap().entries.map((entry) {
                final imgIndex = entry.key;
                final imageData = entry.value;
                final photoId = imageData is Map<String, dynamic> 
                    ? (imageData['photoId'] ?? imageData['photo_id'])?.toString()
                    : null;
                
                // Use unique key for each image: checklistId-photoId
                // IMPORTANT: Use the same checklistId resolution logic as in _loadImagesForChecklistItems
                final itemChecklistId = item['cmCheckListMstId']?.toString() ??
                    item['cm_check_list_mst_id']?.toString() ??
                    item['cmCheckListSiteRespId']?.toString() ??
                    item['cm_check_list_site_resp_id']?.toString() ??
                    checklistId; // Fallback to the one from outer scope
                    
                final imageKey = photoId != null ? '$itemChecklistId-$photoId' : '$itemChecklistId-$imgIndex';
                
                // Try multiple lookup strategies to find the image
                String? loadedImageUrl = _loadedImages[imageKey];
                if (loadedImageUrl == null || loadedImageUrl.isEmpty) {
                  loadedImageUrl = _loadedImages[checklistId];
                }
                if ((loadedImageUrl == null || loadedImageUrl.isEmpty) && photoId != null) {
                  // Try by photoId alone (in case it was stored differently)
                  for (var key in _loadedImages.keys) {
                    if (key.contains(photoId)) {
                      final foundImage = _loadedImages[key];
                      if (foundImage != null && foundImage.isNotEmpty) {
                        loadedImageUrl = foundImage;
                        break;
                      }
                    }
                  }
                }
                
                // Only pass non-null, non-empty image data
                final validImageUrl = (loadedImageUrl != null && loadedImageUrl.isNotEmpty) ? loadedImageUrl : null;
                
                Logger.infoLog('[CM EditView] NUMERIC/TEXT/DYNAMIC_NUMERIC Image lookup - itemChecklistId: $itemChecklistId, checklistId: $checklistId, photoId: $photoId, imageKey: $imageKey, loadedImageUrl: ${validImageUrl != null ? "EXISTS (${validImageUrl.length} chars)" : "NULL/EMPTY"}, available keys: ${_loadedImages.keys.take(5).join(", ")}...');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ImageUploadField(
                    label: null, // No label
                    placeholder: 'Image',
                    isRequired: false,
                    isDisabled: true, // Read-only in edit/view mode
                    externalImageUrl: validImageUrl, // Pass only valid image data (not empty strings)
                    onImageSelected: (File? file) {}, // No-op in edit/view mode
                  ),
                );
              }).toList(),
            ],
          ] else if (respType == 'CHECKBOX') ...[
            // Handle CHECKBOX type
            Row(
              children: [
                Checkbox(
                  value: resp == 'true' ||
                      resp == true ||
                      resp == 'True' ||
                      resp == 'TRUE',
                  onChanged: null, // Non-editable in both edit and view mode
                ),
                Expanded(
                  child: Text(
                    checklistDesc,
                    style: _sectionLabelStyle,
                  ),
                ),
              ],
            ),

            // Show images if cmCheckListSiteRespImagesList is not null and has items - use ImageUploadField
            if (hasImages && imagesList is List) ...[
              const SizedBox(height: 16),
              ...imagesList.asMap().entries.map((entry) {
                final imgIndex = entry.key;
                final imageData = entry.value;
                final photoId = imageData is Map<String, dynamic> 
                    ? (imageData['photoId'] ?? imageData['photo_id'])?.toString()
                    : null;
                
                // Use unique key for each image: checklistId-photoId
                final imageKey = photoId != null ? '$checklistId-$photoId' : '$checklistId-$imgIndex';
                // Try to get loaded image using the unique key
                final loadedImageUrl = _loadedImages[imageKey] ?? _loadedImages[checklistId];
                
                Logger.infoLog('[CM EditView] CHECKBOX Image lookup - checklistId: $checklistId, photoId: $photoId, imageKey: $imageKey, loadedImageUrl: ${loadedImageUrl != null ? "EXISTS (${loadedImageUrl.length} chars)" : "NULL"}');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ImageUploadField(
                    label: null, // No label
                    placeholder: '',
                    isRequired: false,
                    isDisabled: true, // Read-only in edit/view mode
                    externalImageUrl: loadedImageUrl, // Pass loaded image data
                    onImageSelected: (File? file) {}, // No-op in edit/view mode
                  ),
                );
              }).toList(),
            ],
          ] else if (respType == 'CHECKBOX_NUMERIC' ||
              respType == 'CHECKBOX_TEXT') ...[
            // Checkbox + value field (same idea as CMCustomWidget); optional impacted-items table below
            Row(
              children: [
                Checkbox(
                  value: _isCheckboxNumericParentChecked(resp),
                  onChanged: null,
                ),
                Expanded(
                  child: Text(
                    checklistDesc,
                    style: _sectionLabelStyle,
                  ),
                ),
              ],
            ),
            if (_isCheckboxNumericParentChecked(resp)) ...[
              const SizedBox(height: 8),
              CustomFormField(
                label: 'Enter value',
                initialValue: _checkboxNumericParentDisplayValue(item, resp),
                isEditable: false,
                inputType: respType == 'CHECKBOX_NUMERIC'
                    ? InputType.number
                    : InputType.text,
              ),
            ],
            if (hasImages && imagesList is List) ...[
              const SizedBox(height: 16),
              ...imagesList.asMap().entries.map((entry) {
                final imgIndex = entry.key;
                final imageData = entry.value;
                final photoId = imageData is Map<String, dynamic>
                    ? (imageData['photoId'] ?? imageData['photo_id'])?.toString()
                    : null;

                final imageKey =
                    photoId != null ? '$checklistId-$photoId' : '$checklistId-$imgIndex';
                final loadedImageUrl =
                    _loadedImages[imageKey] ?? _loadedImages[checklistId];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ImageUploadField(
                    label: null,
                    placeholder: '',
                    isRequired: false,
                    isDisabled: true,
                    externalImageUrl: loadedImageUrl,
                    onImageSelected: (File? file) {},
                  ),
                );
              }).toList(),
            ],
            if (hasImpactedItems) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  try {
                    Logger.infoLog(
                        '[CM EditView] ✅ Rendering impacted-items table under CHECKBOX_NUMERIC/CHECKBOX_TEXT parent: $checklistDesc');
                    return _buildDynamicDropdownTable(
                      item,
                      showChecklistTitle: false,
                    );
                  } catch (e, stackTrace) {
                    Logger.errorLog(
                        '[CM EditView] ❌ Error building impacted-items table for $checklistDesc: $e');
                    Logger.errorLog('[CM EditView] Stack trace: $stackTrace');
                    return Text(
                      'Error building table: $e',
                      style: const TextStyle(color: Colors.red),
                    );
                  }
                },
              ),
            ],
          ] else if (respType == 'DYNAMIC_DROPDOWN' ||
              respType == 'MULTI_DYNAMIC_DROPDOWN' ||
              (hasImpactedItems &&
                  respType != 'CHECKBOX_NUMERIC' &&
                  respType != 'CHECKBOX_TEXT')) ...[
            // Dynamic impacted-items table only (or types other than CHECKBOX_* that carry cmImpactedItemList)
            Builder(
              builder: (context) {
                try {
                  Logger.infoLog(
                      '[CM EditView] ✅ Rendering impacted-items table for: $checklistDesc (respType: $respType)');
                  Logger.infoLog('[CM EditView] Item keys: ${item.keys.toList()}');
                  Logger.infoLog('[CM EditView] cmImpactedItemList: ${item['cmImpactedItemList'] != null ? "EXISTS" : "NULL"}');
                  Logger.infoLog('[CM EditView] cm_impacted_item_list: ${item['cm_impacted_item_list'] != null ? "EXISTS" : "NULL"}');
                  
                  final tableWidget = _buildDynamicDropdownTable(item);
                  Logger.infoLog('[CM EditView] ✅ Table widget built successfully for: $checklistDesc');
                  return tableWidget;
                } catch (e, stackTrace) {
                  Logger.errorLog('[CM EditView] ❌ Error building impacted-items table for $checklistDesc: $e');
                  Logger.errorLog('[CM EditView] Stack trace: $stackTrace');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checklistDesc,
                        style: _sectionLabelStyle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error building table: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  );
                }
              },
            ),
          ] else ...[
            // Default: show label and resp value for other types (DROPDOWN, RADIO, etc.)
            CustomFormField(
              label: checklistDesc,
              initialValue: resp?.toString() ?? '',
              isEditable: false, // Non-editable in both edit and view mode
            ),

            // Show images if cmCheckListSiteRespImagesList is not null and has items
            if (hasImages && imagesList is List) ...[
              const SizedBox(height: 16),
              ...imagesList.asMap().entries.map((entry) {
                final imgIndex = entry.key;
                final imageData = entry.value;
                final photoId = imageData is Map<String, dynamic> 
                    ? (imageData['photoId'] ?? imageData['photo_id'])?.toString()
                    : null;
                
                // Use unique key for each image: checklistId-photoId
                final imageKey = photoId != null ? '$checklistId-$photoId' : '$checklistId-$imgIndex';
                // Try to get loaded image using the unique key first (since that's how it's stored)
                final loadedImageUrl = _loadedImages[imageKey] ?? _loadedImages[checklistId];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ImageUploadField(
                          label: null, // No label
                          placeholder: '',
                          isRequired: false,
                          isDisabled: true,
                          externalImageUrl: loadedImageUrl,
                          onImageSelected: (File? file) {},
                        ),
                      ),
                      if (loadedImageUrl != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.visibility, color: Colors.white),
                          onPressed: () => _showPhotoViewer(context, loadedImageUrl),
                          tooltip: 'View image',
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text at the top: "checklist calling in view mode"
        // Padding(
        //   padding: const EdgeInsets.only(bottom: 8.0),
        //   child: Text(
        //     'checklist calling in view mode',
        //     style: const TextStyle(
        //       color: Colors.white,
        //       fontSize: 14,
        //       fontStyle: FontStyle.italic,
        //     ),
        //   ),
        // ),

        Container(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._checklistItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final checklistItem = entry.value;
                  return _buildChecklistItem(checklistItem, index);
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
