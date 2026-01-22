// checklist calling in view mode

import 'dart:convert';
import 'dart:io';
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
  late List<Map<String, dynamic>> _checklistItems;
  Map<String, String?> _loadedImages =
      {}; // Store loaded image data by checklist ID or impacted item ID
  Map<String, Map<String, String?>> _impactedItemImages =
      {}; // Store images for impacted items: serialNo -> {checklistId -> imageData}

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
        
        if (respType == 'DYNAMIC_DROPDOWN') {
          final impactedList = checklistItem['cmImpactedItemList'] ?? 
                              checklistItem['cm_impacted_item_list'] ?? [];
          Logger.infoLog('[CM EditView] DYNAMIC_DROPDOWN in init - $checklistDesc, impactedList type: ${impactedList.runtimeType}, isList: ${impactedList is List}, length: ${impactedList is List ? impactedList.length : "N/A"}');
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
      
      // Load images for impacted items in DYNAMIC_DROPDOWN
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
      final respType =
          item['respType']?.toString() ?? item['resp_type']?.toString() ?? '';
      
      if (respType == 'DYNAMIC_DROPDOWN') {
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
                      final imageKey = '$mfgSerialNo-$cmCheckListMstId';
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
  }

  Future<void> _loadImageForItem(String photoId, String checklistId) async {
    try {
      Logger.infoLog('[CM EditView] Starting to load image - photoId: $photoId, checklistId: $checklistId');
      
      // First check cache/SQLite by server_id
      final cachedImage = await ServiceLocator().imageUploadService
          .getImagesByServerId(photoId);

      if (cachedImage != null && cachedImage.imageData != null && cachedImage.imageData!.isNotEmpty) {
        Logger.infoLog('[CM EditView] Image loaded from cache/SQLite - photoId: $photoId, checklistId: $checklistId, imageData length: ${cachedImage.imageData!.length}');
        setState(() {
          _loadedImages[checklistId] = cachedImage.imageData;
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
      
      // First check cache/SQLite by server_id
      final cachedImage = await ServiceLocator().imageUploadService
          .getImagesByServerId(photoId);

      if (cachedImage != null && cachedImage.imageData != null && cachedImage.imageData!.isNotEmpty) {
        Logger.infoLog('[CM EditView] Impacted item image loaded from cache/SQLite - photoId: $photoId, imageKey: $imageKey, imageData length: ${cachedImage.imageData!.length}');
        final parts = imageKey.split('-');
        if (parts.length >= 2) {
          final serialNo = parts[0];
          final checklistId = parts[1];
          final imageData = cachedImage.imageData;
          // Update state and return the image data
          if (mounted) {
            setState(() {
              _impactedItemImages[serialNo] ??= {};
              _impactedItemImages[serialNo]![checklistId] = imageData;
            });
          }
          return imageData;
        }
        return null;
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
            final parts = imageKey.split('-');
            if (parts.length >= 2) {
              final serialNo = parts[0];
              final checklistId = parts[1];
              // Update state and return the image data
              setState(() {
                _impactedItemImages[serialNo] ??= {};
                _impactedItemImages[serialNo]![checklistId] = imageData;
              });
            }
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
    final imageKey = '$serialNo-$checklistId';
    
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

  /// Build image widget from base64 data
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

  /// Shows photo viewer dialog
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

    // Ensure proper data URL format
    final finalImageData = imageData.startsWith('data:image/')
        ? imageData
        : 'data:image/jpeg;base64,$imageData';

    // Show photo viewer dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: Image.memory(
                    base64Decode(finalImageData.split(',').last),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    }
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
    return result;
  }

  /// Build DYNAMIC_DROPDOWN table
  Widget _buildDynamicDropdownTable(Map<String, dynamic> item) {
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
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
    
    Logger.infoLog('[CM EditView] DYNAMIC_DROPDOWN - Building table with ${finalChildItems.length} columns and ${groupedBySerial.length} rows');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table title
        Text(
          checklistDesc,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        
        // Data table
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 12,
              columns: [
                const DataColumn(
                  label: Text('Serial Number', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                // Dynamic columns based on child items
                ...finalChildItems.map((childItem) {
                  final childChecklistDesc = childItem['checklist_desc']?.toString() ??
                      childItem['checklistDesc']?.toString() ?? '';
                  return DataColumn(
                    label: Text(childChecklistDesc, style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ],
              rows: groupedBySerial.entries.map((entry) {
                final serialNo = entry.key;
                final childResponses = serialToChildResponses[serialNo] ?? {};
                
                return DataRow(
                  cells: [
                    // Serial Number cell (non-editable in both edit and view mode)
                    DataCell(
                      Text(
                        serialNo,
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ),
                    // Dynamic cells for each child item
                    ...finalChildItems.map((childItem) {
                      final childId = childItem['cm_check_list_mst_id'] as int? ??
                          childItem['cmCheckListMstId'] as int? ??
                          0;
                      final childRespType = childItem['resp_type']?.toString() ??
                          childItem['respType']?.toString() ?? '';
                      
                      final childResponse = childResponses[childId];
                      String? cellValue;
                      String? imageData;
                      
                      if (childResponse != null) {
                        final resp = childResponse['resp'];
                        
                        // Get cell value based on respType
                        if (childRespType == 'CHECKBOX') {
                          cellValue = (resp == 'true' || resp == true || resp == 'True' || resp == 'TRUE')
                              ? 'Yes'
                              : 'No';
                        } else if (childRespType == 'CHECKBOX_NUMERIC' || childRespType == 'CHECKBOX_TEXT') {
                          final numericValue = childResponse['numeric_value']?.toString() ??
                              childResponse['resp_numeric']?.toString() ?? '';
                          if (resp == '0' || resp == null || resp == 'false') {
                            cellValue = 'No';
                          } else {
                            cellValue = numericValue.isNotEmpty ? numericValue : 'Yes';
                          }
                        } else {
                          cellValue = resp?.toString() ?? '';
                        }
                        
                        // Check if images exist (show camera icon if cmCheckListSiteRespImagesList is not null and has items)
                        final imagesList = childResponse['cmCheckListSiteRespImagesList'] ??
                            childResponse['cm_check_list_site_resp_images_list'];
                        final hasImagesForCell = imagesList != null && 
                                                 imagesList is List && 
                                                 imagesList.isNotEmpty;
                        
                        // Try to get loaded image data
                        if (hasImagesForCell) {
                          imageData = _impactedItemImages[serialNo]?[childId.toString()];
                        }
                      }
                      
                      // Get images list for this cell (for camera icon check)
                      final imagesListForCell = childResponse != null
                          ? (childResponse['cmCheckListSiteRespImagesList'] ??
                             childResponse['cm_check_list_site_resp_images_list'])
                          : null;
                      final hasImagesForCell = imagesListForCell != null && 
                                               imagesListForCell is List && 
                                               imagesListForCell.isNotEmpty;
                      
                      return DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                cellValue ?? '',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Show image thumbnail if cmCheckListSiteRespImagesList exists
                            if (hasImagesForCell && childResponse != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  if (imageData != null) {
                                    _showPhotoViewer(context, imageData);
                                  } else if (childResponse != null) {
                                    // Try to load and show image
                                    _loadAndShowImageForImpactedItem(
                                      context,
                                      serialNo,
                                      childId.toString(),
                                      childResponse,
                                    );
                                  }
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: imageData != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: _buildImageWidget(imageData, height: 40, width: 40),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.image,
                                            size: 20,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
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
    
    // Special logging for DYNAMIC_DROPDOWN
    if (respType == 'DYNAMIC_DROPDOWN') {
      Logger.infoLog('[CM EditView] ⚠️ DYNAMIC_DROPDOWN detected - checklistDesc: $checklistDesc, hasImpactedItems: $hasImpactedItems, impactedItems: ${impactedItems is List ? impactedItems.length : "not a list"}');
      _logItemStructure(item, 'DYNAMIC_DROPDOWN');
      if (impactedItems is List) {
        Logger.infoLog('[CM EditView] Impacted items details: ${impactedItems.map((i) => i is Map ? '${i['mfgSerialNo'] ?? i['mfg_serial_no']} (${i['checklistDesc'] ?? i['checklist_desc']})' : 'not a map').join(", ")}');
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
                    style: const TextStyle(color: Colors.white),
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
          ] else if (respType == 'DYNAMIC_DROPDOWN') ...[
            // Handle DYNAMIC_DROPDOWN type - Build dynamic table
            Builder(
              builder: (context) {
                try {
                  Logger.infoLog('[CM EditView] ✅ Rendering DYNAMIC_DROPDOWN table for: $checklistDesc');
                  Logger.infoLog('[CM EditView] Item keys: ${item.keys.toList()}');
                  Logger.infoLog('[CM EditView] cmImpactedItemList: ${item['cmImpactedItemList'] != null ? "EXISTS" : "NULL"}');
                  Logger.infoLog('[CM EditView] cm_impacted_item_list: ${item['cm_impacted_item_list'] != null ? "EXISTS" : "NULL"}');
                  
                  final tableWidget = _buildDynamicDropdownTable(item);
                  Logger.infoLog('[CM EditView] ✅ Table widget built successfully for: $checklistDesc');
                  return tableWidget;
                } catch (e, stackTrace) {
                  Logger.errorLog('[CM EditView] ❌ Error building DYNAMIC_DROPDOWN table for $checklistDesc: $e');
                  Logger.errorLog('[CM EditView] Stack trace: $stackTrace');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checklistDesc,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
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
