import 'dart:convert';

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
import 'package:app/screens/pulse_dashboard.dart';
import 'package:app/screens/site_visit/all_sites.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'gi_custom_widget.dart';

class GIChecklistScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final CMScreenModeEnum mode;
  final String? visitingPersonImageId; // Image ID from the previous screen
  final List<GenInsCheckListData> checklistItems; // Pre-loaded checklist data
  final Map<int, Map<String, dynamic>>?
  existingResponses; // Existing responses for edit mode
  final int? giId; // General Inspection ID for edit mode

  const GIChecklistScreen({
    super.key,
    required this.siteData,
    required this.mode,
    this.visitingPersonImageId,
    required this.checklistItems,
    this.existingResponses,
    this.giId,
  });

  @override
  State<GIChecklistScreen> createState() => _GIChecklistScreenState();
}

class _GIChecklistScreenState extends State<GIChecklistScreen> {
  // Checklist data
  List<GenInsCheckListData> _checklistItems = [];
  Map<int, Map<String, dynamic>> _checklistResponses =
      {}; // giclm_id -> response data

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

    // Populate existing responses if in edit mode
    if (widget.existingResponses != null) {
      _checklistResponses = Map.from(widget.existingResponses!);
      print('🔍 Loaded existing responses: $_checklistResponses');
      print('🔍 Number of existing responses: ${_checklistResponses.length}');
      for (final entry in _checklistResponses.entries) {
        print('  - Item ${entry.key}: ${entry.value}');
      }
    } else {
      print('🔍 No existing responses provided');
    }

    _getCurrentLocation();
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
    print('🔍 _onChecklistItemChanged called for giclmId: $giclmId');
    print('  - radioValue: $radioValue');
    print('  - imageId: $imageId');
    print('  - textValue: $textValue');

    // Update the response data
    _checklistResponses[giclmId] = {
      'radio_value': radioValue,
      'image_id': imageId,
      'text_value': textValue,
    };

    // Track form changes
    if (!_hasFormDataChanges) {
      print("🔍 Checklist item changed - setting _hasFormDataChanges to true");
      _hasFormDataChanges = true;
    }

    print(
      '🔍 Updated _checklistResponses for $giclmId: ${_checklistResponses[giclmId]}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: "General Inspection Checklist",
        onClose: () => _showUnsavedChangesDialog(),
      ),
      body: Stack(
        children: [
          // Background
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
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_buildChecklistContent()],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Back Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showUnsavedChangesDialog(),
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
                              : _submitForm,
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

  Widget _buildChecklistContent() {
    return Column(
      children: [
        // Site Information Header
        const SizedBox(height: 20),

        // Checklist Items
        ..._checklistItems.map((item) {
          final existingResponse = _checklistResponses[item.giclmId];
          print(
            '🔍 Building checklist item ${item.giclmId} (${item.checklistDesc}):',
          );
          print('  - existingResponse: $existingResponse');

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: GICustomChecklistItem(
              checklistItem: item,
              siteData: widget.siteData,
              mode: widget.mode,
              existingResponse: existingResponse, // Pass existing response data
              onRadioChanged: (radioValue) {
                final currentResponse = _checklistResponses[item.giclmId];
                _onChecklistItemChanged(
                  item.giclmId,
                  radioValue,
                  currentResponse?['image_id'],
                  currentResponse?['text_value'],
                );
              },
              onImageChanged: (imageId) {
                final currentResponse = _checklistResponses[item.giclmId];
                _onChecklistItemChanged(
                  item.giclmId,
                  currentResponse?['radio_value'],
                  imageId,
                  currentResponse?['text_value'],
                );
              },
              onTextChanged: (textValue) {
                final currentResponse = _checklistResponses[item.giclmId];
                _onChecklistItemChanged(
                  item.giclmId,
                  currentResponse?['radio_value'],
                  currentResponse?['image_id'],
                  textValue,
                );
              },
            ),
          );
        }),
      ],
    );
  }

