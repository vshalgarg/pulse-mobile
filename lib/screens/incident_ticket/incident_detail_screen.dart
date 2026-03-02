import 'dart:convert';
import 'dart:io';

import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_form_dropdown.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/incident_ticket_request_model.dart';
import 'package:app/repositories/incident_repository.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/connectivity_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'incident_checklist.dart';

class IncidentDetilScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final CMScreenModeEnum mode;
  final Map<String, dynamic>? apiResponseData;
  final BuildContext? parentContext;

  const IncidentDetilScreen({
    super.key,
    required this.siteData,
    required this.mode,
    this.apiResponseData,
    this.parentContext,
  });

  @override
  State<IncidentDetilScreen> createState() => _IncidentDetilScreenState();
}

class _IncidentDetilScreenState extends State<IncidentDetilScreen> {
  // Dropdown selected values
  String? _selectedIncidentTicketReason;
  String? _selectedCurrentSiteStatus;
  String? _selectedStatus;

  // Text field controllers
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _incidentRemarksController =
      TextEditingController();

  // Image handling
  File? _selectedImage;
  String? _uploadedImgId;
  String? _fetchedImageData;

  // Closed remarks (read-only, displayed when status is CLOSE)
  String? _closedRemarks;

  bool _hasFormDataChanges = false;

  // Checklist data
  bool _isLoadingChecklist = true;
  String? _checklistError;
  Map<String, List<Map<String, dynamic>>> _checklistData = {};
  late IncidentRepository _repository;
  
  // Store checklist selections to persist when navigating back
  Map<String, dynamic>? _storedChecklistSelections;

  // Dropdown options
  final List<String> _incidentTicketReasonOptions = ['Site Down', 'Other'];
  final List<String> _currentSiteStatusOptions = [
    'Restored',
    'Down',
    'Resolved',
    'Unresolved',
  ];
  final List<String> _statusOptions = ['OPEN', 'CLOSED'];

  // Check if mode is view (read-only)
  bool get _isViewMode => widget.mode == CMScreenModeEnum.view;

