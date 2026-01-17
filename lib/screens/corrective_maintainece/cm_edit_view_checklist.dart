// checklist calling in view mode

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
  });

  @override
  State<CMEditViewChecklistWidget> createState() =>
      _CMEditViewChecklistWidgetState();
}

class _CMEditViewChecklistWidgetState extends State<CMEditViewChecklistWidget> {
  late List<Map<String, dynamic>> _checklistItems;
  bool _isExpanded = false;
  Map<String, String?> _loadedImages =
      {}; // Store loaded image data by checklist ID

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

      // Convert the data to the format expected for rendering
      _checklistItems = data.map((item) {
        final Map<String, dynamic> checklistItem = Map<String, dynamic>.from(
          item,
        );

        // Preserve all response data from API
        // resp, cmCheckListSiteRespImagesList, cmImpactedItemList, etc.
        // These come from the merged API response

        return checklistItem;
      }).toList();

      // Sort by cl_order
      _checklistItems.sort((a, b) {
        final orderA = a['cl_order'] as int? ?? a['clOrder'] as int? ?? 0;
        final orderB = b['cl_order'] as int? ?? b['clOrder'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

      // Load images for items that have cmCheckListSiteRespImagesList
      _loadImagesForChecklistItems();
    } catch (e) {
      Logger.errorLog('[CM EditView] Error initializing checklist data: $e');
    }
  }

  Future<void> _loadImagesForChecklistItems() async {
    for (var item in _checklistItems) {
      final imagesList =
          item['cmCheckListSiteRespImagesList'] ??
          item['cm_check_list_site_resp_images_list'] ??
          [];

      if (imagesList is List && imagesList.isNotEmpty) {
        final firstImage = imagesList.first;
        if (firstImage is Map<String, dynamic>) {
          final photoId = firstImage['photoId'] ?? firstImage['photo_id'];
          if (photoId != null) {
            final checklistId =
                item['cmCheckListMstId'] ??
                item['cm_check_list_mst_id'] ??
                item['cmCheckListSiteRespId'] ??
                item['cm_check_list_site_resp_id'];

            if (checklistId != null) {
              await _loadImageForItem(
                photoId.toString(),
                checklistId.toString(),
              );
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

  Widget _buildChecklistItem(Map<String, dynamic> item, int index) {
    final respType =
        item['respType']?.toString() ?? item['resp_type']?.toString() ?? '';
    final checklistDesc =
        item['checklistDesc']?.toString() ??
        item['checklist_desc']?.toString() ??
        '';
    final resp = item['resp'];
    final imagesList =
        item['cmCheckListSiteRespImagesList'] ??
        item['cm_check_list_site_resp_images_list'] ??
        [];

    final checklistId =
        item['cmCheckListMstId']?.toString() ??
        item['cm_check_list_mst_id']?.toString() ??
        item['cmCheckListSiteRespId']?.toString() ??
        item['cm_check_list_site_resp_id']?.toString() ??
        index.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Render field based on respType
          if (respType == 'NUMERIC' ||
              respType == 'TEXT' ||
              respType == 'DYNAMIC_NUMERIC') ...[
            // Show resp value in text box
            CustomFormField(
              label: checklistDesc,
              initialValue: resp?.toString() ?? '',
              isEditable: false, // Read-only in edit/view mode
              inputType: respType == 'NUMERIC' || respType == 'DYNAMIC_NUMERIC'
                  ? InputType.number
                  : InputType.text,
            ),

            // Show images if cmCheckListSiteRespImagesList exists
            if (imagesList is List && imagesList.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...imagesList.asMap().entries.map((entry) {
                final imgIndex = entry.key;
                final loadedImageUrl = _loadedImages[checklistId];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ImageUploadField(
                    label: 'Image ${imgIndex + 1}',
                    placeholder: 'Image',
                    isRequired: false,
                    isDisabled: true, // Read-only in edit/view mode
                    externalImageUrl: loadedImageUrl,
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
                  value:
                      resp == 'true' ||
                      resp == true ||
                      resp == 'True' ||
                      resp == 'TRUE',
                  onChanged: null, // Read-only
                ),
                Expanded(
                  child: Text(
                    checklistDesc,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),

            // Show images if cmCheckListSiteRespImagesList exists
            if (imagesList is List && imagesList.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...imagesList.asMap().entries.map((entry) {
                final imgIndex = entry.key;
                final loadedImageUrl = _loadedImages[checklistId];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ImageUploadField(
                    label: 'Image ${imgIndex + 1}',
                    placeholder: 'Image',
                    isRequired: false,
                    isDisabled: true,
                    externalImageUrl: loadedImageUrl,
                    onImageSelected: (File? file) {},
                  ),
                );
              }).toList(),
            ],
          ] else if (respType == 'DYNAMIC_DROPDOWN') ...[
            // Handle DYNAMIC_DROPDOWN type
            Text(
              checklistDesc,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            // TODO: Render table for DYNAMIC_DROPDOWN with impacted items
            // This would show the table with serial numbers and child responses
            Text(
              'Dynamic Dropdown - Table view (to be implemented)',
              style: const TextStyle(color: Colors.grey),
            ),
          ] else ...[
            // Default: show label and resp value
            CustomFormField(
              label: checklistDesc,
              initialValue: resp?.toString() ?? '',
              isEditable: false,
            ),

            // Show images if cmCheckListSiteRespImagesList exists
            if (imagesList is List && imagesList.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...imagesList.asMap().entries.map((entry) {
                final imgIndex = entry.key;
                final loadedImageUrl = _loadedImages[checklistId];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ImageUploadField(
                    label: 'Image ${imgIndex + 1}',
                    placeholder: 'Image',
                    isRequired: false,
                    isDisabled: true,
                    externalImageUrl: loadedImageUrl,
                    onImageSelected: (File? file) {},
                  ),
                );
              }).toList(),
            ],
          ],
        ],
      ),
    );
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
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
