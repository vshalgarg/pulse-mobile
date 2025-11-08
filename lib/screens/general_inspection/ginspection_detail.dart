import 'dart:convert';
import 'dart:io';

import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_submit_button_v2.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/models/gen_ins_checklist_model.dart';
import 'package:app/repositories/general_inspection_repository.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'gi_checklist_screen.dart';

class GInspectionDetailScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final CMScreenModeEnum mode;
  final Map<String, dynamic>? apiResponseData; // Add API response data
  final BuildContext? parentContext;

  const GInspectionDetailScreen({
    super.key,
    required this.siteData,
    required this.mode,
    this.apiResponseData,
    this.parentContext,
  });

  @override
  State<GInspectionDetailScreen> createState() =>
      _GInspectionDetailScreenState();
}

class _GInspectionDetailScreenState extends State<GInspectionDetailScreen> {
  final TextEditingController _infraEngineerController =
      TextEditingController();
  final TextEditingController _infraEngineerContactController =
      TextEditingController();
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _ownerContactController = TextEditingController();

  String? _uploadedImgId;
  String? _fetchedImageData;
  File? _selectedImage;
  bool _hasFormDataChanges = false;

  // Checklist data
  bool _isLoadingChecklist = true;
  String? _checklistError;
  List<GenInsCheckListData> _checklistItems = [];
  Map<int, Map<String, dynamic>> _existingChecklistResponses = {}; // Store existing responses for edit mode
  late GeneralInspectionRepository _repository;