  void _submitForm() {
    // Debug: Print all responses
    print('🔍 All checklist responses:');
    for (final entry in _checklistResponses.entries) {
      print('  Item ${entry.key}: ${entry.value}');
    }

    // Validate checklist items
    List<String> validationErrors = [];
    for (final item in _checklistItems) {
      if (item.isMandatory) {
        final response = _checklistResponses[item.giclmId];
        bool hasRadio = item.respType.contains('RADIO');
        bool hasImage = item.respType.contains('IMG');
        bool hasText = item.respType.contains('TEXT');

        print('🔍 Validating ${item.checklistDesc}:');
        print(
          '  - hasRadio: $hasRadio, hasImage: $hasImage, hasText: $hasText',
        );
        print('  - response: $response');
        print('  - radio_value: ${response?['radio_value']}');
        print('  - image_id: ${response?['image_id']}');
        print('  - text_value: ${response?['text_value']}');

        if (hasRadio &&
            (response == null ||
                response['radio_value'] == null ||
                response['radio_value'].toString().isEmpty)) {
          validationErrors.add('${item.checklistDesc} is required');
          print('  ❌ Radio validation failed for ${item.checklistDesc}');
        }

        if (hasText &&
            (response == null ||
                response['text_value'] == null ||
                response['text_value'].toString().trim().isEmpty)) {
          validationErrors.add('${item.checklistDesc} is required');
          print('  ❌ Text validation failed for ${item.checklistDesc}');
          print('    - response is null: ${response == null}');
          print('    - text_value is null: ${response?['text_value'] == null}');
          print(
            '    - text_value is empty: ${response?['text_value']?.toString().trim().isEmpty}',
          );
          print('    - text_value value: "${response?['text_value']}"');
        }

        if (hasImage &&
            (response == null ||
                response['image_id'] == null ||
                response['image_id'].toString().isEmpty)) {
          validationErrors.add('${item.checklistDesc} photo is required');
          print('  ❌ Image validation failed for ${item.checklistDesc}');
        }
      }
    }

    if (validationErrors.isNotEmpty) {
      showCustomToast(context, validationErrors.first);
      return;
    }

    // Submit the form data to API
    _submitGeneralInspectionData();
  }

  Future<void> _submitGeneralInspectionData() async {
    LoaderWidget.showLoader(context);
    try {
      // Create the request data
      final requestData = _createRequestData();

      print('🔍 Submitting General Inspection data:');
      print('Request data: $requestData');

      // Submit to API using the same method as site visit
      await ServiceLocator().assetAuditPostService
          .postAssetAuditDataWithPhotoReplacement(
            requests: [requestData],
            activityType: ActivityTypeEnum.generalInspection,
            isLastPage: true,
          );

      print('✅ General inspection submitted successfully');
      showCustomToast(
        context,
        "General inspection checklist submitted successfully",
      );

      // Reset form changes flag after successful submission
      setState(() {
        _hasFormDataChanges = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PulseDashboard()),
      );
    } catch (e) {
      Logger.errorLog('❌ Error submitting general inspection: $e');
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
    print(
      '🔍 Visiting Person Image ID from previous screen: ${widget.visitingPersonImageId}',
    );
    print(
      '🔍 Visiting Person Image ID type: ${widget.visitingPersonImageId.runtimeType}',
    );

    // Use giId from widget (passed from API response data)
    int giId = widget.giId ?? 0;
    print('🔍 Using giId: $giId');

    // Create genInspectionSiteRespList
    List<Map<String, dynamic>> genInspectionSiteRespList = [];

    for (final item in _checklistItems) {
      final response = _checklistResponses[item.giclmId];
      if (response != null) {
        // Determine the response value based on the response type
        String respValue = "";
        if (item.respType.contains('RADIO')) {
          respValue = response['radio_value'] ?? "";
        } else if (item.respType.contains('TEXT')) {
          respValue = response['text_value'] ?? "";
        }

        // Handle image ID - can be either integer (server ID) or string (local ID)
        dynamic respPhotoId;
        final imageId = response['image_id']?.toString();
        if (imageId != null && imageId.isNotEmpty && imageId != "0") {
          // Check if it's a local image ID or server ID
          if (imageId.contains("LOCAL_IMAGE_ID")) {
            respPhotoId = imageId; // Keep as string for local image IDs
          } else {
            respPhotoId = int.tryParse(imageId); // Parse as int for server IDs
          }
        } else {
          respPhotoId = null;
        }

        // Use existing gispId if available (for edit mode), otherwise use 0 (for create mode)
        int gispId = response['gispId'] ?? 0;

        Map<String, dynamic> respItem = {
          "gispId": gispId,
          "siteId": widget.siteData.siteId,
          "giclmId": item.giclmId,
          "checklistDesc": item.checklistDesc,
          "resp": respValue,
          "respPhotoId": respPhotoId,
          "clOrder": item.clOrder,
          "longitude": _longitude?.toString() ?? "0.0",
          "latitude": _latitude?.toString() ?? "0.0",
          "isActive": true,
          "remarks": "",
        };
        genInspectionSiteRespList.add(respItem);
      }
    }

    // Create the main request object
    Map<String, dynamic> requestData = {
      "giId": giId,
      "visitDate":
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}",
      "siteId": widget.siteData.siteId,
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
    print(
      "🔍 _showUnsavedChangesDialog called - _hasFormDataChanges: $_hasFormDataChanges",
    );
    if (_hasFormDataChanges) {
      print("🔍 Showing unsaved changes dialog");
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteData.siteId.toString(),
          section: "General Inspection Checklist",
          parentContext: context,
          onSaveAndExit: () async {
            _submitForm();
          },
          onDiscard: () {
            Navigator.of(context).pop();
          },
        ),
      );
    } else {
      print("🔍 No form changes detected - navigating back directly");
      Navigator.of(context).pop();
    }
  }
}
