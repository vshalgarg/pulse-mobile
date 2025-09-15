import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/extinguisher_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/asset_audit_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../utils/asset_audit_navigation_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';

import '../../../bloc/asset_audit_state.dart';
import '../../../repositories/image_repository.dart';
import '../../../services/api_provider.dart';
import '../../../app_config.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/qr_screen_form_field.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../home_screen.dart';

class BatteryScreen extends StatefulWidget {
  final CategoryData? batteryData;
  final AssetAuditModel? assetAuditData;
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;

  const BatteryScreen({
    super.key,
    this.batteryData,
    this.assetAuditData,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
  });

  @override
  State<BatteryScreen> createState() => _BatteryScreenState();
}

class _BatteryScreenState extends State<BatteryScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  
  // Controllers for AssetAuditFormComponent
  final TextEditingController cbmsSerialController = TextEditingController();
  final TextEditingController batterySerialController = TextEditingController();
  final TextEditingController moduleSerialController = TextEditingController();
  final TextEditingController generalRemarksController = TextEditingController();
  
  // Saved items for each form
  List<Map<String, dynamic>> savedCbmsItems = [];
  List<Map<String, dynamic>> savedBatteryItems = [];
  List<Map<String, dynamic>> savedModuleItems = [];
  
  // Loading states
  bool _isLoadingAssetData = false;
  bool _isPostingData = false;
  
  // Track if we're editing existing items
  bool _isEditingExistingItem = false;

  bool _hasPostedBatteryData = false;

  late ImageRepository _imageService;
  Map<int, String> _imageCache = {};

  // Custom validation functions for AssetAuditFormComponent
  bool _validateCbmsSerialNumber(String serialNumber, bool isQRCodeScanned) {
    print('🔍 CBMS Validation - Serial: $serialNumber, QR: $isQRCodeScanned');
    
    if (widget.batteryData == null) {
      print('❌ CBMS Validation - No battery data');
      return false;
    }
    
    // Check CBMS items
      final cbmsItems = widget.batteryData!.cbms ?? [];
    print('🔍 CBMS Validation - CBMS items count: ${cbmsItems.length}');
    
    bool isValid = false;
    
    if (isQRCodeScanned) {
      isValid = cbmsItems.any(
        (item) {
          final nexgenSerial = item.nexgenSerialNo?.toLowerCase();
          final inputSerial = serialNumber.toLowerCase();
          print('🔍 CBMS QR Check - Comparing: "$nexgenSerial" with "$inputSerial"');
          return nexgenSerial == inputSerial;
        },
      );
    } else {
      isValid = cbmsItems.any(
        (item) {
          final mfgSerial = item.mfgSerialNo?.toLowerCase();
          final inputSerial = serialNumber.toLowerCase();
          print('🔍 CBMS Manual Check - Comparing: "$mfgSerial" with "$inputSerial"');
          return mfgSerial == inputSerial;
        },
      );
    }
    
    print('🔍 CBMS Validation Result: $isValid');
    return isValid;
  }

  bool _validateBatterySerialNumber(String serialNumber, bool isQRCodeScanned) {
    print('🔍 Battery Validation - Serial: $serialNumber, QR: $isQRCodeScanned');
    
    if (widget.batteryData == null) {
      print('❌ Battery Validation - No battery data');
      return false;
    }
    
    // Check Battery Cabinet items
      final batteryCabinetItems = widget.batteryData!.batteryCabinet ?? [];
    print('🔍 Battery Validation - Battery Cabinet items count: ${batteryCabinetItems.length}');
    
    bool isValid = false;
    
    if (isQRCodeScanned) {
      isValid = batteryCabinetItems.any(
        (item) {
          final nexgenSerial = item.nexgenSerialNo?.toLowerCase();
          final inputSerial = serialNumber.toLowerCase();
          print('🔍 Battery QR Check - Comparing: "$nexgenSerial" with "$inputSerial"');
          return nexgenSerial == inputSerial;
        },
      );
    } else {
      isValid = batteryCabinetItems.any(
        (item) {
          final mfgSerial = item.mfgSerialNo?.toLowerCase();
          final inputSerial = serialNumber.toLowerCase();
          print('🔍 Battery Manual Check - Comparing: "$mfgSerial" with "$inputSerial"');
          return mfgSerial == inputSerial;
        },
      );
    }
    
    print('🔍 Battery Validation Result: $isValid');
    return isValid;
  }

  bool _validateModuleSerialNumber(String serialNumber, bool isQRCodeScanned) {
    print('🔍 Module Validation - Serial: $serialNumber, QR: $isQRCodeScanned');
    
    if (widget.batteryData == null) {
      print('❌ Module Validation - No battery data');
      return false;
    }
    
    // Check general battery assets
    final batteryAssets = widget.batteryData!.assets ?? [];
    print('🔍 Module Validation - Battery assets count: ${batteryAssets.length}');
    
    bool isValid = false;
    
    if (isQRCodeScanned) {
      isValid = batteryAssets.any(
        (item) {
          final nexgenSerial = item.nexgenSerialNo?.toLowerCase();
          final inputSerial = serialNumber.toLowerCase();
          print('🔍 Module QR Check - Comparing: "$nexgenSerial" with "$inputSerial"');
          return nexgenSerial == inputSerial;
        },
      );
    } else {
      isValid = batteryAssets.any(
        (item) {
          final mfgSerial = item.mfgSerialNo?.toLowerCase();
          final inputSerial = serialNumber.toLowerCase();
          print('🔍 Module Manual Check - Comparing: "$mfgSerial" with "$inputSerial"');
          return mfgSerial == inputSerial;
        },
      );
    }
    
    print('🔍 Module Validation Result: $isValid');
    return isValid;
  }

  // Callback methods for AssetAuditFormComponent
  void _onCbmsItemSaved(List<Map<String, dynamic>> updatedItems) {
      setState(() {
      savedCbmsItems.clear();
      savedCbmsItems.addAll(updatedItems);
      hasUnsavedChanges = true;
      print('CBMS items updated: ${updatedItems.length} items');
      });
  }

  void _onBatteryItemSaved(List<Map<String, dynamic>> updatedItems) {
      setState(() {
      savedBatteryItems.clear();
      savedBatteryItems.addAll(updatedItems);
      hasUnsavedChanges = true;
      print('Battery items updated: ${updatedItems.length} items');
    });
  }

  void _onModuleItemSaved(List<Map<String, dynamic>> updatedItems) {
      setState(() {
      savedModuleItems.clear();
      savedModuleItems.addAll(updatedItems);
      hasUnsavedChanges = true;
      print('Module items updated: ${updatedItems.length} items');
    });
  }

  @override
  void initState() {
    super.initState();
    // ImageRepository will be initialized in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize image service
    _imageService = ImageRepository(AppConfig.of(context).apiProvider);
    
    // Load data from API if not already loaded
    if (widget.assetAuditData == null) {
      setState(() {
        _isLoadingAssetData = true;
      });
      
      context.read<AssetAuditCubit>().getAssetAuditData(
        siteType: widget.siteType,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );
    }
  }

  // Helper method to get the next available screen based on data availability
  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableTelecomScreen(widget.assetAuditData, 'Battery');
  }

  // Helper method to get the previous available screen based on data availability
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableTelecomScreen(widget.assetAuditData, 'Battery');
  }

  // Helper method to navigate to the next screen based on screen name
  void _navigateToNextScreenWithName(BuildContext context, String screenName) {
    AssetAuditNavigationHelper.navigateToNextTelecomScreen(
      context,
      screenName,
      widget.siteType,
      widget.auditSchId,
      widget.siteAuditSchId,
      widget.assetAuditData,
    );
  }

  // Check if there's data to show
  bool _hasDataToShow() {
    if (widget.batteryData == null) {
      return false;
    }

    // Check if we have any assets
    final hasAssets = widget.batteryData!.assets.isNotEmpty;

    // Check if we have any subcategories with data
    final hasSubCategories = widget.batteryData!.subCategories != null &&
        widget.batteryData!.subCategories!.values.any((items) => items.isNotEmpty);
    if (widget.batteryData!.subCategories != null) {
      for (var entry in widget.batteryData!.subCategories!.entries) {
        if (entry.value.isNotEmpty) {
          return true;
        }
      }
    }
    
    return hasAssets || hasSubCategories;
  }

  String _getBatteryOEMName() {
    if (widget.batteryData != null) {
      final batteryCabinetItems = widget.batteryData!.batteryCabinet ?? [];
      if (batteryCabinetItems.isNotEmpty) {
        return batteryCabinetItems.first.oemName ?? 'Delta';
      }

      final batteryAssets = widget.batteryData!.assets ?? [];
      if (batteryAssets.isNotEmpty) {
        return batteryAssets.first.oemName ?? 'Delta';
      }

      final cbmsItems = widget.batteryData!.cbms ?? [];
      if (cbmsItems.isNotEmpty) {
        return cbmsItems.first.oemName ?? 'Delta';
      }
    }

    return 'Delta'; // Default fallback
  }

  // Method to get Battery capacity from API data
  String _getBatteryCapacity() {
    if (widget.batteryData != null) {
      // Try to get capacity from Battery assets first
      final batteryAssets = widget.batteryData!.assets ?? [];
      if (batteryAssets.isNotEmpty) {
        return batteryAssets.first.capacity ?? '200 AH';
      }

      // Fallback to Battery Cabinet if assets not available
      final batteryCabinetItems = widget.batteryData!.batteryCabinet ?? [];
      if (batteryCabinetItems.isNotEmpty) {
        return batteryCabinetItems.first.capacity ?? '200 AH';
      }

      // Fallback to CBMS if available
      final cbmsItems = widget.batteryData!.cbms ?? [];
      if (cbmsItems.isNotEmpty) {
        return cbmsItems.first.capacity ?? '200 AH';
    }
  }

    return '200 AH'; // Default fallback
  }

  // Helper method to get asset audit site response ID for different item types
  int? _getAssetAuditSiteRespId(String itemType) {
    if (widget.batteryData == null) return null;

      switch (itemType) {
        case 'CBMS':
          final cbmsItems = widget.batteryData!.cbms ?? [];
          if (cbmsItems.isNotEmpty) {
            return cbmsItems.first.assetAuditSiteRespId;
          }
          break;
        case 'Battery':
          final batteryAssets = widget.batteryData!.assets ?? [];
          if (batteryAssets.isNotEmpty) {
            return batteryAssets.first.assetAuditSiteRespId;
          }
          break;
      }

    return null;
  }

  // Helper method to get remarks asset audit site response ID
  int? _getRemarksAssetAuditSiteRespId() {
    if (widget.batteryData == null) return null;

    // Try to get from CBMS first
    final cbmsItems = widget.batteryData!.cbms ?? [];
    if (cbmsItems.isNotEmpty) {
      return cbmsItems.first.assetAuditSiteRespId;
    }

    // Fallback to Battery assets
    final batteryAssets = widget.batteryData!.assets ?? [];
    if (batteryAssets.isNotEmpty) {
      return batteryAssets.first.assetAuditSiteRespId;
    }

    return null;
  }

  /// Post current screen data to API before navigating to next screen
  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      return false;
    }

    try {
      // Create a list to hold all items to post
      List<Map<String, dynamic>> allItemsToPost = [];

      // Add saved CBMS items
      if (savedCbmsItems.isNotEmpty) {
        final enhancedCBMSItems = AssetAuditPostHelper.enhanceSavedItems(
          savedItems: savedCbmsItems,
          screenName: 'CBMS',
        );
        allItemsToPost.addAll(enhancedCBMSItems);
      }

      // Add saved Battery items
      if (savedBatteryItems.isNotEmpty) {
        final enhancedBatteryItems = AssetAuditPostHelper.enhanceSavedItems(
          savedItems: savedBatteryItems,
          screenName: 'Battery',
        );
        allItemsToPost.addAll(enhancedBatteryItems);
      }

      // Add saved Module items
      if (savedModuleItems.isNotEmpty) {
        final enhancedModuleItems = AssetAuditPostHelper.enhanceSavedItems(
          savedItems: savedModuleItems,
          screenName: 'Module',
        );
        allItemsToPost.addAll(enhancedModuleItems);
      }

      // Add user's general remarks if entered
      if (generalRemarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();

        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'Battery',
            'remarks': generalRemarksController.text,
            'recordType': 'Remarks',
            'timestamp': DateTime.now(),
            'assetAuditSiteRespId': remarksAssetAuditSiteRespId,
            'status': 'OK',
            'serialNumber': 'REMARKS',
            'photo': null,
            'photoTakenTs': DateTime.now().toString(),
            'isQRCodeScanned': false,
            'localQrCodeScannedTs': DateTime.now().toString(),
            'localCreatedDt': DateTime.now().toString(),
            'localModifiedDt': DateTime.now().toString(),
          };
          allItemsToPost.add(remarksData);
        }
      }

      if (allItemsToPost.isEmpty) {
        print('Battery Screen: No items to post');
        return true; // No items to post, but that's okay
      }

      final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
        savedItems: allItemsToPost,
        assetAuditData: widget.assetAuditData!,
        itemType: 'Battery',
        itemTypeId: 5,
        screenName: 'battery',
        context: context,
        auditSchId: widget.auditSchId,
      );

      if (requests.isNotEmpty) {
      setState(() {
          _isPostingData = true;
        _hasPostedBatteryData = true;
      });

        context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
      return true;
      }

      return false;
    } catch (e) {
      print('Error posting Battery data: $e');
      return false;
    }
  }

  Future<void> _saveAndExit() async {
    // Post Battery data to API first
    await _postCurrentScreenData();
  }

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      print('Attempting to update status to: $status');
      await context.read<AuditScheduleStatusCubit>().updateStatus(
        status: status,
        siteAuditSchId: widget.siteAuditSchId,
      );
      print('Status update call completed');
    } catch (e) {
      print('Error updating audit schedule status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
            if (state is AssetAuditLoaded) {
          setState(() {
                _isLoadingAssetData = false;
              });
            } else if (state is AssetAuditError) {
              setState(() {
                _isLoadingAssetData = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'Error loading data'),
                  backgroundColor: Colors.red,
                ),
              );
            } else if (state is AssetAuditPosting) {
              setState(() {
                _isPostingData = true;
              });
            } else if (state is AssetAuditPostSuccess) {
          // Only navigate if this Battery screen posted data (not from other screens)
          if (_hasPostedBatteryData) {
            // Refresh data from API before navigating
            try {
              // Trigger a refresh of the asset audit data
              context.read<AssetAuditCubit>().getAssetAuditData(
                siteType: widget.assetAuditData?.pageHeader.first.siteDomainName ?? "",
                auditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "",
                siteAuditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "",
              );

              // Wait for data to refresh, then navigate
                if (mounted) {
                  try {
                      _navigateToNextScreen();
                    // Reset the flag after successful navigation
                    setState(() {
                      _hasPostedBatteryData = false;
                    });
                  } catch (e) {
                    print(e);
                  }
                }

            } catch (e) {
              // Fallback: navigate immediately
              if (mounted) {
                try {
                      _navigateToNextScreen();
                    setState(() {
                      _hasPostedBatteryData = false;
                    });
                  } catch (e) {
                  }
                }
            }
          }

        } else if (state is AssetAuditPostError) {
          // Only show error message if this error belongs to Battery screen data
          if (_hasPostedBatteryData) {
            // Show error message but don't block navigation completely
            showCustomToast(context, '❌ Failed to save Battery data to server. You can continue with local data.');

            // Reset the flag on error
            setState(() {
              _hasPostedBatteryData = false;
            });
          }
        }
      },
        ),
      ],
      child: PopScope(
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
              // Loading indicator for getAssetAuditData API
              if (_isLoadingAssetData)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.green7),
                    ),
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
                            MediaQuery.of(context).viewInsets.bottom + 120,
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
                                if (_hasDataToShow()) ...[
                                  // CBMS Form
                                  Text(
                                    "CBMS Details",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      fontFamily: fontFamilyMontserrat,
                                    ),
                                  ),
                                  getHeight(10),
                                  AssetAuditFormComponent(
                                    componentId: 'cbms_component',
                                    serialLabel: "CBMS - Serial Number *",
                                    serialHintText: "CBMS Serial Number *",
                                    photoLabel: "Add a Photo",
                                    disabledFieldLabel: "CBMS Status",
                                    disabledFieldValue: "Available",
                                    serialController: cbmsSerialController,
                                    initialSavedItems: savedCbmsItems,
                                    onItemSaved: _onCbmsItemSaved,
                                    onStatusChanged: (status) {
                                      // Handle status change if needed
                                    },
                                    customValidator: _validateCbmsSerialNumber,
                                    customValidationErrorMessage: 'Invalid serial number! Please check and try again.',
                                    siteAuditSchId: widget.siteAuditSchId,
                                    showTable: true,
                                    tableTitle: "Saved CBMS Items",
                                    imageHeight: 150,
                                    enableImageCompression: true,
                                  ),
                                  getHeight(20),
                                  
                                  // Battery Form
                                  Text(
                                    "Battery Details",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      fontFamily: fontFamilyMontserrat,
                                    ),
                                  ),
                                  getHeight(10),
                                  CustomFormField(
                                    label: "Battery Make",
                                    initialValue: _getBatteryOEMName(),
                                    isRequired: false,
                                    isEditable: false,
                                  ),
                                  getHeight(15),
                                  AssetAuditFormComponent(
                                    componentId: 'battery_component',
                                    serialLabel: "Battery Cabinet Serial Number *",
                                    serialHintText: "Battery Cabinet Serial Number *",
                                    photoLabel: "Add Photo of Battery Modules",
                                    disabledFieldLabel: "Battery Status",
                                    disabledFieldValue: "Available",
                                    serialController: batterySerialController,
                                    initialSavedItems: savedBatteryItems,
                                    onItemSaved: _onBatteryItemSaved,
                                    onStatusChanged: (status) {
                                      // Handle status change if needed
                                    },
                                    customValidator: _validateBatterySerialNumber,
                                    customValidationErrorMessage: 'Invalid serial number! Please check and try again.',
                                    siteAuditSchId: widget.siteAuditSchId,
                                    showTable: true,
                                    tableTitle: "Saved Battery Items",
                                    imageHeight: 150,
                                    enableImageCompression: true,
                                  ),
                                  getHeight(20),
                                  
                                  // Module Form
                                  Text(
                                    "Module Details",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                      fontFamily: fontFamilyMontserrat,
                                    ),
                                  ),
                                  getHeight(10),
                                  AssetAuditFormComponent(
                                    componentId: 'module_component',
                                    serialLabel: "Module - Serial Number *",
                                    serialHintText: "Module Serial Number *",
                                    photoLabel: "Add a Photo",
                                    disabledFieldLabel: "Module Status",
                                    disabledFieldValue: "Available",
                                    serialController: moduleSerialController,
                                    initialSavedItems: savedModuleItems,
                                    onItemSaved: _onModuleItemSaved,
                                    onStatusChanged: (status) {
                                      // Handle status change if needed
                                    },
                                    customValidator: _validateModuleSerialNumber,
                                    customValidationErrorMessage: 'Invalid serial number! Please check and try again.',
                                    siteAuditSchId: widget.siteAuditSchId,
                                    showTable: true,
                                    tableTitle: "Saved Module Items",
                                    imageHeight: 150,
                                    enableImageCompression: true,
                                  ),
                                  getHeight(20),
                                  
                                  // General Remarks
                                  CustomRemarksField(
                                    label: "Add Remarks",
                                    hintText: "Remarks",
                                    controller: generalRemarksController,
                                  ),
                                ] else ...[
                                  _buildNoDataMessage(),
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
                                text: AssetAuditNavigationHelper.getPreviousAvailableTelecomScreen(
                                  widget.assetAuditData, 
                                  'Battery'
                                ) ?? 'BACK',
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
                                text: AssetAuditNavigationHelper.getNextAvailableTelecomScreen(
                                  widget.assetAuditData, 
                                  'Battery'
                                ) ?? 'SUBMIT',
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () async {
                                  // If no data to show, just navigate to next screen
                                  if (!_hasDataToShow()) {
                                    _navigateToNextScreen();
                                    return;
                                  }

                                  // Allow navigation - no validation blocking

                                  // Post current screen data before navigating
                                  final success = await _postCurrentScreenData();

                                  if (success) {
                                    _navigateToNextScreen();
                                  } else {
                                    showCustomToast(context, 'Failed to post data. Please try again.');
                                  }
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
      ),
    );
  }

  Widget _buildNoDataMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Center(
                        child: Text(
          "No battery data available for this site.",
                    style: TextStyle(
                      color: Colors.white,
            fontSize: 16,
                      fontFamily: fontFamilyMontserrat,
          ),
        ),
      ),
    );
  }

  void _navigateToNextScreen() {
    final nextScreen = _getNextAvailableScreen();
    if (nextScreen != null) {
      _navigateToNextScreenWithName(context, nextScreen);
            } else {
      // No next screen available, go to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }
}