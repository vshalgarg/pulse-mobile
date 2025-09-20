import 'package:app/enum/activity_type_enum.dart';
import 'package:app/screens/asset_audit/asset_audit_widget_helper/WidgetHelper.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/asset_audit_validation_helper.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../commonWidgets/simple_asset_audit_form_component.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/asset_audit_telecom_bottom_buttons.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../services/service_locator.dart';
import '../../../utils/logger.dart';
import '../../../services/asset_audit/central_service_initializer.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';
import '../../../services/asset_audit_post_service.dart';
import '../../../services/image_upload_service.dart';
import '../../../app_config.dart';

class BatteryV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;

  const BatteryV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
  });

  @override
  State<BatteryV2Screen> createState() => _BatteryV2ScreenState();
}

class _BatteryV2ScreenState extends State<BatteryV2Screen> {
  final String _screenName = 'Battery';
  
  // Service
  late CentralAssetAuditService _service;
  
  // Data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;
  
  // Controllers for each section
  final TextEditingController _batteryCabinetSerialController = TextEditingController();
  final TextEditingController _cbmsSerialController = TextEditingController();
  final TextEditingController _batterySerialController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  
  // State
  bool _isLoadingData = false;
  String? _errorMessage;
  bool _hasFormDataChanges = false;
  
  // Section visibility states
  bool _showCbmsDetails = false;

  @override
  void initState() {
    super.initState();
    _service = ServiceLocator().centralAssetAuditService;
    _loadData();
  }

  @override
  void dispose() {
    _batteryCabinetSerialController.dispose();
    _cbmsSerialController.dispose();
    _batterySerialController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (!_hasFormDataChanges) {
      setState(() {
        _hasFormDataChanges = true;
      });
    }
  }

