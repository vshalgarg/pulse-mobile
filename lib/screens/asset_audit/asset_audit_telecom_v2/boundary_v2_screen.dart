import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/asset_audit_validation_helper.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_asset_audit_form_section.dart';
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

class BoundaryV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;

  const BoundaryV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
  });

  @override
  State<BoundaryV2Screen> createState() => _BoundaryV2ScreenState();
}

class _BoundaryV2ScreenState extends State<BoundaryV2Screen> {
  final String _screenName = 'Boundary';
  
  // Service
  late CentralAssetAuditService _service;
  
  // Data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;
  
  // Controllers
  final TextEditingController _remarksController = TextEditingController();
  
  // State
  bool _isLoadingData = false;
  String? _errorMessage;
  bool _hasFormDataChanges = false;
  
  // Section visibility states
  bool _showBoundaryDetails = false;
  bool _showOverallSiteDetails = false;
  
  // Boundary and Overall Site data
  List<Map<String, dynamic>> _savedBoundaryItems = [];
  List<Map<String, dynamic>> _savedOverallSiteItems = [];

  @override
  void initState() {
    super.initState();
    _service = ServiceLocator().centralAssetAuditService;
    _loadData();
    
    // Add listeners for form changes
    _remarksController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
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

      Logger.debugLog('🔄 Boundary V2: Loading data for site ${widget.siteAuditSchId}');
      
      final data = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final boundaryItems = data['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')]
        as Map<String, dynamic>? ?? {};

        // Parse Boundary data
        final boundaryAssets = boundaryItems['assets'] as List<dynamic>? ?? [];
        final remarksData = boundaryItems['remarks'] as List<dynamic>? ?? [];

        // Separate boundary and overall site items
        final boundaryItemsList = boundaryAssets.where((item) => item['record_type'] == 'Boundary').toList();
        final overallSiteItemsList = boundaryAssets.where((item) => item['record_type'] == 'Overall Site').toList();

        final formData = <String, dynamic>{
          'boundaryAvailable': boundaryItemsList.isNotEmpty ? "Yes" : "No",
          'overallSiteAvailable': overallSiteItemsList.isNotEmpty ? "Yes" : "No",
          'boundaryAssets': boundaryItemsList.where((obj) => obj['photo_id'] != null).toList(),
          'boundaryAllAssets': boundaryItemsList,
          'overallSiteAssets': overallSiteItemsList.where((obj) => obj['photo_id'] != null).toList(),
          'overallSiteAllAssets': overallSiteItemsList,
          'remarks': remarksData.isNotEmpty ? remarksData.first['item_type_remark']?.toString() ?? "" : "",
        };

