import 'package:app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/bloc/pm_bloc/pm_cubit.dart';
import 'package:app/bloc/pm_bloc/pm_state.dart';
import 'package:app/bloc/asset_audit_photo_upload_cubit.dart';
import 'package:app/bloc/asset_audit_get_image_cubit.dart';
import 'package:app/bloc/audit_schedule_status_cubit.dart';
import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_dropdown.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import 'package:app/commonWidgets/custom_dialogs/success_dialog.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/models/PmGetDataModel.dart';
import 'package:app/enum/pm_ticket_type_enum.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/screens/preventive_maintainance/pm_solar_pages/pm_solar_page_2.dart';
import 'dart:io';
import 'package:intl/intl.dart';

import '../../../commonWidgets/custom_radio_options.dart';
import '../../../constants/constants_strings.dart';
import '../../../repositories/audit_schedule_repository.dart';
import '../../ticket_screen.dart';

class PmSolarPage1 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;
  final PmGetDataModel pmData;

  const PmSolarPage1({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
    required this.pmData,
  });

  @override
  State<PmSolarPage1> createState() => _PmSolarPage1State();
}


class _PmSolarPage1State extends State<PmSolarPage1> {
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
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.pmData != null) {
        _loadExistingData(widget.pmData!);
      } else {
        context.read<PmCubit>().getPmData(
          siteType: widget.ticketType.name,
          auditSchId: widget.auditSchId,
          siteAuditSchId: widget.siteAuditSchId,
        );
      }
    });
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
      _onFormChanged();
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
    return 'PM Solar - Earthing';
  }

  String _getSuccessMessage() {
    final siteId = _getActualSiteId();
    return "Earthing section for Solar Site (ID: $siteId) has been recorded and saved.";
  }

  String _getCancelMessage() {
    final siteId = _getActualSiteId();
    return "Do you want to cancel the Earthing section for Solar Site (ID: $siteId) ?";
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
    return 'Civil & Structures';
  }

  Future<void> _uploadPhoto(File? file, String key) async {
    if (file == null) return;

    _currentUploadKey = key;
    final photoCubit = context.read<AssetAuditPhotoUploadCubit>();

    await photoCubit.uploadPhoto(
      file: file,
      schId: widget.siteAuditSchId,
    );
  }

  void _loadExistingData(PmGetDataModel data) {
    print('=== Loading Existing Data for PM Solar Page 1 (Earthing) ===');
    setState(() {
      formData.clear();
      photoIds.clear();
      photoTimestamps.clear();
      loadedImageUrls.clear();
      _retryCounts.clear();
      _imageQueue.clear();

      // Load Earthing section data
      final earthingData = data.responseData?.earthing ?? [];
      print('Earthing data count: ${earthingData.length}');
      print('Raw Earthing data: $earthingData');

      for (final item in earthingData) {
        final key = '${item.pmItemType}_${item.clOrder}';
        print('Processing item with key: $key');
        print('Raw pmItemType: "${item.pmItemType}"');
        print('Raw clOrder: "${item.clOrder}"');
        print('Processing item: $key, resp: ${item.resp} (type: ${item.resp.runtimeType}), photoId: ${item.photoId} (type: ${item.photoId.runtimeType}), respType: ${item.respType}');

        // resp contains dropdown values, add directly to formData
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
          final photoIdInt = int.tryParse(item.photoId.toString());
          if (photoIdInt != null) {
            photoIds[key] = photoIdInt;
            _retryCounts[photoIdInt.toString()] = 0;
            print('Added to photoIds: $key = $photoIdInt');
            // Add to queue for serial fetching
            _imageQueue.add({'photoId': photoIdInt.toString(), 'key': key});
          } else {
            print('Invalid photoId format for key $key: ${item.photoId}');
          }
        } else {
          print('No photoId for key $key');
        }

        if (item.photoTakenTs != null) {
          photoTimestamps[key] = item.photoTakenTs!;
          print('Added to photoTimestamps: $key = ${item.photoTakenTs}');
        }

        // Load remarks data if available
        if (item.remarks != null && item.remarks.toString().isNotEmpty) {
          _getRemarksController(key, item.remarks.toString());
          print('Added to remarks: $key = ${item.remarks}');
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
      _retryCounts.remove(photoId);
      _imageRequestKeys.remove(photoId);
    }
  }

  bool _isFieldEditable(dynamic item) {
    final respType = item.respType ?? '';

    if (respType.contains('RADIO')) {
      return true;
    }

    final earthingData = widget.pmData?.responseData?.earthing ?? [];
    final bool isEditable = _checkEarthingDependencies(item, earthingData);

    return isEditable;
  }

  bool _checkEarthingDependencies(dynamic item, List<dynamic> sectionData) {
    final itemDesc = item.checklistDesc?.toLowerCase() ?? '';

    if (itemDesc.contains('rectification remarks')) {
      for (final dropdownItem in sectionData) {
        if (dropdownItem.respType?.contains('DROPDOWN') == true) {
          final dropdownKey = '${dropdownItem.pmItemType}_${dropdownItem.clOrder}';
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
    if (formData.isEmpty) return;

    final cubit = context.read<PmCubit>();
    final state = cubit.state;

    if (state is PmGetLoaded) {
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
    }

    // Added: Check state after await to confirm success
    final postState = cubit.state;
    if (postState is! PmPostSuccess) {
      print('Form submission did not succeed. Current state: $postState');
      return; // Don't proceed if not success
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
      print('Attempting to update status to: $status'); // Added for debugging
      await context.read<AuditScheduleStatusCubit>().updateStatus(
        status: status,
        siteAuditSchId: widget.siteAuditSchId,
      );
      print('Status update call completed'); // Added for debugging
    } catch (e) {
      print('Error updating audit schedule status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  void _saveAndExit() async {
    await _updateAuditScheduleStatus("In Progress");
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen()
        //     TicketScreen(
        //   auditName: "PM",
        //   status: "In Progress",
        // ),
      ),
    );
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
                  Navigator.of(context).pop(); // Pop dialog
                  await _submitForm();
                  _saveAndExit();
                },
                onDiscard: () async {
                  Navigator.of(context).pop(); // Pop dialog
                  await _updateAuditScheduleStatus("in-progress"); // Added for consistency
                  setState(() {
                    hasUnsavedChanges = false;
                  });
                  Navigator.pop(context); // Pop page (now canPop=true)
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
                      Navigator.of(context).pop(); // Pop dialog
                      await _submitForm();
                      _saveAndExit();
                    },
                    onDiscard: () async {
                      Navigator.of(context).pop(); // Pop dialog
                      await _updateAuditScheduleStatus("in-progress");
                      setState(() {
                        hasUnsavedChanges = false;
                      });
                      Navigator.pop(context); // Pop page
                    },
                  ),
                );
              } else {
                await _updateAuditScheduleStatus("in-progress");
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
              print('PmGetLoaded triggered with Earthing data: ${state.pmGetDataModel.responseData?.earthing}');
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

              // _saveAndExit(); // Keep commented as per original; flow handles it outside
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
              if (_currentUploadKey != null) {
                final photoId = int.tryParse(state.response.imgId) ?? 0;
                final timestamp = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

                setState(() {
                  photoIds[_currentUploadKey!] = photoId;
                  photoTimestamps[_currentUploadKey!] = timestamp;
                  _currentUploadKey = null;
                  _dummyState = DateTime.now().millisecondsSinceEpoch;
                });
                print('Photo uploaded: photoId=$photoId, timestamp=$timestamp for key=$_currentUploadKey');
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
        BlocListener<AuditScheduleStatusCubit, AuditScheduleStatusState>(
          listener: (context, state) {
            if (state is AuditScheduleStatusLoading) { // Assume your Cubit emits this on update start
              print('Updating status...');
              // Optional: Show loading overlay if needed
            } else if (state is AuditScheduleStatusSuccess) { // Assume success state
              print('Status updated successfully to ${state.message}');
              // Removed success snackbar as requested
            } else if (state is AuditScheduleStatusError) { // Assume failure state
              print('Status update failed: ${state.error}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update status: ${state.error}')),
              );
            }
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
                      child: _buildEarthingSection(data),
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
                            onPressed: (){
                              Navigator.pop(context);
                            }
                          // isSubmitting
                          //     ? null
                          //     : () async {
                          //   if (formData.isNotEmpty) {
                          //     await _submitForm();
                          //   }
                          //   Navigator.pop(context);
                          // },
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
                            if (formData.isNotEmpty) {
                              await _submitForm();
                              final state = context.read<PmCubit>().state;
                              if (state is PmPostSuccess) {
                                print('Submission successful, navigating to PmSolarPage2');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PmSolarPage2(
                                      ticketType: widget.ticketType,
                                      auditSchId: widget.auditSchId,
                                      siteAuditSchId: widget.siteAuditSchId,
                                      siteId: widget.siteId,
                                      pmData: widget.pmData, // Let PmSolarPage2 fetch its own data
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
                              print('No data to submit, navigating to PmSolarPage2');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PmSolarPage2(
                                    ticketType: widget.ticketType,
                                    auditSchId: widget.auditSchId,
                                    siteAuditSchId: widget.siteAuditSchId,
                                    siteId: widget.siteId,
                                    pmData: widget.pmData, // Let PmSolarPage2 fetch its own data
                                  ),
                                ),
                              );
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

  Widget _buildEarthingSection(PmGetDataModel data) {
    final earthingData = data.responseData?.earthing ?? [];

    if (earthingData.isEmpty) {
      return const Center(
        child: Text(
          'No Earthing data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...earthingData.map((item) => Column(
          children: [
            _buildFormField(item),
            getHeight(15),
          ],
        )).toList(),
      ],
    );
  }

  Widget _buildFormField(dynamic item) {
    final respType = item.respType ?? '';
    final checklistDesc = item.checklistDesc ?? '';
    final pmItemType = item.pmItemType ?? '';
    final key = '${pmItemType}_${item.clOrder}';

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

// class _PmSolarPage1State extends State<PmSolarPage1> {
//   bool hasUnsavedChanges = false;
//   bool isSubmitting = false;
//   Map<String, dynamic> formData = {};
//   Map<String, int> photoIds = {}; // Store photo IDs as integers
//   Map<String, String> photoTimestamps = {};
//   Map<String, String> loadedImageUrls = {}; // Store loaded image URLs
//   Map<String, TextEditingController> textControllers = {};
//   Map<String, TextEditingController> remarksControllers = {};
//   String? _currentUploadKey;
//   Map<String, String> _imageRequestKeys = {}; // Track which key corresponds to which photo_id request
//   String? _lastRequestedPhotoId; // Track the last requested photo ID
//   Map<String, int> _retryCounts = {}; // Track retry attempts for each photo ID
//   int _dummyState = 0; // For forcing UI rebuilds
//   List<Map<String, String>> _imageQueue = []; // Queue for serial image fetches
//   bool _fetchingImage = false; // Flag for ongoing image fetch
//
//   @override
//   void initState() {
//     super.initState();
//     if (widget.pmData != null) {
//       _loadExistingData(widget.pmData!);
//     } else {
//       context.read<PmCubit>().getPmData(
//         siteType: widget.ticketType.name,
//         auditSchId: widget.auditSchId,
//         siteAuditSchId: widget.siteAuditSchId,
//       );
//     }
//   }
//
//   void _onFormChanged() {
//     setState(() {
//       hasUnsavedChanges = formData.isNotEmpty;
//       _dummyState = DateTime.now().millisecondsSinceEpoch;
//     });
//   }
//
//   void _saveFormData(String key, dynamic value) {
//     print('Saving form data: $key = $value');
//     setState(() {
//       formData[key] = value;
//       _onFormChanged();
//     });
//     print('Updated formData: $formData');
//   }
//
//   TextEditingController _getTextController(String key, String initialValue) {
//     if (!textControllers.containsKey(key)) {
//       textControllers[key] = TextEditingController(text: initialValue);
//     } else {
//       textControllers[key]!.text = initialValue;
//     }
//     return textControllers[key]!;
//   }
//
//   TextEditingController _getRemarksController(String key, String initialValue) {
//     if (!remarksControllers.containsKey(key)) {
//       remarksControllers[key] = TextEditingController(text: initialValue);
//     } else {
//       remarksControllers[key]!.text = initialValue;
//     }
//     return remarksControllers[key]!;
//   }
//
//   String _getPmTitle() {
//     return 'PM Solar - Earthing';
//   }
//
//   String _getSuccessMessage() {
//     final siteId = _getActualSiteId();
//     return "Earthing section for Solar Site (ID: $siteId) has been recorded and saved.";
//   }
//
//   String _getCancelMessage() {
//     final siteId = _getActualSiteId();
//     return "Do you want to cancel the Earthing section for Solar Site (ID: $siteId) ?";
//   }
//
//   String _getActualSiteId() {
//     try {
//       final state = context.read<PmCubit>().state;
//       if (state is PmGetLoaded &&
//           state.pmGetDataModel.pageHeader != null &&
//           state.pmGetDataModel.pageHeader!.isNotEmpty &&
//           state.pmGetDataModel.pageHeader!.first.siteCode != null &&
//           state.pmGetDataModel.pageHeader!.first.siteCode!.isNotEmpty) {
//         return state.pmGetDataModel.pageHeader!.first.siteCode!;
//       }
//     } catch (e) {
//       print("PM Screen - Error getting site ID from PM data: $e");
//     }
//     if (widget.siteId != null && widget.siteId!.isNotEmpty && widget.siteId != "N/A") {
//       return widget.siteId!;
//     }
//     return "N/A";
//   }
//
//   String _getButtonText() {
//     return 'Civil & Structures';
//   }
//
//   Future<void> _uploadPhoto(File? file, String key) async {
//     if (file == null) return;
//
//     _currentUploadKey = key;
//     final photoCubit = context.read<AssetAuditPhotoUploadCubit>();
//
//     await photoCubit.uploadPhoto(
//       file: file,
//       schId: widget.siteAuditSchId,
//     );
//   }
//
//   void _loadExistingData(PmGetDataModel data) {
//     print('=== Loading Existing Data for PM Solar Page 1 (Earthing) ===');
//     setState(() {
//       formData.clear();
//       photoIds.clear();
//       photoTimestamps.clear();
//       loadedImageUrls.clear();
//       _retryCounts.clear();
//       _imageQueue.clear();
//
//       // Load Earthing section data
//       final earthingData = data.responseData?.earthing ?? [];
//       print('Earthing data count: ${earthingData.length}');
//       print('Raw Earthing data: $earthingData');
//
//       for (final item in earthingData) {
//         final key = '${item.pmItemType}_${item.clOrder}';
//         print('Processing item with key: $key');
//         print('Raw pmItemType: "${item.pmItemType}"');
//         print('Raw clOrder: "${item.clOrder}"');
//         print('Processing item: $key, resp: ${item.resp} (type: ${item.resp.runtimeType}), photoId: ${item.photoId} (type: ${item.photoId.runtimeType}), respType: ${item.respType}');
//
//         // resp contains dropdown values, add directly to formData
//         if (item.resp != null) {
//           String mappedValue;
//           if (item.resp is int) {
//             print('Warning: resp is int (${item.resp}), converting to String');
//             final respValue = item.resp.toString();
//             if (item.respType?.contains('DROPDOWN') ?? false) {
//               const dropdownOptions = [
//                 'OK',
//                 'Corrected',
//                 'Not OK - To be corrected',
//                 'Not Applicable',
//               ];
//               try {
//                 mappedValue = dropdownOptions[int.parse(respValue)];
//               } catch (e) {
//                 mappedValue = respValue;
//                 print('Failed to map resp to dropdown option: $respValue');
//               }
//             } else if (item.respType?.contains('RADIO') ?? false) {
//               mappedValue = respValue == '1' ? 'yes' : 'no';
//             } else {
//               mappedValue = respValue;
//             }
//           } else {
//             mappedValue = item.resp.toString();
//           }
//           formData[key] = mappedValue;
//           print('Added to formData: $key = $mappedValue');
//         }
//
//         if (item.photoId != null) {
//           final photoIdInt = int.tryParse(item.photoId.toString());
//           if (photoIdInt != null) {
//             photoIds[key] = photoIdInt;
//             _retryCounts[photoIdInt.toString()] = 0;
//             print('Added to photoIds: $key = $photoIdInt');
//             // Add to queue for serial fetching
//             _imageQueue.add({'photoId': photoIdInt.toString(), 'key': key});
//           } else {
//             print('Invalid photoId format for key $key: ${item.photoId}');
//           }
//         } else {
//           print('No photoId for key $key');
//         }
//
//         if (item.photoTakenTs != null) {
//           photoTimestamps[key] = item.photoTakenTs!;
//           print('Added to photoTimestamps: $key = ${item.photoTakenTs}');
//         }
//
//         // Load remarks data if available
//         if (item.remarks != null && item.remarks.toString().isNotEmpty) {
//           _getRemarksController(key, item.remarks.toString());
//           print('Added to remarks: $key = ${item.remarks}');
//         }
//       }
//
//       print('Final formData: $formData');
//       print('Final photoIds: $photoIds');
//       print('Final photoTimestamps: $photoTimestamps');
//       print('Final loadedImageUrls: $loadedImageUrls');
//       _dummyState = DateTime.now().millisecondsSinceEpoch;
//     });
//
//     _fetchNextImage(); // Start processing the queue
//
//     // Fallback: Re-fetch missing images after a delay
//     Future.delayed(const Duration(seconds: 5), () {
//       for (final key in photoIds.keys) {
//         if (!loadedImageUrls.containsKey(key) && photoIds[key] != null) {
//           print('Fallback: Re-fetching image for key: $key, photoId: ${photoIds[key]}');
//           _imageQueue.add({'photoId': photoIds[key]!.toString(), 'key': key});
//           _fetchNextImage();
//         }
//       }
//     });
//   }
//
//   void _fetchNextImage() {
//     if (_fetchingImage || _imageQueue.isEmpty) return;
//
//     _fetchingImage = true;
//
//     final image = _imageQueue.removeAt(0);
//     final photoId = image['photoId']!;
//     final key = image['key']!;
//
//     print('Loading image for photoId: $photoId, key: $key, retry count: ${_retryCounts[photoId] ?? 0}');
//     _imageRequestKeys[photoId] = key;
//     _lastRequestedPhotoId = photoId;
//     final imageCubit = context.read<AssetAuditGetImageCubit>();
//     imageCubit.getImage(imgId: photoId, schId: widget.siteAuditSchId);
//   }
//
//   Future<void> _handleImageLoadRetry(String photoId, String key) async {
//     const maxRetries = 5;
//     const retryDelay = Duration(seconds: 3);
//
//     final currentRetryCount = _retryCounts[photoId] ?? 0;
//     if (currentRetryCount < maxRetries) {
//       _retryCounts[photoId] = currentRetryCount + 1;
//       print('Retrying image load for photoId: $photoId, key: $key, attempt: ${_retryCounts[photoId]} of $maxRetries');
//       await Future.delayed(retryDelay);
//       _imageQueue.insert(0, {'photoId': photoId, 'key': key}); // Add to front of queue for retry
//       _fetchNextImage();
//     } else {
//       _retryCounts.remove(photoId);
//       _imageRequestKeys.remove(photoId);
//     }
//   }
//
//   bool _isFieldEditable(dynamic item) {
//     final respType = item.respType ?? '';
//
//     if (respType.contains('RADIO')) {
//       return true;
//     }
//
//     final earthingData = widget.pmData?.responseData?.earthing ?? [];
//     final bool isEditable = _checkEarthingDependencies(item, earthingData);
//
//     return isEditable;
//   }
//
//   bool _checkEarthingDependencies(dynamic item, List<dynamic> sectionData) {
//     final itemDesc = item.checklistDesc?.toLowerCase() ?? '';
//
//     if (itemDesc.contains('rectification remarks')) {
//       for (final dropdownItem in sectionData) {
//         if (dropdownItem.respType?.contains('DROPDOWN') == true) {
//           final dropdownKey = '${dropdownItem.pmItemType}_${dropdownItem.clOrder}';
//           final dropdownValue = formData[dropdownKey];
//
//           if (dropdownValue == 'Not OK - To be corrected') {
//             return true;
//           }
//         }
//       }
//       return false;
//     }
//
//     return true;
//   }
//
//   Future<void> _submitForm() async {
//     if (formData.isEmpty) return;
//
//     final cubit = context.read<PmCubit>();
//     final state = cubit.state;
//
//     if (state is PmGetLoaded) {
//       await cubit.postPmData(
//         formData: formData,
//         pmData: state.pmGetDataModel,
//         auditSchId: widget.auditSchId,
//         siteAuditSchId: widget.siteAuditSchId,
//         siteId: widget.siteId ?? '',
//         photoIds: photoIds,
//         photoTimestamps: photoTimestamps,
//         remarksData: _getRemarksData(),
//       );
//     }
//   }
//
//   Map<String, String> _getRemarksData() {
//     Map<String, String> remarksData = {};
//     remarksControllers.forEach((key, controller) {
//       if (controller.text.isNotEmpty) {
//         remarksData[key] = controller.text;
//       }
//     });
//     return remarksData;
//   }
//
//   Future<void> _updateAuditScheduleStatus(String status) async {
//     try {
//       await context.read<AuditScheduleStatusCubit>().updateStatus(
//         status: status,
//         siteAuditSchId: widget.siteAuditSchId,
//       );
//     } catch (e) {
//       print('Error updating audit schedule status: $e');
//     }
//   }
//
//   void _saveAndExit() async {
//     await _updateAuditScheduleStatus("in progress");
//     Navigator.of(context).pop();
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => SuccessDialog(
//         ticketId: "$widget.siteId",
//         message: _getSuccessMessage(),
//         onDone: () {
//           Navigator.of(context).pop();
//           Navigator.of(context).pop();
//         },
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     for (var controller in textControllers.values) {
//       controller.dispose();
//     }
//     for (var controller in remarksControllers.values) {
//       controller.dispose();
//     }
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return BlocProvider(
//       create: (context) => AuditScheduleStatusCubit(),
//       child: PopScope(
//       canPop: !hasUnsavedChanges,
//       onPopInvoked: (didPop) async {
//         if (didPop) return;
//
//         if (hasUnsavedChanges) {
//           showDialog(
//             context: context,
//             barrierDismissible: false,
//             builder: (context) => UnsavedChangesDialog(
//               message: _getCancelMessage(),
//               onSaveAndExit: () async {
//                 Navigator.of(context).pop();
//                 await _submitForm();
//                 _saveAndExit();
//               },
//               onDiscard: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           );
//         }
//       },
//       child: Scaffold(
//         extendBodyBehindAppBar: true,
//         resizeToAvoidBottomInset: false,
//         appBar: CustomFormAppbar(
//           title: _getPmTitle(),
//           onClose: () async {
//             if (hasUnsavedChanges) {
//               showDialog(
//                 context: context,
//                 barrierDismissible: false,
//                 builder: (context) => UnsavedChangesDialog(
//                   message: _getCancelMessage(),
//                   onSaveAndExit: () async {
//                     Navigator.of(context).pop();
//                     await _submitForm();
//                     _saveAndExit();
//                   },
//                   onDiscard: () async {
//                     Navigator.of(context).pop();
//                     await _updateAuditScheduleStatus("in-progress");
//                     Navigator.pop(context);
//                   },
//                 ),
//               );
//             } else {
//               await _updateAuditScheduleStatus("in-progress");
//               Navigator.pop(context);
//             }
//           },
//         ),
//         body: _buildContent(widget.pmData!),
//       ),
//       ),
//     );
//   }
//
//   Widget _buildContent(PmGetDataModel data) {
//     return MultiBlocListener(
//       listeners: [
//         BlocListener<PmCubit, PmState>(
//           listener: (context, state) {
//             if (state is PmGetLoaded) {
//               print('PmGetLoaded triggered with Earthing data: ${state.pmGetDataModel.responseData?.earthing}');
//               _loadExistingData(state.pmGetDataModel);
//             } else if (state is PmPostSuccess) {
//               print('Post successful, clearing form data');
//               setState(() {
//                 isSubmitting = false;
//                 formData.clear();
//                 photoIds.clear();
//                 photoTimestamps.clear();
//                 loadedImageUrls.clear();
//                 _retryCounts.clear();
//                 for (final controller in textControllers.values) {
//                   controller.clear();
//                 }
//                 for (final controller in remarksControllers.values) {
//                   controller.clear();
//                 }
//                 hasUnsavedChanges = false;
//                 _dummyState = DateTime.now().millisecondsSinceEpoch;
//               });
//
//               // _saveAndExit();
//             } else if (state is PmPostError) {
//               print('Post error: ${state.message}');
//               setState(() {
//                 isSubmitting = false;
//               });
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('Error saving data: ${state.message}')),
//               );
//             } else if (state is PmPosting) {
//               setState(() {
//                 isSubmitting = true;
//               });
//             }
//           },
//         ),
//         BlocListener<AssetAuditPhotoUploadCubit, AssetAuditPhotoUploadState>(
//           listener: (context, state) {
//             if (state is AssetAuditPhotoUploadSuccess) {
//               if (_currentUploadKey != null) {
//                 final photoId = int.tryParse(state.response.imgId) ?? 0;
//                 final timestamp = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
//
//                 setState(() {
//                   photoIds[_currentUploadKey!] = photoId;
//                   photoTimestamps[_currentUploadKey!] = timestamp;
//                   _currentUploadKey = null;
//                   _dummyState = DateTime.now().millisecondsSinceEpoch;
//                 });
//                 print('Photo uploaded: photoId=$photoId, timestamp=$timestamp for key=$_currentUploadKey');
//               }
//             } else if (state is AssetAuditPhotoUploadFailure) {
//               print('Photo upload failed: ${state.errorMessage}');
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('Photo upload failed: ${state.errorMessage}')),
//               );
//             }
//           },
//         ),
//         BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
//           listener: (context, state) async {
//             if (state is AssetAuditGetImageSuccess) {
//               final imageData = state.imageData;
//               print('Image loaded for photoId: $_lastRequestedPhotoId, data length: ${imageData.length}, data: ${imageData.substring(0, imageData.length > 50 ? 50 : imageData.length)}...');
//               if (_lastRequestedPhotoId != null) {
//                 final key = _imageRequestKeys[_lastRequestedPhotoId];
//                 if (key != null) {
//                   if (imageData.isNotEmpty) {
//                     setState(() {
//                       loadedImageUrls[key] = imageData;
//                       _dummyState = DateTime.now().millisecondsSinceEpoch;
//                       print('Updated loadedImageUrls: $key = ${imageData.substring(0, imageData.length > 50 ? 50 : imageData.length)}...');
//                     });
//                     _imageRequestKeys.remove(_lastRequestedPhotoId);
//                     _retryCounts.remove(_lastRequestedPhotoId);
//                   } else {
//                     print('Empty imageData for photoId: $_lastRequestedPhotoId');
//                     await _handleImageLoadRetry(_lastRequestedPhotoId!, key);
//                   }
//                 } else {
//                   print('No key found for photoId: $_lastRequestedPhotoId');
//                 }
//                 _lastRequestedPhotoId = null;
//               }
//             } else if (state is AssetAuditGetImageFailure) {
//               print('Image load failed for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}');
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(content: Text('Failed to load image: ${state.errorMessage}')),
//               );
//               if (_lastRequestedPhotoId != null) {
//                 final key = _imageRequestKeys[_lastRequestedPhotoId];
//                 if (key != null) {
//                   await _handleImageLoadRetry(_lastRequestedPhotoId!, key);
//                 } else {
//                   print('No key found for failed photoId: $_lastRequestedPhotoId');
//                 }
//                 _imageRequestKeys.remove(_lastRequestedPhotoId);
//                 _lastRequestedPhotoId = null;
//               }
//             }
//             _fetchingImage = false;
//             _fetchNextImage(); // Fetch the next image in the queue
//           },
//         ),
//       ],
//       child: Stack(
//         children: [
//           Positioned.fill(
//             child: SvgPicture.asset(
//               AppImages.home,
//               fit: BoxFit.cover,
//               width: double.infinity,
//               height: double.infinity,
//             ),
//           ),
//           SafeArea(
//             child: Column(
//               children: [
//                 Expanded(
//                   child: SingleChildScrollView(
//                     padding: EdgeInsets.only(
//                       bottom: MediaQuery.of(context).viewInsets.bottom + 120,
//                     ),
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 20,
//                       ),
//                       child: _buildEarthingSection(data),
//                     ),
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.all(16),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Expanded(
//                         child: ArrowButton(
//                           text: 'Back',
//                           isLeftArrow: true,
//                           backgroundColor: AppColors.buttonColorBackBg,
//                           textColor: AppColors.buttonColorTextBg,
//                           onPressed: (){
//                             Navigator.pop(context);
//                           }
//                           // isSubmitting
//                           //     ? null
//                           //     : () async {
//                           //   if (formData.isNotEmpty) {
//                           //     await _submitForm();
//                           //   }
//                           //   Navigator.pop(context);
//                           // },
//                         ),
//                       ),
//                       getWidth(10),
//                       Expanded(
//                         child: ArrowButton(
//                           text: _getButtonText(),
//                           isLeftArrow: false,
//                           backgroundColor: AppColors.buttonColorBg,
//                           textColor: AppColors.buttonColorSite,
//                           onPressed: isSubmitting
//                               ? null
//                               : () async {
//                             if (formData.isNotEmpty) {
//                               await _submitForm();
//                             }
//
//                             // Navigate to next page (Civil & Structures)
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => PmSolarPage2(
//                                   ticketType: widget.ticketType,
//                                   auditSchId: widget.auditSchId,
//                                   siteAuditSchId: widget.siteAuditSchId,
//                                   siteId: widget.siteId,
//                                   pmData: widget.pmData, // Let PmSolarPage2 fetch its own data
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (isSubmitting)
//             Container(
//               color: Colors.black.withOpacity(0.3),
//               child: const Center(
//                 child: CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEarthingSection(PmGetDataModel data) {
//     final earthingData = data.responseData?.earthing ?? [];
//
//     if (earthingData.isEmpty) {
//       return const Center(
//         child: Text(
//           'No Earthing data available',
//           style: TextStyle(fontSize: 16, color: Colors.grey),
//         ),
//       );
//     }
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         ...earthingData.map((item) => Column(
//           children: [
//             _buildFormField(item),
//             getHeight(15),
//           ],
//         )).toList(),
//       ],
//     );
//   }
//
//   Widget _buildFormField(dynamic item) {
//     final respType = item.respType ?? '';
//     final checklistDesc = item.checklistDesc ?? '';
//     final pmItemType = item.pmItemType ?? '';
//     final key = '${pmItemType}_${item.clOrder}';
//
//     // Check if this field should be editable based on other field selections
//     final bool isEditable = _isFieldEditable(item);
//
//     if (respType.contains('TEXT')) {
//       return CustomFormField(
//         label: checklistDesc,
//         hintText: checklistDesc,
//         initialValue: formData[key] ?? '',
//         isRequired: false,
//         isEditable: isEditable,
//         controller: _getTextController(key, formData[key] ?? ''),
//         onChanged: (value) => _saveFormData(key, value),
//       );
//     } else if (respType.contains('DROPDOWN')) {
//       List<String> options = ['OK', 'Corrected', 'Not OK - To be corrected', 'Not Applicable'];
//       if (respType.contains('IMG')) {
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               checklistDesc,
//               style: const TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.white,
//                 fontFamily: fontFamilyMontserrat,
//               ),
//             ),
//             getHeight(8),
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: AppColors.green7,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   CustomDropdown(
//                     label: 'Status',
//                     items: isEditable ? options : [],
//                     initialValue: isEditable ? (formData[key] ?? '') : null,
//                     onChanged: isEditable ? (value) => _saveFormData(key, value) : (_) {},
//                     isRequired: false,
//                   ),
//                   getHeight(10),
//                   if (isEditable)
//                     ImageUploadField(
//                       label: "Add Photo",
//                       externalImageUrl: loadedImageUrls[key],
//                       onImageSelected: (file) async {
//                         if (file != null) {
//                           await _uploadPhoto(file, key);
//                         }
//                       },
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         );
//       } else {
//         return CustomDropdown(
//           label: checklistDesc,
//           items: isEditable ? options : [],
//           initialValue: isEditable ? (formData[key] ?? '') : null,
//           onChanged: isEditable ? (value) => _saveFormData(key, value) : (_) {},
//           isRequired: false,
//         );
//       }
//     } else if (respType.contains('RADIO')) {
//       if (respType.contains('IMG')) {
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             CustomOptionSelector(
//               label: checklistDesc,
//               options: [
//                 OptionItem(
//                   value: "yes",
//                   label: "OK",
//                   selectedIcon: Icons.circle_outlined,
//                   unselectedIcon: Icons.circle_outlined,
//                 ),
//                 OptionItem(
//                   value: "no",
//                   label: "Not OK",
//                   selectedIcon: Icons.circle_outlined,
//                   unselectedIcon: Icons.circle_outlined,
//                 ),
//               ],
//               initialValue: formData[key] ?? 'yes',
//               onChanged: (value) => _saveFormData(key, value),
//             ),
//             getHeight(10),
//             if (isEditable)
//               ImageUploadField(
//                 label: "Upload Image",
//                 externalImageUrl: loadedImageUrls[key],
//                 onImageSelected: (file) async {
//                   if (file != null) {
//                     await _uploadPhoto(file, key);
//                   }
//                 },
//               ),
//           ],
//         );
//       } else {
//         return CustomOptionSelector(
//           label: checklistDesc,
//           options: [
//             OptionItem(
//               value: "yes",
//               label: "OK",
//               selectedIcon: Icons.circle_outlined,
//               unselectedIcon: Icons.circle_outlined,
//             ),
//             OptionItem(
//               value: "no",
//               label: "Not OK",
//               selectedIcon: Icons.circle_outlined,
//               unselectedIcon: Icons.circle_outlined,
//             ),
//           ],
//           initialValue: formData[key] ?? 'yes',
//           onChanged: (value) => _saveFormData(key, value),
//         );
//       }
//     } else if (respType.contains('REMARKS') || checklistDesc.toLowerCase().contains('remarks')) {
//       return CustomFormField(
//         hintText: checklistDesc,
//         label: checklistDesc,
//         initialValue: formData[key] ?? '',
//         isRequired: false,
//         isEditable: isEditable,
//         controller: _getRemarksController(key, formData[key] ?? ''),
//         onChanged: (value) => _saveFormData(key, value),
//       );
//     }
//
//     return CustomFormField(
//       hintText: checklistDesc,
//       label: checklistDesc,
//       initialValue: formData[key] ?? '',
//       isRequired: false,
//       isEditable: isEditable,
//       controller: _getTextController(key, formData[key] ?? ''),
//       onChanged: (value) => _saveFormData(key, value),
//     );
//   }
//
// }