  String? _getBatteryCabinetValue(String key) {
    final assets = _displayFormData?['batteryCabinetAllAssets'] as List?;
    if (assets?.isNotEmpty == true) {
      return assets!.first[key]?.toString();
    }
    return null;
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _errorMessage = null;
      });

      Logger.debugLog('🔄 Battery V2: Loading data for site ${widget.siteAuditSchId}');
      
      final data = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final batteryItems = data['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')]
        as Map<String, dynamic>? ?? {};

        // Parse Battery data
        final batteryCabinetAssets = batteryItems['Battery Cabinet'] as List<dynamic>? ?? [];
        final cbmsAssets = batteryItems['CBMS'] as List<dynamic>? ?? [];
        final batteryAssets = batteryItems['assets'] as List<dynamic>? ?? [];
        final remarksData = batteryItems['remarks'] as List<dynamic>? ?? [];

        final formData = <String, dynamic>{
          'cbmsAvailable': cbmsAssets.isNotEmpty ? "Yes" : "No",
          'capacity': batteryAssets.first?['capacity'],
          'batteryCabinetAssets': batteryCabinetAssets.where((obj) => obj['photo_id'] != null).toList(),
          'batteryCabinetAllAssets': batteryCabinetAssets,
          'batteryCabinetAvailable': batteryCabinetAssets.isNotEmpty,
          'cbmsAssets': cbmsAssets.where((obj) => obj['photo_id'] != null).toList(),
          'cbmsAllAssets': cbmsAssets,
          'batteryAssets': batteryAssets.where((obj) => obj['photo_id'] != null).toList(),
          'batteryAllAssets': batteryAssets,
          'remarks': remarksData.isNotEmpty ? remarksData.first['item_type_remark']?.toString() ?? "" : "",
        };

        setState(() {
          _isLoadingData = false;
          _assetAuditData = data;
          _displayFormData = formData;
          _showCbmsDetails = cbmsAssets.isNotEmpty;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeFormControllers(formData);
        });
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Failed to load Battery data';
        });
      }
    } catch (e) {
      Logger.errorLog('❌ Battery V2: Error loading data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Error loading data: $e';
      });
    }
  }

  void _initializeFormControllers(Map<String, dynamic> formData) {
    final remarks = formData['remarks'] ?? "";
    _remarksController.text = remarks;
    _remarksController.addListener(_onFormChanged);
    Logger.debugLog('📝 Initialized remarks controller with: $remarks');
    if (mounted) {
      setState(() {});
    }
  }

  // Callback methods for each AssetAuditFormComponent
  void _onBatteryCabinetItemSaved(List<Map<String, dynamic>> items) {
    _displayFormData?['batteryCabinetAssets'] = [...items];
    setState(() {
      _hasFormDataChanges = true;
    });
  }

  void _onCbmsItemSaved(List<Map<String, dynamic>> items) {
    _displayFormData?['cbmsAssets'] = [...items];
    setState(() {
      _hasFormDataChanges = true;
    });
  }

  void _onBatteryItemSaved(List<Map<String, dynamic>> items) {
    _displayFormData?['batteryAssets'] = [...items];
    setState(() {
      _hasFormDataChanges = true;
    });
  }

  // Validation methods for each section
  bool _validateBatteryCabinetSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedItems = _displayFormData?['batteryCabinetAllAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(serialNumber, savedItems, isQRCodeScanned);
  }

  bool _validateCbmsSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedItems = _displayFormData?['cbmsAllAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(serialNumber, savedItems, isQRCodeScanned);
  }

  bool _validateBatterySerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedItems = _displayFormData?['batteryAllAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(serialNumber, savedItems, isQRCodeScanned);
  }

  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 Battery V2: Starting postCurrentScreenData');
      
      final finalData = _assetAuditData?['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')];
      final finalRemarks = finalData?['remarks'] as List<dynamic>? ?? [];
      final finalBatteryCabinetAssets = finalData?['Battery Cabinet'] as List<dynamic>? ?? [];
      final finalCbmsAssets = finalData?['CBMS'] as List<dynamic>? ?? [];
      final finalBatteryAssets = finalData?['assets'] as List<dynamic>? ?? [];
      
      // Collect all modified assets
      final modifiedAssetsWithAllProperties = <dynamic>[];
      
      // Add Battery Cabinet assets
      final modifiedBatteryCabinetAssets = _displayFormData?['batteryCabinetAssets'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(DataTransformationHelper.modifyData(finalBatteryCabinetAssets, modifiedBatteryCabinetAssets));

      // Add CBMS assets
      final modifiedCbmsAssets = _displayFormData?['cbmsAssets'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(DataTransformationHelper.modifyData(finalCbmsAssets, modifiedCbmsAssets));

      // Add Battery assets
      final modifiedBatteryAssets = _displayFormData?['batteryAssets'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(DataTransformationHelper.modifyData(finalBatteryAssets, modifiedBatteryAssets));

      // Update remarks
      final String remark = _remarksController.text;
      if(remark.isNotEmpty && finalRemarks.isNotEmpty){
        try {
          finalRemarks.first['item_type_remark'] = remark;
          Logger.debugLog('✅ Updated remarks: $remark');
        } catch (e) {
          Logger.errorLog('❌ Error updating remarks: $e');
        }
      }
      
      // Update local data
      _service.updateDataInSqlite(siteAuditSchId: widget.siteAuditSchId, updatedData: _assetAuditData ?? {});

      // Prepare data for posting
      final postObject = [
        ...modifiedAssetsWithAllProperties,
        ...finalRemarks
      ];

      Logger.debugLog('📤 Battery V2: Prepared ${postObject.length} items for posting');
      // Post data with photo ID replacement
      await ServiceLocator().assetAuditPostService.postAssetAuditDataWithPhotoReplacement(
        requests: postObject,
        isLastPage: AssetAuditNavigationHelper.getTelecomNextScreenName(_assetAuditData, _screenName) == 'SUBMIT',
        activityType: ActivityTypeEnum.assetAudit,
      );


      Logger.debugLog('✅ Battery V2: Data posted successfully');
      
    } catch (e) {
      Logger.errorLog('❌ Battery V2: Error in postCurrentScreenData: $e');
      rethrow;
    }
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteAuditSchId,
          section: "Asset Audit",
          parentContext: context,
          onSaveAndExit: () async {
            await postCurrentScreenData();
          },
          onDiscard: () {
          },
        ),
      );
    } else {
      AssetAuditNavigationHelper.navigateToHomeScreen(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'Asset Audit',
        onClose: () {
          _showUnsavedChangesDialog();
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
                      bottom: MediaQuery.of(context).viewInsets.bottom + 100,
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
                          // Show loading indicator
                          if (_isLoadingData)
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: const Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: AppColors.primaryGreen,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Loading Battery data...',
                                      style: TextStyle(
                                        color: AppColors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Show error message
                          if (_errorMessage != null && !_isLoadingData)
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.errorColor,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: AppColors.errorColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: AppColors.errorColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _loadData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.errorColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Show form when data is loaded
                          if (!_isLoadingData && _errorMessage == null && _displayFormData != null)
                            _buildFormFields(),
                          
                          // Show message when no data
                          if (!_isLoadingData && _errorMessage == null && _displayFormData == null)
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: const Center(
                                child: Text(
                                  'No Battery data available',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Bottom buttons using your specific format
                AssetAuditTelecomBottomButtons(
                  isLoading: _isLoadingData,
                  errorMessage: _errorMessage,
                  onNextButtonClick: () async {
                    if(_hasFormDataChanges) {
                      await postCurrentScreenData();
                    }
                  },
                  assetAuditData: _assetAuditData,
                  auditSchId: widget.auditSchId,
                  siteType: widget.siteType,
                  siteAuditSchId: widget.siteAuditSchId,
                  screenName: _screenName,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CBMS Availability
        WidgetHelper.buildDisabledRadioField(
          label: "CBMS Available",
          isRequired: true,
          initialSelectedValue: _displayFormData?['cbmsAvailable'] ?? "No",
        ),
        getHeight(15),
        
        // CBMS Details Section (only show if available)
        if (_showCbmsDetails) ...[
          const Text(
            "CBMS Details",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          getHeight(15),
          
          // CBMS Form Component
          AssetAuditFormComponent(
            componentId: 'cbms_component',
            serialLabel: "CBMS - Serial Number *",
            serialHintText: "CBMS Serial Number *",
            photoLabel: "Add a Photo",
            serialController: _cbmsSerialController,
            initialSavedItems: _displayFormData?['cbmsAssets'] as List<dynamic>? ?? [],
            onItemSaved: _onCbmsItemSaved,
            onStatusChanged: (status) {
            },
            customValidator: _validateCbmsSerialNumber,
            customValidationErrorMessage: "Invalid CBMS serial number. Please check and try again.",
            siteAuditSchId: widget.siteAuditSchId,
            showTable: true,
            tableTitle: "CBMS Items",
          ),
          getHeight(20),
        ],
        if(_displayFormData?['batteryCabinetAvailable'] || false) ...[
        const Text(
          "Battery Cabinet Details",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        getHeight(15),
         // Battery Cabinet Form Component
         SimpleAssetAuditFormComponent(
           componentId: 'battery_cabinet_component',
           serialLabel: "Battery Cabinet - Serial Number *",
           serialHintText: "Battery Cabinet Serial Number *",
           photoLabel: "Add a Photo",
           serialController: _batteryCabinetSerialController,
           initialSerialValue: _getBatteryCabinetValue('mfg_serial_no'),
           initialPhotoId: _getBatteryCabinetValue('photo_id'),
           initialImageData: _getBatteryCabinetValue('image_data'),
           onDataChanged: (photoId, imageData, isQRCodeScanned, qrCodeScannedTs) {
             // Update the battery cabinet data
             if ((_displayFormData?['batteryCabinetAllAssets'] as List?)?.isNotEmpty == true) {
               final cabinet = (_displayFormData!['batteryCabinetAllAssets'] as List).first;
               _validateBatteryCabinetSerialNumber(_batteryCabinetSerialController.text, isQRCodeScanned ?? false);
               cabinet['photo_id'] = photoId;
               cabinet['image_data'] = imageData;
               cabinet['qr_code_scanned'] = isQRCodeScanned;
               cabinet['qr_code_scanned_ts'] = qrCodeScannedTs;
               _onBatteryCabinetItemSaved([cabinet]);
             }
           },
           siteAuditSchId: widget.siteAuditSchId,
         ),
        getHeight(20),
        ],
        // Count of Battery Modules
        CustomFormField(
          label: "Count of Battery Modules",
          initialValue: _displayFormData?['batteryAllAssets']?.length.toString() ?? "0",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),

        // Battery Details Section
        const Text(
          "Battery Details",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        
        // Battery Form Component
        AssetAuditFormComponent(
          componentId: 'battery_component',
          serialLabel: "Battery - Serial Number *",
          serialHintText: "Battery Serial Number *",
          photoLabel: "Add a Photo",
          disabledFieldLabel: "Capacity *",
          disabledFieldValue: _displayFormData?['capacity'] ?? 'N/A',
          serialController: _batterySerialController,
          initialSavedItems: _displayFormData?['batteryAssets'] as List<dynamic>? ?? [],
          onItemSaved: _onBatteryItemSaved,
          onStatusChanged: (status) {
          },
          customValidator: _validateBatterySerialNumber,
          customValidationErrorMessage: "Invalid Battery serial number. Please check and try again.",
          siteAuditSchId: widget.siteAuditSchId,
          showTable: true,
          tableTitle: "Battery Items",
        ),
        getHeight(20),
        
        // Remarks using CustomRemarksField
        CustomRemarksField(
          label: "Add Remarks",
          hintText: "Remarks",
          controller: _remarksController,
        ),
      ],
    );
  }
}