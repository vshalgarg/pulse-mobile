import 'dart:convert';

import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/gen_ins_checklist_model.dart';
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

  const GIChecklistScreen({
    super.key,
    required this.siteData,
    required this.mode,
    this.visitingPersonImageId,
    required this.checklistItems,
  });

  @override
  State<GIChecklistScreen> createState() => _GIChecklistScreenState();
}

class _GIChecklistScreenState extends State<GIChecklistScreen> {
  // Checklist data
  List<GenInsCheckListData> _checklistItems = [];
  Map<int, Map<String, dynamic>> _checklistResponses = {}; // giclm_id -> response data
  
  // Location data
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    
    // Use the pre-loaded checklist data
    _checklistItems = widget.checklistItems;
    
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

  void _onChecklistItemChanged(int giclmId, String? radioValue, String? imageId, String? textValue) {
    print('🔍 _onChecklistItemChanged called for giclmId: $giclmId');
    print('  - radioValue: $radioValue');
    print('  - imageId: $imageId');
    print('  - textValue: $textValue');
    
    setState(() {
      _checklistResponses[giclmId] = {
        'radio_value': radioValue,
        'image_id': imageId,
        'text_value': textValue,
      };
    });
    
    print('🔍 Updated _checklistResponses for $giclmId: ${_checklistResponses[giclmId]}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: "General Inspection Checklist",
        onClose: () => Navigator.of(context).pop(),
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
                          onPressed: () => Navigator.of(context).pop(),
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
        ..._checklistItems.map((item) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: GICustomChecklistItem(
              checklistItem: item,
              siteData: widget.siteData,
              mode: widget.mode,
              onRadioChanged: (radioValue) {
                final currentResponse = _checklistResponses[item.giclmId];
                _onChecklistItemChanged(
                  item.giclmId, 
                  radioValue, 
                  currentResponse?['image_id'], 
                  currentResponse?['text_value']
                );
              },
              onImageChanged: (imageId) {
                final currentResponse = _checklistResponses[item.giclmId];
                _onChecklistItemChanged(
                  item.giclmId, 
                  currentResponse?['radio_value'], 
                  imageId, 
                  currentResponse?['text_value']
                );
              },
              onTextChanged: (textValue) {
                final currentResponse = _checklistResponses[item.giclmId];
                _onChecklistItemChanged(
                  item.giclmId, 
                  currentResponse?['radio_value'], 
                  currentResponse?['image_id'], 
                  textValue
                );
              },
            ),
          )),
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
        print('  - hasRadio: $hasRadio, hasImage: $hasImage, hasText: $hasText');
        print('  - response: $response');
        print('  - radio_value: ${response?['radio_value']}');
        print('  - image_id: ${response?['image_id']}');
        print('  - text_value: ${response?['text_value']}');
        
        if (hasRadio && (response == null || response['radio_value'] == null || response['radio_value'].toString().isEmpty)) {
          validationErrors.add('${item.checklistDesc} is required');
          print('  ❌ Radio validation failed for ${item.checklistDesc}');
        }
        
        if (hasText && (response == null || response['text_value'] == null || response['text_value'].toString().trim().isEmpty)) {
          validationErrors.add('${item.checklistDesc} is required');
          print('  ❌ Text validation failed for ${item.checklistDesc}');
          print('    - response is null: ${response == null}');
          print('    - text_value is null: ${response?['text_value'] == null}');
          print('    - text_value is empty: ${response?['text_value']?.toString().trim().isEmpty}');
          print('    - text_value value: "${response?['text_value']}"');
        }
        
        if (hasImage && (response == null || response['image_id'] == null || response['image_id'].toString().isEmpty)) {
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
    try {
      // Create the request data
      final requestData = _createRequestData();
      
      print('🔍 Submitting General Inspection data:');
      print('Request data: $requestData');

      // Submit to API using the same method as site visit
      await ServiceLocator().assetAuditPostService.postAssetAuditDataWithPhotoReplacement(
        requests: [requestData],
        activityType: ActivityTypeEnum.generalInspection,
        isLastPage: true,
      );

      print('✅ General inspection submitted successfully');
      showCustomToast(context, "General inspection checklist submitted successfully");
      Navigator.of(context).pop();
    } catch (e) {
      Logger.errorLog('❌ Error submitting general inspection: $e');
      showCustomToast(context, "Failed to submit general inspection data");
    }
  }

  Map<String, dynamic> _createRequestData() {
    // Get current timestamp
    final now = DateTime.now().toUtc();
    final visitDate = now.toIso8601String();
    
    // Debug: Print visiting person image ID
    print('🔍 Visiting Person Image ID from previous screen: ${widget.visitingPersonImageId}');

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

        Map<String, dynamic> respItem = {
          "gispId": 0,
          "siteId": widget.siteData.siteId,
          "giclmId": item.giclmId,
          "checklistDesc": item.checklistDesc,
          "resp": respValue,
          "respPhotoId": int.tryParse(response['image_id'] ?? "0") ?? 0,
          "clOrder": item.clOrder,
          "longitude": _longitude?.toString() ?? "0.0",
          "latitude": _latitude?.toString() ?? "0.0",
          "isActive": true,
          "remarks": ""
        };
        genInspectionSiteRespList.add(respItem);
      }
    }

    // Create the main request object
    Map<String, dynamic> requestData = {
      "giId": 0,
      "visitDate": visitDate,
      "siteId": widget.siteData.siteId,
      "visitingPersonId": 0,
      "visitingPersonImageId": int.tryParse(widget.visitingPersonImageId ?? "0") ?? 0,
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
      "infraDistrictEngineerContactNo": widget.siteData.infraEngineerPhone ?? "",
      "ownerName": widget.siteData.ownerName ?? "",
      "ownerContactNo": widget.siteData.ownerPhone ?? ""
    };

    return requestData;
  }

}
