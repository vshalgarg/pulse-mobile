import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/battery_screen.dart';
import 'package:app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/asset_audit_model.dart';
import '../../../models/asset_audit_post_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../utils/asset_audit_navigation_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../repositories/image_repository.dart';
import '../../../app_config.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

class CCUScreen extends StatefulWidget {
  final CategoryData? ccuData;
  final AssetAuditModel? assetAuditData;
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;

  const CCUScreen({
    super.key, 
    this.ccuData, 
    this.assetAuditData,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
  });

  @override
  State<CCUScreen> createState() => _CCUScreenState();
}

class _CCUScreenState extends State<CCUScreen> {
  // Form controllers for AssetAuditFormComponent
  final TextEditingController rectifierSerialController = TextEditingController();
  final TextEditingController mpptSerialController = TextEditingController();
  final TextEditingController cabinetSerialController = TextEditingController();
  final TextEditingController generalRemarksController = TextEditingController();
  
  // Saved items for each form
  List<Map<String, dynamic>> savedRectifierItems = [];
  List<Map<String, dynamic>> savedMpptItems = [];
  List<Map<String, dynamic>> savedCabinetItems = [];
  
  // State management
  bool hasUnsavedChanges = false;
  bool _isLoadingAssetData = false;
  bool _isPostingData = false;
  bool _hasPostedCCUData = false;
  // Image service for fetching images from API
  late ImageRepository _imageService;
  Map<String, String> _imageCache = {};
  Set<String> _loadingImages = {};

  // Check if there are unsaved changes
  bool get _hasChanges {
    return savedRectifierItems.isNotEmpty ||
           savedMpptItems.isNotEmpty ||
           savedCabinetItems.isNotEmpty ||
           generalRemarksController.text.isNotEmpty;
  }

  // Image loading state management for editing
  String? _currentRequestedImageId;
  bool _isRequestingImage = false;

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

  /// Check if the current form is valid for saving
  bool _isValidSerialNumber(String serialNumber, String itemType) {
    if (widget.assetAuditData == null) {
      return false;
    }

    final ccuData = widget.assetAuditData!.responseData.ccu;
    if (ccuData == null) {
      return false;
    }

    // Check in MPPT items
    if (itemType == 'CCU MPPT') {
      final mpptItems = ccuData.ccuMppt ?? [];
      for (var item in mpptItems) {
        if (item.mfgSerialNo == serialNumber || item.nexgenSerialNo == serialNumber) {
          return true;
        }
      }
    }
    
    // Check in Rectifier items
    if (itemType == 'CCU Rectifiers') {
      final rectifierItems = ccuData.ccuRectifiers ?? [];
      for (var item in rectifierItems) {
        if (item.mfgSerialNo == serialNumber || item.nexgenSerialNo == serialNumber) {
          return true;
        }
      }
    }
    
    // Check in Cabinet items
    if (itemType == 'CCU Cabinet') {
      final cabinetItems = ccuData.ccuCabinet ?? [];
      for (var item in cabinetItems) {
        if (item.mfgSerialNo == serialNumber || item.nexgenSerialNo == serialNumber) {
          return true;
        }
      }
    }

    return false;
  }

