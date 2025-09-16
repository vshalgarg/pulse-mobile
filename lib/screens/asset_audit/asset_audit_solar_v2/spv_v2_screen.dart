import 'dart:io';
import 'dart:convert';
import 'package:app/screens/home_screen.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
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
import '../../../enum/image_activity_type_enum.dart';
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
  late CentralAssetAuditService _service;

  // Loading states
  bool _isLoadingData = true;
  String? _errorMessage;

  // Form controllers
  final TextEditingController _spvSerialController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // Form data
  bool _hasFormDataChanges = false;
  bool _showValidationErrors = false;

  // SPV data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
  }

  void _initializeServices() {
    Logger.debugLog('🔧 Initializing Central Asset Audit service for SPV V2');
    _service = CentralAssetAuditServiceInitializer.getService();
    
    // Check if service is initialized
    if (!CentralAssetAuditServiceInitializer.isInitialized) {
      Logger.errorLog('❌ Central service not initialized!');
      setState(() {
        _errorMessage = 'Central service not initialized. Please restart the app.';
        _isLoadingData = false;
      });
      return;
    }
    
    Logger.debugLog('✅ Central Asset Audit service initialized successfully for SPV V2');
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _errorMessage = null;
      });

      Logger.debugLog('🔄 Loading SPV data for site ${widget.siteAuditSchId}');

      final data = await _service.getAssetAuditData(siteType: widget.siteType, auditSchId: widget.auditSchId, siteAuditSchId: widget.siteAuditSchId);
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
  bool _validateSPVSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedSpvItems = _displayFormData?['allAssets'] as List<dynamic>;
    if (savedSpvItems.isEmpty) return false;
    
    // Check if serial number exists in SPV items
    final isValid = savedSpvItems.any((item) {
      if (isQRCodeScanned) {
        return item['nexgen_serial_no']?.toString().toLowerCase() ==
            serialNumber.toLowerCase();
      } else {
        return item['mfg_serial_no']?.toString().toLowerCase() ==
            serialNumber.toLowerCase();
      }
    });
    
    Logger.debugLog('🔍 SPV Validation - Serial: $serialNumber, QR: $isQRCodeScanned, Valid: $isValid');
    return isValid;
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
      
      // Update assets with modified data
      for(dynamic asset in finalAssets) {
        try {
          final assetSerialNo = asset['mfg_serial_no']?.toString();
          final modifiedAsset = modifiedAssets.where((ass) => 
            ass['mfg_serial_no']?.toString() == assetSerialNo
          ).firstOrNull;
          
          if (modifiedAsset != null) {
            asset['qr_code_scanned'] = modifiedAsset['qr_code_scanned'];
            asset['qr_code_scanned_ts'] = modifiedAsset['qr_code_scanned_ts'];
            asset['photo_id'] = modifiedAsset['photo_id'];
            asset['longitude'] = 'Tobechanged';
            asset['latitude'] = 'Tobechanged';
            asset['asset_status'] = modifiedAsset['asset_status'];
            modifiedAssetsWithAllProperties.add(asset);
            Logger.debugLog('✅ Updated asset: $assetSerialNo');
          } else {
            Logger.debugLog('⚠️ No modified asset found for serial: $assetSerialNo');
          }
        } catch (e) {
          Logger.errorLog('❌ Error updating asset: $e');
        }
      }
      
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
      _service.updateAssetAuditData(siteAuditSchId: widget.siteAuditSchId, updatedData: _assetAuditData ?? {});

      // Prepare data for posting
      final postObject = [
        ...modifiedAssetsWithAllProperties,
        ...finalRemarks
      ];

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

                // Bottom button container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ArrowButton(
                          text: AssetAuditNavigationHelper.getSolarPreviousScreenName(_assetAuditData, _screenName),
                          isLeftArrow: true,
                          backgroundColor: AppColors.buttonColorBackBg,
                          textColor: AppColors.buttonColorTextBg,
                        onPressed: () {
                          AssetAuditNavigationHelper.navigateToPreviousSolarScreen(context, _assetAuditData, _screenName, widget.siteAuditSchId, widget.siteType, widget.auditSchId);
                        },
                        ),
                      ),
                      getWidth(14),
                      Expanded(
                        child: ArrowButton(
                          text: AssetAuditNavigationHelper.getSolarNextScreenName(_assetAuditData, _screenName),
                          isLeftArrow: false,
                          backgroundColor: AppColors.buttonColorBg,
                          textColor: AppColors.buttonColorSite,
                          onPressed: () async {
                            await postCurrentScreenData();
                            AssetAuditNavigationHelper.navigateToNextSolarScreen(context, _assetAuditData, _screenName, widget.siteAuditSchId, widget.siteType, widget.auditSchId);
                          },
                        ),
                      ),
                    ],
                  ),
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


        // Remarks field
        CustomFormField(
          label: "Remarks",
          initialValue: "", // Don't use initialValue when using controller
          isRequired: false,
          isEditable: true,
          controller: _remarksController,
          onChanged: (value) {
            setState(() {
              _hasFormDataChanges = true;
            });
          },
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
          section: "SPV",
          parentContext: context, // Use the outer context (screen context)
          onSaveAndExit: () async {
            await postCurrentScreenData();
          },
          onDiscard: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
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
  }
}