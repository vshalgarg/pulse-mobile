import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/bloc/pm_bloc/pm_cubit.dart';
import 'package:app/bloc/pm_bloc/pm_state.dart';
import 'package:app/bloc/asset_audit_photo_upload_cubit.dart';
import 'package:app/bloc/asset_audit_get_image_cubit.dart';
import 'package:app/bloc/audit_schedule_status_cubit.dart';
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
import 'package:app/screens/preventive_maintainance/pm_solar_pages/pm_solar_page_3.dart';
import 'dart:io';
import 'package:intl/intl.dart';

import '../../../commonWidgets/custom_radio_options.dart';
import '../../../constants/constants_strings.dart';
import '../../../repositories/audit_schedule_repository.dart';
import '../../home_screen.dart';

class PmSolarPage2 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;
  final PmGetDataModel pmData;

  const PmSolarPage2({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
    required this.pmData,
  });

  @override
  State<PmSolarPage2> createState() => _PmSolarPage2State();
}

class _PmSolarPage2State extends State<PmSolarPage2> {
  bool hasUnsavedChanges = false;
  bool isSubmitting = false;
  Map<String, dynamic> formData = {};
  Map<String, int> photoIds = {};
  Map<String, String> photoTimestamps = {};
  Map<String, String> loadedImageUrls = {};
  Map<String, TextEditingController> textControllers = {};
  Map<String, TextEditingController> remarksControllers = {};
  String? _currentUploadKey;
  Map<String, String> _imageRequestKeys = {};
  String? _lastRequestedPhotoId;
  Map<String, int> _retryCounts = {};
  int _dummyState = 0;
  List<Map<String, String>> _imageQueue = [];
  bool _fetchingImage = false;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.pmData != null) {
        print('=== Loading data from widget.pmData for PM Solar Page 2 ===');
        _loadExistingData(widget.pmData!);
      } else {
        print('=== Fetching fresh data from API for PM Solar Page 2 ===');
        context.read<PmCubit>().getPmData(
          siteType: widget.ticketType.name,
          auditSchId: widget.auditSchId,
          siteAuditSchId: widget.siteAuditSchId,
        );
      }
    });
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
    print('Current formData before: $formData');
    setState(() {
      formData[key] = value;
      hasUnsavedChanges = formData.isNotEmpty;
      _dummyState = DateTime.now().millisecondsSinceEpoch;
    });
    print('Updated formData after: $formData');
    print('formData.isEmpty after: ${formData.isEmpty}');
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
    return 'PM Solar - Civil & Structures';
  }

  String _getSuccessMessage() {
    final siteId = _getActualSiteId();
    return "Civil & Structures section for Solar Site (ID: $siteId) has been recorded and saved.";
  }

  String _getCancelMessage() {
    final siteId = _getActualSiteId();
    return "Do you want to cancel the Civil & Structures section for Solar Site (ID: $siteId) ?";
  }

  String _getActualSiteId() {
    // Use widget.siteId directly to avoid context issues
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
    return 'BOS';
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
    print('=== Loading Existing Data for PM Solar Page 2 (Civil & Structures) ===');
    setState(() {
      formData.clear();
      photoIds.clear();
      photoTimestamps.clear();
      loadedImageUrls.clear();
      _retryCounts.clear();
      _imageQueue.clear();

      final civilData = data.responseData?.civilStructures ?? [];
      print('Civil data: $civilData');
      for (final item in civilData) {
        final pmItemType = item['pm_item_type'] ?? '';
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
        } else {
          print('No photoId for key $key');
        }

        if (item['photo_taken_ts'] != null) {
          photoTimestamps[key] = item['photo_taken_ts'];
          print('Added to photoTimestamps: $key = ${item['photo_taken_ts']}');
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

    if (!mounted) {
      print('Widget is not mounted, skipping image fetch');
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
    const maxRetries = 5;
    const retryDelay = Duration(seconds: 3);

    if (!mounted) {
      print('Widget is not mounted, skipping image retry');
      return;
    }

    final currentRetryCount = _retryCounts[photoId] ?? 0;
    if (currentRetryCount < maxRetries) {
      _retryCounts[photoId] = currentRetryCount + 1;
      print('Retrying image load for photoId: $photoId, key: $key, attempt: ${_retryCounts[photoId]} of $maxRetries');
      await Future.delayed(retryDelay);
      
      if (!mounted) {
        print('Widget is not mounted after retry delay, skipping image fetch');
        return;
      }
      
      _imageQueue.insert(0, {'photoId': photoId, 'key': key});
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

    final civilData = widget.pmData?.responseData?.civilStructures ?? [];
    final bool isEditable = _checkCivilDependencies(item, civilData);
    return isEditable;
  }

  bool _checkCivilDependencies(dynamic item, List<dynamic> sectionData) {
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
    final civilData = widget.pmData?.responseData?.civilStructures ?? [];
    bool allRequiredFilled = true;
    for (final item in civilData) {
      final key = '${item['pm_item_type']}_${item['cl_order']}';
      if (item['is_required'] == true && !formData.containsKey(key)) {
        allRequiredFilled = false;
        print('Required field missing: $key');
      }
    }

    if (formData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No data to submit')),
      );
      return;
    }

    if (!allRequiredFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }


    final cubit = context.read<PmCubit>();
    final state = cubit.state;

    PmGetDataModel? pmDataToUse;
    if (state is PmGetLoaded) {
      pmDataToUse = state.pmGetDataModel;
    } else if (widget.pmData != null) {
      pmDataToUse = widget.pmData;
    } else {
      setState(() {
        isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data not available, please reload')),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
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
    } catch (e) {
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
    print('Remarks data: $remarksData');
    return remarksData;
  }

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      // Try to update audit status if the provider is available
      final auditCubit = context.read<AuditScheduleStatusCubit>();
      await auditCubit.updateStatus(
        status: status,
        siteAuditSchId: widget.siteAuditSchId,
      );
    } catch (e) {
      // Silently fail if provider is not available - this is not critical for the form flow
      print('Audit status update skipped: $e');
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
                builder: (dialogContext) => UnsavedChangesDialog(
                  message: _getCancelMessage(),
                  onSaveAndExit: () async {
                    Navigator.of(dialogContext).pop();
                    await _submitForm();
                    _saveAndExit();
                  },
                  onDiscard: () {
                    print('Discard selected');
                    Navigator.of(dialogContext).pop();
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
                  print('Showing unsaved changes dialog on appbar close');
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) => UnsavedChangesDialog(
                      message: _getCancelMessage(),
                      onSaveAndExit: () async {
                        print('Save and exit selected from appbar');
                        Navigator.of(dialogContext).pop();
                        await _submitForm();
                        _saveAndExit();
                      },
                      onDiscard: () async {
                        print('Discard selected from appbar');
                        Navigator.of(dialogContext).pop();
                        // Skip audit status update to avoid provider issues
                        Navigator.pop(context);
                      },
                    ),
                  );
                } else {
                  print('No unsaved changes, closing');
                  // Skip audit status update to avoid provider issues
                  Navigator.pop(context);
                }
              },
            ),
            body: widget.pmData == null
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(widget.pmData!, context),
          ),
        );
  }

  Widget _buildContent(PmGetDataModel data, BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PmCubit, PmState>(
          listener: (context, state) {
            print('PmCubit state changed: $state');
            if (state is PmGetLoaded) {
              print('PmGetLoaded triggered with Civil & Structures data: ${state.pmGetDataModel.responseData?.civilStructures}');
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
              // Don't call _saveAndExit() here - let the BOS button handle navigation
            } else if (state is PmPostError) {
              print('Post error: ${state.message}');
              setState(() {
                isSubmitting = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error saving data: ${state.message}')),
              );
            } else if (state is PmPosting) {
              print('Posting data...');
              setState(() {
                isSubmitting = true;
              });
            }
          },
        ),
        BlocListener<AssetAuditPhotoUploadCubit, AssetAuditPhotoUploadState>(
          listener: (context, state) {
            if (state is AssetAuditPhotoUploadSuccess) {
              if (_currentUploadKey != null) {
                final photoId = int.tryParse(state.response.imgId) ?? 0;
                final timestamp = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
                final keyToSave = _currentUploadKey!;
                setState(() {
                  photoIds[keyToSave] = photoId;
                  photoTimestamps[keyToSave] = timestamp;
                  _currentUploadKey = null;
                  _dummyState = DateTime.now().millisecondsSinceEpoch;
                });
              } else {
                print('Photo upload success but _currentUploadKey is null');
              }
            } else if (state is AssetAuditPhotoUploadFailure) {
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
              if (_lastRequestedPhotoId != null) {
                final key = _imageRequestKeys[_lastRequestedPhotoId];
                if (key != null) {
                  if (imageData.isNotEmpty) {
                    setState(() {
                      loadedImageUrls[key] = imageData;
                      _dummyState = DateTime.now().millisecondsSinceEpoch;
                    });
                    _imageRequestKeys.remove(_lastRequestedPhotoId);
                    _retryCounts.remove(_lastRequestedPhotoId);
                  } else {
                    await _handleImageLoadRetry(_lastRequestedPhotoId!, key);
                  }
                } else {
                  print('No key found for photoId: $_lastRequestedPhotoId');
                }
                _lastRequestedPhotoId = null;
              }
            } else if (state is AssetAuditGetImageFailure) {
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
            }
            _fetchingImage = false;
            _fetchNextImage();
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
                      child: _buildCivilStructuresSection(data),
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
                            print('Back button pressed');
                            if (hasUnsavedChanges) {
                              await _submitForm();
                            }
                            // Pass updated data back to previous screen
                            Navigator.pop(context, widget.pmData);
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
                          onPressed: isSubmitting
                              ? null
                              : () async {
                            print('=== BOS button pressed ===');
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
                            print('Navigating to PmSolarPage3');
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PmSolarPage3(
                                  ticketType: widget.ticketType,
                                  auditSchId: widget.auditSchId,
                                  siteAuditSchId: widget.siteAuditSchId,
                                  siteId: widget.siteId,
                                  pmData: widget.pmData,
                                ),
                              ),
                            );
                            
                            // If data was returned from Page 3, update the current page
                            if (result != null && result is PmGetDataModel) {
                              setState(() {
                                // Update the pmData with the returned data
                                // This will trigger a rebuild with the updated data
                              });
                              // Reload the data to reflect changes
                              _loadExistingData(result);
                            }
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

  Widget _buildCivilStructuresSection(PmGetDataModel data) {
    final civilData = data.responseData?.civilStructures ?? [];

    if (civilData.isEmpty) {
      return const Center(
        child: Text(
          'No Civil & Structures data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...civilData.map((item) => Column(
          children: [
            _buildFormField(item),
            SizedBox(height: 15),
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
    final bool isEditable = _isFieldEditable(item);


    if (respType.contains('TEXT')) {
      return CustomFormField(
        label: checklistDesc,
        hintText: checklistDesc,
        initialValue: formData[key] ?? '',
        isRequired: item['is_required'] == true,
        isEditable: isEditable,
        controller: _getTextController(key, formData[key] ?? ''),
        onChanged: (value) {
          print('Text field changed: $key = $value');
          _saveFormData(key, value);
        },
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
                    items: isEditable ? options : [],
                    initialValue: isEditable ? (formData[key] ?? '') : null,
                    onChanged: isEditable
                        ? (value) {
                      print('Dropdown changed: $key = $value');
                      _saveFormData(key, value);
                    }
                        : (_) {},
                    isRequired: item['is_required'] == true,
                  ),
                  SizedBox(height: 10),
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
                    ),
                ],
              ),
            ),
            SizedBox(height: 15),
          ],
        );
      } else {
        return CustomDropdown(
          label: checklistDesc,
          items: isEditable ? options : [],
          initialValue: isEditable ? (formData[key] ?? '') : null,
          onChanged: isEditable
              ? (value) {
            _saveFormData(key, value);
          }
              : (_) {},
          isRequired: item['is_required'] == true,
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
              onChanged: (value) {
                print('Radio changed: $key = $value');
                _saveFormData(key, value);
              },
            ),
            SizedBox(height: 10),
            if (isEditable)
              ImageUploadField(
                label: "Upload Image",
                externalImageUrl: loadedImageUrls[key],
                onImageSelected: (file) async {
                  print('Image selected for key: $key');
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
          onChanged: (value) {
            _saveFormData(key, value);
          },
        );
      }
    } else if (respType.contains('REMARKS') || checklistDesc.toLowerCase().contains('remarks')) {
      return CustomFormField(
        hintText: checklistDesc,
        label: checklistDesc,
        initialValue: formData[key] ?? '',
        isRequired: item['is_required'] == true,
        isEditable: isEditable,
        controller: _getRemarksController(key, formData[key] ?? ''),
        onChanged: (value) {
          _saveFormData(key, value);
        },
      );
    }

    return CustomFormField(
      hintText: checklistDesc,
      label: checklistDesc,
      initialValue: formData[key] ?? '',
      isRequired: item['is_required'] == true,
      isEditable: isEditable,
      controller: _getTextController(key, formData[key] ?? ''),
      onChanged: (value) {
        print('Default text field changed: $key = $value');
        _saveFormData(key, value);
      },
    );
  }
}