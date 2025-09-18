import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/bloc/pm_bloc/pm_cubit.dart';
import 'package:app/bloc/pm_bloc/pm_state.dart';
import 'package:app/bloc/asset_audit_photo_upload_cubit.dart';
import 'package:app/bloc/asset_audit_get_image_cubit.dart';
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
import 'package:app/screens/preventive_maintainance/pm_solar_pages/pm_solar_page_5.dart';
import 'package:intl/intl.dart';

import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../constants/constants_strings.dart';
import '../../../repositories/audit_schedule_repository.dart';
import '../../home_screen.dart';

class PmSolarPage4 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;
  final PmGetDataModel pmData;

  const PmSolarPage4({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
    required this.pmData,
  });

  @override
  State<PmSolarPage4> createState() => _PmSolarPage4State();
}

class _PmSolarPage4State extends State<PmSolarPage4> {
  bool hasUnsavedChanges = false;
  bool isSubmitting = false;
  Map<String, dynamic> formData = {};
  Map<String, int> photoIds = {}; // Store photo IDs as integers
  Map<String, String> photoTimestamps = {};
  Map<String, String> loadedImageUrls = {}; // Store loaded image URLs
  Map<String, TextEditingController> textControllers = {};
  Map<String, TextEditingController> remarksControllers = {};
  String? _currentUploadKey;
  Map<String, String> _imageRequestKeys = {}; // Track which key corresponds to which photo_id request
  String? _lastRequestedPhotoId; // Track the last requested photo ID
  Map<String, int> _retryCounts = {}; // Track retry attempts for each photo ID
  int _dummyState = 0; // For forcing UI rebuilds
  List<Map<String, String>> _imageQueue = []; // Queue for serial image fetches
  bool _fetchingImage = false; // Flag for ongoing image fetch
  Map<String, DateTime> _uploadStartTimes = {}; // Track upload start times for timeout detection

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
      hasUnsavedChanges = formData.isNotEmpty;
      _dummyState = DateTime.now().millisecondsSinceEpoch;
    });
  }

  void _saveFormData(String key, dynamic value) {
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
    return 'PM Solar - Transformer';
  }

  String _getSuccessMessage() {
    final siteId = _getActualSiteId();
    return "Transformer section for Solar Site (ID: $siteId) has been recorded and saved.";
  }

  String _getCancelMessage() {
    final siteId = _getActualSiteId();
    return "Do you want to cancel the Transformer section for Solar Site (ID: $siteId) ?";
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

  String _getButtonText() {
    return 'Safety Systems';
  }

  Future<void> _uploadPhoto(File? file, String key) async {
    if (file == null) {
      print('Upload cancelled: file is null for key: $key');
      return;
    }

    // Prevent concurrent uploads
    if (_currentUploadKey != null) {
      print('Upload already in progress for key: $_currentUploadKey. Skipping upload for key: $key');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait for current photo upload to complete')),
      );
      return;
    }

    print('Starting photo upload for key: $key');
    setState(() {
      _currentUploadKey = key;
      _uploadStartTimes[key] = DateTime.now();
    });
    
    final photoCubit = context.read<AssetAuditPhotoUploadCubit>();

    try {
      await photoCubit.uploadPhoto(
        file: file,
        schId: widget.siteAuditSchId,
      );
      print('Photo upload initiated for key: $key');
    } catch (e) {
      print('Error during photo upload for key: $key, error: $e');
      setState(() {
        _currentUploadKey = null;
        _uploadStartTimes.remove(key);
      });
    }
  }

  void _loadExistingData(PmGetDataModel data) {
    print('=== Loading Existing Data for PM Solar Page 4 (Transformer) ===');
    setState(() {
      formData.clear();
      photoIds.clear();
      photoTimestamps.clear();
      loadedImageUrls.clear();
      _retryCounts.clear();
      _imageQueue.clear();
      _uploadStartTimes.clear();

      // Load Transformer section data
      final transformerData = data.responseData?.transformer ?? [];
      print('Transformer data count: ${transformerData.length}');
      print('Raw Transformer data: $transformerData');

      for (final item in transformerData) {
        final key = '${item['pm_item_type']}_${item['cl_order']}';
        print('Processing item: $key, resp: ${item['resp']} (type: ${item['resp'].runtimeType}), photoId: ${item['photo_id']} (type: ${item['photo_id'].runtimeType}), respType: ${item['resp_type']}');

        // resp contains dropdown values, add directly to formData
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
            // Add to queue for serial fetching
            _imageQueue.add({'photoId': photoIdInt.toString(), 'key': key});
          } else {
            print('Invalid photoId format for key $key: ${item['photo_id']}');
          }
        } else {
          print('No photoId for key $key');
        }

        if (item['photo_taken_ts'] != null) {
          // Ensure timestamp is in dd/MM/yyyy HH:mm format for API
          try {
            final parsedDate = DateTime.parse(item['photo_taken_ts']!);
            final formattedTimestamp = DateFormat("dd/MM/yyyy HH:mm").format(parsedDate);
            photoTimestamps[key] = formattedTimestamp;
            print('Added to photoTimestamps: $key = $formattedTimestamp (converted from ${item['photo_taken_ts']})');
          } catch (e) {
            // If parsing fails, use the original timestamp
            photoTimestamps[key] = item['photo_taken_ts']!;
            print('Added to photoTimestamps: $key = ${item['photo_taken_ts']} (parsing failed)');
          }
        }

        // Load remarks data if available
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

    _fetchNextImage(); // Start processing the queue

    // Fallback: Re-fetch missing images after a delay
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
    if (_fetchingImage || _imageQueue.isEmpty) return;

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
    const maxRetries = 5;
    const retryDelay = Duration(seconds: 3);

    final currentRetryCount = _retryCounts[photoId] ?? 0;
    if (currentRetryCount < maxRetries) {
      _retryCounts[photoId] = currentRetryCount + 1;
      print('Retrying image load for photoId: $photoId, key: $key, attempt: ${_retryCounts[photoId]} of $maxRetries');
      await Future.delayed(retryDelay);
      _imageQueue.insert(0, {'photoId': photoId, 'key': key}); // Add to front of queue for retry
      _fetchNextImage();
    } else {
      print('Max retries reached for photoId: $photoId, key: $key');
      _retryCounts.remove(photoId);
      _imageRequestKeys.remove(photoId);
    }
  }

  bool _isFieldEditable(dynamic item) {
    final respType = item['resp_type'] ?? '';

    if (respType.contains('RADIO')) {
      return true;
    }

    final transformerData = widget.pmData?.responseData?.transformer ?? [];
    final bool isEditable = _checkTransformerDependencies(item, transformerData);

    return isEditable;
  }

  bool _checkTransformerDependencies(dynamic item, List<dynamic> sectionData) {
    final itemDesc = item['checklist_desc']?.toLowerCase() ?? '';

    if (itemDesc.contains('rectification remarks')) {
      for (final dropdownItem in sectionData) {
        if (dropdownItem['resp_type']?.contains('DROPDOWN') == true) {
          final dropdownKey = '${dropdownItem['pm_item_type']}_${dropdownItem['cl_order']}';
          final dropdownValue = formData[dropdownKey];

          if (dropdownValue == 'Not OK - To be corrected') {
            return true;
          }
        }
      }
      return false;
    }

    return true;
  }

  Future<void> _submitForm() async {
    print('=== _submitForm called ===');
    print('formData.length: ${formData.length}');
    print('Total available fields: ${widget.pmData?.responseData?.transformer?.length ?? 0}');

    // Validate required fields
    final transformerData = widget.pmData?.responseData?.transformer ?? [];
    bool allRequiredFilled = true;
    for (final item in transformerData) {
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

  Future<void> _saveAndExit() async {
    await _updateAuditScheduleStatus("IN-PROGRESS");
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(),
      ),
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
                await _submitForm();
                Navigator.of(context).pop();
              },
              onDiscard: () {
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
                    await _submitForm();
                    _saveAndExit();
                  },
                  onDiscard: () {
                    Navigator.of(context).pop();
                  },
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        body: _buildContent(widget.pmData!),
      ),
    );
  }

  Widget _buildContent(PmGetDataModel data) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PmCubit, PmState>(
          listener: (context, state) {
            if (state is PmGetLoaded) {
              print('PmGetLoaded triggered with Transformer data: ${state.pmGetDataModel.responseData?.transformer}');
              _loadExistingData(state.pmGetDataModel);
            } else if (state is PmPostSuccess) {
              print('Post successful, clearing form data');
              setState(() {
                isSubmitting = false;
                formData.clear();
                photoIds.clear();
                photoTimestamps.clear();
                loadedImageUrls.clear();
                _retryCounts.clear();
                for (final controller in textControllers.values) {
                  controller.clear();
                }
                for (final controller in remarksControllers.values) {
                  controller.clear();
                }
                hasUnsavedChanges = false;
                _dummyState = DateTime.now().millisecondsSinceEpoch;
              });
              // Don't call _saveAndExit() here - let the Next button handle navigation
            } else if (state is PmPostError) {
              print('Post error: ${state.message}');
              setState(() {
                isSubmitting = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error saving data: ${state.message}')),
              );
            } else if (state is PmPosting) {
              setState(() {
                isSubmitting = true;
              });
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
                final keyToSave = _currentUploadKey!; // Save the key before setting to null
                
                // Check upload timing for debugging
                if (_uploadStartTimes.containsKey(keyToSave)) {
                  final uploadDuration = DateTime.now().difference(_uploadStartTimes[keyToSave]!);
                  print('Upload completed in ${uploadDuration.inMilliseconds}ms for key: $keyToSave');
                }
                
                setState(() {
                  photoIds[keyToSave] = photoId;
                  photoTimestamps[keyToSave] = timestamp;
                  _currentUploadKey = null;
                  _uploadStartTimes.remove(keyToSave);
                  _dummyState = DateTime.now().millisecondsSinceEpoch;
                });
                print('Photo uploaded: photoId=$photoId, timestamp=$timestamp for key=$keyToSave');
              } else {
                print('Photo upload success but _currentUploadKey is null');
                print('Upload start times: $_uploadStartTimes');
                // Try to find the most recent upload that might match this success
                if (_uploadStartTimes.isNotEmpty) {
                  final recentUpload = _uploadStartTimes.entries.last;
                  print('Found recent upload for key: ${recentUpload.key}, trying to use it');
                  final photoId = int.tryParse(state.response.imgId) ?? 0;
                  final timestamp = DateFormat("dd/MM/yyyy HH:mm").format(DateTime.now());
                  setState(() {
                    photoIds[recentUpload.key] = photoId;
                    photoTimestamps[recentUpload.key] = timestamp;
                    _uploadStartTimes.remove(recentUpload.key);
                    _dummyState = DateTime.now().millisecondsSinceEpoch;
                  });
                  print('Photo uploaded (fallback): photoId=$photoId, timestamp=$timestamp for key=${recentUpload.key}');
                }
              }
            } else if (state is AssetAuditPhotoUploadFailure) {
              print('Photo upload failed: ${state.errorMessage}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Photo upload failed: ${state.errorMessage}')),
              );
              // Reset the upload key on failure
              setState(() {
                if (_currentUploadKey != null) {
                  _uploadStartTimes.remove(_currentUploadKey);
                }
                _currentUploadKey = null;
              });
            }
          },
        ),
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) async {
            if (state is AssetAuditGetImageSuccess) {
              final imageData = state.imageData;
              print('Image loaded for photoId: $_lastRequestedPhotoId, data length: ${imageData.length}, data: ${imageData.substring(0, imageData.length > 50 ? 50 : imageData.length)}...');
              if (_lastRequestedPhotoId != null) {
                final key = _imageRequestKeys[_lastRequestedPhotoId];
                if (key != null) {
                  if (imageData.isNotEmpty) {
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
            _fetchingImage = false;
            _fetchNextImage(); // Fetch the next image in the queue
          },
        ),
      ],
      child: Stack(
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
                      bottom: MediaQuery.of(context).viewInsets.bottom + 120,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      child: _buildTransformerSection(data),
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
                          onPressed: isSubmitting
                              ? null
                              : () async {
                            if (formData.isNotEmpty) {
                              await _submitForm();
                            }
                            // Pass updated data back to previous screen
                            Navigator.pop(context, widget.pmData);
                          },
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
                            print('=== Next button pressed ===');
                            print('formData before submit: $formData');
                            print('hasUnsavedChanges: $hasUnsavedChanges');
                            
                            // Clear unsaved changes flag to prevent PopScope from showing dialog
                            setState(() {
                              hasUnsavedChanges = false;
                            });
                            
                            if (formData.isNotEmpty) {
                              await _submitForm();
                            }
                            
                            // Navigate to next page regardless of submission status
                            // The BlocListener will handle the submission result
                            print('Navigating to PmSolarPage5');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PmSolarPage5(
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
          if (isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.3),
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

  Widget _buildTransformerSection(PmGetDataModel data) {
    final transformerData = data.responseData?.transformer ?? [];
    
    if (transformerData.isEmpty) {
      return const Center(
        child: Text(
          'No Transformer data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...transformerData.map((item) => Column(
          children: [
            _buildFormField(item),
            getHeight(15),
          ],
        )).toList(),
      ],
    );
  }

  Widget _buildFormField(dynamic item) {
    final respType = item['resp_type'] ?? '';
    final checklistDesc = item['checklist_desc'] ?? '';
    final pmItemType = item['pm_item_type'] ?? '';
    final key = '${pmItemType}_${item['cl_order']}';

    // Check if this field should be editable based on other field selections
    final bool isEditable = _isFieldEditable(item);

    if (respType.contains('TEXT')) {
      return CustomFormField(
        label: checklistDesc,
        hintText: checklistDesc,
        initialValue: formData[key] ?? '',
        isRequired: false,
        isEditable: isEditable,
        controller: _getTextController(key, formData[key] ?? ''),
        onChanged: (value) => _saveFormData(key, value),
      );
    } else if (respType.contains('DROPDOWN')) {
      List<String> options = ['OK', 'Corrected', 'Not OK - To be corrected', 'Not Applicable'];
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
                    label: 'Status',
                    items: isEditable ? options : [],
                    initialValue: isEditable ? (formData[key] ?? '') : null,
                    onChanged: isEditable ? (value) => _saveFormData(key, value) : (_) {},
                    isRequired: false,
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
            getHeight(15),
          ],
        );
      } else {
        return CustomDropdown(
          label: checklistDesc,
          items: isEditable ? options : [],
          initialValue: isEditable ? (formData[key] ?? '') : null,
          onChanged: isEditable ? (value) => _saveFormData(key, value) : (_) {},
          isRequired: false,
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
        hintText: checklistDesc,
        label: checklistDesc,
        initialValue: formData[key] ?? '',
        isRequired: false,
        isEditable: isEditable,
        controller: _getRemarksController(key, formData[key] ?? ''),
        onChanged: (value) => _saveFormData(key, value),
      );
    }

    return CustomFormField(
      hintText: checklistDesc,
      label: checklistDesc,
      initialValue: formData[key] ?? '',
      isRequired: false,
      isEditable: isEditable,
      controller: _getTextController(key, formData[key] ?? ''),
      onChanged: (value) => _saveFormData(key, value),
    );
  }



}
