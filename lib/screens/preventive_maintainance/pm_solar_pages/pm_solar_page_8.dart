import 'dart:io';
import 'package:app/screens/preventive_maintainance/pm_solar_pages/pm_solar_page_9.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/bloc/pm_bloc/pm_cubit.dart';
import 'package:app/bloc/pm_bloc/pm_state.dart';

import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_dropdown.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';

import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/models/PmGetDataModel.dart';
import 'package:app/enum/pm_ticket_type_enum.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/constants/app_images.dart';
import 'package:intl/intl.dart';

import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../constants/constants_strings.dart';
import '../../../repositories/audit_schedule_repository.dart';
import '../../home_screen.dart';

class PmSolarPage8 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;
  final PmGetDataModel pmData;

  const PmSolarPage8({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
    required this.pmData,
  });

  @override
  State<PmSolarPage8> createState() => _PmSolarPage8State();
}

class _PmSolarPage8State extends State<PmSolarPage8> {
  final Map<String, dynamic> formData = {};
  final Map<String, TextEditingController> textControllers = {};
  final Map<String, TextEditingController> remarksControllers = {};
  final Map<String, String> loadedImageUrls = {};
  final Map<String, String> _imageRequestKeys = {};
  String? _lastRequestedPhotoId;
  final Map<String, int> _retryCounts = {};
  final List<Map<String, String>> _imageQueue = [];
  bool _fetchingImage = false;
  bool hasUnsavedChanges = false;
  bool isSubmitting = false;
  int _dummyState = 0;
  Map<String, int> photoIds = {};
  Map<String, String> photoTimestamps = {};
  String? _currentUploadKey;

