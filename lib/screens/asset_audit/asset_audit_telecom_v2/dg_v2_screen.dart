import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/asset_audit_telecom_bottom_buttons.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../utils/logger.dart';
import '../../../services/asset_audit/central_service_initializer.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';
import '../../../services/asset_audit_post_service.dart';
import '../../../services/image_upload_service.dart';
import '../../../enum/image_activity_type_enum.dart';
import '../../../app_config.dart';
import 'dart:convert';
import 'dart:io';

class DGV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;

  const DGV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
  });

  @override
  State<DGV2Screen> createState() => _DGV2ScreenState();
}

class _DGV2ScreenState extends State<DGV2Screen> {
  final String _screenName = 'DG';
  
  // Service
  late CentralAssetAuditService _service;
  
  // Data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;
  
  // Controllers
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  
  // State
  bool _isLoadingData = false;
  String? _errorMessage;
  bool _hasFormDataChanges = false;
  
  // Image data for display
  String? _dgImageData;
  String? _dgMakeImageData;
  
  // Photo IDs for tracking changes
  String? _dgPhotoId;
  String? _dgMakePhotoId;
 
  // DG data
  List<Map<String, dynamic>> _savedDGItems = [];

  @override
  void initState() {
    super.initState();
    _service = CentralAssetAuditServiceInitializer.getService();
    _loadData();
    
    // Add listeners for form changes
    _serialNumberController.addListener(_onFormChanged);
    _remarksController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _serialNumberController.dispose();
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

      Logger.debugLog('🔄 DG V2: Loading data for site ${widget.siteAuditSchId}');
      
      final data = await _service.getAssetAuditData(
        siteType: widget.siteType,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final dgItems = data['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')]
        as Map<String, dynamic>? ?? {};

        // Parse DG data
        final dgAssets = dgItems['assets'] as List<dynamic>? ?? [];
        final remarksData = dgItems['remarks'] as List<dynamic>? ?? [];

        final formData = <String, dynamic>{
          'dgAvailable': dgAssets.isNotEmpty ? "Yes" : "No",
          'dgMake': dgAssets.isNotEmpty ? dgAssets.first['oem_name']?.toString() ?? 'N/A' : 'N/A',
          'dgCapacity': dgAssets.isNotEmpty ? dgAssets.first['capacity']?.toString() ?? 'N/A' : 'N/A',
          'dgCount': dgAssets.isNotEmpty ? dgAssets.length.toString() : "0",
          'dgImageId': dgAssets.isNotEmpty ? dgAssets.first['photo_id']?.toString() : null,
          'dgMakeImageId': dgAssets.isNotEmpty ? dgAssets.first['photo_id']?.toString() : null,
          'dgAssets': dgAssets.where((obj) => obj['photo_id'] != null).toList(),
          'dgAllAssets': dgAssets,
          'remarks': remarksData.isNotEmpty ? remarksData.first['item_type_remark']?.toString() ?? "" : "",
        };

        setState(() {
          _isLoadingData = false;
          _assetAuditData = data;
          _displayFormData = formData;
          _savedDGItems = List<Map<String, dynamic>>.from(dgAssets);
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeFormControllers(formData);
        });
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Failed to load DG data';
        });
      }
    } catch (e) {
      Logger.errorLog('❌ DG V2: Error loading data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Error loading data: $e';
      });
    }
  }

  void _initializeFormControllers(Map<String, dynamic> formData) {
    _remarksController.text = formData['remarks'] ?? '';
    
    // Load image data
    _loadImageData(formData);
    
    Logger.debugLog('📝 Initialized form controllers');
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadImageData(Map<String, dynamic> formData) async {
    try {
      // Load DG photo
      final dgImageId = formData['dgImageId']?.toString();
      if (dgImageId != null && dgImageId.isNotEmpty) {
        _dgPhotoId = dgImageId;
        final dgImageData = await _service.getImageAsDataUrl(dgImageId);
        if (dgImageData != null && mounted) {
          setState(() {
            _dgImageData = dgImageData;
          });
        }
      }

      // Load DG Make photo
      final dgMakeImageId = formData['dgMakeImageId']?.toString();
      if (dgMakeImageId != null && dgMakeImageId.isNotEmpty) {
        _dgMakePhotoId = dgMakeImageId;
        final dgMakeImageData = await _service.getImageAsDataUrl(dgMakeImageId);
        if (dgMakeImageData != null && mounted) {
          setState(() {
            _dgMakeImageData = dgMakeImageData;
          });
        }
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading image data: $e');
    }
  }

  Future<void> _uploadImage(String type, File imageFile) async {
    try {
      final apiService = AppConfig.of(context).apiService;
      final imageUploadService = ImageUploadService(apiService: apiService);
      
      final imageData = await imageFile.readAsBytes();
      
      final photoId = await imageUploadService.uploadImage(
        base64Encode(imageData),
        ImageActivityTypeEnum.assetAudit,
        widget.siteAuditSchId,
      );

      if (photoId.isNotEmpty) {
        setState(() {
          switch (type) {
            case 'dg':
              _dgPhotoId = photoId;
              _dgImageData = 'data:image/jpeg;base64,${base64Encode(imageData)}';
              break;
            case 'dgMake':
              _dgMakePhotoId = photoId;
              _dgMakeImageData = 'data:image/jpeg;base64,${base64Encode(imageData)}';
              break;
          }
          _hasFormDataChanges = true;
        });
        Logger.debugLog('✅ Image uploaded with ID: $photoId');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  // Callback methods for AssetAuditFormComponent
  void _onDGItemSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _savedDGItems = items;
      _hasFormDataChanges = true;
    });
    Logger.debugLog('✅ DG items updated: ${_savedDGItems.length} items');
  }

  // Validation methods for DG serial number
  bool _validateDGSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedItems = _displayFormData?['dgAllAssets'] as List<dynamic>? ?? [];
    if (savedItems.isEmpty) return false;

    final isValid = savedItems.any((item) {
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
      Logger.debugLog('📤 DG V2: Starting postCurrentScreenData');
      
      final finalData = _assetAuditData?['responseData'][AssetAuditNavigationHelper.dataValueForPage(_screenName, 'TELECOM')];
      final finalRemarks = finalData?['remarks'] as List<dynamic>? ?? [];
      final finalDGAssets = finalData?['assets'] as List<dynamic>? ?? [];
      
      // Collect all modified assets
      final modifiedAssetsWithAllProperties = <dynamic>[];
      
      // Add DG assets
      final modifiedDGAssets = _displayFormData?['dgAssets'] as List<dynamic>? ?? [];
      modifiedAssetsWithAllProperties.addAll(_modifyData(finalDGAssets, modifiedDGAssets));
      
      // Add photo IDs to the data
      if (_dgPhotoId != null) {
        finalDGAssets.first['photo_id'] = _dgPhotoId;
      }
      
      if (_dgMakePhotoId != null) {
        finalDGAssets.first['photo_id'] = _dgMakePhotoId;
      }
      modifiedAssetsWithAllProperties.add(finalDGAssets.first);

      // Update remarks
      final String remark = _remarksController.text;
      if(remark.isNotEmpty && finalRemarks.isNotEmpty){
        try {
          finalRemarks.first['item_type_remark'] = remark;
          modifiedAssetsWithAllProperties.add(finalRemarks.first);
          Logger.debugLog('✅ Updated remarks: $remark');
        } catch (e) {
          Logger.errorLog('❌ Error updating remarks: $e');
        }
      }
      
      // Update local data
      _service.updateDataInSqlite(siteAuditSchId: widget.siteAuditSchId, updatedData: _assetAuditData ?? {});

      // Prepare data for posting
      final postObject = [
        ...modifiedAssetsWithAllProperties
      ];

      Logger.debugLog('📤 DG V2: Prepared ${postObject.length} items for posting');
      
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
      
      Logger.debugLog('✅ DG V2: Data posted successfully');
      
    } catch (e) {
      Logger.errorLog('❌ DG V2: Error in postCurrentScreenData: $e');
      rethrow;
    }
  }

  static List<dynamic> _modifyData(List<dynamic> actualData, List<dynamic> modifiedData) {
    List<dynamic> modifiedDataToReturn = [];
    for(dynamic asset in actualData) {
      try {
        final assetSerialNo = asset['mfg_serial_no']?.toString();
        final modifiedAsset = modifiedData.where((ass) =>
        ass['qr_code_scanned'] ?
          ass['nexgen_serial_no']?.toString() == asset['nexgen_serial_no']?.toString()
         : ass['mfg_serial_no']?.toString() == assetSerialNo
        ).firstOrNull;

        if (modifiedAsset != null) {
          asset['qr_code_scanned'] = modifiedAsset['qr_code_scanned'];
          asset['qr_code_scanned_ts'] = modifiedAsset['qr_code_scanned_ts'];
          asset['photo_id'] = modifiedAsset['photo_id'];
          asset['longitude'] = 'Tobechanged';
          asset['latitude'] = 'Tobechanged';
          asset['asset_status'] = modifiedAsset['asset_status'];
          modifiedDataToReturn.add(asset);
          Logger.debugLog('✅ Updated asset: $assetSerialNo');
        } else {
          Logger.debugLog('⚠️ No modified asset found for serial: $assetSerialNo');
        }
      } catch (e) {
        Logger.errorLog('❌ Error updating asset: $e');
      }
    }
    return modifiedDataToReturn;
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
                                      'Loading DG data...',
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
                                  'No DG data available',
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
        // DG Availability (readonly)
        _buildRadioButtonField(
          label: "DG Availability",
          isRequired: true,
          groupValue: _displayFormData?['dgAvailable'] ?? "No",
        ),
        getHeight(15),

        // Add Photo of DG
        ImageUploadField(
          label: "Add Photo of DG",
          placeholder: "Add Photo",
          isRequired: true,
          onImageSelected: (file) {
            if (file != null) {
              _uploadImage('dg', file);
            }
          },
          externalImageUrl: _dgImageData,
        ),
        getHeight(15),

        // DG Make (readonly)
        CustomFormField(
          label: "DG Make",
          initialValue: _displayFormData?['dgMake'] ?? 'N/A',
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),

        // Add Photo of DG Make
        ImageUploadField(
          label: "Add Photo of DG Make",
          placeholder: "Add Photo",
          isRequired: true,
          onImageSelected: (file) {
            if (file != null) {
              _uploadImage('dgMake', file);
            }
          },
          externalImageUrl: _dgMakeImageData,
        ),
        getHeight(15),

        // Count of DG Set (readonly)
        CustomFormField(
          label: "Count of DG Set",
          initialValue: _displayFormData?['dgCount'] ?? '0',
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),

        // DG Details Section using AssetAuditFormComponent
        AssetAuditFormComponent(
          componentId: 'dg_component',
          serialLabel: "DG - Serial Number *",
          serialHintText: "DG Serial Number *",
          photoLabel: "Add a Photo",
          disabledFieldLabel: "Capacity",
          disabledFieldValue: 'N/A',
          serialController: _serialNumberController,
          initialSavedItems: _displayFormData?['dgAssets'] as List<dynamic>? ?? [],
          onItemSaved: _onDGItemSaved,
          onStatusChanged: (status) {
            setState(() {
              _hasFormDataChanges = true;
            });
          },
          customValidator: _validateDGSerialNumber,
          customValidationErrorMessage: "Invalid DG serial number. Please check and try again.",
          siteAuditSchId: widget.siteAuditSchId,
          showTable: true,
          tableTitle: "DG Items",
        ),
        getHeight(20),

        // Add Remarks
        CustomRemarksField(
          label: "Add Remarks",
          hintText: "Remarks",
          controller: _remarksController,
        ),
      ],
    );
  }
}