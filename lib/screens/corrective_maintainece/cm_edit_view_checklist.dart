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
import '../../constants/app_colors.dart';

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
    _initializeChecklistData();
  }

  @override
  void didUpdateWidget(CMEditViewChecklistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checklistItemsByApi != widget.checklistItemsByApi ||
        oldWidget.equipmentType != widget.equipmentType) {
      setState(() {
        _initializeChecklistData();
      });
    }
  }

  void _initializeChecklistData() {
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
        
        // Debug: Log the resp value for each item
        final resp = checklistItem['resp'];
        final respType = checklistItem['respType']?.toString() ?? 
                        checklistItem['resp_type']?.toString() ?? '';
        final checklistDesc = checklistItem['checklistDesc']?.toString() ?? 
                             checklistItem['checklist_desc']?.toString() ?? '';
        Logger.infoLog('[CM EditView] Item: $checklistDesc, respType: $respType, resp: $resp');

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
      _loadImagesForChecklistItems();
      
      // Load images for impacted items in DYNAMIC_DROPDOWN
      _loadImagesForImpactedItems();
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

        for (var imageData in imagesList) {
          if (imageData is Map<String, dynamic>) {
            final photoId = imageData['photoId'] ?? imageData['photo_id'];
            if (photoId != null && checklistId.isNotEmpty) {
              // Use unique key for each image: checklistId-photoId
              final imageKey = '$checklistId-${photoId.toString()}';
              await _loadImageForItem(
                photoId.toString(),
                imageKey, // Use unique key instead of just checklistId
              );
            }
          }
        }
      }
    }
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
      // First check cache
      final cachedImage = await ServiceLocator().imageUploadService
          .getImagesByServerId(photoId);

      if (cachedImage != null && cachedImage.imageData != null) {
        setState(() {
          _loadedImages[checklistId] = cachedImage.imageData;
        });
        return;
      }

      // Try to download if online
      final isOnline = await ConnectivityHelper.isConnected();
      if (isOnline) {
        final uniqueId = await ServiceLocator().imageUploadService
            .downloadImageUsingServerId(
          photoId,
          ActivityTypeEnum.correctiveMaintenance,
          widget.entityId ?? '',
        );

        if (uniqueId != null) {
          final imageData = await ServiceLocator().imageUploadService
              .getImageUsingUniqueId(uniqueId);

          if (imageData != null && mounted) {
            setState(() {
              _loadedImages[checklistId] = imageData;
            });
          }
        }
      }
    } catch (e) {
      Logger.errorLog('[CM EditView] Error loading image $photoId: $e');
    }
  }

  Future<void> _loadImageForImpactedItem(String photoId, String imageKey) async {
    try {
      // First check cache
      final cachedImage = await ServiceLocator().imageUploadService
          .getImagesByServerId(photoId);

      if (cachedImage != null && cachedImage.imageData != null) {
        setState(() {
          final parts = imageKey.split('-');
          if (parts.length >= 2) {
            final serialNo = parts[0];
            final checklistId = parts[1];
            _impactedItemImages[serialNo] ??= {};
            _impactedItemImages[serialNo]![checklistId] = cachedImage.imageData;
          }
        });
        return;
      }

      // Try to download if online
      final isOnline = await ConnectivityHelper.isConnected();
      if (isOnline) {
        final uniqueId = await ServiceLocator().imageUploadService
            .downloadImageUsingServerId(
          photoId,
          ActivityTypeEnum.correctiveMaintenance,
          widget.entityId ?? '',
        );

        if (uniqueId != null) {
          final imageData = await ServiceLocator().imageUploadService
              .getImageUsingUniqueId(uniqueId);

          if (imageData != null && mounted) {
            setState(() {
              final parts = imageKey.split('-');
              if (parts.length >= 2) {
                final serialNo = parts[0];
                final checklistId = parts[1];
                _impactedItemImages[serialNo] ??= {};
                _impactedItemImages[serialNo]![checklistId] = imageData;
              }
            });
          }
        }
      }
    } catch (e) {
      Logger.errorLog('[CM EditView] Error loading impacted item image $photoId: $e');
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
    
    if (impactedItems is! List || impactedItems.isEmpty) {
      return Text(
        'No data available',
        style: const TextStyle(color: Colors.grey),
      );
    }
    
    // Get all child items for column headers
    final childItems = _getAllChildItems(item);
    
    // Group impacted items by mfgSerialNo
    final Map<String, List<Map<String, dynamic>>> groupedBySerial = {};
    for (var impactedItem in impactedItems) {
      if (impactedItem is Map<String, dynamic>) {
        final mfgSerialNo = impactedItem['mfgSerialNo']?.toString() ??
            impactedItem['mfg_serial_no']?.toString() ??
            '';
        if (mfgSerialNo.isNotEmpty) {
          groupedBySerial[mfgSerialNo] ??= [];
          groupedBySerial[mfgSerialNo]!.add(Map<String, dynamic>.from(impactedItem));
        }
      }
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
                const DataColumn(
                  label: Text('Scanned', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                // Dynamic columns based on child items
                ...childItems.map((childItem) {
                  final childChecklistDesc = childItem['checklist_desc']?.toString() ??
                      childItem['checklistDesc']?.toString() ?? '';
                  return DataColumn(
                    label: Text(childChecklistDesc, style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                // Edit column (only in edit mode)
                if (widget.isEditMode)
                  const DataColumn(
                    label: Text('Edit', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
              rows: groupedBySerial.entries.map((entry) {
                final serialNo = entry.key;
                final childResponses = serialToChildResponses[serialNo] ?? {};
                
                // Get first item to check scanned status
                final firstItem = entry.value.isNotEmpty ? entry.value.first : <String, dynamic>{};
                final isScanned = firstItem['isScanned'] == true ||
                    firstItem['is_scanned'] == true;
                
                return DataRow(
                  cells: [
                    // Serial Number cell
                    DataCell(
                      widget.isEditMode
                          ? TextFormField(
                              initialValue: serialNo,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                              onChanged: (value) {
                                // Handle serial number change in edit mode
                              },
                            )
                          : Text(serialNo),
                    ),
                    // Scanned cell
                    DataCell(Text(isScanned ? 'Yes' : 'No')),
                    // Dynamic cells for each child item
                    ...childItems.map((childItem) {
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
                        
                        // Get image data if available
                        final imagesList = childResponse['cmCheckListSiteRespImagesList'] ??
                            childResponse['cm_check_list_site_resp_images_list'] ??
                            [];
                        if (imagesList is List && imagesList.isNotEmpty) {
                          imageData = _impactedItemImages[serialNo]?[childId.toString()];
                        }
                      }
                      
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
                            if (imageData != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: AppColors.color555555,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showPhotoViewer(context, imageData),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    // Edit cell (only in edit mode)
                    if (widget.isEditMode)
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {
                            // TODO: Implement edit functionality
                          },
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(Map<String, dynamic> item, int index) {
    final respType =
        item['respType']?.toString() ?? item['resp_type']?.toString() ?? '';
    final checklistDesc = item['checklistDesc']?.toString() ??
        item['checklist_desc']?.toString() ??
        '';
    final resp = item['resp'];
    final imagesList = item['cmCheckListSiteRespImagesList'] ??
        item['cm_check_list_site_resp_images_list'];
    
    // Check if imagesList is not null (can be empty list or null)
    final hasImages = imagesList != null && 
                     imagesList is List && 
                     imagesList.isNotEmpty;

    final checklistId = item['cmCheckListMstId']?.toString() ??
        item['cm_check_list_mst_id']?.toString() ??
        item['cmCheckListSiteRespId']?.toString() ??
        item['cm_check_list_site_resp_id']?.toString() ??
        index.toString();
    
    // Debug logging
    Logger.infoLog('[CM EditView] Building item: $checklistDesc, respType: $respType, resp: $resp, hasImages: $hasImages');

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
              isEditable: widget.isEditMode, // Editable in edit mode, disabled in view mode
              inputType: respType == 'NUMERIC' || respType == 'DYNAMIC_NUMERIC'
                  ? InputType.number
                  : InputType.text,
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
                
                // Try to get loaded image, or use a unique key for this specific image
                final imageKey = photoId != null ? '$checklistId-$photoId' : '$checklistId-$imgIndex';
                final loadedImageUrl = _loadedImages[checklistId] ?? _loadedImages[imageKey];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ImageUploadField(
                          label: 'Image ${imgIndex + 1}',
                          placeholder: 'Image',
                          isRequired: false,
                          isDisabled: true, // Always disabled in edit/view mode
                          externalImageUrl: loadedImageUrl,
                          onImageSelected: (File? file) {}, // No-op
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
          ] else if (respType == 'CHECKBOX') ...[
            // Handle CHECKBOX type
            Row(
              children: [
                Checkbox(
                  value: resp == 'true' ||
                      resp == true ||
                      resp == 'True' ||
                      resp == 'TRUE',
                  onChanged: widget.isEditMode
                      ? (bool? value) {
                          // Handle checkbox change in edit mode
                        }
                      : null, // Read-only in view mode
                ),
                Expanded(
                  child: Text(
                    checklistDesc,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
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
                
                // Try to get loaded image, or use a unique key for this specific image
                final imageKey = photoId != null ? '$checklistId-$photoId' : '$checklistId-$imgIndex';
                final loadedImageUrl = _loadedImages[checklistId] ?? _loadedImages[imageKey];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ImageUploadField(
                          label: 'Image ${imgIndex + 1}',
                          placeholder: 'Image',
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
          ] else if (respType == 'DYNAMIC_DROPDOWN') ...[
            // Handle DYNAMIC_DROPDOWN type - Build dynamic table
            _buildDynamicDropdownTable(item),
          ] else ...[
            // Default: show label and resp value for other types (DROPDOWN, RADIO, etc.)
            CustomFormField(
              label: checklistDesc,
              initialValue: resp?.toString() ?? '',
              isEditable: widget.isEditMode,
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
                
                // Try to get loaded image, or use a unique key for this specific image
                final imageKey = photoId != null ? '$checklistId-$photoId' : '$checklistId-$imgIndex';
                final loadedImageUrl = _loadedImages[checklistId] ?? _loadedImages[imageKey];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ImageUploadField(
                          label: 'Image ${imgIndex + 1}',
                          placeholder: 'Image',
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
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'checklist calling in view mode',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),

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
