import 'package:app/commonWidgets/asset_audit_solar_bottom_buttons.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/screens/home_screen.dart';
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
import '../../../services/service_locator.dart';
import '../../../services/asset_audit_post_service.dart';
import '../../../services/image_upload_service.dart';
import '../../../enum/activity_type_enum.dart';
import '../../../app_config.dart';

class SPVV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;

  const SPVV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
  });

  @override
  State<SPVV2Screen> createState() => _SPVV2ScreenState();
}

class _SPVV2ScreenState extends State<SPVV2Screen> {
  String _screenName = 'SPV';
  // Loading states
  bool _isLoadingData = true;
  String? _errorMessage;

  // Form controllers
  final TextEditingController _spvSerialController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // Form data
  bool _hasFormDataChanges = false;

  // SPV data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _errorMessage = null;
      });

      Logger.debugLog('🔄 Loading SPV data for site ${widget.siteAuditSchId}');

      final data = await ServiceLocator().centralAssetAuditService.getActualDataFromSqlite(siteAuditSchId: widget.siteAuditSchId);
      if (data != null) {
        // Extract SPV items
        final spvItems = data['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'SOLAR')]
        as Map<String, dynamic>? ?? {};
        
        // Extract form data for display
        final formData = <String, dynamic>{};

        // Extract display data from first item if available
        final firstItem = spvItems['assets'].first;
        formData['spvMake'] = firstItem['oem_name']?.toString() ?? "N/A";
        formData['typeOfSpv'] = firstItem['item_type']?.toString() ?? "N/A";
        formData['totalItems'] = spvItems['assets'].length.toString();
        formData['capacity'] = firstItem['capacity']?.toString() ?? "N/A";
        formData['remarks'] = spvItems['remarks'].first['item_type_remark']?.toString() ?? "";
        formData['assets'] = spvItems['assets'].where((obj) => obj['photo_id'] != null).toList();
        formData['allAssets'] = spvItems['assets'];

        setState(() {
          _isLoadingData = false;
          _assetAuditData = data;
          _displayFormData = formData;
        });
        
        // Set the remarks controller text after the widget is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeFormControllers(formData);
        });
        
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'No SPV data available for this site';
        });
        Logger.errorLog('❌ No SPV data available for site ${widget.siteAuditSchId}');
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading SPV data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Failed to load SPV data: $e';
      });
    }
  }

  // Custom validation function for SPV serial number
  bool _validateSPVSerialNumber(String serialNumber, bool isQrCodeScanned) {
    final savedSpvItems = _displayFormData?['allAssets'] as List<dynamic>;
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(serialNumber, savedSpvItems, isQrCodeScanned);
  }

  // Callback when SPV item is saved
  void _onSPVItemSaved(List<Map<String, dynamic>> items) {
    _displayFormData?['assets'] = [...items];
    setState(() {
      _hasFormDataChanges = true;
    });
    Logger.debugLog('📝 SPV items updated: ${items.length} items');
  }

  // Initialize form controllers with loaded data
  void _initializeFormControllers(Map<String, dynamic> formData) {
    // Set remarks controller text
    final remarks = formData['remarks'] ?? "";
    _remarksController.text = remarks;
    Logger.debugLog('📝 Initialized remarks controller with: $remarks');
    
    // Trigger a rebuild to ensure the UI updates
    if (mounted) {
      setState(() {});
    }
  }
  
  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 SPV V2: Starting postCurrentScreenData');
      
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
          
          Logger.debugLog('✅ Updated remarks: $remark');
        } catch (e) {
          Logger.errorLog('❌ Error updating remarks: $e');
        }
      }
      
      // Update local data
      ServiceLocator().centralAssetAuditService.updateDataInSqlite(siteAuditSchId: widget.siteAuditSchId, updatedData: _assetAuditData ?? {});

      // Prepare data for posting
      final rawPostObject = [
        ...modifiedAssetsWithAllProperties,
        ...finalRemarks
      ];

      // Add auditSchId: 0 to each item
      final postObject = rawPostObject.map((item) {
        if (item is Map<String, dynamic>) {
          return {
            ...item,
           
          };
        }
        return item;
      }).toList();

      Logger.debugLog('📤 SPV V2: Prepared ${postObject.length} items for posting');
      
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
        isLastPage: AssetAuditNavigationHelper.getSolarNextScreenName(_displayFormData, _screenName) == 'SUBMIT',
      );
      
      Logger.debugLog('✅ SPV V2: Data posted successfully');
      
    } catch (e) {
      Logger.errorLog('❌ SPV V2: Error in postCurrentScreenData: $e');
    }
  }

  @override
  void dispose() {
    _spvSerialController.dispose();
    _remarksController.dispose();
    super.dispose();
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
                                      'Loading SPV data...',
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
                                          'Failed to load SPV data',
                                          style: TextStyle(
                                            color: AppColors.errorColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: AppColors.errorColor,
                                      fontSize: 14,
                                    ),
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

                          // Show form fields only when data is loaded and no error
                          if (!_isLoadingData && _errorMessage == null)
                            _buildFormFields(),
                        ],
                      ),
                    ),
                  ),
                ),

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
      children: [
        // Site information fields (read-only)
        CustomFormField(
          label: "SPV Make",
          initialValue: _displayFormData?['spvMake'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Type of SPV",
          initialValue: _displayFormData?['typeOfSpv'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        CustomFormField(
          label: "Total SPV Items",
          initialValue: _displayFormData?['totalItems'] ?? "0",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),

        // AssetAuditFormComponent for SPV items
        AssetAuditFormComponent(
          componentId: 'spv_component',
          serialLabel: "SPV - Serial Number *",
          serialHintText: "SPV Serial Number *",
          photoLabel: "Add a Photo",
          disabledFieldLabel: "SPV (Watt)",
          disabledFieldValue:  _displayFormData?['capacity']?.toString() ?? "",
          serialController: _spvSerialController,
          initialSavedItems: _displayFormData?['assets'] as List<dynamic>? ?? [],
          onItemSaved: _onSPVItemSaved,
          onStatusChanged: (status) {
            setState(() {
              _hasFormDataChanges = true;
            });
          },
          customValidator: _validateSPVSerialNumber,
          customValidationErrorMessage: "Invalid SPV serial number. Please check and try again.",
          siteAuditSchId: widget.siteAuditSchId,
          showTable: true,
          tableTitle: "SPV Items",
        ),


        // Remarks
        CustomRemarksField(
          label: "Add Remarks",
          hintText: "Remarks",
          controller: _remarksController,
          initialValue: _displayFormData?['remarks'] ?? '',
        ),
        getHeight(15),
      ],
    );
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteAuditSchId,
          section: "Asset Audit",
          parentContext: context, // Use the outer context (screen context)
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
}