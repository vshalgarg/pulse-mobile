import 'package:app/app_config.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/screens/home_screen.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/asset_audit_validation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/asset_audit_telecom_bottom_buttons.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/simple_asset_audit_form_component.dart';
import '../../../commonWidgets/asset_audit_form_component.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../services/service_locator.dart';
import '../../../utils/logger.dart';
import '../../../services/asset_audit/central_service_initializer.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';
import '../../../services/asset_audit_post_service.dart';
import '../../../services/image_upload_service.dart';

class CCUV2Screen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;

  const CCUV2Screen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
  });

  @override
  State<CCUV2Screen> createState() => _CCUV2ScreenState();
}

class _CCUV2ScreenState extends State<CCUV2Screen> {
  late CentralAssetAuditService _service;

  // Loading states
  bool _isLoadingData = true;
  String? _errorMessage;

  // Form controllers
  final TextEditingController _hybridCCUMakeController =
      TextEditingController();
  final TextEditingController _cabinetSerialController =
      TextEditingController();
  final TextEditingController _totalRectifierController =
      TextEditingController();
  final TextEditingController _totalMPPTController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // Rectifier form controllers
  final TextEditingController _rectifierSerialController =
      TextEditingController();
  final TextEditingController _rectifierCapacityController =
      TextEditingController();

  // MPPT form controllers
  final TextEditingController _mpptSerialController = TextEditingController();
  final TextEditingController _mpptCapacityController = TextEditingController();

  // Form data
  bool _hasFormDataChanges = false;

  // Asset audit data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;

  // Screen name for navigation
  final String _screenName = 'CCU';

  // Lists to store saved items
  List<Map<String, dynamic>> _savedRectifiers = [];
  List<Map<String, dynamic>> _savedMPPTs = [];

