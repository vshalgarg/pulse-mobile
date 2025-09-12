import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/models/PmGetDataModel.dart';
import 'package:app/screens/preventive_maintainance/pm_pages/pm_page_3.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:io';
import 'package:intl/intl.dart';

import '../../../bloc/pm_bloc/pm_cubit.dart';
import '../../../bloc/pm_bloc/pm_state.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_dropdown.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../constants/constants_strings.dart';
import '../../../enum/pm_ticket_type_enum.dart';
import '../../home_screen.dart';

class PmScreen2 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;
  final PmGetDataModel? pmData;

  const PmScreen2({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
    this.pmData,
  });

  @override
  State<PmScreen2> createState() => _PmScreen2();
}



class _PmScreen2 extends State<PmScreen2> {
  bool hasUnsavedChanges = false;
  Map<String, dynamic> formData = {};
  Map<String, int> photoIds = {};
  Map<String, String> photoTimestamps = {};
  Map<String, String> loadedImageUrls = {};
  Map<String, TextEditingController> textControllers = {};
  Map<String, TextEditingController> remarksControllers = {};
  String? _currentUploadKey;
  Map<String, String> _imageRequestKeys = {}; // Track which key corresponds to which photo_id request
  String? _lastRequestedPhotoId; // Track the last requested photo ID
  Map<String, int> _retryCounts = {}; // Track retry attempts for each photo ID
  int _dummyState = 0; // For forcing UI rebuilds

