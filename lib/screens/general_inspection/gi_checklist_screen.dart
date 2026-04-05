import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/gen_ins_checklist_model.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'gi_custom_widget.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';

class GIChecklistScreen extends StatefulWidget {
  final AllSiteModel siteData;
  /// Physical site id for `genInspection` POST (`siteId` field). When omitted, [siteData.siteId] is used.
  final int? physicalSiteIdForPost;
  final CMScreenModeEnum mode;
  final String? visitingPersonImageId; // Image ID from the previous screen
  final List<GenInsCheckListData> checklistItems; // Pre-loaded checklist data
  final Map<int, Map<String, dynamic>>?
  existingResponses; // Existing responses for edit mode
  final int? giId; // General Inspection ID for edit mode
  final BuildContext? parentContext;

  const GIChecklistScreen({
    super.key,
    required this.siteData,
    this.physicalSiteIdForPost,
    required this.mode,
    this.visitingPersonImageId,
    required this.checklistItems,
    this.existingResponses,
    this.giId,
    this.parentContext,
  });

  @override
  State<GIChecklistScreen> createState() => _GIChecklistScreenState();
}

class _GIChecklistScreenState extends State<GIChecklistScreen> {
  // Checklist data
  List<GenInsCheckListData> _checklistItems = [];
  Map<int, Map<String, dynamic>> _checklistResponses =
      {}; // giclm_id -> response data
  
  // GlobalKeys to access widget state for validation
  final Map<int, GlobalKey<GICustomChecklistItemState>> _widgetKeys = {};

  // Location data
  double? _latitude;
  double? _longitude;

  // Form change tracking
  bool _hasFormDataChanges = false;

  @override
  void initState() {
    super.initState();

    // Use the pre-loaded checklist data
    _checklistItems = widget.checklistItems;
    
    // Initialize GlobalKeys for each checklist item
    for (final item in _checklistItems) {
      _widgetKeys[item.giclmId] = GlobalKey<GICustomChecklistItemState>();
    }

    // Deep copy so we do not mutate the parent's map in place.
    if (widget.existingResponses != null) {
      _checklistResponses = {
        for (final e in widget.existingResponses!.entries)
          e.key: Map<String, dynamic>.from(e.value),
      };
    }

    _getCurrentLocation();
  }

  /// Copies dependent IMG/REMARKS from child widget state into [_checklistResponses]
  /// (those are not always written through the radio/image/text callbacks).
  void _syncDependentFieldsFromWidgets() {
    for (final item in _checklistItems) {
      final st = _widgetKeys[item.giclmId]?.currentState;
      final merged = Map<String, dynamic>.from(
        _checklistResponses[item.giclmId] ?? {},
      );
      if (st != null &&
          item.dependentElements != null &&
          item.dependentElements!.isNotEmpty) {
        String? firstDepImage;
        final remarks = <String>[];
        for (final dep in item.dependentElements!) {
          if (dep.respType == 'IMG') {
            final id = st.getDependentImageId(dep.respType);
            if (id != null && id.isNotEmpty) firstDepImage ??= id;
          } else if (dep.respType == 'REMARKS') {
            final r = st.getDependentRemarks(dep.respType);
            if (r != null && r.trim().isNotEmpty) remarks.add(r.trim());
          }
        }
        if (firstDepImage != null) {
          merged['dependent_image_id'] = firstDepImage;
        } else {
          merged.remove('dependent_image_id');
        }
        if (remarks.isNotEmpty) {
          merged['dependent_remarks'] = remarks.join('; ');
        } else {
          merged.remove('dependent_remarks');
        }
      }
      if (merged.isNotEmpty) {
        _checklistResponses[item.giclmId] = merged;
      } else {
        _checklistResponses.remove(item.giclmId);
      }
    }
  }

  /// Returns a deep copy of current answers for the detail screen to keep across visits.
  Map<int, Map<String, dynamic>> _snapshotResponsesForParent() {
    _syncDependentFieldsFromWidgets();
    return {
      for (final e in _checklistResponses.entries)
        e.key: Map<String, dynamic>.from(e.value),
    };
  }