  @override
  void initState() {
    super.initState();

    _repository = IncidentRepository(ServiceLocator().apiService);
    _initializeFormData();
    _loadChecklistData();

    // Add listeners to track form changes
    _remarksController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });

    _incidentRemarksController.addListener(() {
      if (!_hasFormDataChanges) {
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
  }

  void _initializeFormData() {
    // Initialize form fields with API response data if available
    if (widget.apiResponseData != null) {
      _selectedIncidentTicketReason = widget
          .apiResponseData!['incidentTicketReason']
          ?.toString();
      _selectedCurrentSiteStatus = widget.apiResponseData!['currentSiteStatus']
          ?.toString();
      _selectedStatus = widget.apiResponseData!['status']?.toString();

      _remarksController.text =
          widget.apiResponseData!['remarks']?.toString() ?? "";
      _incidentRemarksController.text =
          widget.apiResponseData!['incidentRemarks']?.toString() ?? "";

      // Initialize closedRemarks if available
      _closedRemarks = widget.apiResponseData!['closedRemarks']?.toString();

      // Initialize image if available - check for incidentImgId
      final imageId =
          widget.apiResponseData!['incidentImgId']?.toString() ??
          widget.apiResponseData!['imageId']?.toString() ??
          widget.apiResponseData!['image_id']?.toString();
      if (imageId != null && imageId.isNotEmpty && imageId != "0") {
        _uploadedImgId = imageId;
        _loadExistingImage(imageId);
      }

      // If status is CLOSE, ensure it's set
      if (_selectedStatus == null || _selectedStatus!.isEmpty) {
        _selectedStatus =
            widget.apiResponseData!['status']?.toString() ?? 'OPEN';
      }
    } else {
      // Default values for create mode
      _selectedIncidentTicketReason = null;
      _selectedCurrentSiteStatus = null;
      _selectedStatus = 'OPEN';
      _remarksController.text = "";
      _incidentRemarksController.text = "";
    }

    // In view mode, if status is CLOSE, mark all as read-only
    if (_isViewMode || _selectedStatus == 'CLOSED') {
      setState(() {
        _hasFormDataChanges = false;
      });
    }
  }

  Future<void> _loadExistingImage(String imageId) async {
    try {
      String? uniqueId;

      // Check if this is already a unique ID (offline mode) or a server ID (online mode)
      if (imageId.contains("LOCAL_IMAGE_ID")) {
        // This is already a unique ID from offline mode
        uniqueId = imageId;
      } else {
        // This is a server ID, try to download from server (online mode)
        uniqueId = await ServiceLocator().imageUploadService
            .downloadImageUsingServerId(
              imageId,
              ActivityTypeEnum.incident,
              widget.siteData.siteId.toString(),
            );
      }

      if (uniqueId != null) {
        // Now get the image data using the unique ID
        final imageData = await ServiceLocator().centralAssetAuditService
            .getImageAsDataUrl(uniqueId);

        if (imageData != null) {
          Logger.debugLog(
            '✅ Image data received: ${imageData.length} characters',
          );
          setState(() {
            _fetchedImageData = imageData;
          });
          Logger.debugLog('✅ Image loaded successfully and state updated');
        } else {
          Logger.errorLog(
            '❌ Failed to load image data with uniqueId $uniqueId - imageData is null',
          );
        }
      } else {
        Logger.errorLog('❌ Failed to get unique ID for image: $imageId');
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading existing image: $e');
    }
  }

  Future<void> _uploadImage() async {
    try {
      if (_selectedImage == null) {
        Toastbar.showErrorToastbar('Please select an image first', context);
        return;
      }

      // Upload image to server
      final imgId = await ServiceLocator().centralAssetAuditService.uploadImage(
        siteAuditSchId: widget.siteData.siteId.toString(),
        imageFile: _selectedImage!,
        isSelfie: false,
        activityType: ActivityTypeEnum.incident,
      );

      if (imgId != null && imgId.isNotEmpty) {
        setState(() {
          _uploadedImgId = imgId;
        });

        // Show appropriate message based on whether it's server or local ID
        if (imgId.contains("LOCAL_IMAGE_ID")) {
          Toastbar.showSuccessToastbar(
            'Photo saved locally (offline mode)',
            context,
          );
        } else {
          Toastbar.showSuccessToastbar('Photo uploaded successfully', context);
        }
      } else {
        Toastbar.showErrorToastbar('Failed to upload photo', context);
        throw Exception('Failed to get image ID');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading photo: $e');
      Toastbar.showErrorToastbar('Failed to upload photo', context);
    }
  }

  Future<void> _loadChecklistData() async {
    try {
      setState(() {
        _isLoadingChecklist = true;
        _checklistError = null;
      });

      Logger.debugLog(
        'Loading incident checklist data for site ID: ${widget.siteData.siteId}',
      );

      // First, try to get checklist data from local database
      try {
        final localChecklistData = await ServiceLocator()
            .centralAssetAuditDataService
            .getIncidentChecklistData(widget.siteData.siteId);

        if (localChecklistData.isNotEmpty) {
          // Use local data if available
          Logger.debugLog(
            '✅ Using local incident checklist data: ${localChecklistData.length} item types',
          );
          setState(() {
            _checklistData = localChecklistData;
            _isLoadingChecklist = false;
          });
          return;
        }
      } catch (localError) {
        Logger.errorLog(
          '❌ Error loading local incident checklist data: $localError',
        );
        // Continue to try API if local data fails
      }

      // If no local data, try to fetch from API
      try {
        final checklistData = await _repository.getIncidentChecklist();

        setState(() {
          _checklistData = checklistData;
          _isLoadingChecklist = false;
        });

        Logger.debugLog(
          '✅ Loaded incident checklist data from API: ${checklistData.length} item types',
        );
      } catch (apiError) {
        Logger.errorLog('❌ API call failed: $apiError');

        // If API failed, show error
        setState(() {
          _isLoadingChecklist = false;
          _checklistError =
              'Failed to load checklist data. Please check your internet connection and try again.';
        });
      }
    } catch (e) {
      Logger.errorLog('❌ Unexpected error loading checklist data: $e');
      setState(() {
        _isLoadingChecklist = false;
        _checklistError = 'Unexpected error: ${e.toString()}';
      });
    }
  }

  Future<void> _submitForm() async {
    // Check if checklist is still loading
    if (_isLoadingChecklist) {
      Toastbar.showInfoToastbar(
        'Please wait while checklist is loading',
        context,
      );
      return;
    }

    // Check if there was an error loading checklist
    if (_checklistError != null) {
      // Show error dialog with retry option
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Checklist Data Error'),
          content: Text(_checklistError!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadChecklistData(); // Retry loading
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
      return;
    }

    // Check if we have checklist data
    if (_checklistData.isEmpty) {
      Toastbar.showErrorToastbar(
        'No checklist data available. Please try downloading the data first.',
        context,
      );
      return;
    }

    // Validate required fields
    if (_selectedIncidentTicketReason == null ||
        _selectedIncidentTicketReason!.isEmpty) {
      Toastbar.showErrorToastbar(
        'Please select Incident Ticket Reason',
        context,
      );
      return;
    }

    if (_selectedCurrentSiteStatus == null ||
        _selectedCurrentSiteStatus!.isEmpty) {
      Toastbar.showErrorToastbar('Please select Current Site Status', context);
      return;
    }

    if (_selectedStatus == null || _selectedStatus!.isEmpty) {
      Toastbar.showErrorToastbar('Please select Status', context);
      return;
    }

    if (_incidentRemarksController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar('Please enter Incident Remarks', context);
      return;
    }

    if (_remarksController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar('Please enter Remarks', context);
      return;
    }

    if (_uploadedImgId == null || _uploadedImgId!.isEmpty) {
      Toastbar.showErrorToastbar('Please add a photo', context);
      return;
    }

    try {
      // In edit/view mode, prepare checklist data from API response
      Map<String, List<Map<String, dynamic>>> checklistDataForScreen =
          _checklistData;

      if (widget.apiResponseData != null &&
          widget.apiResponseData!.containsKey('incidentCheckListSiteResp')) {
        // Extract checklist items from API response and group by incidentItemType
        final checklistResponses =
            widget.apiResponseData!['incidentCheckListSiteResp'] as List?;
        if (checklistResponses != null && checklistResponses.isNotEmpty) {
          final groupedData = <String, List<Map<String, dynamic>>>{};

          for (final item in checklistResponses) {
            final itemMap = item as Map<String, dynamic>;
            final incidentItemType = itemMap['incidentItemType']?.toString();

            if (incidentItemType != null) {
              if (!groupedData.containsKey(incidentItemType)) {
                groupedData[incidentItemType] = [];
              }

              // Convert API response format to checklist format
              groupedData[incidentItemType]!.add({
                'iclm_id': itemMap['iclmId'] as int?,
                'checklist_desc': itemMap['checklistDesc']?.toString(),
                'cl_order': itemMap['clOrder'] as int? ?? 0,
                'resp_type': 'CHECKBOX',
                'incident_item_type': incidentItemType,
              });
            }
          }

          if (groupedData.isNotEmpty) {
            checklistDataForScreen = groupedData;
            Logger.debugLog(
              '✅ Using checklist data from API response: ${groupedData.keys.toList()}',
            );
          }
        }
      }

      // Navigate to checklist screen with pre-loaded data and wait for result
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => IncidentChecklistScreen(
            siteData: widget.siteData,
            mode: widget.mode,
            checklistData: checklistDataForScreen,
            currentStatus: _selectedStatus ?? 'OPEN',
            apiResponseData: widget.apiResponseData,
            parentContext: widget.parentContext ?? context,
            storedSelections: _storedChecklistSelections, // Pass stored selections
          ),
        ),
      );

      // Store the result if it exists (could be from Previous button or Submit)
      if (result != null && result.isNotEmpty) {
        // Check if this is just navigation (Previous button) or actual submission
        final isNavigation = result['isNavigation'] == true;
        
        if (isNavigation) {
          // Just save state, don't submit
          _storedChecklistSelections = result;
          Logger.debugLog('✅ Saved checklist selections for later (navigation only)');
        } else {
          // This is a submit action - proceed with API call
          _storedChecklistSelections = result; // Also store for potential future use
        await _submitIncidentTicket(result);
        }
      }
    } catch (e) {
      Logger.errorLog('❌ Error in submit process: $e');
      rethrow; // Re-throw so UnsavedChangesDialog can handle the error
    }
  }

  Future<void> _submitIncidentTicket(Map<String, dynamic> checklistData) async {
    try {
      if (!mounted) return;
      // Check internet connectivity
      final isConnected = await ConnectivityHelper.isConnected();
      Logger.debugLog('Internet connectivity: $isConnected');

      // Extract checklist responses
      final checklistResponses = checklistData['checklistResponses'] as List?;
      if (checklistResponses == null || checklistResponses.isEmpty) {
        Toastbar.showErrorToastbar('No checklist data to submit', context);
        return;
      }

      // Convert checklist responses to model objects
      final incidentCheckListSiteResp = checklistResponses
          .map(
            (item) => IncidentCheckListSiteResp(
              iclsrId: item['iclsrId'] ?? 0,
              iclmId: item['iclmId'] as int,
              siteId: item['siteId'] as int,
              incidentItemType: item['incidentItemType'] as String,
              checklistDesc: item['checklistDesc']?.toString(),
              resp: item['resp'] as String,
              clOrder: item['clOrder'] as int,
              longitude: item['longitude']?.toString(),
              latitude: item['latitude']?.toString(),
              localAuditLogId: item['localAuditLogId'],
              localCreatedDt: item['localCreatedDt']?.toString(),
              localModifiedDt: item['localModifiedDt']?.toString(),
              syncProcessId: item['syncProcessId'],
              isActive: item['isActive'] ?? true,
              remarks: item['remarks']?.toString(),
            ),
          )
          .toList();

      // Get image ID - convert LOCAL_IMAGE_ID to server ID if needed
      int? imageId;
      String? localImageId; // Store LOCAL_IMAGE_ID for offline mode

      Logger.debugLog('📸 Checking image ID: _uploadedImgId = $_uploadedImgId');

      if (_uploadedImgId != null && _uploadedImgId!.isNotEmpty) {
        Logger.debugLog('📸 Image ID found: $_uploadedImgId');

        if (_uploadedImgId!.contains("LOCAL_IMAGE_ID")) {
          Logger.debugLog(
            '📸 Detected LOCAL_IMAGE_ID, isConnected: $isConnected',
          );

          if (isConnected) {
            // For online mode, try to get the server ID by uploading
            try {
              final imageModel = await ServiceLocator().imageUploadService
                  .getServerIdFromUniqueIdTryUploading(_uploadedImgId!);
              if (imageModel != null && imageModel.serverId != null) {
                imageId = int.tryParse(imageModel.serverId.toString()) ?? 0;
                Logger.debugLog(
                  '✅ Converted LOCAL_IMAGE_ID to server ID: $imageId',
                );
              } else {
                Logger.errorLog(
                  '❌ Failed to get server ID for LOCAL_IMAGE_ID: $_uploadedImgId',
                );
                imageId = 0;
              }
            } catch (e) {
              Logger.errorLog('❌ Error converting image ID: $e');
              imageId = 0;
            }
          } else {
            // For offline mode, keep LOCAL_IMAGE_ID string for later processing
            localImageId = _uploadedImgId!;
            imageId = 0; // Set to 0 initially, will be replaced in JSON
            Logger.debugLog(
              '📸 Offline mode: Storing LOCAL_IMAGE_ID for later: $localImageId',
            );
          }
        } else {
          imageId = int.tryParse(_uploadedImgId!) ?? 0;
          Logger.debugLog('📸 Server ID found: $imageId');
        }
      } else {
        Logger.errorLog(
          '⚠️ No image ID found! _uploadedImgId is null or empty',
        );
        imageId = 0;
      }

      // Build request
      // In edit mode, preserve incidentTicketId from API response
      final incidentTicketId =
          widget.apiResponseData?['incidentTicketId'] as int? ?? 0;

      // Get closedRemarks from checklist data if status is CLOSE
      final closedRemarks = checklistData['closedRemarks']?.toString();

      // Set closedDt only when status is CLOSE, format: "yyyy-MM-dd HH:mm:ss.SSS" in IST
      String? closedDt;
      if (_selectedStatus == 'CLOSED') {
        // Convert UTC to IST (UTC+5:30)
        final utcNow = DateTime.now().toUtc();
        final istNow = utcNow.add(const Duration(hours: 5, minutes: 30));
        final formatter = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
        closedDt = formatter.format(istNow);
        Logger.debugLog('✅ Setting closedDt (IST): $closedDt');
      }

      final request = IncidentTicketRequest(
        incidentTicketId: incidentTicketId,
        incidentItemType: checklistData['parentIncidentType'] as String,
        siteId: widget.siteData.siteId,
        currentSiteStatus: _selectedCurrentSiteStatus ?? '',
        status: _selectedStatus ?? 'OPEN',
        incidentRemarks: _incidentRemarksController.text.trim().isEmpty
            ? null
            : _incidentRemarksController.text.trim(),
        incidentImgId: imageId,
        incidentTicketReason: _selectedIncidentTicketReason ?? '',
        closedBy: null,
        closedDt: closedDt,
        closedRemarks: closedRemarks?.isNotEmpty == true ? closedRemarks : null,
        isActive: true,
        remarks: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim(),
        incidentCheckListSiteResp: incidentCheckListSiteResp,
        incidentImageName: null,
      );

      if (!isConnected) {
        // Save to offline storage - replace imageId with LOCAL_IMAGE_ID string if needed
        await _saveOffline(request, localImageId);
      } else {
        // Submit online
        await _submitOnline(request);
      }
    } catch (e) {
      if (!mounted) return;
      Logger.errorLog('❌ Error submitting incident ticket: $e');
      Toastbar.showErrorToastbar(
        'Failed to save incident ticket: ${e.toString()}',
        context,
      );
    }
  }

  Future<void> _submitOnline(IncidentTicketRequest request) async {
    bool loaderOpen = false;
    try {
      if (!mounted) return;
      // Show loading indicator
      await Future.microtask(() {
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
        loaderOpen = true;
      });

      Logger.debugLog('Submitting incident ticket online: ${request.toJson()}');

      final response = await _repository.postIncidentTicket(request: request);

      // Close loader
      if (loaderOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loaderOpen = false;
      }

      if (!mounted) return;

      Logger.infoLog('✅ Incident ticket submitted successfully: $response');

      // Build toast message with ticketId/siteId if present
      final dynamic ticketId =
          response['incidentTicketId'] ?? response['data']?['incidentTicketId'];
      final toastMsg = ticketId != null
          ? 'Incident ticket $ticketId saved for Site ${widget.siteData.siteId}'
          : 'Incident ticket saved for Site ${widget.siteData.siteId}';

      Toastbar.showSuccessToastbar(toastMsg, context);

      // Navigate back to tickets/home
      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext ?? context,
      );
    } catch (e) {
      if (loaderOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loaderOpen = false;
      }
      if (mounted) {
        Toastbar.showErrorToastbar(
          'Failed to save incident ticket: ${e.toString()}',
          context,
        );
      }
      Logger.errorLog('❌ Error submitting incident ticket online: $e');
    }
  }

  Future<void> _saveOffline(
    IncidentTicketRequest request,
    String? localImageId,
  ) async {
    bool loaderOpen = false;
    try {
      // Show loading indicator
      await Future.microtask(() {
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
        loaderOpen = true;
      });

      // Create a unique request ID for this incident ticket submission
      final requestId =
          'incident_ticket_${widget.siteData.siteId}_${DateTime.now().millisecondsSinceEpoch}';

      // Convert request to JSON and wrap in list (as expected by sync service)
      final requestJson = request.toJson();

      Logger.debugLog(
        '📸 Before replacement - incidentImgId in JSON: ${requestJson['incidentImgId']}',
      );
      Logger.debugLog('📸 localImageId value: $localImageId');
      Logger.debugLog('📸 _uploadedImgId state: $_uploadedImgId');

      // If we have a LOCAL_IMAGE_ID, replace the incidentImgId (0) with the string
      // so that the image processor can detect and convert it later
      if (localImageId != null && localImageId.isNotEmpty) {
        requestJson['incidentImgId'] = localImageId;
        Logger.debugLog(
          '📸 ✅ Replaced incidentImgId with LOCAL_IMAGE_ID: $localImageId',
        );
      } else {
        Logger.errorLog(
          '⚠️ No localImageId to replace! incidentImgId will remain 0',
        );
        Logger.errorLog('📸 _uploadedImgId state: $_uploadedImgId');
        // If _uploadedImgId exists but localImageId is null, try to use _uploadedImgId directly
        if (_uploadedImgId != null &&
            _uploadedImgId!.isNotEmpty &&
            _uploadedImgId!.contains("LOCAL_IMAGE_ID")) {
          requestJson['incidentImgId'] = _uploadedImgId!;
          Logger.debugLog(
            '📸 ✅ Using _uploadedImgId directly: $_uploadedImgId',
          );
        }
      }

      Logger.debugLog(
        '📸 After replacement - incidentImgId in JSON: ${requestJson['incidentImgId']}',
      );

      final requestList = [requestJson];

      // Save to pending requests for sync when online
      final url = '/api/v1/om-schedule/incidentTicket';
      final isSaved = await ServiceLocator().pendingRequestService
          .savePendingRequest(
            requestId: requestId,
            url: url,
            headers: {},
            jsonEncodedRequestData: jsonEncode(requestList),
          );

      // Close loader
      if (loaderOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loaderOpen = false;
      }

      if (isSaved && mounted) {
        Logger.infoLog('✅ Incident ticket data saved to offline storage');
        Toastbar.showSuccessToastbar(
          'Data saved offline. Will sync when online.',
          context,
        );

        // Navigate back
        navigateBackOrToHome(
          context,
          targetContext: widget.parentContext ?? context,
        );
      } else if (!isSaved) {
        throw Exception(
          'Failed to save incident ticket data to offline storage',
        );
      }
    } catch (e) {
      if (loaderOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        loaderOpen = false;
      }
      if (mounted) {
        Toastbar.showErrorToastbar(
          'Failed to save incident ticket offline: ${e.toString()}',
          context,
        );
      }
      Logger.errorLog('❌ Error saving incident ticket offline: $e');
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _incidentRemarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: "Incident Ticket",
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
                        children: [_buildFormFields()],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: CustomSubmitButtonV2(
                    text: "Next",
                    // Disable only in view mode, allow in edit mode even when status is CLOSE
                    onPressed: _submitForm,
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
        // Site Code (Read-only)
        CustomFormField(
          label: "Site Code",
          initialValue: widget.siteData.siteCode,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Site Name (Read-only)
        CustomFormField(
          label: "Site Name",
          initialValue: widget.siteData.siteName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Cluster/District (Read-only)
        CustomFormField(
          label: "District",
          initialValue: widget.siteData.clusterDistrictName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Circle/State (Read-only)
        CustomFormField(
          label: "Circle",
          initialValue: widget.siteData.circleStateName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Infra Engineer
        CustomFormField(
          label: "Infra Engineer Name",
          initialValue: widget.siteData.infraEngineerName ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Infra Engineer Contact No.
        CustomFormField(
          label: "Infra Engineer Contact No.",
          initialValue: widget.siteData.infraEngineerPhone ?? "N/A",
          isRequired: false,
          isEditable: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Cluster Incharge
        CustomFormField(
          label: "Cluster Incharge Name",
          initialValue: widget.siteData.clusterInchargeName ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Cluster Incharge Contact No.
        CustomFormField(
          label: "Cluster Incharge Contact No.",
          initialValue: widget.siteData.clusterInchargeContactNo ?? "N/A",
          isRequired: false,
          isEditable: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Incident Ticket Reason Dropdown
        CustomDropdown(
          label: "Incident Ticket Reason",
          items: _incidentTicketReasonOptions,
          initialValue: _selectedIncidentTicketReason,
          onChanged: (value) {
            if (!_hasFormDataChanges) {
              setState(() {
                _hasFormDataChanges = true;
              });
            }
            setState(() {
              _selectedIncidentTicketReason = value;
            });
          },
          // Only disable when view mode AND status is CLOSE
          isDisabled: _isViewMode && _selectedStatus == 'CLOSED',
          isRequired: true,
        ),
        const SizedBox(height: 15),

        // Incident Remarks Text Field
        CustomRemarksField(
          label: "Incident Remarks",
          hintText: "Enter incident remarks",
          controller: _incidentRemarksController,
          // Only disable when view mode AND status is CLOSE
          isDisabled: _isViewMode && _selectedStatus == 'CLOSED',
        ),
        const SizedBox(height: 15),

        // Current Site Status Dropdown
        CustomDropdown(
          label: "Current Site Status",
          items: _currentSiteStatusOptions,
          initialValue: _selectedCurrentSiteStatus,
          onChanged: (value) {
            if (!_hasFormDataChanges) {
              setState(() {
                _hasFormDataChanges = true;
              });
            }
            setState(() {
              _selectedCurrentSiteStatus = value;
            });
          },
          // Only disable when view mode AND status is CLOSE
          isDisabled: _isViewMode && _selectedStatus == 'CLOSED',
          isRequired: true,
        ),
        const SizedBox(height: 15),

        // Remarks Text Field
        CustomRemarksField(
          label: "Remarks",
          hintText: "Enter remarks",
          controller: _remarksController,
          // Only disable when view mode AND status is CLOSE
          isDisabled: _isViewMode && _selectedStatus == 'CLOSED',
        ),
        const SizedBox(height: 15),

        // Add a Photo Section
        Builder(
          builder: (context) {
            return ImageUploadField(
              label: "Add a Photo",
              placeholder: "Add a Photo",
              isRequired: true,
              externalImageUrl: _fetchedImageData,
              onImageSelected: (file) {
                if (file != null) {
                  Logger.debugLog("Selected image path: ${file.path}");
                  setState(() {
                    _selectedImage = file;
                    _hasFormDataChanges = true;
                  });
                  // Upload image to server
                  _uploadImage();
                } else {
                  setState(() {
                    _selectedImage = null;
                    _uploadedImgId = null;
                    _fetchedImageData = null;
                    _hasFormDataChanges = true;
                  });
                }
              },
              // Only disable when view mode AND status is CLOSE
              isDisabled: _isViewMode && _selectedStatus == 'CLOSED',
            );
          },
        ),
        const SizedBox(height: 15),

        // Status Dropdown
        CustomDropdown(
          label: "Status",
          items: _statusOptions,
          initialValue: _selectedStatus,
          onChanged: (value) {
            if (!_hasFormDataChanges) {
              setState(() {
                _hasFormDataChanges = true;
              });
            }
            setState(() {
              _selectedStatus = value;
            });
          },
          // Disable in create mode when status is OPEN, or when view mode AND status is CLOSE
          isDisabled:
              (widget.mode == CMScreenModeEnum.create &&
                  _selectedStatus == 'OPEN') ||
              (_isViewMode && _selectedStatus == 'CLOSED'),
          isRequired: true,
        ),
        const SizedBox(height: 15),

        // Closed Remarks (only show when status is CLOSE and mode is VIEW)
        if ((_selectedStatus == 'CLOSE' || _selectedStatus == 'CLOSED') && _isViewMode)
          CustomFormField(
            label: "Closed Remarks",
            initialValue: _closedRemarks ?? 'N/A',
            isRequired: false,
            isEditable: false, // Always read-only
          ),
        if ((_selectedStatus == 'CLOSE' || _selectedStatus == 'CLOSED') && _isViewMode)
          const SizedBox(height: 15),
      ],
    );
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges && !_isViewMode) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteData.siteId.toString(),
          section: "Incident Ticket",
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