  @override
  void initState() {
    super.initState();
    if (widget.pmData != null) {
      _loadExistingData(widget.pmData!);
    } else {
      context.read<PmCubit>().getPmData(
        siteType: widget.ticketType.name,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
      );
    }
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges = true;
      _dummyState++;
    });
  }

  void _saveFormData(String key, dynamic value) {
    print('Saving form data - Key: $key, Value: $value');
    setState(() {
      formData[key] = value;
      hasUnsavedChanges = true;
      _dummyState++;
    });
  }

  TextEditingController _getTextController(String key, String initialValue) {
    if (!textControllers.containsKey(key)) {
      textControllers[key] = TextEditingController(text: initialValue);
    } else {
      textControllers[key]!.text = initialValue;
    }
    return textControllers[key]!;
  }

  TextEditingController _getRemarksController(String key, String initialValue) {
    if (!remarksControllers.containsKey(key)) {
      remarksControllers[key] = TextEditingController(text: initialValue);
    } else {
      remarksControllers[key]!.text = initialValue;
    }
    return remarksControllers[key]!;
  }

  String _getPmTitle() {
    return 'PM Solar - Hygiene';
  }

  String _getSuccessMessage() {
    return 'Hygiene section data saved successfully!';
  }

  String _getCancelMessage() {
    return 'Hygiene section data cancelled!';
  }

  String _getActualSiteId() {
    try {
      final state = context.read<PmCubit>().state;
      if (state is PmGetLoaded &&
          state.pmGetDataModel.pageHeader != null &&
          state.pmGetDataModel.pageHeader!.isNotEmpty &&
          state.pmGetDataModel.pageHeader!.first.siteCode != null &&
          state.pmGetDataModel.pageHeader!.first.siteCode!.isNotEmpty) {
        return state.pmGetDataModel.pageHeader!.first.siteCode!;
      }
    } catch (e) {
      print("PM Screen - Error getting site ID from PM data: $e");
    }
    if (widget.siteId != null && widget.siteId!.isNotEmpty && widget.siteId != "N/A") {
      return widget.siteId!;
    }
    return "N/A";
  }

  Future<void> _submitForm() async {
    print('=== _submitForm called ===');
    print('formData.length: ${formData.length}');
    print('Total available fields: ${widget.pmData.responseData?.hygiene?.length ?? 0}');

    // Allow partial submissions - no field validation required
    // Users can submit any subset of fields they want to fill
    final hygieneData = widget.pmData.responseData?.hygiene ?? [];
    print('Total available fields: ${hygieneData.length}');
    print('Fields filled by user: ${formData.length}');
    
    if (formData.isEmpty) {
      print('formData is empty, skipping submission');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No data to submit')),
      );
      return;
    }

    print('Submitting partial data is OK - user filled ${formData.length} fields');

    final cubit = context.read<PmCubit>();
    final state = cubit.state;
    print('Current PmCubit state: $state');

    print('Submitting formData: $formData, photoIds: $photoIds, photoTimestamps: $photoTimestamps, remarks: ${_getRemarksData()}');
    setState(() {
      isSubmitting = true;
    });

    PmGetDataModel? pmDataToUse;
    if (state is PmGetLoaded) {
      pmDataToUse = state.pmGetDataModel;
      print('Using pmData from PmGetLoaded state');
    } else if (widget.pmData != null) {
      pmDataToUse = widget.pmData;
      print('Using pmData from widget');
    } else {
      print('No pmData available');
      setState(() {
        isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data not available, please reload')),
      );
      return;
    }

    try {
      print('=== Submitting to API ===');
      print('auditSchId: ${widget.auditSchId}');
      print('siteAuditSchId: ${widget.siteAuditSchId}');
      print('siteId: ${widget.siteId}');
      print('formData: $formData');
      print('photoIds: $photoIds');
      print('photoTimestamps: $photoTimestamps');
      print('remarksData: ${_getRemarksData()}');
      await cubit.postPmData(
        formData: formData,
        pmData: pmDataToUse!,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
        siteId: widget.siteId ?? '',
        photoIds: photoIds,
        photoTimestamps: photoTimestamps,
        remarksData: _getRemarksData(),
      );
      print('postPmData called successfully');
    } catch (e) {
      print('Error during submission: $e');
      setState(() {
        isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $e')),
      );
    }
  }

  Map<String, String> _getRemarksData() {
    Map<String, String> remarksData = {};
    remarksControllers.forEach((key, controller) {
      if (controller.text.isNotEmpty) {
        remarksData[key] = controller.text;
      }
    });
    return remarksData;
  }

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      print('Updating audit schedule status to: $status');
      await context.read<AuditScheduleStatusCubit>().updateStatus(
        status: status,
        siteAuditSchId: widget.siteAuditSchId,
      );
    } catch (e) {
      print('Error updating audit schedule status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update audit status: $e')),
      );
    }
  }

  void _saveAndExit() async {
    await _updateAuditScheduleStatus("In Progress");
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(),
      ),
    );
  }

  String _getButtonText() {
    return 'Performance Monitoring';
  }

  Future<void> _uploadPhoto(File? file, String key) async {
    if (file == null) return;
    _currentUploadKey = key;
    final photoCubit = context.read<AssetAuditPhotoUploadCubit>();
    await photoCubit.uploadPhoto(file: file, schId: widget.siteAuditSchId);
  }

  void _loadExistingData(PmGetDataModel data) {
    print('Loading existing data for Hygiene section');
    _retryCounts.clear();
    _imageQueue.clear();
    
    final hygieneData = data.responseData?.hygiene ?? [];
    for (var item in hygieneData) {
      final key = '${item.pmItemType ?? ''}_${item.clOrder ?? ''}';
      print('Processing item: $key, resp: ${item.resp}, remarks: ${item.remarks}');
      
      // Handle photo IDs
      if (item.photoId != null) {
        final photoIdInt = int.tryParse(item.photoId.toString());
        if (photoIdInt != null) {
          photoIds[key] = photoIdInt;
          _retryCounts[photoIdInt.toString()] = 0;
          _imageQueue.add({'photoId': photoIdInt.toString(), 'key': key});
        }
      }
      
      if (item.photoTakenTs != null) {
        photoTimestamps[key] = item.photoTakenTs!;
      }
      
      // Handle different response types
      if (item.resp is int) {
        // For dropdown/radio fields, convert int to string
        final respValue = item.resp.toString();
        formData[key] = respValue;
        print('Set formData[$key] = $respValue (from int)');
      } else if (item.resp is String) {
        formData[key] = item.resp;
        print('Set formData[$key] = ${item.resp} (from string)');
      }
      
      // Load remarks
      if (item.remarks != null && item.remarks!.isNotEmpty) {
        _getRemarksController(key, item.remarks!);
        print('Loaded remarks for $key: ${item.remarks}');
      }
      
    }
    
    // Start loading images
    _fetchNextImage();
  }

  void _fetchNextImage() {
    if (_fetchingImage || _imageQueue.isEmpty) return;
    
    _fetchingImage = true;
    final imageData = _imageQueue.removeAt(0);
    final photoId = imageData['photoId']!;
    final key = imageData['key']!;
    
    _lastRequestedPhotoId = photoId;
    _imageRequestKeys[photoId] = key;
    
    print('Fetching image for photoId: $photoId, key: $key');
    
    final imageCubit = context.read<AssetAuditGetImageCubit>();
    imageCubit.getImage(imgId: photoId, schId: widget.siteAuditSchId);
  }

  Future<void> _handleImageLoadRetry(String photoId, String key) async {
    final retryCount = _retryCounts[photoId] ?? 0;
    if (retryCount < 3) {
      _retryCounts[photoId] = retryCount + 1;
      print('Retrying image load for photoId: $photoId, attempt: ${retryCount + 1}');
      
      await Future.delayed(Duration(seconds: 2 * (retryCount + 1)));
      if (mounted) {
        final imageCubit = context.read<AssetAuditGetImageCubit>();
        imageCubit.getImage(imgId: photoId, schId: widget.siteAuditSchId);
      }
    } else {
      print('Max retries reached for photoId: $photoId');
      _fetchingImage = false;
      _fetchNextImage();
    }
  }

  bool _isFieldEditable(String key) {
    // Check if field should be editable based on dependencies
    return _checkHygieneDependencies(key);
  }

  bool _checkHygieneDependencies(String key) {
    // Enable remarks if dropdown value is "Corrected" or "Not OK - To be corrected"
    final dropdownValue = formData[key];
    if (dropdownValue == 'Corrected' || dropdownValue == 'Not OK - To be corrected') {
      return true;
    }
    return false;
  }


  @override
  void dispose() {
    // Dispose all text controllers
    for (var controller in textControllers.values) {
      controller.dispose();
    }
    for (var controller in remarksControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (hasUnsavedChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => UnsavedChangesDialog(
              message: 'You have unsaved changes. Do you want to discard them?',
              onSaveAndExit: () async {
                Navigator.of(context).pop();
                await _submitForm();
                Navigator.of(context).pop();
              },
              onDiscard: () => Navigator.of(context).pop(true),
            ),
          );
          
          if (shouldPop == true && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: CustomFormAppbar(
          title: _getPmTitle(),
          onClose: () async {
            if (hasUnsavedChanges) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => UnsavedChangesDialog(
                  message: _getCancelMessage(),
                  onSaveAndExit: () async {
                    Navigator.of(context).pop();
                    await _submitForm();
                    _saveAndExit();
                  },
                  onDiscard: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        body: MultiBlocListener(
          listeners: [
            BlocListener<PmCubit, PmState>(
              listener: (context, state) {
                if (state is PmGetLoading) {
                  // Handle loading state if needed
                } else if (state is PmGetLoaded) {
                  // Data loaded successfully
                } else if (state is PmGetError) {
                  // Handle error state
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message)),
                  );
                } else if (state is PmPosting) {
                  print('Form submission in progress...');
                  setState(() {
                    isSubmitting = true;
                  });
                } else if (state is PmPostSuccess) {
                  setState(() {
                    isSubmitting = false;
                    hasUnsavedChanges = false;
                    _retryCounts.clear();
                  });
                  
                  // Clear all controllers
                  for (var controller in textControllers.values) {
                    controller.clear();
                  }
                  for (var controller in remarksControllers.values) {
                    controller.clear();
                  }
                  
                  // Don't call _saveAndExit() here - let the Next button handle navigation
                } else if (state is PmPostError) {
                  setState(() {
                    isSubmitting = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message)),
                  );
                }
              },
            ),
            BlocListener<AssetAuditPhotoUploadCubit, AssetAuditPhotoUploadState>(
              listener: (context, state) {
                if (state is AssetAuditPhotoUploadSuccess) {
                  if (_currentUploadKey != null) {
                    final photoId = int.tryParse(state.response.imgId) ?? 0;
                    final timestamp = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
                    setState(() {
                      photoIds[_currentUploadKey!] = photoId;
                      photoTimestamps[_currentUploadKey!] = timestamp;
                      _currentUploadKey = null;
                      _dummyState = DateTime.now().millisecondsSinceEpoch;
                    });
                  }
                } else if (state is AssetAuditPhotoUploadFailure) {
                  print('Photo upload failed: ${state.errorMessage}');
                }
              },
            ),
            BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
              listener: (context, state) async {
                if (state is AssetAuditGetImageSuccess) {
                  final photoId = _lastRequestedPhotoId;
                  if (photoId != null && _imageRequestKeys.containsKey(photoId)) {
                    final key = _imageRequestKeys[photoId]!;
                    setState(() {
                      loadedImageUrls[key] = state.imageData;
                    });
                    print('Image loaded successfully for key: $key');
                  }
                } else if (state is AssetAuditGetImageFailure) {
                  final photoId = _lastRequestedPhotoId;
                  if (photoId != null && _imageRequestKeys.containsKey(photoId)) {
                    final key = _imageRequestKeys[photoId]!;
                    print('Image load error for photoId: $photoId - ${state.errorMessage}');
                    await _handleImageLoadRetry(photoId, key);
                  }
                }
                _fetchingImage = false;
                _fetchNextImage();
              },
            ),
          ],
          child: widget.pmData != null 
            ? _buildContent(widget.pmData!)
            : BlocBuilder<PmCubit, PmState>(
                builder: (context, state) {
                  if (state is PmGetLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is PmGetLoaded) {
                    return _buildContent(state.pmGetDataModel);
                  } else if (state is PmGetError) {
                    return Center(child: Text(state.message));
                  }
                  return const Center(child: Text('No data available'));
                },
              ),
        ),
      ),
    );
  }

  Widget _buildContent(PmGetDataModel data) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Background image - full screen coverage
          Positioned.fill(
            child: SvgPicture.asset(
              AppImages.home,
              fit: BoxFit.cover,
            ),
          ),
          // Content overlay
          SafeArea(
            child: Column(
              children: [
                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHygieneSection(data),
                        getHeight(30),
                        // Add bottom padding to account for fixed buttons
                        getHeight(100),
                      ],
                    ),
                  ),
                ),
                // Fixed navigation buttons at bottom
                Container(
                  padding: const EdgeInsets.all(16),
                  child: _buildNavigationButtons(),
                ),
              ],
            ),
          ),
          // Loading overlay
          if (isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHygieneSection(PmGetDataModel data) {
    final hygieneData = data.responseData?.hygiene ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: hygieneData.map((item) {
        return Column(
          children: [
            _buildFormField(
              item.checklistDesc ?? '',
              'DROPDOWN,IMG',
              item,
            ),
            getHeight(15),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFormField(String label, String respType, dynamic item) {
    // Build the proper key format: pmItemType_clOrder
    final key = '${item.pmItemType}_${item.clOrder}';
    final currentValue = formData[key] ?? '';
    final photoIds = <String, int?>{};
    
    // Extract photo ID if available
    if (item.photoId != null) {
      photoIds[key] = item.photoId;
    }

    if (respType.contains('DROPDOWN') && respType.contains('IMG')) {
      // Both dropdown and image upload needed
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          getHeight(8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green7,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomDropdown(
                  label: 'Status',
                  items: ['OK', 'Corrected', 'Not OK - To be corrected', 'Not Applicable'],
                  initialValue: currentValue.isNotEmpty ? currentValue : null,
                  onChanged: (value) {
                    _saveFormData(key, value);
                    _onFormChanged();
                  },
                  isRequired: true,
                ),
                getHeight(15),
                ImageUploadField(
                  label: "Add Photo",
                  externalImageUrl: loadedImageUrls[key],
                  onImageSelected: (file) async {
                    if (file != null) {
                      await _uploadPhoto(file, key);
                    }
                  },
                ),
                getHeight(15),
                // Remarks field - always show for hygiene items
                CustomFormField(
                  label: 'Remarks',
                  hintText: 'Enter remarks',
                  controller: _getRemarksController(key, currentValue),
                  onChanged: (value) => _onFormChanged(),
                ),
              ],
            ),
          ),
          getHeight(15),
        ],
      );
    } else if (respType.contains('DROPDOWN')) {
      final options = ['OK', 'Corrected', 'Not OK - To be corrected', 'Not Applicable'];
      return CustomDropdown(
        label: 'Status',
        items: options,
        initialValue: currentValue.isNotEmpty ? currentValue : null,
        onChanged: (value) {
          _saveFormData(key, value);
          _onFormChanged();
        },
        isRequired: true,
      );
    } else if (respType.contains('IMG')) {
      return ImageUploadField(
        label: label,
        externalImageUrl: loadedImageUrls[key],
        onImageSelected: (file) async {
          if (file != null) {
            await _uploadPhoto(file, key);
          }
        },
      );
    } else if (respType.contains('TEXT')) {
      return CustomFormField(
        label: label,
        hintText: 'Enter remarks',
        controller: _getTextController(key, currentValue),
        onChanged: (value) => _onFormChanged(),
      );
    } else if (respType.contains('RADIO')) {
      return CustomOptionSelector(
        label: label,
        options: [
          OptionItem(
            value: "yes",
            label: "OK",
            selectedIcon: Icons.circle_outlined,
            unselectedIcon: Icons.circle_outlined,
          ),
          OptionItem(
            value: "no",
            label: "Not OK",
            selectedIcon: Icons.circle_outlined,
            unselectedIcon: Icons.circle_outlined,
          ),
        ],
        initialValue: currentValue,
        onChanged: (value) {
          _saveFormData(key, value);
          _onFormChanged();
        },
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ArrowButton(
            text: 'Back',
            isLeftArrow: true,
            backgroundColor: AppColors.buttonColorBackBg,
            textColor: AppColors.buttonColorTextBg,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        getWidth(10),
        Expanded(
          child: ArrowButton(
            text: _getButtonText(),
            isLeftArrow: false,
            backgroundColor: AppColors.buttonColorBg,
            textColor: AppColors.buttonColorSite,
            onPressed: isSubmitting
                ? null
                : () async {
                  print('=== Performance Monitoring button pressed ===');
                  print('formData before submit: $formData');
                  print('hasUnsavedChanges: $hasUnsavedChanges');
                  
                  // Clear unsaved changes flag to prevent PopScope from showing dialog
                  setState(() {
                    hasUnsavedChanges = false;
                  });
                  
                  if (formData.isNotEmpty) {
                    await _submitForm();
                    final state = context.read<PmCubit>().state;
                    if (state is PmPostSuccess) {
                      print('Submission successful, navigating to PmSolarPage9');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PmSolarPage9(
                            ticketType: widget.ticketType,
                            auditSchId: widget.auditSchId,
                            siteAuditSchId: widget.siteAuditSchId,
                            siteId: widget.siteId,
                            pmData: widget.pmData,
                          ),
                        ),
                      );
                    } else {
                      print('Submission failed, staying on page');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please complete the form submission before proceeding')),
                      );
                    }
                  } else {
                    print('No data to submit, navigating to PmSolarPage9');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PmSolarPage9(
                          ticketType: widget.ticketType,
                          auditSchId: widget.auditSchId,
                          siteAuditSchId: widget.siteAuditSchId,
                          siteId: widget.siteId,
                          pmData: widget.pmData,
                        ),
                      ),
                    );
                  }
                },
          ),
        ),
      ],
    );
  }

}