  void _popBackToDetail() {
    if (!mounted) return;
    Navigator.of(context).pop<Map<int, Map<String, dynamic>>>(
      _snapshotResponsesForParent(),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Logger.errorLog('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Logger.errorLog('Location permissions are permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      Logger.debugLog('Location: $_latitude, $_longitude');
    } catch (e) {
      Logger.errorLog('Error getting location: $e');
    }
  }

  void _onChecklistItemChanged(
    int giclmId,
    String? radioValue,
    String? imageId,
    String? textValue,
  ) {
    // Merge so we never drop server-prepopulated fields (gispId, giId, dependent_image_id, etc.).
    final merged = Map<String, dynamic>.from(_checklistResponses[giclmId] ?? {});
    merged['radio_value'] = radioValue;
    merged['image_id'] = imageId;
    merged['text_value'] = textValue;
    _checklistResponses[giclmId] = merged;

    if (!_hasFormDataChanges) {
      _hasFormDataChanges = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _popBackToDetail();
        }
      },
      child: Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: "General Inspection",
        onClose: () => _showUnsavedChangesDialog(),
      ),
      body: Stack(
        children: [
          // Background (isolated from viewInsets so keyboard animation does not repaint it)
          Positioned.fill(
            child: RepaintBoundary(
              child: SafeSvgPicture.asset(
                AppImages.home,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      20,
                      16,
                      16 + MediaQuery.viewInsetsOf(context).bottom + 100,
                    ),
                    itemCount: _checklistItems.length,
                    itemBuilder: (context, index) {
                      final item = _checklistItems[index];
                      final existingResponse =
                          _checklistResponses[item.giclmId];
                      return RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 3,
                          ),
                          child: GICustomChecklistItem(
                            key: _widgetKeys[item.giclmId],
                            checklistItem: item,
                            siteData: widget.siteData,
                            mode: widget.mode,
                            existingResponse: existingResponse,
                            onRadioChanged: (radioValue) {
                              final currentResponse =
                                  _checklistResponses[item.giclmId];
                              _onChecklistItemChanged(
                                item.giclmId,
                                radioValue,
                                currentResponse?['image_id'],
                                currentResponse?['text_value'],
                              );
                            },
                            onImageChanged: (imageId) {
                              final currentResponse =
                                  _checklistResponses[item.giclmId];
                              _onChecklistItemChanged(
                                item.giclmId,
                                currentResponse?['radio_value'],
                                imageId,
                                currentResponse?['text_value'],
                              );
                            },
                            onTextChanged: (textValue) {
                              final currentResponse =
                                  _checklistResponses[item.giclmId];
                              _onChecklistItemChanged(
                                item.giclmId,
                                currentResponse?['radio_value'],
                                currentResponse?['image_id'],
                                textValue,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Back Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _popBackToDetail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonColorBg,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Back",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.buttonColorSite,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Submit Button
                      Expanded(
                        child: CustomSubmitButtonV2(
                          text: "Submit",
                          onPressed: widget.mode == CMScreenModeEnum.view
                              ? null
                              : () async => await _submitForm(),
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
    ),
    );
  }

  /// Sequential validation: Item-by-item validation
  /// For each checklist item:
  ///   1. Validate parent field is_mandatory first
  ///   2. Then validate dependent elements (only if parent is valid)
  ///   3. Move to next item only if current item is fully valid
  /// Returns false on first failure and shows popup
  bool _validateDependenciesSequentially() {
    // Loop through checklist items in order (STRICT SEQUENTIAL)
    for (final item in _checklistItems) {
      // ============================================================
      // STEP 1: Validate Parent Field Mandatory (is_mandatory)
      // ============================================================
      if (item.isMandatory) {
        final response = _checklistResponses[item.giclmId];
        bool hasRadio = item.respType.contains('RADIO');
        bool hasDropdown = item.respType.contains('DROPDOWN');
        bool hasImage = item.respType.contains('IMG');
        bool hasText = item.respType.contains('TEXT');

        // Check if parent field response is missing
        bool isParentFieldEmpty = false;
        String? errorMessage;

        if ((hasRadio || hasDropdown) &&
            (response == null ||
                response['radio_value'] == null ||
                response['radio_value'].toString().isEmpty)) {
          isParentFieldEmpty = true;
          errorMessage = '${item.checklistDesc} is mandatory';
        } else if (hasText &&
            (response == null ||
                response['text_value'] == null ||
                response['text_value'].toString().trim().isEmpty)) {
          isParentFieldEmpty = true;
          errorMessage = '${item.checklistDesc} is mandatory';
        } else if (hasImage) {
          // Skip image validation if radio_value is 'NA' (case insensitive)
          final radioValue = response?['radio_value']?.toString().toUpperCase();
          bool isRadioValueNA = radioValue == 'NA';

          if (!isRadioValueNA &&
              (response == null ||
                  response['image_id'] == null ||
                  response['image_id'].toString().isEmpty)) {
            isParentFieldEmpty = true;
            errorMessage = '${item.checklistDesc} is mandatory';
          }
        }

        // If parent field is mandatory and empty, show error and STOP
        if (isParentFieldEmpty) {
          _showValidationErrorDialog(errorMessage!);
          return false; // Stop validation - do not check dependent elements
        }
      }

      // ============================================================
      // STEP 2: Validate Dependent Elements (only if parent is valid)
      // ============================================================
      // Get parent response value for dependent element validation
      final parentResponse = _getParentResponseValue(item);
      
      // Only validate dependent elements if parent field has a response
      if (parentResponse != null && parentResponse.isNotEmpty) {
        // Check if this item has dependent elements
        if (item.dependentElements != null && item.dependentElements!.isNotEmpty) {
          // Get widget state for accessing dependent element data
          final widgetKey = _widgetKeys[item.giclmId];
          final widgetState = widgetKey?.currentState;
          
          if (widgetState != null) {
            // Loop through dependent elements in order
            for (final dependentElement in item.dependentElements!) {
              // Determine if this dependent element is mandatory
              final isMandatory = _isDependentElementMandatory(
                dependentElement,
                parentResponse,
              );
              
              // If mandatory, validate the dependent element value
              if (isMandatory) {
                final validationError = _validateDependentElementValue(
                  dependentElement,
                  widgetState,
                );
                
                // If validation fails, show popup and STOP immediately
                if (validationError != null) {
                  _showValidationErrorDialog(validationError);
                  // Highlight the invalid dependent field in red
                  widgetState.highlightDependentField(dependentElement.respType);
                  return false; // Stop validation - do not check other dependencies or next item
                }
              }
            }
          }
        }
      }

      // ============================================================
      // STEP 3: Move to Next Checklist Item
      // Only reached if:
      //   - Parent field is valid (or not mandatory)
      //   - All mandatory dependent elements are valid
      // ============================================================
    }
    
    // All checklist items validated successfully
    return true;
  }
  
  /// Get parent response value for a checklist item
  String? _getParentResponseValue(GenInsCheckListData item) {
    final response = _checklistResponses[item.giclmId];
    if (response == null) return null;
    
    // Get value based on response type
    if (item.respType.contains('RADIO') || item.respType.contains('DROPDOWN')) {
      return response['radio_value']?.toString();
    } else if (item.respType.contains('TEXT')) {
      return response['text_value']?.toString();
    }
    
    return null;
  }
  
  /// Determine if a dependent element is mandatory based on rules
  /// 
  /// Rules:
  /// 1. If mandatoryIfValue == true → Always mandatory (for all parent responses)
  /// 2. If mandatoryIfValue is a List (e.g., ["No", "Not Ok"]) → Mandatory only when parent response matches
  /// 
  /// Example from JSON:
  /// - Parent field: "DG" with options "OK" and "Not OK"
  /// - Dependent element: IMG with mandatoryIfValue: ["No", "Not Ok"]
  /// - Result:
  ///   * If parent response = "OK" → NOT mandatory (because "OK" is not in ["No", "Not Ok"])
  ///   * If parent response = "Not OK" → IS mandatory (because "Not OK" matches "Not Ok" case-insensitively)
  bool _isDependentElementMandatory(
    DependentElement element,
    String? parentResponse,
  ) {
    final mandatoryIfValue = element.mandatoryIfValue;
    
    // Case 1: Boolean mandatory (true = mandatory for all responses)
    if (mandatoryIfValue is bool && mandatoryIfValue == true) {
      return true;
    }
    
    // Case 2: Value-based mandatory (array of values)
    // Example: mandatoryIfValue: ["No", "Not Ok"]
    // This means: mandatory ONLY when parent response is "No" or "Not Ok"
    // If parent response is "OK", it should NOT be mandatory
    if (mandatoryIfValue is List) {
      if (parentResponse == null || parentResponse.isEmpty) {
        return false; // No parent response, not mandatory
      }
      
      // Check if parent response matches any value in the array (case-insensitive)
      // Convert both to lowercase for comparison to handle variations like "Not OK" vs "Not Ok"
      final mandatoryValues = mandatoryIfValue
          .map((e) => e.toString().trim().toLowerCase())
          .toList();
      final parentValueLower = parentResponse.trim().toLowerCase();
      
      // Return true only if parent response matches one of the mandatory values
      // Example: 
      //   - mandatoryIfValue: ["No", "Not Ok"]
      //   - parent = "OK" → returns false (not mandatory)
      //   - parent = "Not OK" → returns true (mandatory, matches "Not Ok" case-insensitively)
      return mandatoryValues.contains(parentValueLower);
    }
    
    // Default: not mandatory
    return false;
  }
  
  /// Validate a single dependent element value
  /// Returns error message if invalid, null if valid
  String? _validateDependentElementValue(
    DependentElement element,
    GICustomChecklistItemState? widgetState,
  ) {
    if (widgetState == null) {
      return '${element.checklistDesc} is mandatory';
    }
    
    if (element.respType == 'IMG') {
      // IMG: At least one image must be added
      final imageId = widgetState.getDependentImageId(element.respType);
      if (imageId == null || imageId.isEmpty) {
        return '${element.checklistDesc} is mandatory';
      }
    } else if (element.respType == 'REMARKS' || element.respType == 'TEXT') {
      // REMARKS/TEXT: Non-empty text required
      final value = element.respType == 'REMARKS'
          ? widgetState.getDependentRemarks(element.respType)
          : widgetState.getDependentTextValue(element.respType);
      
      if (value == null || value.trim().isEmpty) {
        return '${element.checklistDesc} is mandatory';
      }
    }
    
    return null; // Valid
  }
  
  /// Show validation error dialog
  void _showValidationErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Validation Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            errorMessage,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitForm() async {
    // Validate sequentially: Main fields first, then dependent elements
    // This function handles both main field and dependent element validation
    if (!_validateDependenciesSequentially()) {
      return; // Stop if validation fails
    }

    // All validations passed - submit the form data to API
    await _submitGeneralInspectionData();
  }

  Future<void> _submitGeneralInspectionData() async {
    LoaderWidget.showLoader(context);
    try {
      // Create the request data
      final requestData = _createRequestData();

      // Submit to API using the same method as site visit
      await ServiceLocator().assetAuditPostService
          .postAssetAuditDataWithPhotoReplacement(
            requests: [requestData],
            activityType: ActivityTypeEnum.generalInspection,
            isLastPage: true,
          );
      if (!mounted) return;

      showCustomToast(
        context,
        "General inspection submitted successfully",
      );

      // Reset form changes flag after successful submission
      setState(() {
        _hasFormDataChanges = false;
      });

      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext ?? context,
      );
    } catch (e) {
      Logger.errorLog('❌ Error submitting general inspection: $e');
      if (!mounted) return;
      showCustomToast(context, "Failed to submit general inspection data");
      rethrow; // Re-throw so UnsavedChangesDialog can handle the error
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  Map<String, dynamic> _createRequestData() {
    // Get current timestamp
    final now = DateTime.now();

    // Debug: Print visiting person image ID

    // Use giId from widget (passed from API response data)
    int giId = widget.giId ?? 0;
    final siteIdForPayload =
        widget.physicalSiteIdForPost ?? widget.siteData.siteId;

    // Create genInspectionSiteRespList
    List<Map<String, dynamic>> genInspectionSiteRespList = [];

    for (final item in _checklistItems) {
      final response = _checklistResponses[item.giclmId];
      if (response != null) {
        // Determine the response value based on the response type
        String respValue = "";
        if (item.respType.contains('RADIO')) {
          respValue = response['radio_value'] ?? "";
        } else if (item.respType.contains('DROPDOWN')) {
          respValue = response['radio_value'] ?? ""; // Dropdown uses same key as radio
        } else if (item.respType.contains('TEXT')) {
          respValue = response['text_value'] ?? "";
        }

        // Handle image ID - main IMG field or dependent IMG (stored as dependent_image_id when populated from API)
        dynamic respPhotoId;
        final imageIdStr = (response['image_id'] ?? response['dependent_image_id'])
            ?.toString();
        if (imageIdStr != null &&
            imageIdStr.isNotEmpty &&
            imageIdStr != "0") {
          if (imageIdStr.contains("LOCAL_IMAGE_ID")) {
            respPhotoId = imageIdStr;
          } else {
            respPhotoId = int.tryParse(imageIdStr);
          }
        } else {
          respPhotoId = null;
        }

        // Collect remarks from dependent elements
        String remarksText = "";
        if (item.dependentElements != null && item.dependentElements!.isNotEmpty) {
          // Get widget state to access dependent element data
          final widgetKey = _widgetKeys[item.giclmId];
          final widgetState = widgetKey?.currentState;
          
          if (widgetState != null) {
            // Collect all REMARKS from dependent elements
            List<String> remarksList = [];
            for (final dependentElement in item.dependentElements!) {
              if (dependentElement.respType == 'REMARKS') {
                final remarkValue = widgetState.getDependentRemarks(dependentElement.respType);
                if (remarkValue != null && remarkValue.trim().isNotEmpty) {
                  remarksList.add(remarkValue.trim());
                }
              }
            }
            // Join all remarks with semicolon or newline
            remarksText = remarksList.join("; ");
          }
        }

        // Use existing gispId if available (for edit mode), otherwise use 0 (for create mode)
        final gispRaw = response['gispId'] ?? response['gisp_id'];
        int gispId = gispRaw is int ? gispRaw : (int.tryParse(gispRaw?.toString() ?? '') ?? 0);

        Map<String, dynamic> respItem = {
          "gispId": gispId,
          "siteId": siteIdForPayload,
          "giclmId": item.giclmId,
          "checklistDesc": item.checklistDesc,
          "resp": respValue,
          "respPhotoId": respPhotoId,
          "clOrder": item.clOrder,
          "longitude": _longitude?.toString() ?? "0.0",
          "latitude": _latitude?.toString() ?? "0.0",
          "isActive": true,
          "remarks": remarksText, // Use collected remarks instead of empty string
        };
        genInspectionSiteRespList.add(respItem);
      }
    }

    // Create the main request object
    Map<String, dynamic> requestData = {
      "giId": giId,
      "visitDate":
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}",
      "siteId": siteIdForPayload,
      "visitingPersonId": 0,
      "visitingPersonImageId": widget.visitingPersonImageId ?? "0",
      "isActive": true,
      "remarks": "",
      "genInspectionSiteRespList": genInspectionSiteRespList,
      "circle": widget.siteData.circleStateName,
      "cluster": widget.siteData.clusterDistrictName,
      "client": widget.siteData.clientName,
      "siteName": widget.siteData.siteName,
      "siteCode": widget.siteData.siteCode,
      "operator": "",
      "infraDistrictEngineerName": widget.siteData.infraEngineerName ?? "",
      "infraDistrictEngineerContactNo":
          widget.siteData.infraEngineerPhone ?? "",
      "ownerName": widget.siteData.ownerName ?? "",
      "ownerContactNo": widget.siteData.ownerPhone ?? "",
    };

    return requestData;
  }

  void _showUnsavedChangesDialog() {

    if (_hasFormDataChanges) {

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteData.siteId.toString(),
          section: "General Inspection Checklist",
          parentContext: widget.parentContext ?? context,
          onSaveAndExit: () async {
            await _submitForm();
          },
          onDiscard: () {},
        ),
      );
    } else {
      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext ?? context,
      );
    }
  }
}
