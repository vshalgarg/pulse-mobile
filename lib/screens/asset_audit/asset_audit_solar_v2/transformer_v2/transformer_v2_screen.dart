import 'dart:io';
import 'dart:convert';
import 'package:app/screens/home_screen.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/svg.dart';
import '../../../../commonWidgets/custom_form_appbar.dart';
import '../../../../commonWidgets/custom_form_field.dart';
import '../../../../commonWidgets/custom_image_upload_field.dart';
import '../../../../commonWidgets/custom_buttons/arrow_botton.dart';
import '../../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../../commonWidgets/asset_audit_form_component.dart';
import '../../../../commonWidgets/asset_audit_solar_bottom_buttons.dart';
import '../../../../constants/app_colors.dart';
import '../../../../constants/app_images.dart';
import '../../../../constants/constants_methods.dart';
import '../../../../utils/logger.dart';
import '../../../../models/asset_audit_model.dart';
import '../../../../services/asset_audit/central_service_initializer.dart';
import '../../../../services/asset_audit/central_asset_audit_service.dart';
import '../../../../services/asset_audit_post_service.dart';
import '../../../../services/image_upload_service.dart';
import '../../../../enum/image_activity_type_enum.dart';
import '../../../../app_config.dart';

class TransformerV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;

  const TransformerV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
  });

  @override
  State<TransformerV2Screen> createState() => _TransformerV2ScreenState();
}

class _TransformerV2ScreenState extends State<TransformerV2Screen> {
  final String _screenName = 'Transformer';
  
  // Service
  late CentralAssetAuditService _service;
  
  // Data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;
  
  // Controllers
  final TextEditingController _transformerSerialController = TextEditingController();
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
    _service = CentralAssetAuditServiceInitializer.getService();
    _loadData();
    
    // Add listeners for form changes
    _transformerSerialController.addListener(_onFormChanged);
    _remarksController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _transformerSerialController.dispose();
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

      Logger.debugLog('🔄 Transformer V2: Loading data for site ${widget.siteAuditSchId}');
      
      final data = await _service.getAssetAuditData(
        siteType: widget.siteType,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final transformerItems = data['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'SOLAR')]
        as Map<String, dynamic>? ?? {};

        if (transformerItems.isNotEmpty) {
          final firstItem = transformerItems['assets'].first;
          final formData = <String, dynamic>{
            'transformerType': firstItem['item_type']?.toString() ?? "N/A",
            'transformerMake': firstItem['oem_name']?.toString() ?? "N/A",
            'capacity': firstItem['capacity']?.toString() ?? "N/A",
            'totalItems': transformerItems['assets'].length.toString(),
            'remarks': transformerItems['remarks'].first['item_type_remark']?.toString() ?? "",
            'assets': transformerItems['assets'].where((obj) => obj['photo_id'] != null).toList(),
            'allAssets': transformerItems['assets'],
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
            _errorMessage = 'No Transformer data found';
          });
        }
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Failed to load Transformer data';
        });
      }
    } catch (e) {
      Logger.errorLog('❌ Transformer V2: Error loading data: $e');
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

  // Callback when Transformer item is saved
  void _onTransformerItemSaved(List<Map<String, dynamic>> items) {
    _displayFormData?['assets'] = [...items];
    setState(() {
      _hasFormDataChanges = true;
    });
  }

  // Validate Transformer serial number
  bool _validateTransformerSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedTransformerItems = _displayFormData?['allAssets'] as List<dynamic>? ?? [];
    if (savedTransformerItems.isEmpty) return false;

    final isValid = savedTransformerItems.any((item) {
      if (isQRCodeScanned) {
        return item['nexgen_serial_no']?.toString().toLowerCase() ==
            serialNumber.toLowerCase();
      } else {
        return item['mfg_serial_no']?.toString().toLowerCase() ==
            serialNumber.toLowerCase();
      }
    });

    return isValid;
  }

  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 Transformer V2: Starting postCurrentScreenData');
      
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

      Logger.debugLog('📤 Transformer V2: Prepared ${postObject.length} items for posting');
      
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
      
      Logger.debugLog('✅ Transformer V2: Data posted successfully');
      
    } catch (e) {
      Logger.errorLog('❌ Transformer V2: Error in postCurrentScreenData: $e');
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
                                      'Loading Transformer data...',
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
                                  'No Transformer data available',
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
                AssetAuditSolarBottomButtons(
                  isLoading: _isLoadingData,
                  errorMessage: _errorMessage,
                  onNextButtonClick: () async {
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
        // Transformer Type
        CustomFormField(
          label: "Transformer Type",
          initialValue: _displayFormData?['transformerType']?.toString() ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        
        // Transformer Make
        CustomFormField(
          label: "Transformer Make",
          initialValue: _displayFormData?['transformerMake']?.toString() ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        
        // Count of Transformer
        CustomFormField(
          label: "Count of Transformer",
          initialValue: _displayFormData?['totalItems']?.toString() ?? "0",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        
        // Transformer Section
        const Text(
          "Transformer",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        getHeight(15),
        
        // Transformer Form Component
        AssetAuditFormComponent(
          componentId: 'transformer_component',
          serialLabel: "Transformer - Serial Number *",
          serialHintText: "Transformer Serial Number *",
          photoLabel: "Add a Photo",
          disabledFieldLabel: "Rating",
          disabledFieldValue: _displayFormData?['capacity']?.toString() ?? "",
          serialController: _transformerSerialController,
          initialSavedItems: _displayFormData?['assets'] as List<dynamic>? ?? [],
          onItemSaved: _onTransformerItemSaved,
          onStatusChanged: (status) {
            setState(() {
              _hasFormDataChanges = true;
            });
          },
          customValidator: _validateTransformerSerialNumber,
          customValidationErrorMessage: "Invalid Transformer serial number. Please check and try again.",
          siteAuditSchId: widget.siteAuditSchId,
          showTable: true,
          tableTitle: "Transformer Items",
        ),
        getHeight(15),
        
        // Remarks
        CustomFormField(
          label: "Add Remarks",
          initialValue: "",
          isRequired: false,
          isEditable: true,
          controller: _remarksController,
          onChanged: (value) {
            setState(() {
              _hasFormDataChanges = true;
            });
          },
        ),
      ],
    );
  }
}