  int? _getAssetAuditSiteRespId(String itemType, {String? serialNumber}) {
    if (widget.assetAuditData == null) {
      return null;
    }

    final ccuData = widget.assetAuditData!.responseData.ccu;
    if (ccuData != null) {
      // First try to find by serial number if provided
      if (serialNumber != null) {
        // Check in MPPT items
        if (itemType == 'CCU MPPT') {
          final mpptItems = ccuData.ccuMppt ?? [];
          for (var item in mpptItems) {
            if (item.mfgSerialNo == serialNumber || item.nexgenSerialNo == serialNumber) {
              print('CCU Debug: Found MPPT item by serial $serialNumber, assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
              return item.assetAuditSiteRespId;
            }
          }
        }
        
        // Check in Rectifier items
        if (itemType == 'CCU Rectifiers') {
          final rectifierItems = ccuData.ccuRectifiers ?? [];
          for (var item in rectifierItems) {
            if (item.mfgSerialNo == serialNumber || item.nexgenSerialNo == serialNumber) {
              return item.assetAuditSiteRespId;
            }
          }
        }
        
        // Check in Cabinet items
        if (itemType == 'CCU Cabinet') {
          final cabinetItems = ccuData.ccuCabinet ?? [];
          for (var item in cabinetItems) {
            if (item.mfgSerialNo == serialNumber || item.nexgenSerialNo == serialNumber) {
              print('CCU Debug: Found Cabinet item by serial $serialNumber, assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
              return item.assetAuditSiteRespId;
            }
          }
        }
        
        // If serial number not found, use fallback for unknown serial numbers
        print('CCU Debug: Serial number $serialNumber not found in backend data, using fallback for $itemType');
      }
      
      // Fallback to first matching item type (for unknown serial numbers or when no serial provided)
      final assets = ccuData.assets;
      if (assets.isNotEmpty) {
        for (int i = 0; i < assets.length; i++) {
          var asset = assets[i];

          if (asset.itemType == itemType ||
              (itemType == 'CCU Cabinet' && asset.itemType == 'CCU') ||
              (itemType == 'CCU Rectifiers' && asset.itemType == 'CCU') ||
              (itemType == 'CCU MPPT' && asset.itemType == 'CCU')) {
            print('CCU Debug: Using fallback assetAuditSiteRespId: ${asset.assetAuditSiteRespId} for itemType: $itemType (serial: $serialNumber)');
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

    // Final fallback: if no items found, generate a temporary ID for unknown serial numbers
    print('CCU Debug: No items found for $itemType, using temporary ID for serial: $serialNumber');
    return DateTime.now().millisecondsSinceEpoch; // Use timestamp as temporary ID
  }

  @override
  void initState() {
    super.initState();
    // Initialize image service
    _imageService = ImageRepository(AppConfig.of(context).apiProvider);
  }

  // Validation methods for each form type
  bool _validateRectifierSerialNumber(String serialNumber, bool isQRCodeScanned) {
    print('🔍 Rectifier Validation - Serial: $serialNumber, QR: $isQRCodeScanned');
    
    if (widget.assetAuditData == null) {
      print('🔍 No asset audit data available for validation');
      return true;
    }

    final ccuData = widget.assetAuditData!.responseData.categories['CCU'];
    if (ccuData == null) {
      print('🔍 No CCU data available for validation');
      return true;
    }

    final rectifierItems = ccuData.subCategories?['rectifier'] ?? [];
    print('🔍 Rectifier Validation - Rectifier items count: ${rectifierItems.length}');
    
    if (rectifierItems.isEmpty) {
      print('🔍 No rectifier items to validate against');
      return true;
    }

    // Check if serial number exists in the data
    for (final item in rectifierItems) {
      final nexgenSerial = item.nexgenSerialNo ?? '';
      final mfgSerial = item.mfgSerialNo ?? '';
      final inputSerial = serialNumber.trim();
      
      print('🔍 Rectifier QR Check - Comparing: "$nexgenSerial" with "$inputSerial"');
      print('🔍 Rectifier QR Check - Comparing: "$mfgSerial" with "$inputSerial"');
      
      if (nexgenSerial == inputSerial || mfgSerial == inputSerial) {
        print('🔍 Rectifier Validation Result: true');
        return true;
      }
    }
    
    print('🔍 Rectifier Validation Result: false');
    return false;
  }

  bool _validateMpptSerialNumber(String serialNumber, bool isQRCodeScanned) {
    print('🔍 MPPT Validation - Serial: $serialNumber, QR: $isQRCodeScanned');
    
    if (widget.assetAuditData == null) {
      print('🔍 No asset audit data available for validation');
      return true;
    }

    final ccuData = widget.assetAuditData!.responseData.categories['CCU'];
    if (ccuData == null) {
      print('🔍 No CCU data available for validation');
      return true;
    }

    final mpptItems = ccuData.subCategories?['mppt'] ?? [];
    print('🔍 MPPT Validation - MPPT items count: ${mpptItems.length}');
    
    if (mpptItems.isEmpty) {
      print('🔍 No MPPT items to validate against');
      return true;
    }

    // Check if serial number exists in the data
    for (final item in mpptItems) {
      final nexgenSerial = item.nexgenSerialNo ?? '';
      final mfgSerial = item.mfgSerialNo ?? '';
      final inputSerial = serialNumber.trim();
      
      print('🔍 MPPT QR Check - Comparing: "$nexgenSerial" with "$inputSerial"');
      print('🔍 MPPT QR Check - Comparing: "$mfgSerial" with "$inputSerial"');
      
      if (nexgenSerial == inputSerial || mfgSerial == inputSerial) {
        print('🔍 MPPT Validation Result: true');
        return true;
      }
    }
    
    print('🔍 MPPT Validation Result: false');
    return false;
  }

  bool _validateCabinetSerialNumber(String serialNumber, bool isQRCodeScanned) {
    print('🔍 Cabinet Validation - Serial: $serialNumber, QR: $isQRCodeScanned');
    
    if (widget.assetAuditData == null) {
      print('🔍 No asset audit data available for validation');
      return true;
    }

    final ccuData = widget.assetAuditData!.responseData.categories['CCU'];
    if (ccuData == null) {
      print('🔍 No CCU data available for validation');
      return true;
    }

    final cabinetItems = ccuData.subCategories?['cabinet'] ?? [];
    print('🔍 Cabinet Validation - Cabinet items count: ${cabinetItems.length}');
    
    if (cabinetItems.isEmpty) {
      print('🔍 No cabinet items to validate against');
      return true;
    }

    // Check if serial number exists in the data
    for (final item in cabinetItems) {
      final nexgenSerial = item.nexgenSerialNo ?? '';
      final mfgSerial = item.mfgSerialNo ?? '';
      final inputSerial = serialNumber.trim();
      
      print('🔍 Cabinet QR Check - Comparing: "$nexgenSerial" with "$inputSerial"');
      print('🔍 Cabinet QR Check - Comparing: "$mfgSerial" with "$inputSerial"');
      
      if (nexgenSerial == inputSerial || mfgSerial == inputSerial) {
        print('🔍 Cabinet Validation Result: true');
        return true;
      }
    }
    
    print('🔍 Cabinet Validation Result: false');
    return false;
  }

  // Callback methods for AssetAuditFormComponent
  void _onRectifierItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedRectifierItems = updatedItems;
      hasUnsavedChanges = true;
      print('Rectifier items updated: ${updatedItems.length} items');
    });
  }

  void _onMpptItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedMpptItems = updatedItems;
      hasUnsavedChanges = true;
      print('MPPT items updated: ${updatedItems.length} items');
    });
  }

