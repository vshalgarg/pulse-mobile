import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/survelliance_screen.dart';
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

import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../home_screen.dart';

class SolarPlatesScreen extends StatefulWidget {
  final CategoryData? solarPlatesData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage; // Flag to show success message
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;

  // Data from previous screens in the flow
  final List<Map<String, dynamic>>? extinguisherItems;

  const SolarPlatesScreen({
    super.key,
    this.solarPlatesData,
    this.assetAuditData,
    this.showSuccessMessage = false, // Default to false
    this.extinguisherItems,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
  });

  @override
  State<SolarPlatesScreen> createState() => _SolarPlatesScreenState();
}

class _SolarPlatesScreenState extends State<SolarPlatesScreen> {
  // Controllers for AssetAuditFormComponent
  final TextEditingController solarPanelSerialController = TextEditingController();
  final TextEditingController solarInverterSerialController = TextEditingController();
  final TextEditingController generalRemarksController = TextEditingController();
  final TextEditingController solarPanelCapacityController = TextEditingController();

  // Saved items lists
  List<Map<String, dynamic>> savedSolarPanelItems = [];
  List<Map<String, dynamic>> savedSolarInverterItems = [];

  // State management
  bool hasUnsavedChanges = false;
  bool _isLoadingAssetData = false;
  bool _isPostingData = false;
  bool _hasPostedSolarPlatesData = false;

  // Image service
  late ImageRepository _imageService;
  Map<String, String> _imageCache = {};
  Set<String> _loadingImages = {};
  String? _currentRequestedImageId;
  bool _isRequestingImage = false;

  // Data counts
  int totalSolarPanelItems = 0;
  int totalSolarInverterItems = 0;

