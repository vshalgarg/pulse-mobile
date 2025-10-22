import 'dart:convert';

import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/gen_ins_checklist_model.dart';
import 'package:app/repositories/general_inspection_repository.dart';
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

  const GIChecklistScreen({
    super.key,
    required this.siteData,
    required this.mode,
    this.visitingPersonImageId,
  });

  @override
  State<GIChecklistScreen> createState() => _GIChecklistScreenState();
}

class _GIChecklistScreenState extends State<GIChecklistScreen> {
  bool _isLoadingChecklist = true;
  String? _checklistError;

  late GeneralInspectionRepository _repository;
  
  // Checklist data
  List<GenInsCheckListData> _checklistItems = [];
  Map<int, Map<String, dynamic>> _checklistResponses = {}; // giclm_id -> response data
  
  // Location data
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();

    _repository = GeneralInspectionRepository(ServiceLocator().apiService);
    
    _getCurrentLocation();
    _loadChecklistData();
  }

  Future<void> _loadChecklistData() async {
    try {
      setState(() {
        _isLoadingChecklist = true;
        _checklistError = null;
      });

      // Use default site domain ID for now (can be made configurable later)
      final siteDomainId = 1;
      
      Logger.debugLog('Loading checklist data for site domain ID: $siteDomainId');
      
      final checklistItems = await _repository.getGenInsCheckListData(siteDomainId);
      
      // Sort by cl_order
      checklistItems.sort((a, b) => a.clOrder.compareTo(b.clOrder));
      
      setState(() {
        _checklistItems = checklistItems;
        _isLoadingChecklist = false;
      });
      
      Logger.debugLog('Loaded ${checklistItems.length} checklist items');
    } catch (e) {
      Logger.errorLog('Error loading checklist data: $e');
      setState(() {
        _isLoadingChecklist = false;
        _checklistError = e.toString();
      });
    }
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
    );
  }

  Widget _buildChecklistContent() {
    return Column(
      children: [
        // Site Information Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Site Information",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Site: ${widget.siteData.siteName}",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                "Code: ${widget.siteData.siteCode}",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                "Location: ${widget.siteData.clusterDistrictName}, ${widget.siteData.circleStateName}",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),

        // Checklist Items
        if (_isLoadingChecklist)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          )
        else if (_checklistError != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.errorColor),
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: AppColors.errorColor),
                const SizedBox(height: 8),
                Text(
                  'Error loading checklist: $_checklistError',
                  style: const TextStyle(color: AppColors.errorColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadChecklistData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else
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

    // Create the JSON response
    _createAndPrintResponse();
  }

  void _createAndPrintResponse() {
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

    // Create the main response object
    Map<String, dynamic> response = {
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

    // Print the full JSON response with formatting
    final jsonString = jsonEncode(response);
    final prettyJson = _formatJson(jsonString);
    
    Logger.debugLog('Full General Inspection Response:');
    print('\n' + '=' * 80);
    print('GENERAL INSPECTION RESPONSE JSON:');
    print('=' * 80);
    print(prettyJson);
    print('=' * 80);
    print('Raw JSON (for API):');
    print(jsonString);
    print('=' * 80 + '\n');

    showCustomToast(context, "General inspection checklist submitted successfully");
    Navigator.of(context).pop();
  }

  String _formatJson(String jsonString) {
    try {
      final dynamic jsonData = jsonDecode(jsonString);
      return const JsonEncoder.withIndent('  ').convert(jsonData);
    } catch (e) {
      return jsonString; // Return original if formatting fails
    }
  }
}