  void _onCabinetItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedCabinetItems = updatedItems;
      hasUnsavedChanges = true;
      print('Cabinet items updated: ${updatedItems.length} items');
    });
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
    Set<String> photoIds = {};

    // Add photo IDs from rectifier items
    for (var item in savedRectifierItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId'].toString());
      }
    }

    // Add photo IDs from MPPT items
    for (var item in savedMpptItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId'].toString());
      }
    }

    // Add photo IDs from cabinet items
    for (var item in savedCabinetItems) {
      if (item['photoId'] != null) {
        photoIds.add(item['photoId'].toString());
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
      final imageMap = await _imageService.fetchImagesByIds(
        photoIds.map((id) => int.parse(id)).toList(),
      );

      // Update cache and remove loading state
      setState(() {
        _imageCache.addAll(
          imageMap.map((key, value) => MapEntry(key.toString(), value)),
        );
        _loadingImages.removeAll(photoIds);
      });
    } catch (e) {
      setState(() {
        _loadingImages.removeAll(photoIds);
      });
    }
  }

  // Navigation methods
  void _navigateToNextScreen(BuildContext context, String? nextScreen) {
    if (nextScreen != null) {
      AssetAuditNavigationHelper.navigateToNextTelecomScreenDeprecated(
        context,
        nextScreen,
        widget.siteType ?? '',
        widget.auditSchId ?? '',
        widget.siteAuditSchId ?? '',
        widget.assetAuditData,
      );
    } else {
      // No next screen available, go to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }

  // Helper method to get the next available screen based on data availability
  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableTelecomScreen(widget.assetAuditData, 'CCU');
  }

  // Helper method to get the previous available screen based on data availability
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableTelecomScreen(widget.assetAuditData, 'CCU');
  }

  Future<void> _saveAndExit() async {
    // Save current screen data before exiting
    await _postCurrentScreenData();
  }

  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      return false;
    }

    try {
      // Create a list to hold all requests to post
      List<AssetAuditPostRequest> allRequests = [];

      // Add saved Rectifier items
      if (savedRectifierItems.isNotEmpty) {
        final rectifierRequests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
          savedItems: savedRectifierItems,
          assetAuditData: widget.assetAuditData!,
          itemType: 'Rectifier',
          itemTypeId: 1, // You may need to adjust this based on your item type IDs
          screenName: 'CCU',
          context: context,
          auditSchId: widget.auditSchId,
        );
        allRequests.addAll(rectifierRequests);
      }

      // Add saved MPPT items
      if (savedMpptItems.isNotEmpty) {
        final mpptRequests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
          savedItems: savedMpptItems,
          assetAuditData: widget.assetAuditData!,
          itemType: 'MPPT',
          itemTypeId: 2, // You may need to adjust this based on your item type IDs
          screenName: 'CCU',
          context: context,
          auditSchId: widget.auditSchId,
        );
        allRequests.addAll(mpptRequests);
      }

      // Add saved Cabinet items
      if (savedCabinetItems.isNotEmpty) {
        final cabinetRequests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
          savedItems: savedCabinetItems,
          assetAuditData: widget.assetAuditData!,
          itemType: 'Cabinet',
          itemTypeId: 3, // You may need to adjust this based on your item type IDs
          screenName: 'CCU',
          context: context,
          auditSchId: widget.auditSchId,
        );
        allRequests.addAll(cabinetRequests);
      }

      if (allRequests.isNotEmpty) {
        // Post the data using AssetAuditCubit
        context.read<AssetAuditCubit>().postAssetAuditData(
          requests: allRequests,
        );
        return true;
      }

      return true; // No data to post, but that's okay
    } catch (e) {
      print('Error posting CCU data: $e');
      return false;
    }
  }

  Widget build(BuildContext context) {
    return BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
      listener: (context, state) {
        if (state is AssetAuditGetImageSuccess &&
            _isRequestingImage &&
            _currentRequestedImageId != null) {
          final imageData = state.imageData;
          if (imageData.isNotEmpty) {
            // Store in cache
            _imageCache[_currentRequestedImageId!] = imageData;
            // Image data is now handled by AssetAuditFormComponent
          }
          // Reset flags
          _isRequestingImage = false;
          _currentRequestedImageId = null;
        } else if (state is AssetAuditGetImageFailure && _isRequestingImage) {
          _isRequestingImage = false;
          _currentRequestedImageId = null;
        }
      },
      child: BlocConsumer<AssetAuditCubit, AssetAuditState>(
        listener: (context, state) {
          if (state is AssetAuditLoaded) {
            // Update the local data with fresh data from API
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Data loading is now handled by AssetAuditFormComponent
              }
            });
          } else if (state is AssetAuditPostSuccess) {
            // Check if this success state contains CCU-related items
            bool isCCUData = false;
            for (var response in state.responses) {
              if (response.itemTypeRemark != null &&
                  (response.itemTypeRemark!.contains('CCU') ||
                      response.itemTypeRemark!.contains('Cabinet') ||
                      response.itemTypeRemark!.contains('Rectifier') ||
                      response.itemTypeRemark!.contains('MPPT'))) {
                isCCUData = true;
                break;
              }
              if (_hasPostedCCUData) {
                isCCUData = true;
                break;
              }
            }

            if (isCCUData) {
              _hasPostedCCUData = false;
              // Refresh data from API to show updated items
              if (mounted) {
                print('CCU Debug: Refreshing data after successful API posting');
                context.read<AssetAuditCubit>().getAssetAuditData(
                  siteType: widget.assetAuditData?.pageHeader.first.siteDomainName ?? "",
                  auditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "",
                  siteAuditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "",
                );
              }
            }
          } else if (state is AssetAuditPostError) {
            if (_hasPostedCCUData) {
              print("error");
              setState(() {
                _hasPostedCCUData = false;
              });
            }
          }
        },
        builder: (context, state) {
          return PopScope(
            canPop: !hasUnsavedChanges,
            child: Scaffold(
              extendBodyBehindAppBar: true,
              resizeToAvoidBottomInset: false,
              appBar: CustomFormAppbar(
                title: "Asset Audit",
                onClose: () async {
                  if (hasUnsavedChanges) {
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (dialogContext) => UnsavedChangesDialog(
                        siteAuditSchId: widget.siteAuditSchId,
                        section: "Asset Audit",
                        parentContext: context, // Use the outer context (screen context)
                        onSaveAndExit: () async {
                          await _saveAndExit();
                        },
                        onDiscard: () {
                        },
                      ),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => HomeScreen()
                      ),
                    );
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
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom + 120,
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
                                    // CCU Cabinet Form
                                    AssetAuditFormComponent(
                                      componentId: 'cabinet_component',
                                      serialLabel: "Cabinet - Serial Number *",
                                      serialHintText: "Cabinet Serial Number *",
                                      photoLabel: "Add a Photo",
                                      disabledFieldLabel: "Cabinet Status",
                                      disabledFieldValue: "Available",
                                      serialController: cabinetSerialController,
                                      initialSavedItems: savedCabinetItems,
                                      onItemSaved: _onCabinetItemSaved,
                                      onStatusChanged: (bool? status) {
                                        // Handle status change if needed
                                      },
                                      customValidator: _validateCabinetSerialNumber,
                                      customValidationErrorMessage: 'Invalid serial number! Please check and try again.',
                                      siteAuditSchId: widget.siteAuditSchId,
                                      showTable: true,
                                      tableTitle: "Saved Cabinet Items",
                                      imageHeight: 150,
                                      enableImageCompression: true,
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // CCU Rectifier Form
                                    AssetAuditFormComponent(
                                      componentId: 'rectifier_component',
                                      serialLabel: "Rectifier - Serial Number *",
                                      serialHintText: "Rectifier Serial Number *",
                                      photoLabel: "Add a Photo",
                                      disabledFieldLabel: "Rectifier Status",
                                      disabledFieldValue: "Available",
                                      serialController: rectifierSerialController,
                                      initialSavedItems: savedRectifierItems,
                                      onItemSaved: _onRectifierItemSaved,
                                      onStatusChanged: (bool? status) {
                                        // Handle status change if needed
                                      },
                                      customValidator: _validateRectifierSerialNumber,
                                      customValidationErrorMessage: 'Invalid serial number! Please check and try again.',
                                      siteAuditSchId: widget.siteAuditSchId,
                                      showTable: true,
                                      tableTitle: "Saved Rectifier Items",
                                      imageHeight: 150,
                                      enableImageCompression: true,
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // CCU MPPT Form
                                    AssetAuditFormComponent(
                                      componentId: 'mppt_component',
                                      serialLabel: "MPPT - Serial Number *",
                                      serialHintText: "MPPT Serial Number *",
                                      photoLabel: "Add a Photo",
                                      disabledFieldLabel: "MPPT Status",
                                      disabledFieldValue: "Available",
                                      serialController: mpptSerialController,
                                      initialSavedItems: savedMpptItems,
                                      onItemSaved: _onMpptItemSaved,
                                      onStatusChanged: (bool? status) {
                                        // Handle status change if needed
                                      },
                                      customValidator: _validateMpptSerialNumber,
                                      customValidationErrorMessage: 'Invalid serial number! Please check and try again.',
                                      siteAuditSchId: widget.siteAuditSchId,
                                      showTable: true,
                                      tableTitle: "Saved MPPT Items",
                                      imageHeight: 150,
                                      enableImageCompression: true,
                                    ),
                                    
                                    const SizedBox(height: 20),
                                    
                                    // General Remarks
                                    CustomRemarksField(
                                      label: "Add Remarks",
                                      hintText: "Remarks",
                                      controller: generalRemarksController,
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
                                  text: _getPreviousAvailableScreen() ?? 'BACK',
                                  isLeftArrow: true,
                                  backgroundColor: AppColors.buttonColorBg,
                                  textColor: AppColors.buttonColorSite,
                                  onPressed: () {
                                    final prevScreen = _getPreviousAvailableScreen();
                                    if(prevScreen != null) {
                                      _navigateToNextScreen(context, prevScreen);
                                    } else {
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: ArrowButton(
                                  text: _getNextAvailableScreen() ?? 'SUBMIT',
                                  isLeftArrow: false,
                                  backgroundColor: AppColors.buttonColorBackBg,
                                  textColor: AppColors.buttonColorTextBg,
                                  onPressed: () {
                                    _postCurrentScreenData();
                                    _navigateToNextScreen(context, _getNextAvailableScreen());
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
      ),
    );
  }
}