  // Validation methods for AssetAuditFormComponent
  bool _validateSolarPanelSerialNumber(String serialNumber, bool isQRCodeScanned) {
    print('🔍 Solar Panel Validation - Serial: $serialNumber, QR: $isQRCodeScanned');
    
    if (widget.assetAuditData == null) {
      print('🔍 No asset audit data available for validation');
      return true;
    }

    final solarPlatesData = widget.assetAuditData!.responseData.categories['Solar Plates'];
    if (solarPlatesData == null) {
      print('🔍 No Solar Plates data available for validation');
      return true;
    }

    final solarPanelItems = solarPlatesData.assets;
    print('🔍 Solar Panel Validation - Solar Panel items count: ${solarPanelItems.length}');

    if (isQRCodeScanned) {
      // For QR code scans, validate against nexgen_serial_no
      final isValid = solarPanelItems.any(
        (item) => item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );
      print('🔍 Solar Panel QR Check - Comparing: "${solarPanelItems.map((e) => e.nexgenSerialNo).toList()}" with "$serialNumber"');
      print('🔍 Solar Panel Validation Result: $isValid');
      return isValid;
    } else {
      // For manual entries, validate against mfg_serial_no
      final isValid = solarPanelItems.any(
        (item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );
      print('🔍 Solar Panel Manual Check - Comparing: "${solarPanelItems.map((e) => e.mfgSerialNo).toList()}" with "$serialNumber"');
      print('🔍 Solar Panel Validation Result: $isValid');
      return isValid;
    }
  }

  bool _validateSolarInverterSerialNumber(String serialNumber, bool isQRCodeScanned) {
    print('🔍 Solar Inverter Validation - Serial: $serialNumber, QR: $isQRCodeScanned');
    
    if (widget.assetAuditData == null) {
      print('🔍 No asset audit data available for validation');
      return true;
    }

    final solarPlatesData = widget.assetAuditData!.responseData.categories['Solar Plates'];
    if (solarPlatesData == null) {
      print('🔍 No Solar Plates data available for validation');
      return true;
    }

    final solarInverterItems = solarPlatesData.assets;
    print('🔍 Solar Inverter Validation - Solar Inverter items count: ${solarInverterItems.length}');

    if (isQRCodeScanned) {
      // For QR code scans, validate against nexgen_serial_no
      final isValid = solarInverterItems.any(
        (item) => item.nexgenSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );
      print('🔍 Solar Inverter QR Check - Comparing: "${solarInverterItems.map((e) => e.nexgenSerialNo).toList()}" with "$serialNumber"');
      print('🔍 Solar Inverter Validation Result: $isValid');
      return isValid;
    } else {
      // For manual entries, validate against mfg_serial_no
      final isValid = solarInverterItems.any(
        (item) => item.mfgSerialNo?.toLowerCase() == serialNumber.toLowerCase(),
      );
      print('🔍 Solar Inverter Manual Check - Comparing: "${solarInverterItems.map((e) => e.mfgSerialNo).toList()}" with "$serialNumber"');
      print('🔍 Solar Inverter Validation Result: $isValid');
      return isValid;
    }
  }

  // Callback methods for AssetAuditFormComponent
  void _onSolarPanelItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedSolarPanelItems = updatedItems;
      hasUnsavedChanges = true;
      print('Solar Panel items updated: ${updatedItems.length} items');
    });
  }

  void _onSolarInverterItemSaved(List<Map<String, dynamic>> updatedItems) {
    setState(() {
      savedSolarInverterItems = updatedItems;
      hasUnsavedChanges = true;
      print('Solar Inverter items updated: ${updatedItems.length} items');
    });
  }

  // Method to get OEM name from API data
  String _getSolarPlatesOEMName() {
    if (widget.assetAuditData != null) {
      final solarPlatesData = widget.assetAuditData!.responseData.categories['Solar Plates'];
      if (solarPlatesData != null) {
        final solarPlatesAssets = solarPlatesData.assets;
        if (solarPlatesAssets.isNotEmpty) {
          return solarPlatesAssets.first.oemName ?? 'Delta';
        }
      }
    }
    return 'Delta'; // Default fallback
  }

  // Check if there are unsaved changes
  bool get _hasChanges {
    return savedSolarPanelItems.isNotEmpty ||
           savedSolarInverterItems.isNotEmpty ||
           generalRemarksController.text.isNotEmpty;
  }

  /// Check if there is data to show on the screen
  bool _hasDataToShow() {
    if (widget.assetAuditData == null) {
      print('Solar Plates Screen: No asset audit data available');
      return false;
    }

    final solarPlatesData = widget.assetAuditData!.responseData.categories['Solar Plates'];
    if (solarPlatesData == null) {
      print('Solar Plates Screen: No Solar Plates data available');
      return false;
    }

    // Check if we have any assets
    final hasAssets = solarPlatesData.assets.isNotEmpty;

    // Check if we have any subcategories with data
    final hasSubCategories =
        solarPlatesData.subCategories != null &&
        solarPlatesData.subCategories!.values.any(
          (items) => items.isNotEmpty,
        );

    final hasData = hasAssets || hasSubCategories;

    print('Solar Plates Screen: Data availability check:');
    print('  - Assets: $hasAssets (${solarPlatesData.assets.length})');
    print('  - Subcategories: $hasSubCategories');
    print('  - Has data to show: $hasData');

    return hasData;
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
    return AssetAuditNavigationHelper.getNextAvailableTelecomScreen(widget.assetAuditData, 'Solar Plates');
  }

  // Helper method to get the previous available screen based on data availability
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableTelecomScreen(widget.assetAuditData, 'Solar Plates');
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

      // Add saved Solar Panel items
      if (savedSolarPanelItems.isNotEmpty) {
        final solarPanelRequests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
          savedItems: savedSolarPanelItems,
          assetAuditData: widget.assetAuditData!,
          itemType: 'Solar Panel',
          itemTypeId: 1, // You may need to adjust this based on your item type IDs
          screenName: 'Solar Plates',
          context: context,
          auditSchId: widget.auditSchId,
        );
        allRequests.addAll(solarPanelRequests);
      }

      // Add saved Solar Inverter items
      if (savedSolarInverterItems.isNotEmpty) {
        final solarInverterRequests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
          savedItems: savedSolarInverterItems,
          assetAuditData: widget.assetAuditData!,
          itemType: 'Solar Inverter',
          itemTypeId: 2, // You may need to adjust this based on your item type IDs
          screenName: 'Solar Plates',
          context: context,
          auditSchId: widget.auditSchId,
        );
        allRequests.addAll(solarInverterRequests);
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
      print('Error posting Solar Plates data: $e');
      return false;
    }
  }

  /// Build the "No Data" message widget
  Widget _buildNoDataMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: AppColors.white.withOpacity(0.7),
          ),
          getHeight(16),
          Text(
            'No Solar Plates Data Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
              fontFamily: fontFamilyMontserrat,
            ),
            textAlign: TextAlign.center,
          ),
          getHeight(8),
          Text(
            'There are no Solar Panel or Solar Inverter items to audit for this site.',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.white.withOpacity(0.8),
              fontFamily: fontFamilyMontserrat,
            ),
            textAlign: TextAlign.center,
          ),
          getHeight(16),
          Text(
            'You can proceed to the next screen or contact your administrator if you believe this is an error.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.white.withOpacity(0.6),
              fontFamily: fontFamilyMontserrat,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _imageService = ImageRepository(AppConfig.of(context).apiProvider);
    _loadSolarPlatesData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (widget.assetAuditData == null) {
      print('🔍 DEBUG: Calling getAssetAuditData with:');
      print('  - siteType: ${widget.siteType}');
      print('  - auditSchId: ${widget.auditSchId}');
      print('  - siteAuditSchId: ${widget.siteAuditSchId}');

      context.read<AssetAuditCubit>().getAssetAuditData(
        siteType: widget.siteType,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );
    }
  }

  void _loadSolarPlatesData() {
    if (widget.assetAuditData != null) {
      final solarPlatesData = widget.assetAuditData!.responseData.categories['Solar Plates'];
      if (solarPlatesData != null) {
        setState(() {
          // Load Solar Plates assets data
          final solarPlatesAssets = solarPlatesData.assets;
          if (solarPlatesAssets.isNotEmpty) {
            // Process Solar Plates assets for count only
            for (var item in solarPlatesAssets) {
              print(
                'Solar Plates Asset Item: ${item.itemType} - ${item.nexgenSerialNo}',
              );
            }
          }

          // Load remarks and populate the CustomRemarksField
          final remarks = solarPlatesData.remarks;
          if (remarks.isNotEmpty) {
            // Process remarks and populate the CustomRemarksField
            for (var remark in remarks) {
              print(
                'Solar Plates Remark: ${remark.itemType} - ${remark.itemTypeRemark}',
              );

              // Populate the CustomRemarksField with the first valid remark
              if (remark.itemTypeRemark != null &&
                  remark.itemTypeRemark!.isNotEmpty) {
                generalRemarksController.text = remark.itemTypeRemark!;
                print(
                  'Solar Plates Screen: Loaded remark from API: ${remark.itemTypeRemark}',
                );
                break; // Use the first valid remark
              }
            }
          }

          // Update total count based on actual data
          totalSolarPanelItems = solarPlatesAssets.length;
          totalSolarInverterItems = solarPlatesAssets.length;

          print(
            'Solar Plates Data loaded: Total expected items: $totalSolarPanelItems',
          );
          print('Solar Plates Assets: ${solarPlatesAssets.length}');
        });
      }
    }
  }

  @override
  void dispose() {
    solarPanelSerialController.dispose();
    solarInverterSerialController.dispose();
    generalRemarksController.dispose();
    solarPanelCapacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AssetAuditCubit, AssetAuditState>(
      listener: (context, state) {
        if (state is AssetAuditLoaded) {
          setState(() {
            _isLoadingAssetData = false;
          });
        } else if (state is AssetAuditPostSuccess) {
          setState(() {
            _isPostingData = false;
            _hasPostedSolarPlatesData = false;
          });
        } else if (state is AssetAuditPostError) {
          setState(() {
            _isPostingData = false;
            _hasPostedSolarPlatesData = false;
          });
        }
      },
      child: PopScope(
        canPop: !_hasChanges,
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
                              if (_hasDataToShow()) ...[
                                CustomFormField(
                                  label: "Solar Panel Make",
                                  initialValue: _getSolarPlatesOEMName(),
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Count of Solar Panel",
                                  initialValue: totalSolarPanelItems.toString(),
                                  isRequired: true,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                CustomFormField(
                                  label: "Type of Solar Panel",
                                  initialValue: "Mono",
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                
                                // Solar Panel Form
                                AssetAuditFormComponent(
                                  componentId: 'solar_panel_component',
                                  serialLabel: "Solar Panel - Serial Number *",
                                  serialHintText: "Solar Panel Serial Number *",
                                  photoLabel: "Add a Photo",
                                  disabledFieldLabel: "Solar Panel Status",
                                  disabledFieldValue: "Available",
                                  serialController: solarPanelSerialController,
                                  initialSavedItems: savedSolarPanelItems,
                                  onItemSaved: _onSolarPanelItemSaved,
                                  onStatusChanged: (bool? status) {
                                    // Handle status change if needed
                                  },
                                  customValidator: _validateSolarPanelSerialNumber,
                                  customValidationErrorMessage: 'Invalid serial number! Please check and try again.',
                                  siteAuditSchId: widget.siteAuditSchId,
                                  showTable: true,
                                  tableTitle: "Saved Solar Panel Items",
                                  imageHeight: 150,
                                  enableImageCompression: true,
                                ),
                                
                                getHeight(20),
                                
                                // Solar Inverter Form
                                AssetAuditFormComponent(
                                  componentId: 'solar_inverter_component',
                                  serialLabel: "Solar Inverter - Serial Number *",
                                  serialHintText: "Solar Inverter Serial Number *",
                                  photoLabel: "Add a Photo",
                                  disabledFieldLabel: "Solar Inverter Status",
                                  disabledFieldValue: "Available",
                                  serialController: solarInverterSerialController,
                                  initialSavedItems: savedSolarInverterItems,
                                  onItemSaved: _onSolarInverterItemSaved,
                                  onStatusChanged: (bool? status) {
                                    // Handle status change if needed
                                  },
                                  customValidator: _validateSolarInverterSerialNumber,
                                  customValidationErrorMessage: 'Invalid serial number! Please check and try again.',
                                  siteAuditSchId: widget.siteAuditSchId,
                                  showTable: true,
                                  tableTitle: "Saved Solar Inverter Items",
                                  imageHeight: 150,
                                  enableImageCompression: true,
                                ),
                                
                                getHeight(20),
                                
                                CustomFormField(
                                  label: "Total Capacity of Solar (Kwatt)",
                                  initialValue: "20 KW",
                                  isRequired: false,
                                  isEditable: false,
                                ),
                                getHeight(15),
                                
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

                    // Navigation buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      child: Row(
                        children: [
                          Expanded(
                            child: ArrowButton(
                              text: _getPreviousAvailableScreen() ?? 'BACK',
                              isLeftArrow: true,
                              backgroundColor: AppColors.buttonColorBackBg,
                              textColor: AppColors.buttonColorTextBg,
                              onPressed: () {
                                final previousScreen = _getPreviousAvailableScreen();
                                if (previousScreen != null) {
                                  _navigateToNextScreen(context, previousScreen);
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
                              onPressed: () async {
                                if (savedSolarPanelItems.isNotEmpty || savedSolarInverterItems.isNotEmpty) {
                                  setState(() {
                                    _isPostingData = true;
                                    _hasPostedSolarPlatesData = true;
                                  });
                                  await _postCurrentScreenData();
                                }
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
                  if (state is AssetAuditPosting || _isPostingData) {
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
}
