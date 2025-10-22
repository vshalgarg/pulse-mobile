import 'dart:io';

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
import 'gi_custom_widget.dart';

class GIChecklistScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final CMScreenModeEnum mode;

  const GIChecklistScreen({
    super.key,
    required this.siteData,
    required this.mode,
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

  @override
  void initState() {
    super.initState();

    _repository = GeneralInspectionRepository(ServiceLocator().apiService);
    
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

  void _onChecklistItemChanged(int giclmId, String? radioValue, File? imageFile) {
    setState(() {
      _checklistResponses[giclmId] = {
        'radio_value': radioValue,
        'image_file': imageFile,
      };
    });
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
              mode: widget.mode,
              onRadioChanged: (radioValue) => _onChecklistItemChanged(item.giclmId, radioValue, null),
              onImageChanged: (imageFile) => _onChecklistItemChanged(item.giclmId, null, imageFile),
            ),
          )),
      ],
    );
  }

  void _submitForm() {
    // Validate checklist items
    List<String> validationErrors = [];
    for (final item in _checklistItems) {
      if (item.isMandatory) {
        final response = _checklistResponses[item.giclmId];
        bool hasRadio = item.respType.contains('RADIO');
        bool hasImage = item.respType.contains('IMG');
        
        if (hasRadio && (response == null || response['radio_value'] == null)) {
          validationErrors.add('${item.checklistDesc} is required');
        }
        
        if (hasImage && (response == null || response['image_file'] == null)) {
          validationErrors.add('${item.checklistDesc} photo is required');
        }
      }
    }

    if (validationErrors.isNotEmpty) {
      showCustomToast(context, validationErrors.first);
      return;
    }

    // TODO: Implement form submission logic with checklist data
    Logger.debugLog('Submitting checklist with ${_checklistResponses.length} responses');
    for (final entry in _checklistResponses.entries) {
      Logger.debugLog('Item ${entry.key}: ${entry.value}');
    }

    Future.delayed(const Duration(seconds: 2), () {
      showCustomToast(context, "General inspection checklist submitted successfully");
      Navigator.of(context).pop();
    });
  }
}
