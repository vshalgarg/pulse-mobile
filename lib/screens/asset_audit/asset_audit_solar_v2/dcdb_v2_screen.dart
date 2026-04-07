import 'package:app/commonWidgets/asset_audit_solar_bottom_buttons.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/asset_audit_validation_helper.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../utils/logger.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';
import '../../../services/asset_audit_post_service.dart';
import '../../../services/image_upload_service.dart';
import '../../../app_config.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';

class DCDBV2Screen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;
  final BuildContext parentContext;

  const DCDBV2Screen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
    required this.parentContext,
  });

  @override
  State<DCDBV2Screen> createState() => _DCDBV2ScreenState();
}

class _DCDBV2ScreenState extends State<DCDBV2Screen> {
  final String _screenName = 'DCDB';

  // Service
  late CentralAssetAuditService _service;

  // Data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;

  // Controllers
  final TextEditingController _dcdbSerialController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // State
  bool _isLoadingData = false;
  String? _errorMessage;
  bool _hasFormDataChanges = false;

  @override
  void initState() {
    super.initState();
    _service = ServiceLocator().centralAssetAuditService;
    _loadData();
  }

  @override
  void dispose() {
    _dcdbSerialController.dispose();
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

      Logger.debugLog(
        '🔄 DCDB V2: Loading data for site ${widget.siteAuditSchId}',
      );

      final data = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        final dcdbItems =
            data['responseData'][AssetAuditNavigationHelper.dataValueForPage(
                  _screenName,
                  'SOLAR',
                )]
                as Map<String, dynamic>? ??
            {};

        if (dcdbItems.isNotEmpty) {
          final firstItem = dcdbItems['assets'].first;
          final formData = <String, dynamic>{
            'ajbType': firstItem['oem_name']?.toString() ?? "N/A",
            'totalItems': dcdbItems['assets'].length.toString(),
            'remarks':
                dcdbItems['remarks'].first['item_type_remark']?.toString() ??
                "",
            'assets': dcdbItems['assets']
                .where((obj) => obj['photo_id'] != null)
                .toList(),
            'allAssets': dcdbItems['assets'],
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
            _errorMessage = 'No DCDB data found';
          });
        }
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Failed to load DCDB data';
        });
      }
    } catch (e) {
      Logger.errorLog('❌ DCDB V2: Error loading data: $e');
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

  // Callback when DCDB item is saved
  void _onDCDBItemSaved(List<Map<String, dynamic>> items) {
    _displayFormData?['assets'] = [...items];
    setState(() {
      _hasFormDataChanges = true;
    });
  }

  // Validate DCDB serial number
  bool _validateDCDBSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final savedDcdbItems =
        _displayFormData?['allAssets'] as List<dynamic>? ?? [];
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(
      serialNumber,
      savedDcdbItems,
      isQRCodeScanned,
    );
  }

  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 DCDB V2: Starting postCurrentScreenData');

      final modifiedAssets =
          _displayFormData?['assets'] as List<dynamic>? ?? [];
      final modifiedAssetsWithAllProperties = [];
      final finalData =
          _assetAuditData?['responseData'][AssetAuditNavigationHelper.dataValueForPage(
            _screenName,
            'SOLAR',
          )];
      final finalAssets = finalData?['assets'] as List<dynamic>? ?? [];
      final finalRemarks = finalData?['remarks'] as List<dynamic>? ?? [];

      Logger.debugLog(
        '📊 Data counts - Modified: ${modifiedAssets.length}, Final: ${finalAssets.length}, Remarks: ${finalRemarks.length}',
      );

      modifiedAssetsWithAllProperties.addAll(
        DataTransformationHelper.modifyData(finalAssets, modifiedAssets),
      );

      // Update remarks
      final String remark = _remarksController.text;
      if (remark.isNotEmpty && finalRemarks.isNotEmpty) {
        try {
          finalRemarks.first['item_type_remark'] = remark;
          finalRemarks.first['assetStatus'] = 'OK';
          Logger.debugLog('✅ Updated remarks: $remark');
        } catch (e) {
          Logger.errorLog('❌ Error updating remarks: $e');
        }
      }

      // Update local data
      _service.updateDataInSqlite(
        siteAuditSchId: widget.siteAuditSchId,
        updatedData: _assetAuditData ?? {},
      );

      // Prepare data for posting
      final postObject = [...modifiedAssetsWithAllProperties, ...finalRemarks];

      Logger.debugLog(
        '📤 DCDB V2: Prepared ${postObject.length} items for posting',
      );
      // Post data with photo ID replacement
      await ServiceLocator().assetAuditPostService
          .postAssetAuditDataWithPhotoReplacement(
            requests: postObject,
            isLastPage:
                AssetAuditNavigationHelper.getSolarNextScreenName(
                  _assetAuditData,
                  _screenName,
                ) ==
                'SUBMIT',
            activityType: ActivityTypeEnum.assetAudit,
          );
      Logger.debugLog('✅ DCDB V2: Data posted successfully');
    } catch (e) {
      Logger.errorLog('❌ DCDB V2: Error in postCurrentScreenData: $e');
      rethrow;
    }
  }

  void _showUnsavedChangesDialog() {
    if (!_hasFormDataChanges) {
      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext,
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return UnsavedChangesDialog(
          parentContext: widget.parentContext,
          onSaveAndExit: () async {
            if (_hasFormDataChanges) {
              await postCurrentScreenData();
            }
          },
          onDiscard: () {},
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
        title: 'DCDB',
        onClose: () {
          _showUnsavedChangesDialog();
        },
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: SafeSvgPicture.asset(
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
                                      'Loading DCDB data...',
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
                          if (!_isLoadingData &&
                              _errorMessage == null &&
                              _displayFormData != null)
                            _buildFormFields(),

                          // Show message when no data
                          if (!_isLoadingData &&
                              _errorMessage == null &&
                              _displayFormData == null)
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: const Center(
                                child: Text(
                                  'No DCDB data available',
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
                AssetAuditSolarBottomButtons(
                  isLoading: _isLoadingData,
                  errorMessage: _errorMessage,
                  onNextButtonClick: () async {
                    if (_hasFormDataChanges) {
                      await postCurrentScreenData();
                    }
                  },
                  assetAuditData: _assetAuditData,
                  auditSchId: widget.auditSchId,
                  siteType: widget.siteType,
                  siteAuditSchId: widget.siteAuditSchId,
                  screenName: _screenName,
                  parentContext: widget.parentContext,
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
        // AJB Type
        CustomFormField(
          label: "DCDB Make",
          initialValue: _displayFormData?['ajbType']?.toString() ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        // Total Items
        CustomFormField(
          label: "Count of AJB",
          initialValue: _displayFormData?['totalItems']?.toString() ?? "0",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),

        // DCDB Form Component
        AssetAuditFormComponent(
          componentId: 'dcdb_component',
          serialLabel: "DCDB - Serial Number",
          serialHintText: "DCDB Serial Number ",
          photoLabel: "Add a Photo",
          serialController: _dcdbSerialController,
          initialSavedItems:
              _displayFormData?['assets'] as List<dynamic>? ?? [],
          onItemSaved: _onDCDBItemSaved,
          onStatusChanged: (status) {},
          customValidator: _validateDCDBSerialNumber,
          customValidationErrorMessage:
              "Invalid DCDB serial number. Please check and try again.",
          siteAuditSchId: widget.siteAuditSchId,
          showTable: true,
          tableTitle: "DCDB Items",
        ),

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