  // Cabinet data
  String? _cabinetPhotoId;
  String? _cabinetImageData;
  bool? isQrCodeScanned = false;
  String? qrCodeScannedTs = null;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
  }

  void _initializeServices() {
    Logger.debugLog('🔧 Initializing Central Asset Audit service for CCU');
    _service = ServiceLocator().centralAssetAuditService;

    Logger.debugLog(
      '✅ Central Asset Audit service initialized successfully for CCU',
    );
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

      Logger.debugLog('🔄 Loading CCU data for site ${widget.siteAuditSchId}');

      // Use the actual service to load data
      final data = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        Logger.debugLog('📊 Received CCU data from service');
        Logger.debugLog('📊 Data keys: ${data.keys.toList()}');

        // Extract CCU data
        final ccuData =
            data['responseData']?[AssetAuditNavigationHelper.dataValueForPage(
                  _screenName,
                  'TELECOM',
                )]
                as Map<String, dynamic>?;
        final formData = <String, dynamic>{};

        if (ccuData != null) {
          // Extract CCU Cabinet data
          final ccuCabinet = ccuData['CCU Cabinet'] as List<dynamic>? ?? [];
          if (ccuCabinet.isNotEmpty) {
            final cabinet = ccuCabinet.first as Map<String, dynamic>;
            formData['hybridCCUMake'] =
                cabinet['oem_name']?.toString() ?? "N/A";
            formData['cabinetSerial'] =
                cabinet['mfg_serial_no']?.toString() ?? "";
            formData['ccuCabinetAvailable'] = true;
            _cabinetPhotoId = cabinet['photo_id']?.toString();
            if (_cabinetPhotoId != null) {
              _cabinetImageData = await _service.getImageAsDataUrl(
                _cabinetPhotoId.toString(),
              );
            }
            isQrCodeScanned = cabinet['qr_code_scanned'] as bool? ?? false;
            qrCodeScannedTs = cabinet['qr_code_scanned_ts']?.toString();
            formData['cabinets'] = ccuCabinet;
          } else {
            formData['ccuCabinetAvailable'] = false;
          }

          // Extract Rectifiers data
          final rectifiers = ccuData['CCU Rectifiers'] as List<dynamic>? ?? [];
          formData['totalRectifier'] = rectifiers.length.toString();
          formData['rectifiers'] = rectifiers
              .where((item) => item['photo_id'] != null)
              .toList();
          formData['allRectifiers'] = rectifiers;

          // Extract MPPT data
          final mppts = ccuData['CCU MPPT'] as List<dynamic>? ?? [];
          formData['totalMPPT'] = mppts.length.toString();
          formData['mppts'] = mppts
              .where((item) => item['photo_id'] != null)
              .toList();
          formData['allMppts'] = mppts;
          formData['mpptCapacity'] = mppts.isNotEmpty
              ? mppts.first['capacity']
              : 'N/A';

          // Extract remarks
          final remarks = ccuData['remarks'] as List<dynamic>? ?? [];
          if (remarks.isNotEmpty) {
            final remark = remarks.first as Map<String, dynamic>;
            formData['remarks'] = remark['item_type_remark']?.toString() ?? "";
            formData['remarksExist'] = true;
          } else {
            formData['remarksExist'] = false;
          }

          // Initialize saved items
          _savedRectifiers = List<Map<String, dynamic>>.from(
            formData['rectifiers'] ?? [],
          );
          _savedMPPTs = List<Map<String, dynamic>>.from(
            formData['mppts'] ?? [],
          );
        } else {
          Logger.errorLog('❌ No CCU data found!');
        }

        setState(() {
          _isLoadingData = false;
          _assetAuditData = data;
          _displayFormData = formData;
        });

        // Initialize form controllers
        _initializeFormControllers(formData);

        Logger.debugLog('✅ CCU data loaded successfully');
        Logger.debugLog('📊 Form data: $formData');
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'No data available for this site';
        });
        Logger.errorLog(
          '❌ No data available for site ${widget.siteAuditSchId}',
        );
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading CCU data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  void _initializeFormControllers(Map<String, dynamic> formData) {
    _hybridCCUMakeController.text = formData['hybridCCUMake']?.toString() ?? "";
    _totalRectifierController.text =
        formData['totalRectifier']?.toString() ?? "";

    print("formData['totalMPPT']: ${formData['totalMPPT']}");

    if ((formData['totalMPPT'] ?? 0) != 0) {
      _totalMPPTController.text = formData['totalMPPT'].toString();
    }

    _remarksController.text = formData['remarks']?.toString() ?? "";
    _remarksController.addListener(_onFormChanged);
    if (mounted) {
      setState(() {});
    }
  }

  void _onRectifierSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _savedRectifiers = items;
      _hasFormDataChanges = true;
    });
  }

  void _onMPPTSaved(List<Map<String, dynamic>> items) {
    setState(() {
      _savedMPPTs = items;
      _hasFormDataChanges = true;
    });
  }

  void _onCabinetDataChanged(
    String? photoId,
    String? imageData,
    bool? isQRCodeScanned1,
    String? qrCodeScannedTs1,
  ) {
    //Logger.debugLog("vishal ")
    setState(() {
      _cabinetPhotoId = photoId;
      _cabinetImageData = imageData;
      _hasFormDataChanges = true;
      isQrCodeScanned = isQRCodeScanned1 ?? false;
      qrCodeScannedTs = qrCodeScannedTs1;
    });
  }

  Future<void> postCurrentScreenData() async {
    try {
      Logger.debugLog('📤 CCU V2: Starting postCurrentScreenData');

      final finalCCuData =
          _assetAuditData?['responseData']?[AssetAuditNavigationHelper.dataValueForPage(
                _screenName,
                'TELECOM',
              )]
              as Map<String, dynamic>?;

      final modifiedAssetsWithAllProperties = <Map<String, dynamic>>[];

      // ===== CCU Cabinet =====
      final ccuCabinetList = finalCCuData?['CCU Cabinet'];
      if (ccuCabinetList != null &&
          ccuCabinetList is List &&
          ccuCabinetList.isNotEmpty) {
        for (var cabinet in ccuCabinetList) {
          final cabinetMap = Map<String, dynamic>.from(cabinet);

          if (_cabinetSerialController.text.isNotEmpty &&
              _cabinetPhotoId != null) {
            bool isValid = _validateCabinetSerialNumber(
              _cabinetSerialController.text,
              isQrCodeScanned ?? false,
            );

            if (!isValid) {
              throw Exception("Please select cabinet serial number");
            }

            cabinetMap['photo_id'] = _cabinetPhotoId;
            cabinetMap['asset_status'] = 'OK';

            if (isQrCodeScanned ?? false) {
              cabinetMap['qr_code_scanned'] = true;
              cabinetMap['qr_code_scanned_ts'] = qrCodeScannedTs;
            }

            modifiedAssetsWithAllProperties.add(cabinetMap);
          }
        }
      }

      // ===== CCU Rectifiers =====
      final rectifierList = finalCCuData?['CCU Rectifiers'];
      if (rectifierList != null &&
          rectifierList is List &&
          rectifierList.isNotEmpty) {
        final modifiedRectifiers =
            _modifyData(rectifierList, _savedRectifiers) ?? [];
        modifiedAssetsWithAllProperties.addAll(
          modifiedRectifiers.cast<Map<String, dynamic>>(),
        );
      }

      // ===== CCU MPPT =====
      final mpptList = finalCCuData?['CCU MPPT'];
      if (mpptList != null && mpptList is List && mpptList.isNotEmpty) {
        final modifiedMppts = _modifyData(mpptList, _savedMPPTs) ?? [];
        modifiedAssetsWithAllProperties.addAll(
          modifiedMppts.cast<Map<String, dynamic>>(),
        );
      }

      // ===== Remarks =====
      final remarksList = finalCCuData?['Remarks'];
      if (remarksList != null &&
          remarksList is List &&
          remarksList.isNotEmpty) {
        final finalRemarks = Map<String, dynamic>.from(remarksList.first);
        final String remark = _remarksController.text;
        if (remark.isNotEmpty) {
          finalRemarks['item_type_remark'] = remark;
          modifiedAssetsWithAllProperties.add(finalRemarks);
        }
      }

      // ===== Update local SQLite =====
      _service.updateDataInSqlite(
        siteAuditSchId: widget.siteAuditSchId,
        updatedData: _assetAuditData ?? {},
      );

      // ===== Prepare data for posting =====
      final postObject = [...modifiedAssetsWithAllProperties];

      Logger.debugLog(
        '📤 SPV V2: Prepared ${postObject.length} items for posting',
      );

      // ===== Post API =====
      final apiService = AppConfig.of(context).apiService;
      final imageUploadService = ImageUploadService(apiService: apiService);
      final postService = AssetAuditPostService(
        apiService: apiService,
        imageUploadService: imageUploadService,
      );

      await postService.postAssetAuditDataWithPhotoReplacement(
        requests: postObject,
        isLastPage:
            AssetAuditNavigationHelper.getTelecomNextScreenName(
              _assetAuditData,
              _screenName,
            ) ==
            'SUBMIT',
      );

      Logger.debugLog('✅ SPV V2: Data posted successfully');
    } catch (e, s) {
      Logger.errorLog('❌ CCU V2: Error in postCurrentScreenData: $e', s);
      rethrow;
    }
  }

  // Future<void> postCurrentScreenData() async {
  //   try {
  //     Logger.debugLog('📤 CCU V2: Starting postCurrentScreenData');

  //     final finalCCuData =
  //         _assetAuditData?['responseData']?[AssetAuditNavigationHelper.dataValueForPage(
  //               _screenName,
  //               'TELECOM',
  //             )]
  //             as Map<String, dynamic>?;
  //     final modifiedAssetsWithAllProperties = [];
  //     final finalCabinet =
  //         finalCCuData?['CCU Cabinet']?.first ?? Map<String, dynamic>;
  //     if (finalCabinet != null &&
  //         _cabinetSerialController.text.isNotEmpty &&
  //         _cabinetPhotoId != null) {
  //       bool isValid = _validateCabinetSerialNumber(
  //         _cabinetSerialController.text,
  //         isQrCodeScanned ?? false,
  //       );
  //       if (!isValid) {
  //         throw new Exception("Please select cabinet serial number");
  //       }
  //       finalCabinet['photo_id'] = _cabinetPhotoId;
  //       finalCabinet['asset_status'] = 'OK';
  //       if (isQrCodeScanned ?? false) {
  //         finalCabinet['qr_code_scanned'] = true;
  //         finalCabinet['qr_code_scanned_ts'] = qrCodeScannedTs;
  //       }
  //       modifiedAssetsWithAllProperties.add(finalCabinet);
  //     }

  //     final modifiedRectifiers = _modifyData(
  //       finalCCuData?['CCU Rectifiers'],
  //       _savedRectifiers,
  //     );

  //     modifiedAssetsWithAllProperties.addAll(modifiedRectifiers);

  //     final modifiedMppts = _modifyData(finalCCuData?['CCU MPPT'], _savedMPPTs);
  //     modifiedAssetsWithAllProperties.addAll(modifiedMppts);

  //     if (finalCCuData?['Remarks'] != null) {
  //       final finalRemarks =
  //           finalCCuData?['Remarks']?.first ?? Map<String, dynamic>;
  //       final String remark = _remarksController.text;
  //       if (remark.isNotEmpty && finalRemarks.isNotEmpty) {
  //         try {
  //           finalRemarks['item_type_remark'] = remark;
  //           modifiedAssetsWithAllProperties.add(finalRemarks);
  //         } catch (e) {
  //           Logger.errorLog('❌ Error updating remarks: $e');
  //         }
  //       }
  //     }

  //     _service.updateDataInSqlite(
  //       siteAuditSchId: widget.siteAuditSchId,
  //       updatedData: _assetAuditData ?? {},
  //     );

  //     // Prepare data for posting
  //     final postObject = [...modifiedAssetsWithAllProperties];

  //     Logger.debugLog(
  //       '📤 SPV V2: Prepared ${postObject.length} items for posting',
  //     );

  //     // Initialize AssetAuditPostService
  //     final apiService = AppConfig.of(context).apiService;
  //     final imageUploadService = ImageUploadService(apiService: apiService);
  //     final postService = AssetAuditPostService(
  //       apiService: apiService,
  //       imageUploadService: imageUploadService,
  //     );

  //     // Post data with photo ID replacement
  //     await postService.postAssetAuditDataWithPhotoReplacement(
  //       requests: postObject,
  //       isLastPage:
  //           AssetAuditNavigationHelper.getTelecomNextScreenName(
  //             _assetAuditData,
  //             _screenName,
  //           ) ==
  //           'SUBMIT',
  //     );

  //     Logger.debugLog('✅ SPV V2: Data posted successfully');
  //   } catch (e) {
  //     Logger.errorLog('❌ CCU V2: Error in postCurrentScreenData: $e');
  //     rethrow;
  //   }
  // }

  static List<dynamic> _modifyData(
    List<dynamic> actualData,
    List<dynamic> modifiedData,
  ) {
    List<dynamic> modifiedDataToReturn = [];
    for (dynamic asset in actualData) {
      try {
        final assetSerialNo = asset['mfg_serial_no']?.toString();
        final modifiedAsset = modifiedData
            .where((ass) => ass['mfg_serial_no']?.toString() == assetSerialNo)
            .firstOrNull;

        if (modifiedAsset != null) {
          asset['qr_code_scanned'] = modifiedAsset['qr_code_scanned'];
          asset['qr_code_scanned_ts'] = modifiedAsset['qr_code_scanned_ts'];
          asset['photo_id'] = modifiedAsset['photo_id'];
          asset['asset_status'] = modifiedAsset['asset_status'];
          modifiedDataToReturn.add(asset);
          Logger.debugLog('✅ Updated asset: $assetSerialNo');
        } else {
          Logger.debugLog(
            '⚠️ No modified asset found for serial: $assetSerialNo',
          );
        }
      } catch (e) {
        Logger.errorLog('❌ Error updating asset: $e');
      }
    }
    return modifiedDataToReturn;
  }

  @override
  void dispose() {
    _hybridCCUMakeController.dispose();
    _cabinetSerialController.dispose();
    _totalRectifierController.dispose();
    _totalMPPTController.dispose();
    _remarksController.dispose();
    _rectifierSerialController.dispose();
    _rectifierCapacityController.dispose();
    _mpptSerialController.dispose();
    _mpptCapacityController.dispose();
    super.dispose();
  }

  // Custom validation function for Cabinet serial number
  bool _validateCabinetSerialNumber(String serialNumber, bool isQRCodeScanned) {
    print("cabinets: ${_displayFormData?['cabinets']}");
    print("serialNumber: $serialNumber");
    print("isQRCodeScanned: $isQRCodeScanned");
    final cabinets = _displayFormData?['cabinets'] as List<dynamic>?;
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(
      serialNumber,
      cabinets,
      isQRCodeScanned,
    );
  }

  // Custom validation function for Rectifier serial number
  bool _validateRectifierSerialNumber(
    String serialNumber,
    bool isQRCodeScanned,
  ) {
    final allRectifiers = _displayFormData?['allRectifiers'] as List<dynamic>?;
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(
      serialNumber,
      allRectifiers,
      isQRCodeScanned,
    );
  }

  // Custom validation function for mppt serial number
  bool _validateMpptSerialNumber(String serialNumber, bool isQRCodeScanned) {
    final allMppts = _displayFormData?['allMppts'] as List<dynamic>?;
    return AssetAuditValidationHelper.validateQRCodeSerialNumber(
      serialNumber,
      allMppts,
      isQRCodeScanned,
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
                                      'Loading CCU data...',
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
                                color: AppColors.errorColor.withValues(
                                  alpha: 0.1,
                                ),
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
                                          'Failed to load CCU data',
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
                AssetAuditTelecomBottomButtons(
                  isLoading: _isLoadingData,
                  errorMessage: _errorMessage,
                  onNextButtonClick: () async {
                    if (_hasFormDataChanges) {
                      print("postCurrentScreenData called : $_assetAuditData");
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
      children: [
        // Hybrid CCU Make
        CustomFormField(
          label: "Hybrid CCU Make",
          initialValue: _displayFormData?['hybridCCUMake'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
        if (_displayFormData?['ccuCabinetAvailable'] ?? false) ...[
          // Cabinet Serial Number and Photo using SimpleAssetAuditFormComponent
          SimpleAssetAuditFormComponent(
            componentId: 'cabinet_component',
            serialLabel: "Cabinet Serial Number",
            serialHintText: "Cabinet Serial Number",
            photoLabel: "Add Photo of Cabinet",
            serialController: _cabinetSerialController,
            initialPhotoId: _cabinetPhotoId,
            initialImageData: _cabinetImageData,
            onDataChanged: _onCabinetDataChanged,
            siteAuditSchId: widget.siteAuditSchId,
          ),
          getHeight(20),
        ],

        // Total Count of Rectifier
        if (_displayFormData?['totalRectifier'] != "0") ...[
          CustomFormField(
            label: "Total Count of Rectifier",
            initialValue: _displayFormData?['totalRectifier'] ?? "0",
            isRequired: false,
            isEditable: false,
          ),
          getHeight(15),

          // Rectifiers Details Section
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Rectifiers Details",
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                AssetAuditFormComponent(
                  componentId: 'rectifier_component',
                  serialLabel: "Rectifier - Serial Number *",
                  serialHintText: "Rectifier Serial Number *",
                  photoLabel: "Add a Photo",
                  serialController: _rectifierSerialController,
                  initialSavedItems: _savedRectifiers,
                  onItemSaved: _onRectifierSaved,
                  onStatusChanged: (status) {
                    setState(() {
                      _hasFormDataChanges = true;
                    });
                  },
                  customValidator: _validateRectifierSerialNumber,
                  siteAuditSchId: widget.siteAuditSchId,
                  showTable: true,
                  tableTitle: "Rectifiers",
                ),
              ],
            ),
          ),
        ],
        // Total Count of MPPT
        if (_displayFormData?['totalMPPT'] != "0") ...[
          CustomFormField(
            label: "Total Count of MPPT",
            initialValue: _displayFormData?['totalMPPT'] ?? "0",
            isRequired: false,
            isEditable: false,
          ),
          getHeight(15),

          // MPPT Details Section
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "MPPT Details",
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                AssetAuditFormComponent(
                  componentId: 'mppt_component',
                  serialLabel: "MPPT - Serial Number *",
                  serialHintText: "MPPT Serial Number *",
                  photoLabel: "Add a Photo",
                  disabledFieldLabel: "Capacity",
                  disabledFieldValue:
                      _displayFormData?['mpptCapacity']?.toString() ?? 'N/A',
                  serialController: _mpptSerialController,
                  initialSavedItems: _savedMPPTs,
                  onItemSaved: _onMPPTSaved,
                  onStatusChanged: (status) {
                    setState(() {
                      _hasFormDataChanges = true;
                    });
                  },
                  customValidator: _validateMpptSerialNumber,
                  siteAuditSchId: widget.siteAuditSchId,
                  showTable: true,
                  tableTitle: "MPPTs",
                ),
              ],
            ),
          ),
          getHeight(20),
        ],

        if (_displayFormData?['remarksExist'] == true) ...[
          // Add Remarks
          CustomRemarksField(
            label: "Add Remarks",
            hintText: "Remarks",
            controller: _remarksController,
            initialValue: _displayFormData?['remarks'] ?? '',
          ),
        ],
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
          parentContext: context,
          onSaveAndExit: () async {
            await postCurrentScreenData();
          },
          onDiscard: () {},
        ),
      );
    } else {
      AssetAuditNavigationHelper.navigateToHomeScreen(context);
    }
  }
}
