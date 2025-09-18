import 'dart:io';
import 'dart:convert';
import 'package:app/commonWidgets/asset_audit_solar_bottom_buttons.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/asset_audit_validation_helper.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_buttons/arrow_botton.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../utils/logger.dart';
import '../../../models/asset_audit_model.dart';
import '../../../services/asset_audit/central_service_initializer.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';
import '../../../services/asset_audit_post_service.dart';
import '../../../services/image_upload_service.dart';
import '../../../enum/activity_type_enum.dart';
import '../../../app_config.dart';

class PcuV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;

  const PcuV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
  });

  @override
  State<PcuV2Screen> createState() => _PcuV2ScreenState();
}

class _PcuV2ScreenState extends State<PcuV2Screen> {
  final String _screenName = 'PCU';
  
  // Service
  late CentralAssetAuditService _service;
  
  // Data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;
  
  // Controllers
  final TextEditingController _inverterSerialController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  
  // State
  bool _isLoadingData = false;
  String? _errorMessage;
  bool _hasFormDataChanges = false;
  
  // Image handling
  String? _selectedImagePath;
  String? _uploadedImgId;
  String? _fetchedImageData;

  @override
  void initState() {
    super.initState();
    _service = ServiceLocator().centralAssetAuditService;
    _loadData();
    
    // Add listeners for form changes
    _inverterSerialController.addListener(_onFormChanged);
    _remarksController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _inverterSerialController.dispose();
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

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _errorMessage = null;
      });

      Logger.debugLog('🔄 Inverter V2: Loading data for site ${widget.siteAuditSchId}');
      
      final data = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final inverterItems =
            data['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'SOLAR')]
            as Map<String, dynamic>? ?? {};

        if (inverterItems.isNotEmpty) {
          final firstItem = inverterItems['assets'].first;
          final formData = <String, dynamic>{
            'inverterMake': firstItem['oem_name']?.toString() ?? "N/A",
            'typeOfInverter': firstItem['item_type']?.toString() ?? "N/A",
            'capacity': firstItem['capacity']?.toString() ?? "N/A",
            'totalItems': inverterItems['assets'].length.toString(),
            'remarks': inverterItems['remarks'].first['item_type_remark']?.toString() ?? "",
            'assets': inverterItems['assets'].where((obj) => obj['photo_id'] != null).toList(),
            'allAssets': inverterItems['assets'],
          };

          setState(() {
            _isLoadingData = false;
            _assetAuditData = data;
            _displayFormData = formData;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeFormControllers(formData);
          });
        } else {
          setState(() {
            _isLoadingData = false;
            _errorMessage = 'No Inverter data found';
          });
        }
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Failed to load Inverter data';
        });
      }
    } catch (e) {
      Logger.errorLog('❌ Inverter V2: Error loading data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Error loading data: $e';
      });
    }
  }

  void _initializeFormControllers(Map<String, dynamic> formData) {
    final remarks = formData['remarks'] ?? "";
    _remarksController.text = remarks;
    Logger.debugLog('📝 Initialized remarks controller with: $remarks');
    if (mounted) {
      setState(() {});
    }
  }

  // Callback when Inverter item is saved
  void _onInverterItemSaved(List<Map<String, dynamic>> items) {
    _displayFormData?['assets'] = [...items];
    setState(() {
      _hasFormDataChanges = true;
    });
  }

  // Validate Inverter serial number
  bool _validateInverterSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedInverterItems = _displayFormData?['allAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(serialNumber, savedInverterItems, isQRCodeScanned);
  }

  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 Inverter V2: Starting postCurrentScreenData');
      
      final modifiedAssets = _displayFormData?['assets'] as List<dynamic>? ?? [];
      final modifiedAssetsWithAllProperties = [];
      final finalData = _assetAuditData?['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'SOLAR')];
      final finalAssets = finalData?['assets'] as List<dynamic>? ?? [];
      final finalRemarks = finalData?['remarks'] as List<dynamic>? ?? [];
      
      Logger.debugLog('📊 Data counts - Modified: ${modifiedAssets.length}, Final: ${finalAssets.length}, Remarks: ${finalRemarks.length}');
      modifiedAssetsWithAllProperties.addAll(DataTransformationHelper.modifyData(finalAssets, modifiedAssets));

      // Update remarks
      final String remark = _remarksController.text;
      if(remark.isNotEmpty && finalRemarks.isNotEmpty){
        try {
          finalRemarks.first['item_type_remark'] = remark;
         finalRemarks.first['assetStatus'] = 'OK';
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

      Logger.debugLog('📤 Inverter V2: Prepared ${postObject.length} items for posting');
      
      // Initialize AssetAuditPostService
      final apiService = AppConfig.of(context).apiService;
      final imageUploadService = ImageUploadService(apiService: apiService);
      final postService = AssetAuditPostService(
        apiService: apiService,
        imageUploadService: imageUploadService,
      );
      
      // Post data with photo ID replacement
      await postService.postAssetAuditDataWithPhotoReplacement(
        requests: postObject,
      );
      
      Logger.debugLog('✅ Inverter V2: Data posted successfully');
      
    } catch (e) {
      Logger.errorLog('❌ Inverter V2: Error in postCurrentScreenData: $e');
      rethrow;
    }
  }

  void _showUnsavedChangesDialog() {
    if (!_hasFormDataChanges) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return UnsavedChangesDialog(
          parentContext: context, // Use the outer context (screen context)
          onSaveAndExit: () async {
            await postCurrentScreenData();
          },
          onDiscard: () {
          },
        );
      },
    );
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
                                      'Loading Inverter data...',
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
                                  'No Inverter data available',
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
                
                // Bottom buttons
                AssetAuditSolarBottomButtons(
                  isLoading: _isLoadingData,
                  errorMessage: _errorMessage,
                  onNextButtonClick:  () async {
                    await postCurrentScreenData();
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
        // Inverter Make
        CustomFormField(
          label: "Inverter Make",
          initialValue: _displayFormData?['inverterMake']?.toString() ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        
        // Capacity of Inverter
        CustomFormField(
          label: "Capacity of Inverter",
          initialValue: _displayFormData?['capacity']?.toString() ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        
        // Count of Inverter
        CustomFormField(
          label: "Count of Inverter",
          initialValue: _displayFormData?['totalItems']?.toString() ?? "0",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        
        // Inverter Details Section
        const Text(
          "Inverter Details",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        getHeight(15),
        
        // Inverter Form Component
        AssetAuditFormComponent(
          componentId: 'inverter_component',
          serialLabel: "Inverter - Serial Number *",
          serialHintText: "Inverter Serial Number *",
          photoLabel: "Add a Photo",
          disabledFieldLabel: "Rating",
          disabledFieldValue: _displayFormData?['capacity']?.toString() ?? "",
          serialController: _inverterSerialController,
          initialSavedItems: _displayFormData?['assets'] as List<dynamic>? ?? [],
          onItemSaved: _onInverterItemSaved,
          onStatusChanged: (status) {
            setState(() {
              _hasFormDataChanges = true;
            });
          },
          customValidator: _validateInverterSerialNumber,
          customValidationErrorMessage: "Invalid Inverter serial number. Please check and try again.",
          siteAuditSchId: widget.siteAuditSchId,
          showTable: true,
          tableTitle: "Inverter Items",
        ),
        getHeight(15),
        
        // Remarks
        CustomRemarksField(
          label: "Add Remarks",
          hintText: "Remarks",
          controller: _remarksController,
          initialValue: _displayFormData?['remarks'] ?? '',
        ),
      ],
    );
  }
}