  @override
  void initState() {
    super.initState();

    print("🔍 general isnpection data: ${widget.siteData.toJson()}");

    _repository = GeneralInspectionRepository(ServiceLocator().apiService);
    _initializeFormData(); // Initialize form fields with existing data
    _loadChecklistData();
    
    // Add listeners to track form changes
    _infraEngineerController.addListener(() {
      if (!_hasFormDataChanges) {
        print("🔍 Infra Engineer changed - setting _hasFormDataChanges to true");
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
    
    _infraEngineerContactController.addListener(() {
      if (!_hasFormDataChanges) {
        print("🔍 Infra Engineer Contact changed - setting _hasFormDataChanges to true");
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
    
    _ownerController.addListener(() {
      if (!_hasFormDataChanges) {
        print("🔍 Owner changed - setting _hasFormDataChanges to true");
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
    
    _ownerContactController.addListener(() {
      if (!_hasFormDataChanges) {
        print("🔍 Owner Contact changed - setting _hasFormDataChanges to true");
        setState(() {
          _hasFormDataChanges = true;
        });
      }
    });
  }

  void _populateExistingResponses() {
    if (widget.mode == CMScreenModeEnum.edit && widget.apiResponseData != null) {
      final genInspectionSiteRespList = widget.apiResponseData!['genInspectionSiteRespList'] as List<dynamic>?;
      if (genInspectionSiteRespList != null) {
        for (final response in genInspectionSiteRespList) {
          final giclmId = response['giclmId'] as int?;
          if (giclmId != null) {
            // Find the corresponding checklist item to determine response type
            GenInsCheckListData? checklistItem;
            try {
              checklistItem = _checklistItems.firstWhere(
                (item) => item.giclmId == giclmId,
              );
            } catch (e) {
              print('🔍 Warning: No checklist item found for giclmId: $giclmId');
              // Skip this response if no matching checklist item is found
              continue;
            }
            
            if (checklistItem != null) {
              Map<String, dynamic> responseData = {
                'image_id': response['respPhotoId']?.toString(),
                'giId': widget.apiResponseData!['giId']?.toString(), // Include giId
                'gispId': response['gispId'] as int?, // Include gispId for edit mode
              };
              
              // Set the appropriate response value based on the checklist item type
              if (checklistItem.respType.contains('RADIO')) {
                // Map the resp value using respTypeValueMap to get the correct display value
                final respValue = response['resp'] as String?;
                if (respValue != null && respValue.isNotEmpty && checklistItem.respTypeValueMap != null) {
                  try {
                    final Map<String, dynamic> decodedMap = json.decode(checklistItem.respTypeValueMap!.value);
                    String? displayValue;
                    decodedMap.forEach((key, value) {
                      if (value.toString().toLowerCase() == respValue.toLowerCase()) {
                        displayValue = value.toString();
                      }
                    });
                    responseData['radio_value'] = displayValue ?? respValue;
                  } catch (e) {
                    print('🔍 Error decoding respTypeValueMap: $e');
                    responseData['radio_value'] = respValue;
                  }
                } else {
                  responseData['radio_value'] = respValue;
                }
              } else if (checklistItem.respType.contains('TEXT')) {
                responseData['text_value'] = response['resp'] as String?;
              }
              
              _existingChecklistResponses[giclmId] = responseData;
            }
          }
        }
        print('🔍 Populated existing responses: $_existingChecklistResponses');
      }
    }
  }

  void _initializeFormData() {
    // Debug: Print the entire API response data structure
    print("🔍 Full API Response Data: ${widget.apiResponseData}");
    
    // Initialize form fields with API response data if available, otherwise use site data
    if (widget.apiResponseData != null) {
      print("🔍 Initializing form data from API response");
      
      // Debug: Print individual field values
      print("🔍 infraDistrictEngineerName: ${widget.apiResponseData!['infraDistrictEngineerName']}");
      print("🔍 infraDistrictEngineerContactNo: ${widget.apiResponseData!['infraDistrictEngineerContactNo']}");
      print("🔍 ownerName: ${widget.apiResponseData!['ownerName']}");
      print("🔍 ownerContactNo: ${widget.apiResponseData!['ownerContactNo']}");
      
      _infraEngineerController.text = widget.apiResponseData!['infraDistrictEngineerName']?.toString() ?? "";
      _infraEngineerContactController.text = widget.apiResponseData!['infraDistrictEngineerContactNo']?.toString() ?? "";
      _ownerController.text = widget.apiResponseData!['ownerName']?.toString() ?? "";
      _ownerContactController.text = widget.apiResponseData!['ownerContactNo']?.toString() ?? "";
      
      // Handle existing image from API response
      final visitingPersonImageId = widget.apiResponseData!['visitingPersonImageId']?.toString();
      print("🔍 visitingPersonImageId from API: $visitingPersonImageId");
      
      if (visitingPersonImageId != null && visitingPersonImageId.isNotEmpty) {
        _uploadedImgId = visitingPersonImageId;
        print("🔍 Loading image with ID: $visitingPersonImageId");
        _loadImage(visitingPersonImageId);
      } else {
        print("🔍 No visitingPersonImageId found in API response");
        _uploadedImgId = null;
      }
    } else {
      print("🔍 No API response data, using site data");
      // Fallback to site data
      _infraEngineerController.text = widget.siteData.infraEngineerName ?? "";
      _infraEngineerContactController.text = widget.siteData.infraEngineerPhone ?? "";
      _ownerController.text = widget.siteData.ownerName ?? "";
      _ownerContactController.text = widget.siteData.ownerPhone ?? "";
      
      // Handle existing image from site data
      if (widget.siteData.visitingPersonImageId != null &&
          widget.siteData.visitingPersonImageId!.isNotEmpty) {
        _uploadedImgId = widget.siteData.visitingPersonImageId;
        print("🔍 Loading image with ID from site data: ${widget.siteData.visitingPersonImageId}");
        _loadImage(widget.siteData.visitingPersonImageId!);
      } else {
        print("🔍 No visitingPersonImageId found in site data");
        _uploadedImgId = null;
      }
    }
  }

  Future<void> _submitForm() async {
    // Validate selfie - check if we have an uploaded image ID
    if (_uploadedImgId == null || _uploadedImgId!.isEmpty) {
      showCustomToast(context, "Please add a selfie");
      return;
    }

    // Check if checklist is still loading
    if (_isLoadingChecklist) {
      showCustomToast(context, "Please wait while checklist is loading");
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

    // Check if we have checklist items
    if (_checklistItems.isEmpty) {
      showCustomToast(context, "No checklist data available. Please try downloading the data first.");
      return;
    }

    // Extract giId from API response data if available
    int? giId;
    if (widget.apiResponseData != null) {
      giId = widget.apiResponseData!['giId'] as int?;
      print('🔍 Extracted giId from API response: $giId');
    }

    // Debug: Print visiting person image ID before navigation
    print('🔍 Passing visitingPersonImageId to checklist screen: $_uploadedImgId');

    try {
      // Navigate to checklist screen with pre-loaded data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GIChecklistScreen(
            siteData: widget.siteData,
            mode: widget.mode,
            visitingPersonImageId: _uploadedImgId,
            checklistItems: _checklistItems,
            existingResponses: _existingChecklistResponses.isNotEmpty ? _existingChecklistResponses : null,
            giId: giId,
            parentContext: widget.parentContext ?? context,
          ),
        ),
      );
    } catch (e) {
      Logger.errorLog('❌ Error in submit process: $e');
      rethrow; // Re-throw so UnsavedChangesDialog can handle the error
    }
  }

  Future<void> _loadImage(String imageId) async {
    try {
      print("🔍 _loadImage called with imageId: $imageId");

      String? uniqueId;
      
      // Check if this is already a unique ID (offline mode) or a server ID (online mode)
      if (imageId.contains("LOCAL_IMAGE_ID")) {
        // This is already a unique ID from offline mode
        print("🔍 Detected unique ID (offline mode): $imageId");
        uniqueId = imageId;
      } else {
        // This is a server ID, try to download from server (online mode)
        print("🔍 Detected server ID (online mode): $imageId");
        uniqueId = await ServiceLocator().imageUploadService
            .downloadImageUsingServerId(
              imageId,
              ActivityTypeEnum.generalInspection,
              widget.siteData.siteId.toString(),
            );
        print("🔍 Download result - uniqueId: $uniqueId");
      }

      if (uniqueId != null) {
        // Now get the image data using the unique ID
        final imageData = await ServiceLocator().centralAssetAuditService.getImageAsDataUrl(uniqueId);

        print("🔍 Image loading result: ${imageData != null ? 'SUCCESS' : 'FAILED'}");

        if (imageData != null) {
          Logger.debugLog('✅ Image data received: ${imageData.length} characters');
          setState(() {
            _fetchedImageData = imageData;
          });
          Logger.debugLog('✅ Image loaded successfully and state updated');
        } else {
          Logger.errorLog('❌ Failed to load image data with uniqueId $uniqueId - imageData is null');
        }
      } else {
        Logger.errorLog('❌ Failed to get unique ID for image: $imageId');
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading image: $e');
    }
  }

  @override
  void dispose() {
    _infraEngineerController.dispose();
    _infraEngineerContactController.dispose();
    _ownerController.dispose();
    _ownerContactController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: "General Inspection",
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

  Widget _buildFormFields() {
    return Column(
      children: [
        // Circle/State
        CustomFormField(
          label: "Circle/State",
          initialValue: widget.siteData.circleStateName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Cluster/District
        CustomFormField(
          label: "Cluster/District",
          initialValue: widget.siteData.clusterDistrictName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Site Code
        CustomFormField(
          label: "Site Code",
          initialValue: widget.siteData.siteCode,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Site Name
        CustomFormField(
          label: "Site Name",
          initialValue: widget.siteData.siteName,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Customer
        CustomFormField(
          label: "Customer",
          initialValue: widget.siteData.clientName ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Infra Engineer
        CustomFormField(
          label: "Infra Engineer",
          controller: _infraEngineerController,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Infra Engineer Contact No.
        CustomFormField(
          label: "Infra Engineer Contact No.",
          controller: _infraEngineerContactController,
          isRequired: false,
          isEditable: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 15),

        // Owner
        CustomFormField(
          label: "Owner",
          controller: _ownerController,
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),

        // Owner Contact No.
        CustomFormField(
          label: "Owner Contact No.",
          controller: _ownerContactController,
          isRequired: false,
          isEditable: false,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),

        Builder(
          builder: (context) {
            print("🔍 Building ImageUploadField - _fetchedImageData: ${_fetchedImageData != null ? 'HAS_DATA' : 'NULL'}");
            return ImageUploadField(
              label: "Add a Selfie",
              placeholder: "Selfie",
              isRequired: true,
              externalImageUrl: _fetchedImageData,
              onImageSelected: (file) {
                if (file != null) {
                  debugPrint("Selected image path: ${file.path}");
                  setState(() {
                    _selectedImage = file;
                    _hasFormDataChanges = true;
                  });
                  // Upload selfie to server
                  _uploadSelfie();
                } else {
                  setState(() {
                    _selectedImage = null;
                    _uploadedImgId = null;
                    _fetchedImageData = null;
                    _hasFormDataChanges = true;
                  });
                }
              },
            );
          },
        ),
        getHeight(15),
      ],
    );
  }

  Future<void> _uploadSelfie() async {
    try {
      if (_selectedImage == null) {
        Toastbar.showErrorToastbar('Please select an image first', context);
        return;
      }

      // Internet connected - upload to server
      final imgId = await ServiceLocator().centralAssetAuditService.uploadImage(
        siteAuditSchId: widget.siteData.siteId.toString(),
        imageFile: _selectedImage!,
        isSelfie: false,
        activityType: ActivityTypeEnum.generalInspection,
      );

      print("imgId: after upload $imgId");

      // Update the database with the new image ID
      final dbData = await ServiceLocator().centralAssetAuditService
          .getActualDataFromSqlite(
            siteAuditSchId: widget.siteData.siteId.toString(),
          );
      if (dbData != null) {
        final pageHeaders = dbData['pageHeader'] as List<dynamic>?;
        final pageHeader = pageHeaders?.isNotEmpty == true
            ? pageHeaders!.first as Map<String, dynamic>
            : null;
        if (pageHeader != null) {
          pageHeader['maker_selfie_image_id'] = imgId;

          // Save the updated data back to the database
          await ServiceLocator().centralAssetAuditService.updateDataInSqlite(
            siteAuditSchId: widget.siteData.siteId.toString(),
            updatedData: dbData,
          );
        }
      }

      if (imgId != null && imgId.isNotEmpty) {
        setState(() {
          _uploadedImgId = imgId;
          print('uploadedImgId: $_uploadedImgId, $imgId');
        });

        // Show appropriate message based on whether it's server or local ID
        if (imgId.contains("LOCAL_IMAGE_ID")) {
          showCustomToast(context, 'Selfie saved locally (offline mode)');
        } else {
          showCustomToast(context, 'Selfie uploaded successfully');
        }
      } else {
        showCustomToast(context, 'Failed to upload selfie');
        throw Exception('Failed to get image ID');
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading selfie: $e');
    }
  }

  Future<void> _loadChecklistData() async {
    try {
      setState(() {
        _isLoadingChecklist = true;
        _checklistError = null;
      });

      Logger.debugLog('Loading checklist data for site ID: ${widget.siteData.siteId}');
      
      // First, try to get checklist data from local database
      try {
        final localChecklistData = await ServiceLocator().centralAssetAuditDataService
            .getGIChecklistData(widget.siteData.siteId);
        
        if (localChecklistData.isNotEmpty) {
          // Use local data if available
          Logger.debugLog('Using local checklist data: ${localChecklistData.length} items');
          setState(() {
            _checklistItems = localChecklistData;
            _isLoadingChecklist = false;
          });
          _populateExistingResponses(); // Populate existing responses after checklist data is loaded
          return;
        } else {
          Logger.debugLog('No local checklist data found for site ID: ${widget.siteData.siteId}');
        }
      } catch (localError) {
        Logger.debugLog('Local data retrieval failed: $localError');
      }
      
      // If no local data, try to fetch from API
      Logger.debugLog('No local data found, fetching from API...');
      try {
        final siteDomainId = 1; // Default site domain ID
        final checklistItems = await _repository.getGenInsCheckListData(siteDomainId);
        
        // Sort by cl_order
        checklistItems.sort((a, b) => a.clOrder.compareTo(b.clOrder));
        
        setState(() {
          _checklistItems = checklistItems;
          _isLoadingChecklist = false;
        });
        
        Logger.debugLog('Loaded ${checklistItems.length} checklist items from API');
        _populateExistingResponses(); // Populate existing responses after checklist data is loaded
      } catch (apiError) {
        Logger.errorLog('API call failed: $apiError');
        
        // If API failed, try to get any available local data as fallback
        try {
          final fallbackData = await ServiceLocator().centralAssetAuditDataService
              .getGIChecklistData(widget.siteData.siteId);
          
          if (fallbackData.isNotEmpty) {
            Logger.debugLog('Using fallback local data: ${fallbackData.length} items');
            setState(() {
              _checklistItems = fallbackData;
              _isLoadingChecklist = false;
              _checklistError = null; // Clear error since we have local data
            });
            _populateExistingResponses(); // Populate existing responses after checklist data is loaded
            return;
          }
        } catch (fallbackError) {
          Logger.errorLog('Fallback local data also failed: $fallbackError');
        }
        
        // If both API and local data failed, show error
        setState(() {
          _isLoadingChecklist = false;
          _checklistError = 'Failed to load checklist data. Please check your internet connection and try downloading the data first.';
        });
      }
    } catch (e) {
      Logger.errorLog('Unexpected error loading checklist data: $e');
      setState(() {
        _isLoadingChecklist = false;
        _checklistError = 'Unexpected error: ${e.toString()}';
      });
    }
  }

  void _showUnsavedChangesDialog() {
    print("🔍 _showUnsavedChangesDialog called - _hasFormDataChanges: $_hasFormDataChanges");
    if (_hasFormDataChanges) {
      print("🔍 Showing unsaved changes dialog");
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteData.siteId.toString(),
          section: "General Inspection",
          parentContext: widget.parentContext ?? context,
          onSaveAndExit: () async {
            await _submitForm();
          },
          onDiscard: () {},
        ),
      );
    } else {
      print("🔍 No form changes detected - navigating back directly");
      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext ?? context,
      );
    }
  }

}