        setState(() {
          _isLoadingData = false;
          _assetAuditData = data;
          _displayFormData = formData;
          _savedBoundaryItems = List<Map<String, dynamic>>.from(boundaryItemsList);
          _savedOverallSiteItems = List<Map<String, dynamic>>.from(overallSiteItemsList);
          _showBoundaryDetails = boundaryItemsList.isNotEmpty;
          _showOverallSiteDetails = overallSiteItemsList.isNotEmpty;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeFormControllers(formData);
        });
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Failed to load Boundary data';
        });
      }
    } catch (e) {
      Logger.errorLog('❌ Boundary V2: Error loading data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Error loading data: $e';
      });
    }
  }

  void _initializeFormControllers(Map<String, dynamic> formData) {
    _remarksController.text = formData['remarks'] ?? '';
    Logger.debugLog('📝 Initialized form controllers');
    if (mounted) {
      setState(() {});
    }
  }

  // Callback methods for CustomAssetAuditFormSection
  void _onBoundaryItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _savedBoundaryItems = items;
      _hasFormDataChanges = true;
    });
    Logger.debugLog('✅ Boundary items updated: ${_savedBoundaryItems.length} items');
  }

  void _onOverallSiteItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _savedOverallSiteItems = items;
      _hasFormDataChanges = true;
    });
    Logger.debugLog('✅ Overall Site items updated: ${_savedOverallSiteItems.length} items');
  }

  // Validation methods
  bool _validateBoundarySerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedItems = _displayFormData?['boundaryAllAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(serialNumber, savedItems, isQRCodeScanned);
  }

  bool _validateOverallSiteSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedItems = _displayFormData?['overallSiteAllAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(serialNumber, savedItems, isQRCodeScanned);
  }

  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 Boundary V2: Starting postCurrentScreenData');
      
      final finalData = _assetAuditData?['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')];
      final finalRemarks = finalData?['remarks'] as List<dynamic>? ?? [];
      final finalBoundaryAssets = finalData?['assets'] as List<dynamic>? ?? [];
      
      // Collect all modified assets
      final modifiedAssetsWithAllProperties = <dynamic>[];
      
      // Add Boundary assets
      final modifiedBoundaryAssets = _displayFormData?['boundaryAssets'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(DataTransformationHelper.modifyData(finalBoundaryAssets, modifiedBoundaryAssets));

      // Add Overall Site assets
      final modifiedOverallSiteAssets = _displayFormData?['overallSiteAssets'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(DataTransformationHelper.modifyData(finalBoundaryAssets, modifiedOverallSiteAssets));

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

      Logger.debugLog('📤 Boundary V2: Prepared ${postObject.length} items for posting');
      
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
        isLastPage: AssetAuditNavigationHelper.getTelecomNextScreenName(_assetAuditData, _screenName) == 'SUBMIT',
      );
      
      Logger.debugLog('✅ Boundary V2: Data posted successfully');
      
    } catch (e) {
      Logger.errorLog('❌ Boundary V2: Error in postCurrentScreenData: $e');
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
            if(_hasFormDataChanges) {
              await postCurrentScreenData();
            }
          },
          onDiscard: () {
          },
        ),
      );
    } else {
      AssetAuditNavigationHelper.navigateToHomeScreen(context);
    }
  }

  Widget _buildRadioButtonField({
    required String label,
    required bool isRequired,
    required String groupValue,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isRequired)
              const Text(
                " *",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
          ],
        ),
        getHeight(8),
        Row(
          children: [
            Radio<String>(
              value: "Yes",
              groupValue: groupValue,
              onChanged: null,
              activeColor: AppColors.primaryGreen,
            ),
            const Text(
              "Yes",
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 20),
            Radio<String>(
              value: "No",
              groupValue: groupValue,
              onChanged: null,
              activeColor: AppColors.primaryGreen,
            ),
            const Text(
              "No",
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
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
                                      'Loading Boundary data...',
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
                                color: AppColors.errorColor.withValues(alpha: 0.1),
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
                                  'No Boundary data available',
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
        // Fencing/Boundary Availability
        _buildRadioButtonField(
          label: "Fencing / Boundary Available",
          isRequired: true,
          groupValue: _displayFormData?['boundaryAvailable'] ?? "No",
          onChanged: (value) {
            setState(() {
              _displayFormData?['boundaryAvailable'] = value;
              _hasFormDataChanges = true;
            });
          },
        ),
        getHeight(15),
        
        // Fencing/Boundary Details Section (only show if available)
        if (_showBoundaryDetails) ...[
          CustomAssetAuditFormSection(
            sectionTitle: "Fencing / Boundary",
            showTitle: true,
            showStatus: true,
            inputLabel: "Fencing / Boundary - Serial Number *",
            inputHintText: "Fencing / Boundary Serial Number *",
            isInputRequired: true,
            photoLabel: "Add a Photo",
            isPhotoRequired: true,
            statusLabel: "Status",
            isStatusRequired: true,
            siteAuditSchId: widget.siteAuditSchId,
          ),
          getHeight(20),
        ],

        // Overall Site Photos / Videos Section
        _buildRadioButtonField(
          label: "Overall Site Photos / Videos Available",
          isRequired: true,
          groupValue: _displayFormData?['overallSiteAvailable'] ?? "No",
          onChanged: (value) {
            setState(() {
              _displayFormData?['overallSiteAvailable'] = value;
              _hasFormDataChanges = true;
            });
          },
        ),
        getHeight(15),
        
        // Overall Site Details Section (only show if available)
        if (_showOverallSiteDetails) ...[
          CustomAssetAuditFormSection(
            sectionTitle: "Overall Site Photos / Videos",
            showTitle: true,
            showStatus: false,
            inputLabel: "Overall Site - Serial Number *",
            inputHintText: "Overall Site Serial Number *",
            isInputRequired: true,
            photoLabel: "Add a Photo",
            isPhotoRequired: true,
            siteAuditSchId: widget.siteAuditSchId,
          ),
          getHeight(20),
        ],
        
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
