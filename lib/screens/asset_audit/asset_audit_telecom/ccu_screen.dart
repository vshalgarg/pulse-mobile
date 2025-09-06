import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/battery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/asset_audit_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../repositories/image_repository.dart';
import '../../../app_config.dart';
import 'dart:io';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/qr_screen_form_field.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

class CCUScreen extends StatefulWidget {
  final CategoryData? ccuData;
  final AssetAuditModel? assetAuditData;

  const CCUScreen({super.key, this.ccuData, this.assetAuditData});

  @override
  State<CCUScreen> createState() => _CCUScreenState();
}

class _CCUScreenState extends State<CCUScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedFile;
  String? selectedStatus;
  String? selectedBatteryStatus;
  String? selectedType;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;

  int totalRectifierItems = 6;
  int totalMPPTItems = 6;
  int totalCabinetItems = 6;
  int currentScannedItems = 0;
  List<Map<String, dynamic>> savedRectifierItems = [];
  List<Map<String, dynamic>> savedMPPTItems = [];
  List<Map<String, dynamic>> savedCabinetItems = [];
  Map<String, dynamic> currentFormData = {};
  String? uploadedPhotoPath;

  String? rectifierSerialNumber;
  String? rectifierPhoto;
  int? rectifierPhotoId;
  String? rectifierStatus;

  int? cabinetPhotoId;
  final remarksController = TextEditingController();
  final capacityController = TextEditingController();

  String? mpptSerialNumber;
  String? mpptPhoto;
  int? mpptPhotoId;
  String? mpptStatus;

  final TextEditingController rectifierSerialController =
      TextEditingController();
  final TextEditingController mpptSerialController = TextEditingController();

  int rectifierCardKey = 0;
  int mpptCardKey = 0;

  bool _hasPostedCCUData = false;

  // ===== CHANGE TRACKING SYSTEM =====
  // Track original values for existing items
  Map<String, dynamic> _originalFormData = {};
  
  // Track new items that haven't been posted yet
  List<Map<String, dynamic>> _newItems = [];
  
  // Track modified existing items
  Map<String, dynamic> _modifiedItems = {};
  
  // Track deleted items
  List<String> _deletedItemIds = [];
  
  // Overall change status
  bool get _hasChanges {
    // Check if there are any meaningful changes (not just default values)
    final hasNewItems = _newItems.isNotEmpty;
    final hasModifiedItems = _modifiedItems.entries.any((entry) {
      final originalValue = _originalFormData[entry.key];
      return _hasValueChanged(originalValue, entry.value);
    });
    final hasDeletedItems = _deletedItemIds.isNotEmpty;
    
    final result = hasNewItems || hasModifiedItems || hasDeletedItems;

    return result;
  }
  
  // Track if forms are filled with new data
  bool _isRectifierFormFilled = false;
  bool _isMPPTFormFilled = false;
  // ===== END CHANGE TRACKING SYSTEM =====

  // ===== IMAGE LOADING INFRASTRUCTURE =====
  late ImageRepository _imageService;
  Map<int, String> _imageCache = {};
  Set<int> _loadingImages = {};
  // ===== END IMAGE LOADING INFRASTRUCTURE =====

  String _getCCUCapacity() {
    if (widget.assetAuditData == null) {
      return '';
    }

    final ccuData = widget.assetAuditData!.responseData.ccu;
    if (ccuData != null) {
      final cabinetItems = ccuData.ccuCabinet ?? [];
      if (cabinetItems.isNotEmpty) {
        final firstItem = cabinetItems.first;
        return firstItem.capacity ?? '';
      }
    }

    return '';
  }

  String _getCCUOEMName() {
    if (widget.assetAuditData != null) {
      final ccuData = widget.assetAuditData!.responseData.ccu;
      if (ccuData != null) {
        final assets = ccuData.assets;
      if (assets.isNotEmpty) {
        final firstAsset = assets.first;
        if (firstAsset.oemName != null && firstAsset.oemName!.isNotEmpty) {
          return firstAsset.oemName!;
        }
      }
      }
    }
    return '';
  }

  int? _getAssetAuditSiteRespId(String itemType) {
    if (widget.assetAuditData == null) {
      return null;
    }



    final ccuData = widget.assetAuditData!.responseData.ccu;
    if (ccuData != null) {
      final assets = ccuData.assets;
    if (assets.isNotEmpty) {
      for (int i = 0; i < assets.length; i++) {
        var asset = assets[i];

        if (asset.itemType == itemType ||
            (itemType == 'CCU Cabinet' && asset.itemType == 'CCU') ||
            (itemType == 'CCU Rectifiers' && asset.itemType == 'CCU') ||
            (itemType == 'CCU MPPT' && asset.itemType == 'CCU')) {
          return asset.assetAuditSiteRespId;
        }
      }
    }

    switch (itemType) {
      case 'CCU Cabinet':
          final ccuCabinetItems = ccuData.ccuCabinet ?? [];

        if (ccuCabinetItems.isNotEmpty) {
          final firstItem = ccuCabinetItems.first;
          return firstItem.assetAuditSiteRespId;
        }
        break;

      case 'CCU Rectifiers':
          final ccuRectifierItems = ccuData.ccuRectifiers ?? [];

        if (ccuRectifierItems.isNotEmpty) {
          final firstItem = ccuRectifierItems.first;
          return firstItem.assetAuditSiteRespId;
        }
        break;

      case 'CCU MPPT':
          final ccuMpptItems = ccuData.ccuMppt ?? [];

        if (ccuMpptItems.isNotEmpty) {
          final firstItem = ccuMpptItems.first;
          return firstItem.assetAuditSiteRespId;
        }
        break;
      }
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);

    if (!_hasDataToShow()) {
      // Use post frame callback to avoid build context issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToBatteryScreen();
      });
      return;
    }

    capacityController.text = _getCCUCapacity();

    // Initialize image service
    _imageService = ImageRepository(AppConfig.of(context).apiProvider);

    _loadCCUData();
    
    // Initialize change tracking system
    _initializeChangeTracking();
  }

  bool _hasDataToShow() {
    if (widget.assetAuditData == null) {
      return false;
    }

    final ccuData = widget.assetAuditData!.responseData.ccu;
    if (ccuData == null) {
        return false;
    }

    final hasRectifierItems = (ccuData.ccuRectifiers?.length ?? 0) > 0;
    final hasMpptItems = (ccuData.ccuMppt?.length ?? 0) > 0;
    final hasCabinetItems = (ccuData.ccuCabinet?.length ?? 0) > 0;
    final hasGeneralAssets = ccuData.assets.isNotEmpty;
    final hasRemarks = ccuData.remarks.isNotEmpty;

    // Check if there are any items to show
    final hasAnyItems =
        hasRectifierItems ||
        hasMpptItems ||
        hasCabinetItems ||
        hasGeneralAssets ||
        hasRemarks;

    return hasAnyItems;
  }

  /// Load images for saved items using the image API
  void _loadImagesForSavedItems() async {
    Set<int> photoIds = {};
    
    // Add photo IDs from rectifier items
    for (var item in savedRectifierItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId']);
      }
    }
    
    // Add photo IDs from MPPT items
    for (var item in savedMPPTItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId']);
      }
    }
    
    // Add photo IDs from cabinet items
    for (var item in savedCabinetItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId']);
      }
    }
    
    if (photoIds.isEmpty) {

      return;
    }
    

    try {
      // Mark images as loading
      setState(() {
        _loadingImages.addAll(photoIds);
      });
      
      // Fetch images from API
      final imageMap = await _imageService.fetchImagesByIds(photoIds.toList());
      
      // Update cache and remove loading state
      setState(() {
        _imageCache.addAll(imageMap);
        _loadingImages.removeAll(photoIds);
      });

    } catch (e) {

      setState(() {
        _loadingImages.removeAll(photoIds);
      });
    }
  }

  /// Build photo column for saved items list
  Widget _buildPhotoColumn(Map<String, dynamic> item) {
    final photoId = item['photoId'];
    
    if (photoId == null) {
      return Icon(
        Icons.photo_camera_outlined,
        color: AppColors.greyColor,
        size: 20,
      );
    }
    
    // Check if image is cached
    final imageData = _imageCache[photoId];
    if (imageData != null) {
      return GestureDetector(
        onTap: () => _showImageDialog(imageData),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.green7, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Base64ImageWidget(
              base64Data: imageData,
              width: 30,
              height: 30,
              boxFit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    
    // Show camera icon if no image data
    return Icon(
      Icons.photo_camera,
      color: AppColors.green7,
      size: 20,
    );
  }

  /// Show image in full screen dialog
  void _showImageDialog(String imageData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              AppBar(
                title: Text('Image View'),
                actions: [
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: Base64ImageWidget(
                  base64Data: imageData,
                  boxFit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToBatteryScreen() {

    // Check if we're just editing existing items (which shouldn't block navigation)
    if (_isJustEditingExistingItems()) {
      _saveEditedItemsAndNavigate();
      return;
    }
    
    if (!_hasChanges) {
    pushPage(
      context,
      BatteryScreen(
        batteryData: widget.assetAuditData?.responseData.battery,
        assetAuditData: widget.assetAuditData,
      ),
    );
      return;
    }
    
    // Check if the changes are just form fields that don't need validation
    if (_areChangesJustFormFields()) {

      _saveFormFieldsAndNavigate();
      return;
    }
    

    _showChangesConfirmationDialog();
  }

  void _loadCCUData() {
    if (!_hasDataToShow()) {
      return;
    }

    if (widget.assetAuditData != null) {
      setState(() {
        // Access CCU data from the correct typed structure
        final ccuData = widget.assetAuditData!.responseData.ccu;
        if (ccuData != null) {
          // Clear existing saved items to avoid duplicates
          savedRectifierItems.clear();
          savedMPPTItems.clear();
          savedCabinetItems.clear();
          currentScannedItems = 0;

          // Load CCU Rectifiers
          final rectifierItems = ccuData.ccuRectifiers ?? [];
          for (var item in rectifierItems) {
            Map<String, dynamic> savedItem = {
              'serialNumber':
                  item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
              'photo': null,
              'photoId': item.photoId,
              'status': item.assetStatus ?? 'Unknown',
              'timestamp': DateTime.now(),
              'isQRCodeScanned': item.qrCodeScanned ?? false,
              'itemType': item.itemType ?? 'Unknown',
              'remarks': item.itemTypeRemark ?? 'CCU Rectifier Item',
              'assetStatus': item.assetStatus,
              'assetAuditSiteRespId': item.assetAuditSiteRespId,

              // Full API response details
              'asset_audit_site_resp_id': item.assetAuditSiteRespId,
              'site_audit_sch_id': item.siteAuditSchId,
              'item_instance_id': item.itemInstanceId,
              'oem_name': item.oemName,
              'nexgen_serial_no': item.nexgenSerialNo,
              'mfg_serial_no': item.mfgSerialNo,
              'qr_code_scanned': item.qrCodeScanned ?? false,
              'qr_code_scanned_ts': item.qrCodeScannedTs,
              'image_name': item.imageName,
              'longitude': item.longitude,
              'latitude': item.latitude,
              'capacity': item.capacity,
              'item_type_group': item.itemTypeGroup,
              'record_type': item.recordType,
              'item_type_remark': item.itemTypeRemark,
            };
            savedRectifierItems.add(savedItem);
            currentScannedItems++;
          }

          // Load CCU MPPT
          final mpptItems = ccuData.ccuMppt ?? [];
          for (var item in mpptItems) {
            Map<String, dynamic> savedItem = {
              'serialNumber':
                  item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
              'photo': null,
              'photoId': item.photoId,
              'status': item.assetStatus ?? 'Unknown',
              'timestamp': DateTime.now(),
              'isQRCodeScanned': item.qrCodeScanned ?? false,
              'itemType': item.itemType ?? 'Unknown',
              'remarks': item.itemTypeRemark ?? 'CCU MPPT Item',
              'assetStatus': item.assetStatus,
              'assetAuditSiteRespId': item.assetAuditSiteRespId,

              // Full API response details
              'asset_audit_site_resp_id': item.assetAuditSiteRespId,
              'site_audit_sch_id': item.siteAuditSchId,
              'item_instance_id': item.itemInstanceId,
              'oem_name': item.oemName,
              'nexgen_serial_no': item.nexgenSerialNo,
              'mfg_serial_no': item.mfgSerialNo,
              'qr_code_scanned': item.qrCodeScanned ?? false,
              'qr_code_scanned_ts': item.qrCodeScannedTs,
              'image_name': item.imageName,
              'longitude': item.longitude,
              'latitude': item.latitude,
              'capacity': item.capacity,
              'item_type_group': item.itemTypeGroup,
              'record_type': item.recordType,
              'item_type_remark': item.itemTypeRemark,
            };
            savedMPPTItems.add(savedItem);
            currentScannedItems++;
          }

          // Load CCU Cabinet
          final cabinetItems = ccuData.ccuCabinet ?? [];
          for (var item in cabinetItems) {
            Map<String, dynamic> savedItem = {
              'serialNumber':
                  item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
              'photo': null,
              'photoId': item.photoId,
              'status': item.assetStatus ?? 'Unknown',
              'timestamp': DateTime.now(),
              'isQRCodeScanned': item.qrCodeScanned ?? false,
              'itemType': item.itemType ?? 'Unknown',
              'remarks': item.itemTypeRemark ?? 'CCU Cabinet Item',
              'assetStatus': item.assetStatus,
              'assetAuditSiteRespId': item.assetAuditSiteRespId,

              // Full API response details
              'asset_audit_site_resp_id': item.assetAuditSiteRespId,
              'site_audit_sch_id': item.siteAuditSchId,
              'item_instance_id': item.itemInstanceId,
              'oem_name': item.oemName,
              'nexgen_serial_no': item.nexgenSerialNo,
              'mfg_serial_no': item.mfgSerialNo,
              'qr_code_scanned': item.qrCodeScanned ?? false,
              'qr_code_scanned_ts': item.qrCodeScannedTs,
              'image_name': item.imageName,
              'longitude': item.longitude,
              'latitude': item.latitude,
              'capacity': item.capacity,
              'item_type_group': item.itemTypeGroup,
              'record_type': item.recordType,
              'item_type_remark': item.itemTypeRemark,
            };
            savedCabinetItems.add(savedItem);
            currentScannedItems++;
          }

          // Load general CCU assets
          final generalAssets = ccuData.assets;
          for (var item in generalAssets) {
            Map<String, dynamic> savedItem = {
              'serialNumber':
                  item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
              'photo': null,
              'photoId': item.photoId,
              'status': item.assetStatus ?? 'Unknown',
              'timestamp': DateTime.now(),
              'isQRCodeScanned': item.qrCodeScanned ?? false,
              'itemType': item.itemType ?? 'Unknown',
              'remarks': item.itemTypeRemark ?? 'CCU Item',
              'assetStatus': item.assetStatus,
              'assetAuditSiteRespId': item.assetAuditSiteRespId,

              // Full API response details
              'asset_audit_site_resp_id': item.assetAuditSiteRespId,
              'site_audit_sch_id': item.siteAuditSchId,
              'item_instance_id': item.itemInstanceId,
              'oem_name': item.oemName,
              'nexgen_serial_no': item.nexgenSerialNo,
              'mfg_serial_no': item.mfgSerialNo,
              'qr_code_scanned': item.qrCodeScanned ?? false,
              'qr_code_scanned_ts': item.qrCodeScannedTs,
              'image_name': item.imageName,
              'longitude': item.longitude,
              'latitude': item.latitude,
              'capacity': item.capacity,
              'item_type_group': item.itemTypeGroup,
              'record_type': item.recordType,
              'item_type_remark': item.itemTypeRemark,
            };

            // Add to appropriate list based on item type
            if (item.itemType?.contains('Rectifier') == true) {
              savedRectifierItems.add(savedItem);
              currentScannedItems++;
            } else if (item.itemType?.contains('MPPT') == true) {
              savedMPPTItems.add(savedItem);
              currentScannedItems++;
            } else if (item.itemType?.contains('Cabinet') == true) {
              savedCabinetItems.add(savedItem);
              currentScannedItems++;
            }
          }

          // Update counts based on actual data
          totalRectifierItems = savedRectifierItems.length;
          totalMPPTItems = savedMPPTItems.length;

          // Load remarks data
          final remarks = ccuData.remarks;
        if (remarks.isNotEmpty) {
          for (var remark in remarks) {
              if (remark.itemTypeRemark != null &&
                  remark.itemTypeRemark!.isNotEmpty) {
                remarksController.text = remark.itemTypeRemark!;
                break; // Use the first valid remark
              }
            }
          }
        }
      });
      
      // Load images for saved items
      _loadImagesForSavedItems();
    }
  }

  @override
  void dispose() {
    serialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      // Trigger rebuild when form changes
    });
  }

  void _saveAndExit() async {
    Navigator.of(context).pop();

    await Future.delayed(const Duration(milliseconds: 200));

    if (!_hasDataToShow()) {
      if (mounted) {
        _navigateToBatteryScreen();
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) => SuccessDialog(
          ticketId: "UVORKJR00044",
          message:
              "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
          onDone: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      );
    }
  }

  bool _isFormValid() {
    if (!_hasDataToShow()) {
      return true;
    }

    setState(() {
      showValidationErrors = true;
    });

    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : null;

    if (serialNumber == null || serialNumber.isEmpty) {
      return false;
    }

    // Check if photo is added
    String? photo = rectifierPhoto ?? mpptPhoto;
    if (photo == null || photo.isEmpty) {
      return false;
    }

    int? photoId = rectifierPhotoId ?? mpptPhotoId;
    if (photo != null && photoId == null) {
      return false;
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)

    return true;
  }

  bool _validateForm() {
    if (!_hasDataToShow()) {
      return true;
    }

    final serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : null;

    if (serialNumber == null || serialNumber.isEmpty) {
      return false;
    }

    // Check if photo is added
    String? photo = rectifierPhoto ?? mpptPhoto;
    if (photo == null || photo.isEmpty) {
      return false;
    }

    // Note: status is not required since it comes from API
    // and is set to true by default (backendStatus: true)
    String? status = rectifierStatus ?? mpptStatus;

    return true;
  }

  void _saveRectifierForm() {
    // If there's no data to show, don't save
    if (!_hasDataToShow()) {
      return;
    }

    if (savedRectifierItems.length >= totalRectifierItems) {
      showCustomToast(
        context,
        'Maximum number of Rectifier items ($totalRectifierItems) already added.',
      );
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': rectifierSerialNumber,
          'photo': rectifierPhoto,
          'photoId': rectifierPhotoId,
          // Include the photoId from API
          'status': rectifierStatus ?? "OK",
          // Default to "OK" if null (since it comes from API)
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          // Track if this was QR scanned or manual entry (false for manual entry)
          'itemType': 'CCU Rectifier',
          // Add item type for better tracking
          'remarks': remarksController.text.isNotEmpty
              ? remarksController.text
              : 'CCU Rectifier Item',
          // Add remarks for API
          'assetStatus': rectifierStatus ?? "OK",
          // Map to assetStatus field
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('CCU Rectifiers'),
          // Get ID from GET API response
        };

        // Add to saved rectifier items list
        savedRectifierItems.add(currentFormData);
        currentScannedItems++;

        // Clear AssetTypeCard form for next entry
        rectifierSerialNumber = null;
        rectifierPhoto = null;
        rectifierPhotoId = null;
        rectifierStatus = null;

        // Clear the controller
        rectifierSerialController.clear();

        // Force rebuild of the CustomInfoCard widget
        rectifierCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      // Show success message
      int remainingRectifiers =
          totalRectifierItems - savedRectifierItems.length;
      showCustomToast(
        context,
        'Rectifier item saved successfully! ${remainingRectifiers > 0 ? '(${remainingRectifiers} remaining)' : '(All items added)'}',
      );
    } else {
      // Form validation failed
    }
  }

  void _saveMPPTForm() {
    // If there's no data to show, don't save
    if (!_hasDataToShow()) {
      return;
    }

    if (savedMPPTItems.length >= totalMPPTItems) {
      showCustomToast(
        context,
        'Maximum number of MPPT items ($totalMPPTItems) already added.',
      );
      return;
    }

    // Check if photo is selected but photoId is not yet available
    if (mpptPhoto != null && mpptPhotoId == null) {
      showCustomToast(
        context,
        'Please wait for photo upload to complete before saving.',
      );
      return;
    }

    if (_isFormValid()) {
      setState(() {
        // Create a map of current form data
        Map<String, dynamic> currentFormData = {
          'serialNumber': mpptSerialNumber,
          'photo': mpptPhoto,
          'photoId': mpptPhotoId,
          'status': mpptStatus ?? "OK",
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false,
          'itemType': 'CCU MPPT',
          'remarks': remarksController.text.isNotEmpty
              ? remarksController.text
              : 'CCU MPPT Item',
          'assetStatus': mpptStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('CCU MPPT'),
        };

        // Add to saved MPPT items list
        savedMPPTItems.add(currentFormData);
        currentScannedItems++;

        // Clear AssetTypeCard form for next entry
        mpptSerialNumber = null;
        mpptPhoto = null;
        mpptPhotoId = null;
        mpptStatus = null;

        // Clear the controller
        mpptSerialController.clear();

        // Force rebuild of the CustomInfoCard widget
        mpptCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      // Show success message
      int remainingMPPTs = totalMPPTItems - savedMPPTItems.length;
      showCustomToast(
        context,
        'MPPT item saved successfully! ${remainingMPPTs > 0 ? '(${remainingMPPTs} remaining)' : '(All items added)'}',
      );
    } else {
      // Form validation failed
    }
  }

  bool _isAllItemsScanned() {
    // If there's no data to show, return true
    if (!_hasDataToShow()) {
      return true;
    }

    return (savedRectifierItems.length >= totalRectifierItems) &&
        (savedMPPTItems.length >= totalMPPTItems);
  }

  /// Automatically save cabinet item when photo is uploaded
  void _autoSaveCabinetItem() {
    if (!_hasDataToShow()) {
      return;
    }

    // Check if we have a photo path
    if (uploadedPhotoPath == null || uploadedPhotoPath!.isEmpty) {
      return;
    }

    // Check if we have a photo ID
    if (cabinetPhotoId == null) {
      return;
    }

    // Check if cabinet item already exists
    bool cabinetExists = savedCabinetItems.any(
      (item) => item['itemType'] == 'CCU Cabinet' || item['itemType'] == 'CCU',
    );

    if (cabinetExists) {
      return;
    }

    // Create cabinet item
    Map<String, dynamic> cabinetItem = {
      'serialNumber': 'CCU Cabinet',
      'photo': uploadedPhotoPath,
      'photoId': cabinetPhotoId,
      'status': 'OK',
      'timestamp': DateTime.now(),
      'isQRCodeScanned': false,
      'itemType': 'CCU Cabinet',
      'remarks': 'CCU Cabinet',
      'assetStatus': 'OK',
      'assetAuditSiteRespId': _getAssetAuditSiteRespId('CCU Cabinet'),
    };

    setState(() {
      savedCabinetItems.add(cabinetItem);
      currentScannedItems++;
    });

    showCustomToast(context, 'Cabinet item auto-saved successfully!');
  }

  /// Clear the cabinet form for next entry
  void _clearCabinetForm() {
    // If there's no data to show, don't clear form
    if (!_hasDataToShow()) {
      return;
    }

    setState(() {
      uploadedPhotoPath = null;
      cabinetPhotoId = null;
      serialController.clear();
      capacityController.clear();
      hasUnsavedChanges = false;
    });
  }

  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    if (widget.assetAuditData == null) return false;

    // If there's no data to show, validation fails
    if (!_hasDataToShow()) return false;

    final ccuData = widget.assetAuditData!.responseData.ccu;
    if (ccuData == null) return false;

    if (isQRCodeScanned) {
      // For QR code scans, validate against nexgen_serial_no
      // First check assets data
      final assets = ccuData.assets;
      if (assets.isNotEmpty) {
        final isValid = assets.any(
          (asset) =>
              asset.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
        );

        if (isValid) {
          showCustomToast(context, 'QR Code validated successfully!');
          return true;
        }
      }

      // Fallback to category data
      final allItems = [
        ...(ccuData.ccuCabinet ?? []),
        ...(ccuData.ccuRectifiers ?? []),
        ...(ccuData.ccuMppt ?? []), // Add MPPT items for validation
      ];

      final isValid = allItems.any(
        (item) =>
            item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );

      if (isValid) {
        showCustomToast(context, 'QR Code validated successfully!');
      } else {
        showCustomToast(
          context,
          'Invalid QR Code! Serial number not found in system.',
        );
      }

      return isValid;
    } else {
      // For manual entries, validate against mfg_serial_no
      // First check assets data
      final assets = ccuData.assets;
      if (assets.isNotEmpty) {
        final isValid = assets.any(
          (asset) =>
              asset.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
        );

        if (isValid) {
          showCustomToast(context, 'Manual entry validated successfully!');
          return true;
        }
      }

      // Fallback to category data
      final allItems = [
        ...(ccuData.ccuCabinet ?? []),
        ...(ccuData.ccuRectifiers ?? []),
        ...(ccuData.ccuMppt ?? []), // Add MPPT items for validation
      ];

      final isValid = allItems.any(
        (item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );

      if (isValid) {
        showCustomToast(context, 'Manual entry validated successfully!');
      } else {
        showCustomToast(
          context,
          'Invalid manual entry! Serial number not found in system.',
        );
      }

      return isValid;
    }
  }

  int? _getRemarksAssetAuditSiteRespId() {
    if (widget.assetAuditData == null) {
      return null;
    }

    final ccuData = widget.assetAuditData!.responseData.ccu;
    if (ccuData == null) return null;

    // Check if there are remarks in the backend data
    final remarks = ccuData.remarks;
    if (remarks.isNotEmpty) {
      // First try to find a general remarks entry (CCU category is usually the main one)
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null &&
            remark.assetAuditSiteRespId > 0 &&
            remark.itemTypeRemark != null &&
            remark.itemTypeRemark!.isNotEmpty) {
          return remark.assetAuditSiteRespId;
        }
      }
    }

    return null;
  }

  /// Post current screen data to API before navigating to next screen
  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      return false;
    }

    // If there's no data to show, no need to post
    if (!_hasDataToShow()) {
      return true;
    }

    // Validate that all required data is filled
    if (!_validateAllRequiredFields()) {
      showCustomToast(
        context,
        '❌ Please fill all required fields before proceeding',
      );
      return false;
    }

    try {
      // Create a list to hold all items to post
      List<Map<String, dynamic>> allItemsToPost = [];

      // Add saved rectifier items
      if (savedRectifierItems.isNotEmpty) {
        final enhancedRectifierItems = AssetAuditPostHelper.enhanceSavedItems(
          savedItems: savedRectifierItems,
          screenName: 'CCU Rectifier',
        );
        allItemsToPost.addAll(enhancedRectifierItems);
      }

      // Add saved MPPT items
      if (savedMPPTItems.isNotEmpty) {
        final enhancedMPPTItems = AssetAuditPostHelper.enhanceSavedItems(
          savedItems: savedMPPTItems,
          screenName: 'CCU MPPT',
        );
        allItemsToPost.addAll(enhancedMPPTItems);
      }

      // Add saved Cabinet items
      if (savedCabinetItems.isNotEmpty) {
        final enhancedCabinetItems = AssetAuditPostHelper.enhanceSavedItems(
          savedItems: savedCabinetItems,
          screenName: 'CCU Cabinet',
        );
        allItemsToPost.addAll(enhancedCabinetItems);
      }

      // Add user's general remarks if entered
      if (remarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();

        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'CCU',
            // Use the main screen category
            'remarks': remarksController.text,
            // User's actual remarks text
            'recordType': 'Remarks',
            'timestamp': DateTime.now(),
            'assetAuditSiteRespId': remarksAssetAuditSiteRespId,
            // Use backend remarks ID
            'status': 'OK',
            // Default status for remarks
            'serialNumber': 'REMARKS',
            // Default serial for remarks
            'photo': null,
            // No photo file for remarks
            'photoTakenTs': DateTime.now().toString(),
            // Current timestamp
            'isQRCodeScanned': false,
            // Remarks are not QR scanned
            'localQrCodeScannedTs': DateTime.now().toString(),
            // Local timestamp for QR scan
            'localCreatedDt': DateTime.now().toString(),
            // Local creation timestamp
            'localModifiedDt': DateTime.now().toString(),
            // Local modification timestamp
          };
          allItemsToPost.add(remarksData);
        }
      }

      if (allItemsToPost.isEmpty) {
        return false;
      }

      // Convert to POST request format
      final requests =
          await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: allItemsToPost,
            assetAuditData: widget.assetAuditData!,
            itemType: 'CCU',
            itemTypeId: AssetAuditPostHelper.getItemTypeId('CCU'),
            screenName: 'CCU',
            context: context,
            auditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId
                .toString(),
          );

      if (requests.isEmpty) {
        return false;
      }

      // Set flag to indicate CCU screen is posting data
      setState(() {
        _hasPostedCCUData = true;
      });

      // Use the existing cubit to post data
      context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);

      // Return true to indicate data is being posted
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate that all required fields are filled before proceeding
  bool _validateAllRequiredFields() {
    // Check if we have any saved items
    bool hasSavedItems =
        savedRectifierItems.isNotEmpty ||
        savedMPPTItems.isNotEmpty ||
        savedCabinetItems.isNotEmpty;

    if (!hasSavedItems) {
      return false;
    }

    // Validate each saved item
    for (var item in savedRectifierItems) {
      if (item['photo'] == null || item['photoId'] == null) {
        return false;
      }
    }

    for (var item in savedMPPTItems) {
      if (item['photo'] == null || item['photoId'] == null) {
        return false;
      }
    }

    for (var item in savedCabinetItems) {
      if (item['photo'] == null || item['photoId'] == null) {
        return false;
      }
    }

    return true;
  }

  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.isEmpty) {
      return 'N/A';
    }

    // If it's a QR code, truncate to show first and last few characters
    if (serialNumber.length > 20) {
      return '${serialNumber.substring(0, 8)}...${serialNumber.substring(serialNumber.length - 8)}';
    }

      return serialNumber;
  }

  void _editMPPTItem(Map<String, dynamic> item) {
    if (!_hasDataToShow()) {
      return;
    }

    setState(() {
      // Load the item data back into the form
      mpptSerialNumber = item["serialNumber"];
      mpptPhoto = item["photo"];
      mpptStatus = item["status"];

      // Set the serial controller text
      mpptSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved MPPT items
      savedMPPTItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      mpptCardKey++;

      hasUnsavedChanges = true;
    });

    // Show message to user
    showCustomToast(
      context,
      'MPPT item loaded for editing. Make changes and save again.',
    );
  }

  void _editCabinetItem(Map<String, dynamic> item) {
    if (!_hasDataToShow()) {
      return;
    }

    setState(() {
      // Load the item data back into the form
      uploadedPhotoPath = item["photo"];
      cabinetPhotoId = item["photoId"];
      selectedStatus = item["status"];

      // Remove the item from saved cabinet items
      savedCabinetItems.remove(item);
      currentScannedItems--;

      hasUnsavedChanges = true;
    });

    // Show message to user
    showCustomToast(
      context,
      'Cabinet item loaded for editing. Make changes and save again.',
    );
  }

  void _editRectifierItem(Map<String, dynamic> item) {
    if (!_hasDataToShow()) {
      return;
    }

    setState(() {
      // Load the item data back into the form
      rectifierSerialNumber = item["serialNumber"];
      rectifierPhoto = item["photo"];
      rectifierStatus = item["status"];

      // Set the serial controller text
      rectifierSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved rectifier items
      savedRectifierItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      rectifierCardKey++;

      hasUnsavedChanges = true;
    });

    // Show message to user
    showCustomToast(
      context,
      'Rectifier item loaded for editing. Make changes and save again.',
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  /// Check if user can proceed to next screen
  bool _canProceedToNextScreen() {
    // Check if we have any saved items
    bool hasSavedItems =
        savedRectifierItems.isNotEmpty ||
        savedMPPTItems.isNotEmpty ||
        savedCabinetItems.isNotEmpty;

    // Check if we have any items to scan
    bool hasItemsToScan = totalRectifierItems > 0 || totalMPPTItems > 0;

    // If no items to scan, allow navigation
    if (!hasItemsToScan) {
      return true;
    }

    // If we have items to scan, require at least one saved item
    return hasSavedItems;
  }

  /// Update local data with fresh data received from API
  void _updateLocalDataWithFreshData(AssetAuditLoaded state) {
    try {
      // Get the fresh CCU data from the API response
      final freshCCUData = state.assetAuditData?.responseData.ccu;

      if (freshCCUData != null) {
        setState(() {
          // Clear existing saved items to show fresh data
          savedRectifierItems.clear();
          savedMPPTItems.clear();
          savedCabinetItems.clear();
          currentScannedItems = 0;

          // Load fresh data into the UI
          _loadCCUDataFromFreshData(freshCCUData);
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Load CCU data from fresh data received from API
  void _loadCCUDataFromFreshData(CategoryData freshCCUData) {
    try {
      // Clear existing saved items to avoid duplicates
      savedRectifierItems.clear();
      savedMPPTItems.clear();
      savedCabinetItems.clear();
      currentScannedItems = 0;

      // Load CCU Rectifiers
      final rectifierItems = freshCCUData.ccuRectifiers ?? [];
      for (var item in rectifierItems) {
        Map<String, dynamic> savedItem = {
          'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
          'photo': null,
          'photoId': item.photoId,
          'status': item.assetStatus ?? 'Unknown',
          'timestamp': DateTime.now(),
          'isQRCodeScanned': item.qrCodeScanned ?? false,
          'itemType': item.itemType ?? 'Unknown',
          'remarks': item.itemTypeRemark ?? 'CCU Rectifier Item',
          'assetStatus': item.assetStatus,
          'assetAuditSiteRespId': item.assetAuditSiteRespId,

          // Full API response details
          'asset_audit_site_resp_id': item.assetAuditSiteRespId,
          'site_audit_sch_id': item.siteAuditSchId,
          'item_instance_id': item.itemInstanceId,
          'oem_name': item.oemName,
          'nexgen_serial_no': item.nexgenSerialNo,
          'mfg_serial_no': item.mfgSerialNo,
          'qr_code_scanned': item.qrCodeScanned ?? false,
          'qr_code_scanned_ts': item.qrCodeScannedTs,
          'image_name': item.imageName,
          'longitude': item.longitude,
          'latitude': item.latitude,
          'capacity': item.capacity,
          'item_type_group': item.itemTypeGroup,
          'record_type': item.recordType,
          'item_type_remark': item.itemTypeRemark,
        };
        savedRectifierItems.add(savedItem);
        currentScannedItems++;
      }

      // Load CCU MPPT
      final mpptItems = freshCCUData.ccuMppt ?? [];
      for (var item in mpptItems) {
        Map<String, dynamic> savedItem = {
          'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
          'photo': null,
          'photoId': item.photoId,
          'status': item.assetStatus ?? 'Unknown',
          'timestamp': DateTime.now(),
          'isQRCodeScanned': item.qrCodeScanned ?? false,
          'itemType': item.itemType ?? 'Unknown',
          'remarks': item.itemTypeRemark ?? 'CCU MPPT Item',
          'assetStatus': item.assetStatus,
          'assetAuditSiteRespId': item.assetAuditSiteRespId,

          // Full API response details
          'asset_audit_site_resp_id': item.assetAuditSiteRespId,
          'site_audit_sch_id': item.siteAuditSchId,
          'item_instance_id': item.itemInstanceId,
          'oem_name': item.oemName,
          'nexgen_serial_no': item.nexgenSerialNo,
          'mfg_serial_no': item.mfgSerialNo,
          'qr_code_scanned': item.qrCodeScanned ?? false,
          'qr_code_scanned_ts': item.qrCodeScannedTs,
          'image_name': item.imageName,
          'longitude': item.longitude,
          'latitude': item.latitude,
          'capacity': item.capacity,
          'item_type_group': item.itemTypeGroup,
          'record_type': item.recordType,
          'item_type_remark': item.itemTypeRemark,
        };
        savedMPPTItems.add(savedItem);
        currentScannedItems++;
      }

      // Load CCU Cabinet
      final cabinetItems = freshCCUData.ccuCabinet ?? [];
      for (var item in cabinetItems) {
        Map<String, dynamic> savedItem = {
          'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
          'photo': null,
          'photoId': item.photoId,
          'status': item.assetStatus ?? 'Unknown',
          'timestamp': DateTime.now(),
          'isQRCodeScanned': item.qrCodeScanned ?? false,
          'itemType': item.itemType ?? 'Unknown',
          'remarks': item.itemTypeRemark ?? 'CCU Cabinet Item',
          'assetStatus': item.assetStatus,
          'assetAuditSiteRespId': item.assetAuditSiteRespId,

          // Full API response details
          'asset_audit_site_resp_id': item.assetAuditSiteRespId,
          'site_audit_sch_id': item.siteAuditSchId,
          'item_instance_id': item.itemInstanceId,
          'oem_name': item.oemName,
          'nexgen_serial_no': item.nexgenSerialNo,
          'mfg_serial_no': item.mfgSerialNo,
          'qr_code_scanned': item.qrCodeScanned ?? false,
          'qr_code_scanned_ts': item.qrCodeScannedTs,
          'image_name': item.imageName,
          'longitude': item.longitude,
          'latitude': item.latitude,
          'capacity': item.capacity,
          'item_type_group': item.itemTypeGroup,
          'record_type': item.recordType,
          'item_type_remark': item.itemTypeRemark,
        };
        savedCabinetItems.add(savedItem);
        currentScannedItems++;
      }

      // Load general CCU assets
      final generalAssets = freshCCUData.assets;
      for (var item in generalAssets) {
        Map<String, dynamic> savedItem = {
          'serialNumber': item.mfgSerialNo ?? item.nexgenSerialNo ?? 'Unknown',
          'photo': null,
          'photoId': item.photoId,
          'status': item.assetStatus ?? 'Unknown',
          'timestamp': DateTime.now(),
          'isQRCodeScanned': item.qrCodeScanned ?? false,
          'itemType': item.itemType ?? 'Unknown',
          'remarks': item.itemTypeRemark ?? 'CCU Item',
          'assetStatus': item.assetStatus,
          'assetAuditSiteRespId': item.assetAuditSiteRespId,

          // Full API response details
          'asset_audit_site_resp_id': item.assetAuditSiteRespId,
          'site_audit_sch_id': item.siteAuditSchId,
          'item_instance_id': item.itemInstanceId,
          'oem_name': item.oemName,
          'nexgen_serial_no': item.nexgenSerialNo,
          'mfg_serial_no': item.mfgSerialNo,
          'qr_code_scanned': item.qrCodeScanned ?? false,
          'qr_code_scanned_ts': item.qrCodeScannedTs,
          'image_name': item.imageName,
          'longitude': item.longitude,
          'latitude': item.latitude,
          'capacity': item.capacity,
          'item_type_group': item.itemTypeGroup,
          'record_type': item.recordType,
          'item_type_remark': item.itemTypeRemark,
        };

        // Add to appropriate list based on item type
        if (item.itemType?.contains('Rectifier') == true) {
          savedRectifierItems.add(savedItem);
          currentScannedItems++;
        } else if (item.itemType?.contains('MPPT') == true) {
          savedMPPTItems.add(savedItem);
          currentScannedItems++;
        } else if (item.itemType?.contains('Cabinet') == true) {
          savedCabinetItems.add(savedItem);
          currentScannedItems++;
        }
      }

      // Update counts based on fresh data
      totalRectifierItems = savedRectifierItems.length;
      totalMPPTItems = savedMPPTItems.length;

      // Process fresh remarks data
      final remarks = freshCCUData.remarks;
      if (remarks.isNotEmpty) {
        for (var remark in remarks) {
          if (remark.itemTypeRemark != null &&
              remark.itemTypeRemark!.isNotEmpty) {
            // Update the remarks controller with fresh data
            remarksController.text = remark.itemTypeRemark!;
            break; // Use the first valid remark
          }
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Widget _buildRectifierSavedItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Serial",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Scanned",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Photo",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Status",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Edit",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          getHeight(10),

          // Debug information
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved Items: ${savedRectifierItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalRectifierItems',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (savedRectifierItems.isNotEmpty)
            ...savedRectifierItems
                .map(
                  (item) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item['serialNumber'] ?? 'N/A',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontFamily: fontFamilyMontserrat,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              item['isQRCodeScanned'] == true
                                  ? Icons.check
                                  : Icons.close,
                              color: item['isQRCodeScanned'] == true
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildPhotoColumn(item),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item['status'] ?? 'N/A',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontFamily: fontFamilyMontserrat,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: IconButton(
                            onPressed: () => _editSavedItem(item, 'rectifier'),
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.blue,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
        ],
      ),
    );
  }

  Widget _buildMPPTSavedItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Serial",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Scanned",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Photo",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Status",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Edit",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

            ],
          ),
          getHeight(10),

          // Debug information
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved Items: ${savedMPPTItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalMPPTItems',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (savedMPPTItems.isNotEmpty)
            ...savedMPPTItems
                .map(
                  (item) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    // padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      // border: Border.all(color: AppColors.greyColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item['serialNumber'] ?? 'N/A',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontFamily: fontFamilyMontserrat,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              item['isQRCodeScanned'] == true
                                  ? Icons.check
                                  : Icons.close,
                              color: item['isQRCodeScanned'] == true
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildPhotoColumn(item),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item['status'] ?? 'N/A',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontFamily: fontFamilyMontserrat,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: IconButton(
                            onPressed: () => _editSavedItem(item, 'mppt'),
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.blue,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
        ],
      ),
    );
  }

  Widget _buildCabinetSavedItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.green7,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Serial",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Scanned",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Photo",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Capacity",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Status",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 50), // Space for Edit button
            ],
          ),
        ),

        // Debug information
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saved Items: ${savedCabinetItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalCabinetItems',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (savedCabinetItems.isNotEmpty)
          ...savedCabinetItems
              .map(
                (item) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.greyColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            item['serialNumber'] ?? 'N/A',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            item['isQRCodeScanned'] == true
                                ? Icons.check
                                : Icons.close,
                            color: item['isQRCodeScanned'] == true
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildPhotoColumn(item),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            item['capacity'] ?? 'N/A',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            item['status'] ?? 'N/A',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: IconButton(
                          onPressed: () => _editSavedItem(item, 'cabinet'),
                          icon: const Icon(
                            Icons.edit,
                            color: AppColors.blue,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
        if (state is AssetAuditLoaded) {
          // Update the local data with fresh data from API
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateLocalDataWithFreshData(state);
            }
          });
        } else if (state is AssetAuditPostSuccess) {
          // Check if this success state contains CCU-related items
          bool isCCUData = false;
          for (var response in state.responses) {
            // Primary check: itemTypeRemark contains CCU-related text
            if (response.itemTypeRemark != null &&
                (response.itemTypeRemark!.contains('CCU') ||
                    response.itemTypeRemark!.contains('Cabinet') ||
                    response.itemTypeRemark!.contains('Rectifier') ||
                    response.itemTypeRemark!.contains('MPPT'))) {
              isCCUData = true;
              break;
            }

            // Fallback check: Check if this is a response to CCU screen data by looking at the flag
            if (_hasPostedCCUData) {
              isCCUData = true;
              break;
            }
          }

          if (isCCUData) {
            _navigateToBatteryScreen();
            _hasPostedCCUData = false;
          }
        } else if (state is AssetAuditPostError) {
          // Only show error message if this error belongs to CCU screen data
          if (_hasPostedCCUData) {
          // Show error message and block navigation
          showCustomToast(
            context,
            '❌ Failed to save CCU data. Please try again.',
          );

            // Reset the flag on error
            setState(() {
              _hasPostedCCUData = false;
            });
          }
        }
      },
      builder: (context, state) {
        return PopScope(
        canPop: !hasUnsavedChanges,
        onPopInvoked: (didPop) async {
          if (didPop) return;

          if (hasUnsavedChanges) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => UnsavedChangesDialog(
                message:
                    "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                onSaveAndExit: () {
                  _saveAndExit();
                },
                onDiscard: () {
                    Navigator.pop(context);
                },
              ),
            );
          }
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          appBar: CustomFormAppbar(
            title: "Asset Audit",
            onClose: () async {
              if (hasUnsavedChanges) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => UnsavedChangesDialog(
                    message:
                        "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                    onSaveAndExit: () {
                      _saveAndExit();
                    },
                    onDiscard: () {
                        Navigator.pop(context);
                    },
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          body: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: SvgPicture.asset(
                  AppImages.home,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              SafeArea(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom:
                                  MediaQuery.of(context).viewInsets.bottom +
                                  120,
                          ),
                          child: Container(
                            padding: const EdgeInsets.only(
                              top: 20,
                              left: 16,
                              right: 16,
                              bottom: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!_hasDataToShow()) ...[
                                  Container(
                                    width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                      ),
                                      child: const Column(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                            color: Colors.white,
                                            size: 48,
                                        ),
                                          SizedBox(height: 16),
                                        Text(
                                            'No CCU Data Available',
                                          style: TextStyle(
                                            color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                          SizedBox(height: 8),
                                        Text(
                                            'This screen will be skipped as there is no CCU data to audit.',
                                          textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  CustomFormField(
                                    label: "Hybrid CCU Make ",
                                    initialValue: _getCCUOEMName(),
                                    isRequired: false,
                                    isEditable: false,
                                  ),
                                  getHeight(15),
                                  SerialNumberField(
                                    label: "Cabinet Serial Number",
                                    controller: serialController,
                                  ),
                                  getHeight(15),
                                  ImageUploadField(
                                    label: "Add a Selfie",
                                    placeholder: "Selfie",
                                    isRequired: true,
                                    onImageSelected: (file) async {
                                      if (file != null) {
                                        setState(() {
                                          uploadedPhotoPath = file.path;
                                          hasUnsavedChanges = true;
                                        });

                                        // Upload photo immediately and get photoId for Cabinet
                                        try {
                                          final photoFile = File(file.path);
                                          if (await photoFile.exists()) {
                                            final photoId =
                                                await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                                  photoFile: photoFile,
                                                  schId:
                                                      widget
                                                          .assetAuditData
                                                          ?.pageHeader
                                                          .first
                                                          .siteAuditSchId
                                                          .toString() ??
                                                      "0",
                                                  imgId: null,
                                                  context: context,
                                                );

                                            if (photoId != null) {
                                              setState(() {
                                                cabinetPhotoId =
                                                    photoId; // Store the photoId for Cabinet
                                              });

                                              // Automatically save cabinet item when photo is uploaded
                                              _autoSaveCabinetItem();
                                            }
                                          }
                                        } catch (e) {
                                            // Handle error silently
                                        }
                                      } else {
                                        setState(() {
                                          uploadedPhotoPath = null;
                                          cabinetPhotoId = null;
                                        });
                                      }
                                    },
                                  ),
                                  getHeight(15),
                                  CustomFormField(
                                    label: "Total Count of Rectifier ",
                                    initialValue: totalRectifierItems
                                        .toString(),
                                    isRequired: true,
                                    isEditable: true,
                                    onChanged: (value) {
                                      setState(() {
                                        totalRectifierItems =
                                            int.tryParse(value) ?? 6;
                                        hasUnsavedChanges = true;
                                      });
                                    },
                                  ),
                                  getHeight(15),
                                  Text(
                                    "Rectifiers Details",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      fontFamily: fontFamilyMontserrat,
                                    ),
                                  ),
                                  getHeight(3),
                                  CustomInfoCard(
                                    key: ValueKey(
                                      'rectifier_$rectifierCardKey',
                                    ),
                                    serialLabel: "Rectifier - Serial Number",
                                    serialHintText: "Rectifier Serial Number",
                                    photoLabel: "Add a Photo",
                                    statusLabel: "Status",
                                      serialController:
                                          rectifierSerialController,
                                    onSave: _saveRectifierForm,
                                    isStatusEditable: true,
                                    backendStatus: false,
                                    onPhotoTap: (photoPath) async {
                                      setState(() {
                                        rectifierPhoto = photoPath;
                                        hasUnsavedChanges = true;
                                      });

                                      // Upload photo immediately and get photoId
                                      if (photoPath != null &&
                                          photoPath.isNotEmpty) {
                                        try {
                                          final photoFile = File(photoPath);
                                          if (await photoFile.exists()) {
                                            final photoId =
                                                await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                                  photoFile: photoFile,
                                                  schId:
                                                      widget
                                                          .assetAuditData
                                                          ?.pageHeader
                                                          .first
                                                          .siteAuditSchId
                                                          .toString() ??
                                                      "0",
                                                  imgId: null,
                                                  context: context,
                                                );

                                            if (photoId != null) {
                                              setState(() {
                                                rectifierPhotoId = photoId;
                                              });
                                            }
                                          }
                                        } catch (e) {
                                            // Handle error silently
                                        }
                                      }
                                    },
                                    onStatusChanged: (val) {
                                      setState(() {
                                          rectifierStatus = val
                                              ? "OK"
                                              : "Not OK";
                                        hasUnsavedChanges = true;
                                      });
                                    },
                                    onSerialChanged: (serialNumber) {
                                      setState(() {
                                        rectifierSerialNumber = serialNumber;
                                        hasUnsavedChanges = true;
                                      });

                                      // Validate serial number if not empty
                                      if (serialNumber.isNotEmpty) {
                                        final isValid = _validateSerialNumber(
                                          serialNumber,
                                          false,
                                        );
                                        if (isValid) {
                                          // Serial number is valid, keep it
                                        } else {
                                          // Serial number is invalid, clear it
                                          setState(() {
                                            rectifierSerialNumber = null;
                                            hasUnsavedChanges = false;
                                          });
                                        }
                                      }
                                    },
                                    initialStatus: rectifierStatus == "OK"
                                        ? true
                                        : (rectifierStatus == "Not OK"
                                              ? false
                                              : null),
                                    initialPhotoPath: rectifierPhoto,
                                    isEditable: true,
                                  ),

                                  getHeight(8),
                                  // Rectifier saved items section
                                  _buildRectifierSavedItemsList(),
                                  getHeight(15),
                                  CustomFormField(
                                    label: "Total Count of MPPT",
                                    initialValue: totalMPPTItems.toString(),
                                    isRequired: true,
                                    isEditable: true,
                                    onChanged: (value) {
                                      setState(() {
                                        totalMPPTItems =
                                            int.tryParse(value) ?? 6;
                                        hasUnsavedChanges = true;
                                      });
                                    },
                                  ),
                                  getHeight(15),
                                  Text(
                                    "MPPT Details",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      fontFamily: fontFamilyMontserrat,
                                    ),
                                  ),
                                  getHeight(3),
                                  CustomInfoCard(
                                    key: ValueKey('mppt_$mpptCardKey'),
                                    serialLabel: "MPPT - Serial Number *",
                                    serialHintText: "MPPT Serial Number",
                                    photoLabel: "Add a Photo",
                                    statusLabel: "Status",
                                    serialController: mpptSerialController,
                                    onSave: _saveMPPTForm,
                                    isStatusEditable: true,
                                    backendStatus: false,
                                    remarksLabel: "Capacity",
                                    remarksHintText: "Eg:200",
                                    remarksController: capacityController,
                                    isRemarksEditable: false,
                                    onPhotoTap: (photoPath) async {
                                      setState(() {
                                        mpptPhoto = photoPath;
                                        hasUnsavedChanges = true;
                                      });

                                      // Upload photo immediately and get photoId
                                      if (photoPath != null &&
                                          photoPath.isNotEmpty) {
                                        try {
                                          final photoFile = File(photoPath);
                                          if (await photoFile.exists()) {
                                            final photoId =
                                                await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
                                                  photoFile: photoFile,
                                                  schId:
                                                      widget
                                                          .assetAuditData
                                                          ?.pageHeader
                                                          .first
                                                          .siteAuditSchId
                                                          .toString() ??
                                                      "0",
                                                  imgId: null,
                                                  context: context,
                                                );

                                            if (photoId != null) {
                                              setState(() {
                                                mpptPhotoId = photoId;
                                              });
                                            }
                                          }
                                        } catch (e) {
                                            // Handle error silently
                                        }
                                      }
                                    },
                                    onStatusChanged: (val) {
                                      setState(() {
                                        mpptStatus = val ? "OK" : "Not OK";
                                        hasUnsavedChanges = true;
                                      });
                                    },
                                    onSerialChanged: (serialNumber) {
                                      setState(() {
                                        mpptSerialNumber = serialNumber;
                                        hasUnsavedChanges = true;
                                      });

                                      if (serialNumber.isNotEmpty) {
                                        final isValid = _validateSerialNumber(
                                          serialNumber,
                                          false,
                                        );
                                        if (isValid) {
                                          // Serial number is valid, keep it
                                        } else {
                                          // Serial number is invalid, clear it
                                          setState(() {
                                            mpptSerialNumber = null;
                                            hasUnsavedChanges = false;
                                          });
                                        }
                                      }
                                    },
                                    initialStatus: mpptStatus == "OK"
                                        ? true
                                        : (mpptStatus == "Not OK"
                                              ? false
                                              : null),
                                    initialPhotoPath: mpptPhoto,
                                    isEditable: true,
                                  ),

                                  getHeight(8),
                                  _buildMPPTSavedItemsList(),
                                  getHeight(15),
                                  CustomRemarksField(
                                    label: "Add Remarks",
                                    hintText: "Remarks",
                                    controller: remarksController,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        child: Row(
                          children: [
                            Expanded(
                              child: ArrowButton(
                                text: "Back",
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            getWidth(14),
                            Expanded(
                              child: ArrowButton(
                                  text: _hasDataToShow()
                                      ? "Battery"
                                      : "Skip CCU",
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                  onPressed: () {
                                    // Use our new smart navigation system
                                    _navigateToBatteryScreen();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Full-screen loading overlay when posting data
              BlocBuilder<AssetAuditCubit, AssetAuditState>(
                builder: (context, state) {
                  if (state is AssetAuditPosting) {
                    return Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  /// Edit a saved item based on its type
  void _editSavedItem(Map<String, dynamic> item, String itemType) {

    setState(() {
      // Populate the form fields with the item's data for editing
      switch (itemType) {
        case 'rectifier':
          // Populate rectifier form with item data
          rectifierSerialController.text = item['serialNumber'] ?? '';
          rectifierSerialNumber = item['serialNumber'] ?? ''; // Also set the variable
          rectifierStatus = item['status'] ?? 'OK';
          rectifierPhotoId = item['photoId'];
          rectifierPhoto = item['photo'];
          savedRectifierItems.remove(item);
          currentScannedItems--;
          break;
          
        case 'mppt':
          // Populate MPPT form with item data
          mpptSerialController.text = item['serialNumber'] ?? '';
          mpptSerialNumber = item['serialNumber'] ?? ''; // Also set the variable
          mpptStatus = item['status'] ?? 'OK';
          mpptPhotoId = item['photoId'];
          mpptPhoto = item['photo'];

          // Remove the item from saved list since it's now in the form for editing
          savedMPPTItems.remove(item);
          currentScannedItems--;
          break;
          
        // case 'cabinet':
        //   // Populate cabinet form with item data
        //   cabinetSerialController.text = item['serialNumber'] ?? '';
        //   cabinetSerialNumber = item['serialNumber'] ?? ''; // Also set the variable
        //   cabinetStatus = item['status'] ?? 'OK';
        //   cabinetPhotoId = item['photoId'];
        //   cabinetPhoto = item['photo'];
        //
        //   // Remove the item from saved list since it's now in the form for editing
        //   savedCabinetItems.remove(item);
        //   currentScannedItems--;
        //   break;
      }
      
      // Mark that there are unsaved changes
      hasUnsavedChanges = true;
      
      // Show a message to the user
      showCustomToast(
        context,
        'Item loaded for editing. Make your changes and save.',
      );
    });
  }

  /// Clear all form data
  void _clearFormData() {
    // Clear rectifier form
    rectifierSerialController.clear();
    rectifierStatus = 'OK';
    rectifierPhotoId = null;
    rectifierPhoto = null;
    
    // Clear MPPT form
    mpptSerialController.clear();
    mpptStatus = 'OK';
    mpptPhotoId = null;
    mpptPhoto = null;
    //
    // // Clear cabinet form
    // cabinetSerialController.clear();
    // cabinetStatus = 'OK';
    // cabinetPhotoId = null;
    // cabinetPhoto = null;
  }

  // ===== CHANGE TRACKING SYSTEM METHODS =====
  
  /// Initialize the change tracking system
  void _initializeChangeTracking() {
    // Reset change tracking to ensure clean state
    _clearChangeTracking();
    
    // Store original values when screen loads
    _storeOriginalValues();
    
    // Add listeners to track changes
    _addFormListeners();

  }
  
  /// Store original values for change detection
  void _storeOriginalValues() {
    _originalFormData = {
      'rectifierSerialNumber': rectifierSerialNumber ?? '',
      'rectifierStatus': rectifierStatus ?? 'OK',
      'rectifierPhoto': rectifierPhoto,
      'rectifierPhotoId': rectifierPhotoId,
      'mpptSerialNumber': mpptSerialNumber ?? '',
      'mpptStatus': mpptStatus ?? 'OK',
      'mpptPhoto': mpptPhoto,
      'mpptPhotoId': mpptPhotoId,
      'savedRectifierItems': List<Map<String, dynamic>>.from(savedRectifierItems),
      'savedMPPTItems': List<Map<String, dynamic>>.from(savedMPPTItems),
      'savedCabinetItems': List<Map<String, dynamic>>.from(savedCabinetItems),
    };

  }
  
  /// Add listeners to track form changes
  void _addFormListeners() {
    rectifierSerialController.addListener(() {
      _trackFieldChange('rectifierSerialNumber', rectifierSerialController.text);
    });
    
    mpptSerialController.addListener(() {
      _trackFieldChange('mpptSerialNumber', mpptSerialController.text);
    });
    
    // Track form filling status
    _trackFormFillingStatus();
  }
  
  /// Track if forms are filled with new data
  void _trackFormFillingStatus() {
    // Only consider forms filled if they have meaningful data that's different from defaults
    _isRectifierFormFilled = rectifierSerialNumber != null && 
                             rectifierSerialNumber!.isNotEmpty &&
                             rectifierSerialNumber!.trim() != '' &&
                             (rectifierPhoto != null || (rectifierStatus != null && rectifierStatus != 'OK'));
    
    _isMPPTFormFilled = mpptSerialNumber != null && 
                        mpptSerialNumber!.isNotEmpty &&
                        mpptSerialNumber!.trim() != '' &&
                        (mpptSerialNumber!.trim() != '' &&
                         (mpptPhoto != null || (mpptStatus != null && mpptStatus != 'OK')));

  }
  
  /// Track field changes
  void _trackFieldChange(String fieldName, dynamic newValue) {
    final originalValue = _originalFormData[fieldName];
    
    if (_hasValueChanged(originalValue, newValue)) {

      _modifiedItems[fieldName] = newValue;
      hasUnsavedChanges = true;
    } else {
      // Remove from modified items if value is back to original
      _modifiedItems.remove(fieldName);
      hasUnsavedChanges = _modifiedItems.isNotEmpty || _newItems.isNotEmpty;
    }
    
    // Update form filling status
    _trackFormFillingStatus();
    
    // Detect new items
    _detectNewItems();
    
    setState(() {});
  }
  
  /// Check if a value has actually changed
  bool _hasValueChanged(dynamic original, dynamic current) {
    if (original == null && current == null) return false;
    if (original == null && (current == null || current == '' || current == 'OK')) return false;
    if (current == null && (original == null || original == '' || original == 'OK')) return false;
    
    if (original is String && current is String) {
      final originalTrimmed = original.trim();
      final currentTrimmed = current.trim();
      
      // Don't consider empty strings or default values as changes
      if (originalTrimmed.isEmpty && currentTrimmed.isEmpty) return false;
      if (originalTrimmed.isEmpty && currentTrimmed == 'OK') return false;
      if (currentTrimmed.isEmpty && originalTrimmed == 'OK') return false;
      
      return originalTrimmed != currentTrimmed;
    }
    
    if (original is int && current is int) {
      return original != current;
    }
    
    return original != current;
  }
  
  /// Detect new items that haven't been posted yet
  void _detectNewItems() {
    _newItems.clear();
    
    // Check rectifier form for new items - only if it's actually filled with meaningful data
    if (_isRectifierFormFilled && 
        rectifierSerialNumber != null && 
        rectifierSerialNumber!.trim().isNotEmpty) {
      
      // Check if this is a truly new item (not an edited existing one)
      if (!_isRectifierInOriginalData()) {
        _newItems.add({
          'type': 'rectifier',
          'data': {
            'serialNumber': rectifierSerialNumber,
            'status': rectifierStatus ?? 'OK',
            'photo': rectifierPhoto,
            'photoId': rectifierPhotoId,
          }
        });

      } else {
        print('CCU Screen: Rectifier item is existing (editing): ${rectifierSerialNumber}');
      }
    }
    
    // Check MPPT form for new items - only if it's actually filled with meaningful data
    if (_isMPPTFormFilled && 
        mpptSerialNumber != null && 
        mpptSerialNumber!.trim().isNotEmpty) {
      
      // Check if this is a truly new item (not an edited existing one)
      if (!_isMPPTInOriginalData()) {
        _newItems.add({
          'type': 'mppt',
          'data': {
            'serialNumber': mpptSerialNumber,
            'status': mpptStatus ?? 'OK',
            'photo': mpptPhoto,
            'photoId': mpptPhotoId,
          }
        });

      } else {
        print('CCU Screen: MPPT item is existing (editing): ${mpptSerialNumber}');
      }
    }
    

  }
  
  /// Check if rectifier form data exists in original data
  bool _isRectifierInOriginalData() {
    final originalRectifierItems = _originalFormData['savedRectifierItems'] as List<Map<String, dynamic>>?;
    if (originalRectifierItems == null) return false;
    
    // Check if serial number exists in original data (this identifies existing items)
    final hasExistingSerial = originalRectifierItems.any((item) => 
      item['serialNumber'] == rectifierSerialNumber && 
      rectifierSerialNumber != null && 
      rectifierSerialNumber!.trim().isNotEmpty
    );

    return hasExistingSerial;
  }
  
  /// Check if MPPT form data exists in original data
  bool _isMPPTInOriginalData() {
    final originalMPPTItems = _originalFormData['savedMPPTItems'] as List<Map<String, dynamic>>?;
    if (originalMPPTItems == null) return false;
    
    // Check if serial number exists in original data (this identifies existing items)
    final hasExistingSerial = originalMPPTItems.any((item) => 
      item['serialNumber'] == mpptSerialNumber && 
      mpptSerialNumber != null && 
      mpptSerialNumber!.trim().isNotEmpty
    );

    
    return hasExistingSerial;
  }
  
  /// Check if we're just editing existing items (not adding new ones)
  bool _isJustEditingExistingItems() {
    // If we have no new items but have modified items, we're just editing
    final hasNoNewItems = _newItems.isEmpty;
    final hasModifiedItems = _modifiedItems.isNotEmpty;
    final hasDeletedItems = _deletedItemIds.isNotEmpty;
    
    // We're just editing if:
    // 1. No new items are being added
    // 2. Some fields are modified (editing existing items)
    // 3. No items are being deleted
    final isJustEditing = hasNoNewItems && hasModifiedItems && !hasDeletedItems;

    
    return isJustEditing;
  }
  
  /// Save edited items and navigate (for existing item edits)
  void _saveEditedItemsAndNavigate() {

    _updateSavedItemsWithEdits();
    
    // Clear the forms
    _clearFormData();
    
    // Clear change tracking
    _clearChangeTracking();
    
    // Navigate to next screen
    pushPage(
      context,
      BatteryScreen(
        batteryData: widget.assetAuditData?.responseData.battery,
        assetAuditData: widget.assetAuditData,
      ),
    );
  }
  
  /// Update saved items with edited values
  void _updateSavedItemsWithEdits() {

    
    // Update rectifier items if modified
    if (_modifiedItems.containsKey('rectifierSerialNumber') || 
        _modifiedItems.containsKey('rectifierStatus') ||
        _modifiedItems.containsKey('rectifierPhoto')) {
      
      // Find the item in saved list and update it
      for (int i = 0; i < savedRectifierItems.length; i++) {
        final item = savedRectifierItems[i];
        if (item['serialNumber'] == rectifierSerialNumber) {
          // Update the item with new values
          savedRectifierItems[i] = {
            ...item,
            'status': rectifierStatus ?? item['status'],
            'photo': rectifierPhoto ?? item['photo'],
            'photoId': rectifierPhotoId ?? item['photoId'],
          };

          break;
        }
      }
    }
    
    // Update MPPT items if modified
    if (_modifiedItems.containsKey('mpptSerialNumber') || 
        _modifiedItems.containsKey('mpptStatus') ||
        _modifiedItems.containsKey('mpptPhoto')) {
      
      // Find the item in saved list and update it
      for (int i = 0; i < savedMPPTItems.length; i++) {
        final item = savedMPPTItems[i];
        if (item['serialNumber'] == mpptSerialNumber) {
          // Update the item with new values
          savedMPPTItems[i] = {
            ...item,
            'status': mpptStatus ?? item['status'],
            'photo': mpptPhoto ?? item['photo'],
            'photoId': mpptPhotoId ?? item['photoId'],
          };
          break;
        }
      }
    }
  }
  
  /// Check if changes are just form fields (not requiring validation)
  bool _areChangesJustFormFields() {
    // If we have no new items and no deleted items, but have modified fields,
    // and we have existing saved items, then we're just editing form fields
    final hasNoNewItems = _newItems.isEmpty;
    final hasNoDeletedItems = _deletedItemIds.isEmpty;
    final hasModifiedFields = _modifiedItems.isNotEmpty;
    final hasExistingItems = savedRectifierItems.isNotEmpty || 
                            savedMPPTItems.isNotEmpty || 
                            savedCabinetItems.isNotEmpty;
    
    final isJustFormFields = hasNoNewItems && 
                            hasNoDeletedItems && 
                            hasModifiedFields && 
                            hasExistingItems;

    
    return isJustFormFields;
  }

  /// Save form fields and navigate (for form field changes only)
  void _saveFormFieldsAndNavigate() {
if (_modifiedItems.containsKey('rectifierSerialNumber')) {
      rectifierSerialNumber = _modifiedItems['rectifierSerialNumber'];
    }
    if (_modifiedItems.containsKey('rectifierStatus')) {
      rectifierStatus = _modifiedItems['rectifierStatus'];
    }
    if (_modifiedItems.containsKey('rectifierPhoto')) {
      rectifierPhoto = _modifiedItems['rectifierPhoto'];
    }
    if (_modifiedItems.containsKey('rectifierPhotoId')) {
      rectifierPhotoId = _modifiedItems['rectifierPhotoId'];
    }
    
    if (_modifiedItems.containsKey('mpptSerialNumber')) {
      mpptSerialNumber = _modifiedItems['mpptSerialNumber'];
    }
    if (_modifiedItems.containsKey('mpptStatus')) {
      mpptStatus = _modifiedItems['mpptStatus'];
    }
    if (_modifiedItems.containsKey('mpptPhoto')) {
      mpptPhoto = _modifiedItems['mpptPhoto'];
    }
    if (_modifiedItems.containsKey('mpptPhotoId')) {
      mpptPhotoId = _modifiedItems['mpptPhotoId'];
    }
    
    // Clear the forms
    _clearFormData();
    
    // Clear change tracking
    _clearChangeTracking();
    
    // Navigate to next screen
    pushPage(
      context,
      BatteryScreen(
        batteryData: widget.assetAuditData?.responseData.battery,
        assetAuditData: widget.assetAuditData,
      ),
    );
  }
  
  /// Check if current state is valid for navigation without strict validation
  bool _isCurrentStateValidForNavigation() {
    // Check if we have any saved items (which means the screen has data)
    final hasSavedItems = savedRectifierItems.isNotEmpty || 
                          savedMPPTItems.isNotEmpty || 
                          savedCabinetItems.isNotEmpty;
    
    // Check if forms are just partially filled (not requiring complete validation)
    final hasPartialFormData = (rectifierSerialNumber != null && rectifierSerialNumber!.trim().isNotEmpty) ||
                               (mpptSerialNumber != null && mpptSerialNumber!.trim().isNotEmpty);
    
    // Navigation is valid if:
    // 1. We have saved items (screen has data), OR
    // 2. Forms are not filled (no partial data), OR  
    // 3. Forms are completely filled (ready to save)
    final isValidForNavigation = hasSavedItems || 
                                !hasPartialFormData ||
                                _areFormsCompletelyFilled();

    return isValidForNavigation;
  }
  
  /// Check if forms are completely filled (ready for validation)
  bool _areFormsCompletelyFilled() {
    // Rectifier form is completely filled
    final rectifierComplete = rectifierSerialNumber != null && 
                              rectifierSerialNumber!.trim().isNotEmpty &&
                              rectifierPhoto != null &&
                              rectifierStatus != null;
    
    // MPPT form is completely filled
    final mpptComplete = mpptSerialNumber != null && 
                         mpptSerialNumber!.trim().isNotEmpty &&
                         mpptPhoto != null &&
                         mpptStatus != null;
    
    final isComplete = rectifierComplete || mpptComplete;

    return isComplete;
  }
  
  /// Show confirmation dialog for unsaved changes
  void _showChangesConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: _buildChangesSummary(),
        actions: [
          TextButton(
                            onPressed: () {
              Navigator.of(context).pop();
              _discardAllChangesAndNavigate();
            },
            child: const Text('Discard All'),
          ),
          TextButton(
                            onPressed: () {
              Navigator.of(context).pop();
              _saveAllChangesAndNavigate();
                            },
            child: const Text('Save All'),
                        ),
                      ],
                    ),
                  );
  }
  
  /// Build summary of all changes
  Widget _buildChangesSummary() {
    final List<Widget> summaryItems = [];
    
    if (_newItems.isNotEmpty) {
      summaryItems.add(
        Text('📝 New Items (${_newItems.length}):', 
             style: const TextStyle(fontWeight: FontWeight.bold))
      );
      for (final item in _newItems) {
        summaryItems.add(Text('  • ${item['type']}: ${item['data']['serialNumber']}'));
      }
      summaryItems.add(const SizedBox(height: 8));
    }
    
    if (_modifiedItems.isNotEmpty) {
      summaryItems.add(
        Text('✏️ Modified Fields (${_modifiedItems.length}):', 
             style: const TextStyle(fontWeight: FontWeight.bold))
      );
      for (final entry in _modifiedItems.entries) {
        summaryItems.add(Text('  • ${_getFieldDisplayName(entry.key)}'));
      }
      summaryItems.add(const SizedBox(height: 8));
    }
    
    if (_deletedItemIds.isNotEmpty) {
      summaryItems.add(
        Text('🗑️ Deleted Items (${_deletedItemIds.length}):', 
             style: const TextStyle(fontWeight: FontWeight.bold))
      );
      summaryItems.add(const SizedBox(height: 8));
    }
    
    summaryItems.add(
      const Text('Would you like to save these changes before proceeding?')
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: summaryItems,
    );
  }
  
  /// Get user-friendly field display names
  String _getFieldDisplayName(String fieldName) {
    final displayNames = {
      'rectifierSerialNumber': 'Rectifier Serial Number',
      'rectifierStatus': 'Rectifier Status',
      'rectifierPhoto': 'Rectifier Photo',
      'rectifierPhotoId': 'Rectifier Photo ID',
      'mpptSerialNumber': 'MPPT Serial Number',
      'mpptStatus': 'MPPT Status',
      'mpptPhoto': 'MPPT Photo',
      'mpptPhotoId': 'MPPT Photo ID',
    };
    
    return displayNames[fieldName] ?? fieldName;
  }
  
  /// Save all changes and navigate
  Future<void> _saveAllChangesAndNavigate() async {
    try {

      if (_newItems.isNotEmpty) {
        await _saveNewItems();
      }
      
      // Save modified items
      if (_modifiedItems.isNotEmpty) {
        await _saveModifiedItems();
      }
      
      // Clear all change tracking
      _clearChangeTracking();
      
      showCustomToast(context, '✅ All changes saved successfully!');
      pushPage(
        context,
        BatteryScreen(
          batteryData: widget.assetAuditData?.responseData.battery,
          assetAuditData: widget.assetAuditData,
        ),
      );
      
    } catch (e) {

      showCustomToast(context, '❌ Error saving changes: $e');
    }
  }
  
  /// Save new items to saved lists
  Future<void> _saveNewItems() async {

    for (final newItem in _newItems) {
      final itemData = newItem['data'] as Map<String, dynamic>;
      
      switch (newItem['type']) {
        case 'rectifier':
          savedRectifierItems.add({
            'serialNumber': itemData['serialNumber'],
            'status': itemData['status'],
            'photo': itemData['photo'],
            'photoId': itemData['photoId'],
            'timestamp': DateTime.now(),
            'isQRCodeScanned': false,
            'itemType': 'CCU Rectifier',
            'remarks': 'New CCU Rectifier Item',
          });
          break;
          
        case 'mppt':
          savedMPPTItems.add({
            'serialNumber': itemData['serialNumber'],
            'status': itemData['status'],
            'photo': itemData['photo'],
            'photoId': itemData['photoId'],
            'timestamp': DateTime.now(),
            'isQRCodeScanned': false,
            'itemType': 'CCU MPPT',
            'remarks': 'New CCU MPPT Item',
          });
          break;
      }
    }
    
    // Clear forms after saving
    _clearFormData();

  }
  
  /// Save modified items
  Future<void> _saveModifiedItems() async {

    if (_modifiedItems.containsKey('rectifierSerialNumber')) {
      rectifierSerialNumber = _modifiedItems['rectifierSerialNumber'];
    }
    if (_modifiedItems.containsKey('rectifierStatus')) {
      rectifierStatus = _modifiedItems['rectifierStatus'];
    }
    if (_modifiedItems.containsKey('rectifierPhoto')) {
      rectifierPhoto = _modifiedItems['rectifierPhoto'];
    }
    if (_modifiedItems.containsKey('rectifierPhotoId')) {
      rectifierPhotoId = _modifiedItems['rectifierPhotoId'];
    }
    
    if (_modifiedItems.containsKey('mpptSerialNumber')) {
      mpptSerialNumber = _modifiedItems['mpptSerialNumber'];
    }
    if (_modifiedItems.containsKey('mpptStatus')) {
      mpptStatus = _modifiedItems['mpptStatus'];
    }
    if (_modifiedItems.containsKey('mpptPhoto')) {
      mpptPhoto = _modifiedItems['mpptPhoto'];
    }
    if (_modifiedItems.containsKey('mpptPhotoId')) {
      mpptPhotoId = _modifiedItems['mpptPhotoId'];
    }
    

  }
  
  /// Discard all changes and navigate
  void _discardAllChangesAndNavigate() {

    _resetToOriginalValues();
    
    // Clear all change tracking
    _clearChangeTracking();
    
    pushPage(
      context,
      BatteryScreen(
        batteryData: widget.assetAuditData?.responseData.battery,
        assetAuditData: widget.assetAuditData,
      ),
    );
  }
  
  /// Reset to original values
  void _resetToOriginalValues() {
    setState(() {
      rectifierSerialNumber = _originalFormData['rectifierSerialNumber'];
      rectifierStatus = _originalFormData['rectifierStatus'];
      rectifierPhoto = _originalFormData['rectifierPhoto'];
      rectifierPhotoId = _originalFormData['rectifierPhotoId'];
      rectifierSerialController.text = rectifierSerialNumber ?? '';
      
      mpptSerialNumber = _originalFormData['mpptSerialNumber'];
      mpptStatus = _originalFormData['mpptStatus'];
      mpptPhoto = _originalFormData['mpptPhoto'];
      mpptPhotoId = _originalFormData['mpptPhotoId'];
      mpptSerialController.text = mpptSerialNumber ?? '';
      
      // Reset saved items to original state
      savedRectifierItems = List<Map<String, dynamic>>.from(_originalFormData['savedRectifierItems'] ?? []);
      savedMPPTItems = List<Map<String, dynamic>>.from(_originalFormData['savedMPPTItems'] ?? []);
      savedCabinetItems = List<Map<String, dynamic>>.from(_originalFormData['savedCabinetItems'] ?? []);
      
      currentScannedItems = savedRectifierItems.length + savedMPPTItems.length + savedCabinetItems.length;
    });
  }
  
  /// Clear all change tracking
  void _clearChangeTracking() {
    _newItems.clear();
    _modifiedItems.clear();
    _deletedItemIds.clear();
    hasUnsavedChanges = false;
    _isRectifierFormFilled = false;
    _isMPPTFormFilled = false;

  }
}
