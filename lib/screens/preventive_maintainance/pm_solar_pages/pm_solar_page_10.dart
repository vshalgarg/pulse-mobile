import 'dart:io';
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
import '../../home_screen.dart';

class PmSolarPage10 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;
  final PmGetDataModel pmData;

  const PmSolarPage10({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
    required this.pmData,
  });

  @override
  State<PmSolarPage10> createState() => _PmSolarPage10State();
}


class _PmSolarPage10State extends State<PmSolarPage10> {
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
  bool _successDialogShown = false; // Flag to prevent multiple success dialogs
  Map<String, int> photoIds = {};
  Map<String, String> photoTimestamps = {};
  String? _currentUploadKey;
  int _dummyState = 0;
  @override
  void initState() {
    super.initState();
    print('=== initState called ===');
    if (widget.pmData != null) {
      print('Loading existing data');
      _loadExistingData(widget.pmData!);
    } else {
      print('Fetching PM data for siteType: ${widget.ticketType.name}, auditSchId: ${widget.auditSchId}, siteAuditSchId: ${widget.siteAuditSchId}');
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
      print('Form changed, hasUnsavedChanges: $hasUnsavedChanges, formData: $formData');
    });
  }

  void _saveFormData(String key, dynamic value) {
    print('=== _saveFormData called ===');
    print('Saving form data: $key = $value');
    setState(() {
      formData[key] = value;
      hasUnsavedChanges = formData.isNotEmpty;
      _dummyState = DateTime.now().millisecondsSinceEpoch;
    });
    print('Updated formData: $formData');
  }

  TextEditingController _getTextController(String key, String initialValue) {
    if (!textControllers.containsKey(key)) {
      textControllers[key] = TextEditingController(text: initialValue);
      print('Created new text controller for $key with value: $initialValue');
    } else {
      textControllers[key]!.text = initialValue;
      print('Updated text controller for $key with value: $initialValue');
    }
    return textControllers[key]!;
  }

  TextEditingController _getRemarksController(String key, String initialValue) {
    if (!remarksControllers.containsKey(key)) {
      remarksControllers[key] = TextEditingController(text: initialValue);
      print('Created new remarks controller for $key with value: $initialValue');
    } else {
      remarksControllers[key]!.text = initialValue;
      print('Updated remarks controller for $key with value: $initialValue');
    }
    return remarksControllers[key]!;
  }

  String _getPmTitle() {
    return 'PM Solar - Cables';
  }

  String _getSuccessMessage() {
    final siteId = _getActualSiteId();
    return 'Cables section for Solar Site (ID: $siteId) has been recorded and saved. PM Solar completed!';
  }

  String _getCancelMessage() {
    final siteId = _getActualSiteId();
    return 'Do you want to cancel the Cables section for Solar Site (ID: $siteId)?';
  }

  String _getActualSiteId() {
    if (widget.siteId != null && widget.siteId!.isNotEmpty && widget.siteId != "N/A") {
      return widget.siteId!;
    }
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
    return "N/A";
  }

  String _getButtonText() {
    return 'Submit';
  }

  Future<void> _uploadPhoto(File? file, String key) async {
    if (file == null) {
      print('No file selected for upload, key: $key');
      return;
    }

    print('Uploading photo for key: $key');
    _currentUploadKey = key;
    final photoCubit = context.read<AssetAuditPhotoUploadCubit>();
    await photoCubit.uploadPhoto(
      file: file,
      schId: widget.siteAuditSchId,
    );
  }

  void _loadExistingData(PmGetDataModel data) {
    print('=== Loading Existing Data for PM Solar Page 10 (Cables) ===');
    setState(() {
      formData.clear();
      photoIds.clear();
      photoTimestamps.clear();
      loadedImageUrls.clear();
      _retryCounts.clear();
      _imageQueue.clear();

      final cablesData = data.responseData?.cables ?? [];
      print('Cables data count: ${cablesData.length}');
      print('Raw Cables data: $cablesData');

      for (final item in cablesData) {
        final pmItemType = item['pm_item_type']?.toString() ?? '';
        final clOrder = item['cl_order']?.toString() ?? '';
        final key = '${pmItemType}_$clOrder';
        print('Processing item with key: $key');
        print('Raw pmItemType: "$pmItemType"');
        print('Raw clOrder: "$clOrder"');
        print('Item details: pmCheckListSiteRespId=${item['pm_check_list_site_resp_id']}, resp=${item['resp']}, photoId=${item['photo_id']}');

        if (item['resp'] != null) {
          String mappedValue;
          if (item['resp'] is int) {
            print('Warning: resp is int (${item['resp']}), converting to String');
            final respValue = item['resp'].toString();
            if (item['resp_type']?.contains('DROPDOWN') ?? false) {
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
            } else if (item['resp_type']?.contains('RADIO') ?? false) {
              mappedValue = respValue == '1' ? 'yes' : 'no';
            } else {
              mappedValue = respValue;
            }
          } else {
            mappedValue = item['resp'].toString();
          }
          formData[key] = mappedValue;
          print('Added to formData: $key = $mappedValue');
        }

        if (item['photo_id'] != null) {
          final photoIdInt = int.tryParse(item['photo_id'].toString());
          if (photoIdInt != null) {
            photoIds[key] = photoIdInt;
            _retryCounts[photoIdInt.toString()] = 0;
            print('Added to photoIds: $key = $photoIdInt');
            _imageQueue.add({'photoId': photoIdInt.toString(), 'key': key});
          } else {
            print('Invalid photoId format for key $key: ${item['photo_id']}');
          }
        }

        if (item['photo_taken_ts'] != null) {
          // Ensure timestamp is in dd/MM/yyyy HH:mm format for API
          try {
            final parsedDate = DateTime.parse(item['photo_taken_ts'].toString());
            final formattedTimestamp = DateFormat("dd/MM/yyyy HH:mm").format(parsedDate);
            photoTimestamps[key] = formattedTimestamp;
            print('Added to photoTimestamps: $key = $formattedTimestamp (converted from ${item['photo_taken_ts']})');
          } catch (e) {
            // If parsing fails, use the original timestamp
            photoTimestamps[key] = item['photo_taken_ts'].toString();
            print('Added to photoTimestamps: $key = ${item['photo_taken_ts']} (parsing failed)');
          }
        }

        if (item['remarks'] != null && item['remarks'].toString().isNotEmpty) {
          _getRemarksController(key, item['remarks'].toString());
          print('Added to remarks: $key = ${item['remarks']}');
        }
      }

      print('Final formData: $formData');
      print('Final photoIds: $photoIds');
      print('Final photoTimestamps: $photoTimestamps');
      print('Final loadedImageUrls: $loadedImageUrls');
      _dummyState = DateTime.now().millisecondsSinceEpoch;
    });

    _fetchNextImage();

    Future.delayed(const Duration(seconds: 5), () {
      for (final key in photoIds.keys) {
        if (!loadedImageUrls.containsKey(key) && photoIds[key] != null) {
          print('Fallback: Re-fetching image for key: $key, photoId: ${photoIds[key]}');
          _imageQueue.add({'photoId': photoIds[key]!.toString(), 'key': key});
          _fetchNextImage();
        }
      }
    });
  }

  void _fetchNextImage() {
    if (_fetchingImage || _imageQueue.isEmpty) {
      print('Skipping _fetchNextImage: _fetchingImage=$_fetchingImage, _imageQueue.isEmpty=${_imageQueue.isEmpty}');
      return;
    }

    _fetchingImage = true;
    final image = _imageQueue.removeAt(0);
    final photoId = image['photoId']!;
    final key = image['key']!;

    print('Loading image for photoId: $photoId, key: $key, retry count: ${_retryCounts[photoId] ?? 0}');
    _imageRequestKeys[photoId] = key;
    _lastRequestedPhotoId = photoId;
    final imageCubit = context.read<AssetAuditGetImageCubit>();
    imageCubit.getImage(imgId: photoId, schId: widget.siteAuditSchId);
  }

  Future<void> _handleImageLoadRetry(String photoId, String key) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    final currentRetryCount = _retryCounts[photoId] ?? 0;
    if (currentRetryCount < maxRetries) {
      _retryCounts[photoId] = currentRetryCount + 1;
      print('Retrying image load for photoId: $photoId, key: $key, attempt: ${_retryCounts[photoId]} of $maxRetries');
      await Future.delayed(retryDelay * (currentRetryCount + 1));
      if (mounted) {
        _imageQueue.insert(0, {'photoId': photoId, 'key': key});
        _fetchNextImage();
      }
    } else {
      print('Max retries reached for photoId: $photoId, key: $key');
      _retryCounts.remove(photoId);
      _imageRequestKeys.remove(photoId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load image for $key after $maxRetries attempts')),
      );
      _fetchingImage = false;
      _fetchNextImage();
    }
  }

  bool _isFieldEditable(dynamic item) {
    final respType = item['resp_type']?.toString() ?? '';
    if (respType.contains('RADIO')) {
      return true;
    }

    // For dropdown fields, they should be editable initially
    if (respType.contains('DROPDOWN')) {
      return true;
    }

    // For other fields (like remarks), check dependencies
    final cablesData = widget.pmData?.responseData?.cables ?? [];
    final key = '${item['pm_item_type']}_${item['cl_order']}';
    return _checkCablesDependencies(key, cablesData);
  }

  bool _checkCablesDependencies(String key, List<dynamic> sectionData) {
    final dropdownValue = formData[key];
    
    // If no dropdown value is set yet, allow editing (for initial load)
    if (dropdownValue == null) {
      return true;
    }
    
    // For remarks fields, only allow editing if dropdown is 'Corrected' or 'Not OK - To be corrected'
    if (dropdownValue == 'Corrected' || dropdownValue == 'Not OK - To be corrected') {
      return true;
    }
    return false;
  }

  Future<void> _submitForm() async {

    print('=== _submitForm called ===');
    print('formData.length: ${formData.length}');
    print('Total available fields: ${widget.pmData?.responseData?.cables?.length ?? 0}');

    final cablesData = widget.pmData?.responseData?.cables ?? [];
    bool allRequiredFilled = true;
    for (final item in cablesData) {
      final key = '${item['pm_item_type']}_${item['cl_order']}';
      if (item['is_required'] == true && !formData.containsKey(key)) {
        allRequiredFilled = false;
        print('Required field missing: $key');
      }
    }

    if (formData.isEmpty) {
      print('formData is empty, skipping submission');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No data to submit')),
      );
      return;
    }

    if (!allRequiredFilled) {
      print('Not all required fields are filled');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }


    try {
      print('Submitting data: formData=$formData');
      final cubit = context.read<PmCubit>();
      final state = cubit.state;
      print('Current PmCubit state: $state');

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
        pmData: pmDataToUse,
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
    print('Remarks data: $remarksData');
    return remarksData;
  }

  Future<void> _updateAuditScheduleStatus(String status, {required String siteAuditSchId, String? siteId}) async {
    try {
      print('Updating audit schedule status to: $status, siteAuditSchId: $siteAuditSchId, siteId: $siteId');
      
      if (!mounted) {
        print('Widget is not mounted, skipping audit status update');
        return;
      }
      
      await context.read<AuditScheduleStatusCubit>().updateStatus(
        status: status,
        siteAuditSchId: siteAuditSchId,
        // siteId: siteId,
      );
      print('Audit schedule status updated successfully to: $status');
    } catch (e) {
      print('Error updating audit schedule status: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update audit status: $e')),
        );
      }
    }
  }

  // Future<void> _saveAndExit(BuildContext innerContext) async {
  //   print('=== _saveAndExit called ===');
  //   await _submitForm();
  //   if (mounted) {
  //     print('Showing success dialog...');
  //     await showDialog(
  //       context: innerContext,
  //       barrierDismissible: false,
  //       builder: (dialogContext) => SuccessDialog(
  //         ticketId: _getActualSiteId(),
  //         message: _getSuccessMessage(),
  //         onDone: () async {
  //           print('Success dialog - onDone called');
  //           await _updateAuditScheduleStatus(
  //             'complete',
  //             siteAuditSchId: widget.siteAuditSchId,
  //             siteId: widget.siteId,
  //           );
  //           if (mounted) {
  //             Navigator.of(dialogContext).pop(); // Close dialog
  //             Navigator.popUntil(innerContext, (route) => route.isFirst); // Go back to main screen
  //           }
  //         },
  //       ),
  //     );
  //   }
  // }

  Future<void> _saveAndExit(BuildContext pageContext) async {
    await _updateAuditScheduleStatus(
      'IN-PROGRESS',
      siteAuditSchId: widget.siteAuditSchId,
      siteId: widget.siteId,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(),
      ),
    );
  }

  @override
  void dispose() {
    print('Disposing controllers...');
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
    return Builder(
      builder: (innerContext) => PopScope(
        canPop: !hasUnsavedChanges,
        onPopInvoked: (didPop) async {
          if (didPop) return;

          if (hasUnsavedChanges) {
            print('Showing unsaved changes dialog');
            showDialog(
              context: innerContext,
              barrierDismissible: false,
              builder: (dialogContext) => UnsavedChangesDialog(
                message: _getCancelMessage(),
                onSaveAndExit: () async {
                  print('Save and exit selected');
                  Navigator.of(dialogContext).pop();
                  await _submitForm();
                  await _updateAuditScheduleStatus(
                    'IN-PROGRESS',
                    siteAuditSchId: widget.siteAuditSchId,
                    siteId: widget.siteId,
                  );
                  if (mounted) {
                    Navigator.of(innerContext).pop();
                  }
                },
                onDiscard: () async {
                  print('Discard selected');
                  Navigator.of(dialogContext).pop();
                  await _updateAuditScheduleStatus(
                    'IN-PROGRESS',
                    siteAuditSchId: widget.siteAuditSchId,
                    siteId: widget.siteId,
                  );
                  if (mounted) {
                    Navigator.of(innerContext).pop();
                  }
                },
              ),
            );
          }
        },
        child: MultiBlocListener(
          listeners: [
            BlocListener<PmCubit, PmState>(
              listener: (context, state) async {
                print('PmCubit state changed: $state');
                if (state is PmGetLoaded) {
                  print('PmGetLoaded triggered with Cables data: ${state.pmGetDataModel.responseData?.cables}');
                  _loadExistingData(state.pmGetDataModel);
                } else if (state is PmPostSuccess) {
                  print('Post successful, checking if success dialog already shown: $_successDialogShown');
                  
                  // Prevent multiple success dialogs
                  if (_successDialogShown) {
                    print('Success dialog already shown, skipping...');
                    return;
                  }
                  
                  print('Showing success dialog');
                  _successDialogShown = true; // Set flag to prevent multiple dialogs
                  
                  setState(() {
                    formData.clear();
                    for (final key in photoIds.keys) {
                      if (!loadedImageUrls.containsKey(key)) {
                        _imageQueue.add({
                          'photoId': photoIds[key]!.toString(),
                          'key': key,
                        });
                      }
                    }
                    for (final controller in textControllers.values) {
                      controller.clear();
                    }
                    for (final controller in remarksControllers.values) {
                      controller.clear();
                    }
                    hasUnsavedChanges = false;
                    _dummyState = DateTime.now().millisecondsSinceEpoch;
                  });
                  _fetchNextImage();
                  
                  // Show success dialog
                  if (mounted) {
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => SuccessDialog(
                        ticketId: _getActualSiteId(),
                        message: _getSuccessMessage(),
                        onDone: () async {
                          print('Success dialog - onDone called');
                          await _updateAuditScheduleStatus(
                            'COMPLETED',
                            siteAuditSchId: widget.siteAuditSchId,
                            siteId: widget.siteId,
                          );
                          if (mounted) {
                            Navigator.of(dialogContext).pop(); // Close dialog
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HomeScreen(),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  }
                } else if (state is PmPostError) {
                  print('Post error: ${state.message}');
                  _successDialogShown = false; // Reset flag on error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving data: ${state.message}')),
                  );
                } else if (state is PmPosting) {
                  print('Posting data...');
                  _successDialogShown = false; // Reset flag when starting new submission
                }
              },
            ),
            BlocListener<AuditScheduleStatusCubit, AuditScheduleStatusState>(
              listener: (context, state) {
                if (state is AuditScheduleStatusSuccess) {
                  print('Status updated successfully to ${state.message}');
                  // No snackbar shown - removed as requested
                } else if (state is AuditScheduleStatusError) {
                  print('Status update failed: ${state.error}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update status: ${state.error}')),
                  );
                }
              },
            ),
            BlocListener<AssetAuditPhotoUploadCubit, AssetAuditPhotoUploadState>(
              listener: (context, state) {
                if (state is AssetAuditPhotoUploadSuccess) {
                  print('Photo upload success: _currentUploadKey = $_currentUploadKey');
                  if (_currentUploadKey != null) {
                    final photoId = int.tryParse(state.response.imgId) ?? 0;
                    final timestamp = DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now());
                    final keyToSave = _currentUploadKey!;
                    setState(() {
                      photoIds[keyToSave] = photoId;
                      photoTimestamps[keyToSave] = timestamp;
                      _retryCounts[photoId.toString()] = 0;
                      _imageQueue.add({'photoId': photoId.toString(), 'key': keyToSave});
                      _currentUploadKey = null;
                      _dummyState = DateTime.now().millisecondsSinceEpoch;
                    });
                    print('Photo uploaded: photoId=$photoId, timestamp=$timestamp for key=$keyToSave');
                    _fetchNextImage();
                  } else {
                    print('Photo upload success but _currentUploadKey is null');
                  }
                } else if (state is AssetAuditPhotoUploadFailure) {
                  print('Photo upload failed: ${state.errorMessage}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Photo upload failed: ${state.errorMessage}')),
                  );
                }
              },
            ),
            BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
              listener: (context, state) async {
                if (state is AssetAuditGetImageSuccess) {
                  final imageData = state.imageData;
                  print('Image loaded for photoId: $_lastRequestedPhotoId, data length: ${imageData.length}');
                  if (_lastRequestedPhotoId != null) {
                    final key = _imageRequestKeys[_lastRequestedPhotoId];
                    if (key != null) {
                      if (imageData.isNotEmpty) {
                        setState(() {
                          loadedImageUrls[key] = imageData;
                          _dummyState = DateTime.now().millisecondsSinceEpoch;
                          print('Updated loadedImageUrls: $key');
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
                  _fetchingImage = false;
                  _fetchNextImage();
                } else if (state is AssetAuditGetImageFailure) {
                  print('Image load failed for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to load image: ${state.errorMessage}')),
                  );
                  if (_lastRequestedPhotoId != null) {
                    final key = _imageRequestKeys[_lastRequestedPhotoId];
                    if (key != null) {
                      await _handleImageLoadRetry(_lastRequestedPhotoId!, key);
                    }
                    _imageRequestKeys.remove(_lastRequestedPhotoId);
                    _lastRequestedPhotoId = null;
                  }
                  _fetchingImage = false;
                  _fetchNextImage();
                }
              },
            ),
          ],
          child: Scaffold(
            extendBodyBehindAppBar: true,
            resizeToAvoidBottomInset: false,
            appBar: CustomFormAppbar(
              title: _getPmTitle(),
              onClose: () async {
                if (hasUnsavedChanges) {
                  print('Showing unsaved changes dialog on appbar close');
                  showDialog(
                    context: innerContext,
                    barrierDismissible: false,
                    builder: (dialogContext) => UnsavedChangesDialog(
                      message: _getCancelMessage(),
                      onSaveAndExit: () async {
                        print('Save and exit selected from appbar');
                        Navigator.of(dialogContext).pop();
                        await _submitForm();
                        await _updateAuditScheduleStatus(
                          'IN-PROGRESS',
                          siteAuditSchId: widget.siteAuditSchId,
                          siteId: widget.siteId,
                        );
                        if (mounted) {
                          Navigator.pop(innerContext);
                        }
                      },
                      onDiscard: () async {
                        print('Discard selected from appbar');
                        Navigator.of(dialogContext).pop();
                        await _updateAuditScheduleStatus(
                          'IN-PROGRESS',
                          siteAuditSchId: widget.siteAuditSchId,
                          siteId: widget.siteId,
                        );
                        if (mounted) {
                          Navigator.pop(innerContext);
                        }
                      },
                    ),
                  );
                } else {
                  print('No unsaved changes, closing');
                  await _updateAuditScheduleStatus(
                    'IN-PROGRESS',
                    siteAuditSchId: widget.siteAuditSchId,
                    siteId: widget.siteId,
                  );
                  Navigator.pop(innerContext);
                }
              },
            ),
            body: widget.pmData == null
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(widget.pmData!, innerContext),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(PmGetDataModel data, BuildContext innerContext) {
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
                    bottom: MediaQuery.of(innerContext).viewInsets.bottom + 120,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: _buildCablesSection(data),
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
                        onPressed: () async {
                          print('Back button pressed');
                          if (hasUnsavedChanges) {
                            await _submitForm();
                          }
                          // Pass updated data back to previous screen
                          Navigator.pop(innerContext, widget.pmData);
                        },
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ArrowButton(
                        text: _getButtonText(),
                        isLeftArrow: false,
                        backgroundColor: AppColors.buttonColorBg,
                        textColor: AppColors.buttonColorSite,
                        onPressed: () => _submitForm(),
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

  Widget _buildCablesSection(PmGetDataModel data) {
    final cablesData = data.responseData?.cables ?? [];
    print('Building Cables section with data: $cablesData');

    if (cablesData.isEmpty) {
      return const Center(
        child: Text(
          'No Cables data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cablesData.map((item) => Column(
        children: [
          _buildFormField(item),
          SizedBox(height: 15),
        ],
      )).toList(),
    );
  }

  Widget _buildFormField(dynamic item) {
    final respType = item['resp_type']?.toString() ?? '';
    final checklistDesc = item['checklist_desc']?.toString() ?? '';
    final pmItemType = item['pm_item_type']?.toString() ?? '';
    final key = '${pmItemType}_${item['cl_order']}';
    final currentValue = formData[key] ?? '';
    final bool isEditable = _isFieldEditable(item);

    print('Building form field: key=$key, respType=$respType, checklistDesc=$checklistDesc, isEditable=$isEditable');

    if (respType.contains('DROPDOWN') && respType.contains('IMG')) {
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
          SizedBox(height: 8),
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
                  items: isEditable
                      ? [
                    'OK',
                    'Corrected',
                    'Not OK - To be corrected',
                    'Not Applicable',
                  ]
                      : [],
                  initialValue: currentValue.isNotEmpty ? currentValue : null,
                  onChanged: isEditable
                      ? (value) {
                    print('Dropdown changed: $key = $value');
                    _saveFormData(key, value);
                  }
                      : (_) {},
                  isRequired: item['is_required'] == true,
                ),
                SizedBox(height: 15),
                if (isEditable)
                  ImageUploadField(
                    label: "Add Photo",
                    externalImageUrl: loadedImageUrls[key],
                    onImageSelected: (file) async {
                      print('Image selected for key: $key');
                      if (file != null) {
                        await _uploadPhoto(file, key);
                      }
                    },
                    isRequired: item['is_required'] == true,
                  ),
              ],
            ),
          ),
        ],
      );
    } else if (respType.contains('DROPDOWN')) {
      final options = [
        'OK',
        'Corrected',
        'Not OK - To be corrected',
        'Not Applicable',
      ];
      return CustomDropdown(
        label: checklistDesc,
        items: isEditable ? options : [],
        initialValue: currentValue.isNotEmpty ? currentValue : null,
        onChanged: isEditable
            ? (value) {
          print('Dropdown changed: $key = $value');
          _saveFormData(key, value);
        }
            : (_) {},
        isRequired: item['is_required'] == true,
      );
    } else if (respType.contains('IMG')) {
      return ImageUploadField(
        label: checklistDesc,
        externalImageUrl: loadedImageUrls[key],
        onImageSelected: (file) async {
          print('Image selected for key: $key');
          if (file != null) {
            await _uploadPhoto(file, key);
          }
        },
        isRequired: item['is_required'] == true,
      );
    } else if (respType.contains('TEXT')) {
      return CustomFormField(
        label: checklistDesc,
        hintText: 'Enter remarks',
        controller: _getTextController(key, currentValue),
        onChanged: (value) {
          print('Text field changed: $key = $value');
          _saveFormData(key, value);
        },
        isRequired: item['is_required'] == true,
      );
    } else if (respType.contains('RADIO')) {
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
        initialValue: currentValue,
        onChanged: (value) {
          print('Radio changed: $key = $value');
          _saveFormData(key, value);
        },
        isRequired: item['is_required'] == true,
      );
    }

    return CustomFormField(
      label: checklistDesc,
      hintText: checklistDesc,
      controller: _getTextController(key, currentValue),
      onChanged: (value) {
        print('Default text field changed: $key = $value');
        _saveFormData(key, value);
      },
      isRequired: item['is_required'] == true,
    );
  }
}