  @override
  void initState() {
    super.initState();
    if (widget.pmData != null && formData.isEmpty) {
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
      hasUnsavedChanges = formData.isNotEmpty;
      _dummyState = DateTime.now().millisecondsSinceEpoch;
    });
  }

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      print('=== _updateAuditScheduleStatus called ===');
      print('Status: $status');
      print('siteAuditSchId: ${widget.siteAuditSchId}');
      
      await context.read<AuditScheduleStatusCubit>().updateStatus(
        status: status,
        siteAuditSchId: widget.siteAuditSchId,
      );
      
      print('Status update API call completed');
    } catch (e) {
      print('Error updating audit schedule status: $e');
      rethrow; // Re-throw to let the caller handle the error
    }
  }

  Future<void> _saveAndExit() async {
    print('=== _saveAndExit called ===');
    print('siteAuditSchId: ${widget.siteAuditSchId}');
    print('formData: $formData');
    print('hasUnsavedChanges: $hasUnsavedChanges');
    
    try {
      await _updateAuditScheduleStatus("In Progress");
      print('Status update completed');
      
      if (mounted) {
        print('Navigating to HomeScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(),
          ),
        );
      } else {
        print('Widget not mounted, cannot navigate');
      }
    } catch (e) {
      print('Error in _saveAndExit: $e');
    }
  }

  void _saveFormData(String key, dynamic value) {
    setState(() {
      formData[key] = value;
      _onFormChanged();
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
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "PM Telecom - CT";
      case PmTicketTypeEnum.solar:
        return "PM Solar - CT";
    }
  }

  String _getButtonText() {
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "Earthing";
      case PmTicketTypeEnum.solar:
        return "Earthing";
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

  String _getCancelMessage() {
    final siteId = _getActualSiteId();
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "Do you want to cancel the CT section for Telecom Site (ID: $siteId) ?";
      case PmTicketTypeEnum.solar:
        return "Do you want to cancel the CT section for Solar Site (ID: $siteId) ?";
    }
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
    return widget.siteId ?? 'Unknown';
  }

  /// Check if a field is a mobile number field
  bool _isMobileNumberField(String checklistDesc) {
    final mobileKeywords = [
      'mobile',
      'phone',
      'contact',
      'number',
      'telephone',
      'cell',
      'whatsapp'
    ];
    
    final desc = checklistDesc.toLowerCase();
    return mobileKeywords.any((keyword) => desc.contains(keyword));
  }

  /// Validate mobile number format
  String? _validateMobileNumber(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty values, let required validation handle it
    }
    
    // Remove any non-digit characters
    final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid Indian mobile number (10 digits starting with 6-9)
    if (cleanValue.length == 10) {
      final firstDigit = int.tryParse(cleanValue[0]);
      if (firstDigit != null && firstDigit >= 6 && firstDigit <= 9) {
        return null; // Valid mobile number
      }
    }
    
    // Check if it's a valid mobile number with country code (11 digits starting with 91)
    if (cleanValue.length == 11 && cleanValue.startsWith('91')) {
      final thirdDigit = int.tryParse(cleanValue[2]);
      if (thirdDigit != null && thirdDigit >= 6 && thirdDigit <= 9) {
        return null; // Valid mobile number with country code
      }
    }
    
    return 'Please enter a valid 10-digit mobile number';
  }

  /// Get input formatters for mobile number fields
  List<TextInputFormatter> _getMobileNumberFormatters() {
    return [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(10), // Limit to 10 digits
    ];
  }

  Future<void> _uploadPhoto(File? file, String key) async {
    if (file == null) return;
    _currentUploadKey = key;
    final photoCubit = context.read<AssetAuditPhotoUploadCubit>();
    await photoCubit.uploadPhoto(file: file, schId: widget.siteAuditSchId);
  }


  void _loadExistingData(PmGetDataModel data) {
    print('=== _loadExistingData called ===');
    print('Loading existing data for PM Page 2');
    setState(() {
      formData.clear();
      photoIds.clear();
      photoTimestamps.clear();
      loadedImageUrls.clear();
      _retryCounts.clear();

      final ctData = data.responseData?.ct ?? [];
      print('CT data count: ${ctData.length}');
      print('Raw CT data: $ctData');

      for (final item in ctData) {
        final key = '${item.pmItemType}_${item.clOrder}';
        print('Processing item: $key, resp: ${item.resp} (type: ${item.resp.runtimeType}), photoId: ${item.photoId} (type: ${item.photoId.runtimeType}), respType: ${item.respType}');

        if (item.resp != null) {
          String mappedValue;
          if (item.resp is int) {
            print('Warning: resp is int (${item.resp}), converting to String');
            final respValue = item.resp.toString();
            if (item.respType?.contains('DROPDOWN') ?? false) {
              const dropdownOptions = [
                'OK',
                'Corrected',
                'Not OK - To be corrected',
                'Not Applicable',
              ];
              try {
                mappedValue = dropdownOptions[int.parse(respValue)];
              } catch (e) {
                mappedValue = respValue;
                print('Failed to map resp to dropdown option: $respValue');
              }
            } else if (item.respType?.contains('RADIO') ?? false) {
              mappedValue = respValue == '1' ? 'yes' : 'no';
            } else {
              mappedValue = respValue;
            }
          } else {
            mappedValue = item.resp.toString();
          }
          formData[key] = mappedValue;
          print('Added to formData: $key = $mappedValue');
        }

        if (item.photoId != null) {
          final photoIdInt = int.tryParse(item.photoId.toString()); // Convert to String first
          if (photoIdInt != null) {
            photoIds[key] = photoIdInt;
            _retryCounts[photoIdInt.toString()] = 0; // Initialize retry count
            print('Added to photoIds: $key = $photoIdInt');
            print('Calling _loadImageForPhotoId for key: $key, photoId: $photoIdInt');
            _loadImageForPhotoId(photoIdInt.toString(), key); // Pass as String
          } else {
            print('Invalid photoId format: ${item.photoId}');
          }
        } else {
          print('No photoId for key: $key');
        }

        if (item.photoTakenTs != null) {
          photoTimestamps[key] = item.photoTakenTs!;
          print('Added to photoTimestamps: $key = ${item.photoTakenTs}');
        }
      }

      print('Final formData: $formData');
      print('Final photoIds: $photoIds');
      print('Final photoTimestamps: $photoTimestamps');
      print('Final loadedImageUrls: $loadedImageUrls');
      _dummyState = DateTime.now().millisecondsSinceEpoch;
    });

    // Fallback: Re-fetch images for any missing loadedImageUrls after a delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        print('=== Fallback image loading check ===');
        print('photoIds: $photoIds');
        print('loadedImageUrls: $loadedImageUrls');
        for (final key in photoIds.keys) {
          if (!loadedImageUrls.containsKey(key) && photoIds[key] != null) {
            print('Fallback: Re-fetching image for key: $key, photoId: ${photoIds[key]}');
            _loadImageForPhotoId(photoIds[key]!.toString(), key);
          }
        }
      }
    });
  }

  void _loadImageForPhotoId(String photoId, String key) {
    if (!mounted) return;
    
    print('Loading image for photoId: $photoId, key: $key, retry count: ${_retryCounts[photoId] ?? 0}');
    _imageRequestKeys[photoId] = key; // Store the mapping between photoId and key
    _lastRequestedPhotoId = photoId; // Track the last requested photo ID
    final imageCubit = context.read<AssetAuditGetImageCubit>();
    imageCubit.getImage(imgId: photoId, schId: widget.siteAuditSchId);
  }

  Future<void> _handleImageLoadRetry(String photoId, String key) async {
    const maxRetries = 5;
    const retryDelay = Duration(seconds: 3);

    final currentRetryCount = _retryCounts[photoId] ?? 0;
    if (currentRetryCount < maxRetries) {
      _retryCounts[photoId] = currentRetryCount + 1;
      print('Retrying image load for photoId: $photoId, key: $key, attempt: ${_retryCounts[photoId]} of $maxRetries');
      await Future.delayed(retryDelay);
      _loadImageForPhotoId(photoId, key);
    } else {
      print('Max retries reached for photoId: $photoId, key: $key');
      _retryCounts.remove(photoId); // Clean up retry count
      _imageRequestKeys.remove(photoId); // Clean up request tracking
    }
  }

  Future<void> _submitForm() async {
    print('=== _submitForm called ===');
    print('formData.isEmpty: ${formData.isEmpty}');
    print('formData: $formData');
    print('photoIds: $photoIds');
    print('photoTimestamps: $photoTimestamps');
    
    if (formData.isEmpty) {
      print('Form data is empty, returning early');
      return;
    }
    
    // Wait for any ongoing photo uploads to complete
    if (_currentUploadKey != null) {
      print('Waiting for photo upload to complete for key: $_currentUploadKey');
      // Wait for the photo upload to complete (max 10 seconds)
      int waitTime = 0;
      while (_currentUploadKey != null && waitTime < 10000) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitTime += 100;
      }
      if (_currentUploadKey != null) {
        print('Photo upload timeout, proceeding with form submission');
      } else {
        print('Photo upload completed');
      }
    }
    
    print('Submitting form data...');
    final cubit = context.read<PmCubit>();
    final state = cubit.state;
    print('PmCubit state: ${state.runtimeType}');
    
    if (state is PmGetLoaded) {
      print('PmGetLoaded state confirmed, calling postPmData');
      print('Final photoIds before submission: $photoIds');
      print('Final photoTimestamps before submission: $photoTimestamps');
      
      await cubit.postPmData(
        formData: formData,
        pmData: state.pmGetDataModel,
        auditSchId: widget.auditSchId,
        siteAuditSchId: widget.siteAuditSchId,
        siteId: widget.siteId ?? '',
        photoIds: photoIds,
        photoTimestamps: photoTimestamps,
        remarksData: _getRemarksData(),
      );
      print('postPmData completed');
    } else {
      print('PmCubit state is not PmGetLoaded, cannot submit');
    }
  }

  Widget _buildFormField(dynamic item) {
    final checklistDesc = item.checklistDesc ?? '';
    final pmItemType = item.pmItemType ?? '';
    final respType = item.respType ?? '';
    final key = '${pmItemType}_${item.clOrder}';
    final isEditable = true;

    print('Building form field for key: $key, respType: $respType, formData value: ${formData[key]}');

    if (respType.contains('DROPDOWN')) {
      List<String> options = [
        'OK',
        'Corrected',
        'Not OK - To be corrected',
        'Not Applicable',
      ];
      if (respType.contains('IMG')) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              checklistDesc,
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
                    items: isEditable ? options : [],
                    initialValue: formData[key] ?? options[0],
                    onChanged: isEditable
                        ? (value) => _saveFormData(key, value)
                        : (_) {},
                  ),
                  getHeight(10),
                  if (isEditable)
                    ImageUploadField(
                      label: "Add Photo",
                      externalImageUrl: loadedImageUrls[key],
                      onImageSelected: (file) async {
                        if (file != null) {
                          await _uploadPhoto(file, key);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      } else {
        return CustomDropdown(
          label: checklistDesc,
          items: isEditable ? options : [],
          initialValue: formData[key] ?? options[0],
          onChanged: isEditable ? (value) => _saveFormData(key, value) : (_) {},
        );
      }
    } else if (respType.contains('RADIO')) {
      if (respType.contains('IMG')) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomOptionSelector(
              label: checklistDesc,
              options: [
                OptionItem(
                  value: "yes",
                  label: "OK",
                  selectedIcon: Icons.check_circle,
                  unselectedIcon: Icons.circle_outlined,
                ),
                OptionItem(
                  value: "no",
                  label: "Not OK",
                  selectedIcon: Icons.cancel,
                  unselectedIcon: Icons.circle_outlined,
                ),
              ],
              initialValue: formData[key] ?? 'yes',
              onChanged: (value) => _saveFormData(key, value),
            ),
            getHeight(10),
            if (isEditable)
              ImageUploadField(
                label: "Upload Image",
                externalImageUrl: loadedImageUrls[key],
                onImageSelected: (file) async {
                  if (file != null) {
                    await _uploadPhoto(file, key);
                  }
                },
              ),
          ],
        );
      } else {
        return CustomOptionSelector(
          label: checklistDesc,
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
          initialValue: formData[key] ?? 'yes',
          onChanged: (value) => _saveFormData(key, value),
        );
      }
    } else if (respType.contains('REMARKS') || checklistDesc.toLowerCase().contains('remarks')) {
      return CustomFormField(
        label: checklistDesc,
        hintText: checklistDesc,
        initialValue: formData[key] ?? '',
        isRequired: false,
        isEditable: isEditable,
        controller: _getRemarksController(key, formData[key] ?? ''),
        onChanged: (value) => _saveFormData(key, value),
      );
    }

    // Check if this is a mobile number field
    final isMobileField = _isMobileNumberField(checklistDesc);
    
    return CustomFormField(
      label: checklistDesc,
      hintText: isMobileField ? "Enter 10-digit mobile number" : checklistDesc,
      initialValue: formData[key] ?? '',
      isRequired: false,
      isEditable: isEditable,
      controller: _getTextController(key, formData[key] ?? ''),
      onChanged: (value) => _saveFormData(key, value),
      validator: isMobileField ? _validateMobileNumber : null,
      inputFormatters: isMobileField ? _getMobileNumberFormatters() : null,
      keyboardType: isMobileField ? TextInputType.phone : TextInputType.text,
    );
  }

  Widget _buildCTSection(PmGetDataModel data) {
    final ctData = data.responseData?.ct ?? [];
    if (ctData.isEmpty) {
      return const Center(
        child: Text(
          'No CT data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...ctData
            .map(
              (item) =>
              Column(children: [_buildFormField(item), getHeight(15)]),
        )
            .toList(),
      ],
    );
  }

  @override
  void dispose() {
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
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => UnsavedChangesDialog(
              message: _getCancelMessage(),
              onSaveAndExit: () async {
                Navigator.of(context).pop();
                print('=== onSaveAndExit called ===');
                print('formData before submit: $formData');
                await _submitForm();
                print('_submitForm completed, calling _saveAndExit');
                await _saveAndExit();
              },
              onDiscard: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          );
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
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
                    print('=== onSaveAndExit called (second dialog) ===');
                    print('formData before submit: $formData');
                    await _submitForm();
                    print('_submitForm completed, calling _saveAndExit');
                    await _saveAndExit();
                  },
                  onDiscard: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
              );
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        body: MultiBlocListener(
          listeners: [
            BlocListener<AuditScheduleStatusCubit, AuditScheduleStatusState>(
              listener: (context, state) {
                print('=== AuditScheduleStatusCubit state changed ===');
                print('State type: ${state.runtimeType}');
                
                if (state is AuditScheduleStatusSuccess) {
                  print('Status updated successfully to ${state.message}');
                  // No snackbar shown - removed as requested
                } else if (state is AuditScheduleStatusError) {
                  print('Status update failed: ${state.error}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update status: ${state.error}')),
                  );
                } else if (state is AuditScheduleStatusLoading) {
                  print('Status update loading...');
                } else {
                  print('Unknown state: $state');
                }
              },
            ),
            BlocListener<PmCubit, PmState>(
              listener: (context, state) {
                if (state is PmGetLoaded) {
                  print('PmGetLoaded triggered with CT data: ${state.pmGetDataModel.responseData?.ct}');
                  _loadExistingData(state.pmGetDataModel);
                } else if (state is PmPostSuccess) {
                  print('Post successful, fetching updated data');
                  setState(() {
                    hasUnsavedChanges = false;
                    formData.clear();
                    photoIds.clear();
                    photoTimestamps.clear();
                    loadedImageUrls.clear();
                    _dummyState = DateTime.now().millisecondsSinceEpoch;
                  });
                  context.read<PmCubit>().getPmData(
                    siteType: widget.ticketType.name,
                    auditSchId: widget.auditSchId,
                    siteAuditSchId: widget.siteAuditSchId,
                  );
                } else if (state is PmPostError) {
                  print('Post error: ${state.message}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${state.message}')),
                  );
                }
              },
            ),
            BlocListener<AssetAuditPhotoUploadCubit, AssetAuditPhotoUploadState>(
              listener: (context, state) {
                print('=== AssetAuditPhotoUploadCubit state changed ===');
                print('State type: ${state.runtimeType}');
                print('_currentUploadKey: $_currentUploadKey');
                
                if (state is AssetAuditPhotoUploadSuccess) {
                  print('Photo upload successful!');
                  print('Response imgId: ${state.response.imgId}');
                  if (_currentUploadKey != null) {
                    final photoId = int.tryParse(state.response.imgId) ?? 0;
                    final timestamp = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
                    print('Setting photoIds[$_currentUploadKey] = $photoId');
                    print('Setting photoTimestamps[$_currentUploadKey] = $timestamp');
                    
                    setState(() {
                      photoIds[_currentUploadKey!] = photoId;
                      photoTimestamps[_currentUploadKey!] = timestamp;
                      _currentUploadKey = null;
                      _dummyState = DateTime.now().millisecondsSinceEpoch;
                    });
                    
                    print('Photo upload completed for key: $_currentUploadKey');
                    print('Updated photoIds: $photoIds');
                    print('Updated photoTimestamps: $photoTimestamps');
                  } else {
                    print('No _currentUploadKey found for successful upload');
                  }
                } else if (state is AssetAuditPhotoUploadFailure) {
                  print('Photo upload failed: ${state.errorMessage}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Photo upload failed: ${state.errorMessage}')),
                  );
                } else if (state is AssetAuditPhotoUploadLoading) {
                  print('Photo upload in progress...');
                }
              },
            ),
            BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
              listener: (context, state) async {
                print('=== AssetAuditGetImageCubit state changed ===');
                print('State type: ${state.runtimeType}');
                print('_lastRequestedPhotoId: $_lastRequestedPhotoId');
                
                if (state is AssetAuditGetImageSuccess) {
                  final imageData = state.imageData;
                  print('Image loaded for photoId: $_lastRequestedPhotoId, data length: ${imageData.length}, data: ${imageData.substring(0, imageData.length > 50 ? 50 : imageData.length)}...');
                  if (_lastRequestedPhotoId != null) {
                    final key = _imageRequestKeys[_lastRequestedPhotoId];
                    print('Key for photoId $_lastRequestedPhotoId: $key');
                    if (key != null) {
                      // Accept any non-empty imageData to allow for server-specific formats
                      if (imageData.isNotEmpty) {
                        print('Setting loadedImageUrls[$key] with image data');
                        setState(() {
                          loadedImageUrls[key] = imageData;
                          _dummyState = DateTime.now().millisecondsSinceEpoch;
                          print('Updated loadedImageUrls: $key = ${imageData.substring(0, imageData.length > 50 ? 50 : imageData.length)}...');
                        });
                        _imageRequestKeys.remove(_lastRequestedPhotoId);
                        _retryCounts.remove(_lastRequestedPhotoId);
                      } else {
                        print('Empty imageData for photoId: $_lastRequestedPhotoId');
                        await _handleImageLoadRetry(_lastRequestedPhotoId!, key);
                      }
                    } else {
                      print('No key found for photoId: $_lastRequestedPhotoId');
                    }
                    _lastRequestedPhotoId = null;
                  }
                } else if (state is AssetAuditGetImageFailure) {
                  print('Image load failed for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load image: ${state.errorMessage}')),
                  );
                  if (_lastRequestedPhotoId != null) {
                    final key = _imageRequestKeys[_lastRequestedPhotoId];
                    if (key != null) {
                      await _handleImageLoadRetry(_lastRequestedPhotoId!, key);
                    } else {
                      print('No key found for failed photoId: $_lastRequestedPhotoId');
                    }
                    _imageRequestKeys.remove(_lastRequestedPhotoId);
                    _lastRequestedPhotoId = null;
                  }
                }
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
                return Center(child: Text("Error: ${state.message}"));
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(PmGetDataModel data) {
    return Stack(
      children: [
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: _buildCTSection(data),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
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
                        onPressed: () async {
                          if (formData.isNotEmpty) {
                            await _submitForm();
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PmScreen3(
                                ticketType: widget.ticketType,
                                auditSchId: widget.auditSchId,
                                siteAuditSchId: widget.siteAuditSchId,
                                siteId: widget.siteId,
                                pmData: widget.pmData,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

