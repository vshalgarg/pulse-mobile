import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/models/PmGetDataModel.dart';
import 'package:app/screens/preventive_maintainance/pm_pages/pm_page_7.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import '../../../bloc/pm_bloc/pm_cubit.dart';
import '../../../bloc/pm_bloc/pm_state.dart';
import '../../../bloc/asset_audit_photo_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_dropdown.dart';
import '../../../commonWidgets/custom_image_upload_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../constants/constants_strings.dart';
import '../../../enum/pm_ticket_type_enum.dart';
import '../../home_screen.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class PmScreen6 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;
  final PmGetDataModel? pmData;

  const PmScreen6({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
    this.pmData,
  });

  @override
  State<PmScreen6> createState() => _PmScreen6();
}

class _PmScreen6 extends State<PmScreen6> {
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

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      print('Updating audit schedule status to: $status');
      await context.read<AuditScheduleStatusCubit>().updateStatus(
        status: status,
        siteAuditSchId: widget.siteAuditSchId,
      );
    } catch (e) {
      print('Error updating audit schedule status: $e');
    }
  }

  Future<void> _saveAndExit() async {
    print('Save and Exit called');
    await _updateAuditScheduleStatus("In Progress");
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(),
        ),
      );
    }
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
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "PM Telecom - DG";
      case PmTicketTypeEnum.solar:
        return "PM Solar - DG";
    }
  }

  String _getSuccessMessage() {
    final siteId = _getActualSiteId();
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "DG section for Telecom Site (ID: $siteId) has been recorded and saved.";
      case PmTicketTypeEnum.solar:
        return "DG section for Solar Site (ID: $siteId) has been recorded and saved.";
    }
  }

  String _getCancelMessage() {
    final siteId = _getActualSiteId();
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "Do you want to cancel the DG section for Telecom Site (ID: $siteId) ?";
      case PmTicketTypeEnum.solar:
        return "Do you want to cancel the DG section for Solar Site (ID: $siteId) ?";
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
    if (widget.siteId != null && widget.siteId!.isNotEmpty && widget.siteId != "N/A") {
      return widget.siteId!;
    }
    return "N/A";
  }

  String _getButtonText() {
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "Solar";
      case PmTicketTypeEnum.solar:
        return "Solar";
    }
  }

  Future<void> _uploadPhoto(File? file, String key) async {
    if (file == null) return;

    print('Uploading photo for key: $key');
    _currentUploadKey = key;
    final photoCubit = context.read<AssetAuditPhotoUploadCubit>();

    await photoCubit.uploadPhoto(
      file: file,
      schId: widget.siteAuditSchId,
    );
  }

  void _loadExistingData(PmGetDataModel data) {
    print('=== Loading Existing Data for PM Page 6 ===');
    setState(() {
      formData.clear();
      photoIds.clear();
      photoTimestamps.clear();
      loadedImageUrls.clear();
      _retryCounts.clear();
      _imageQueue.clear();

      final dgData = data.responseData?.dg ?? [];
      print('DG data count: ${dgData.length}');
      print('Raw DG data: $dgData');

      for (final item in dgData) {
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
          final photoIdInt = int.tryParse(item.photoId.toString());
          if (photoIdInt != null) {
            photoIds[key] = photoIdInt;
            _retryCounts[photoIdInt.toString()] = 0;
            print('Added to photoIds: $key = $photoIdInt');
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

    _fetchNextImage();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        for (final key in photoIds.keys) {
          if (!loadedImageUrls.containsKey(key) && photoIds[key] != null) {
            print('Fallback: Re-fetching image for key: $key, photoId: ${photoIds[key]}');
            _imageQueue.add({'photoId': photoIds[key]!.toString(), 'key': key});
            _fetchNextImage();
          }
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
      _imageQueue.insert(0, {'photoId': photoId, 'key': key});
      _fetchNextImage();
    } else {
      print('Max retries reached for photoId: $photoId, key: $key');
      _retryCounts.remove(photoId);
      _imageRequestKeys.remove(photoId);
    }
  }

  bool _isFieldEditable(dynamic item) {
    final respType = item.respType ?? '';

    if (respType.contains('RADIO') || respType.contains('DROPDOWN')) {
      return true;
    }

    final dgData = widget.pmData?.responseData?.dg ?? [];
    final bool isEditable = _checkDGDependencies(item, dgData);

    return isEditable;
  }

  bool _checkDGDependencies(dynamic item, List<dynamic> sectionData) {
    final itemDesc = item.checklistDesc?.toLowerCase() ?? '';

    if (itemDesc.contains('rectification remarks') || item.respType?.contains('REMARKS') == true) {
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
    print('=== SUBMIT FORM DEBUG ===');
    print('formData: $formData');
    print('formData.isEmpty: ${formData.isEmpty}');
    print('photoIds: $photoIds');
    print('photoTimestamps: $photoTimestamps');
    print('remarksData: ${_getRemarksData()}');

    if (formData.isEmpty) {
      print('Form data is empty, returning early');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

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

  Widget _buildFormField(dynamic item) {
    final respType = item.respType ?? '';
    final checklistDesc = item.checklistDesc ?? '';
    final pmItemType = item.pmItemType ?? '';
    final key = '${pmItemType}_${item.clOrder}';

    final bool isEditable = _isFieldEditable(item);

    print('Processing item with respType: ${item.respType}, checklistDesc: ${item.checklistDesc}, externalImageUrl: ${loadedImageUrls[key]}');

    if (respType.contains('TEXT')) {
      return CustomFormField(
        label: checklistDesc,
        initialValue: formData[key]?.toString() ?? '',
        isRequired: false,
        isEditable: isEditable,
        controller: _getTextController(key, formData[key]?.toString() ?? ''),
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
                    initialValue: isEditable ? (formData[key]?.toString() ?? '') : null,
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
          initialValue: isEditable ? (formData[key]?.toString() ?? '') : null,
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
                  label: "Yes",
                  selectedIcon: Icons.check_circle,
                  unselectedIcon: Icons.circle_outlined,
                ),
                OptionItem(
                  value: "no",
                  label: "No",
                  selectedIcon: Icons.cancel,
                  unselectedIcon: Icons.circle_outlined,
                ),
              ],
              initialValue: formData[key]?.toString() ?? '',
              onChanged: isEditable ? (value) => _saveFormData(key, value) : (_) {},
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
        );
      } else {
        return CustomOptionSelector(
          label: checklistDesc,
          options: [
            OptionItem(
              value: "yes",
              label: "Yes",
              selectedIcon: Icons.check_circle,
              unselectedIcon: Icons.circle_outlined,
            ),
            OptionItem(
              value: "no",
              label: "No",
              selectedIcon: Icons.cancel,
              unselectedIcon: Icons.circle_outlined,
            ),
          ],
          initialValue: formData[key]?.toString() ?? '',
          onChanged: isEditable ? (value) => _saveFormData(key, value) : (_) {},
        );
      }
    } else if (respType.contains('REMARKS') || checklistDesc.toLowerCase().contains('remarks')) {
      return CustomFormField(
        hintText: checklistDesc,
        label: checklistDesc,
        initialValue: formData[key]?.toString() ?? '',
        isRequired: false,
        isEditable: isEditable,
        controller: _getRemarksController(key, formData[key]?.toString() ?? ''),
        onChanged: (value) => _saveFormData(key, value),
      );
    }

    return CustomFormField(
      label: checklistDesc,
      initialValue: formData[key]?.toString() ?? '',
      isRequired: false,
      isEditable: isEditable,
      controller: _getTextController(key, formData[key]?.toString() ?? ''),
      onChanged: (value) => _saveFormData(key, value),
    );
  }

  Widget _buildDGSection(PmGetDataModel data) {
    final dgData = data.responseData?.dg ?? [];

    if (dgData.isEmpty) {
      return const Center(
        child: Text(
          'No DG data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...dgData.map((item) => Column(
          children: [
            _buildFormField(item),
            getHeight(15),
          ],
        )).toList(),
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
                await _submitForm();
                await _saveAndExit();
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
                    await _saveAndExit();
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
        body: widget.pmData != null
            ? MultiBlocListener(
          listeners: [
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
            BlocListener<PmCubit, PmState>(
              listener: (context, state) {
                if (state is PmGetLoaded) {
                  print('PmGetLoaded triggered with DG data: ${state.pmGetDataModel.responseData?.dg}');
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

                  context.read<PmCubit>().getPmData(
                    siteType: widget.ticketType.name,
                    auditSchId: widget.auditSchId,
                    siteAuditSchId: widget.siteAuditSchId,
                  );
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
                _fetchNextImage();
              },
            ),
          ],
          child: _buildContent(widget.pmData!),
        )
            : MultiBlocListener(
          listeners: [
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
            BlocListener<PmCubit, PmState>(
              listener: (context, state) {
                if (state is PmGetLoaded) {
                  print('PmGetLoaded triggered with DG data: ${state.pmGetDataModel.responseData?.dg}');
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
                  context.read<PmCubit>().getPmData(
                    siteType: widget.ticketType.name,
                    auditSchId: widget.auditSchId,
                    siteAuditSchId: widget.siteAuditSchId,
                  );
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
                _fetchNextImage();
              },
            ),
          ],
          child: BlocBuilder<PmCubit, PmState>(
            builder: (context, state) {
              if (state is PmGetLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is PmGetLoaded) {
                final data = state.pmGetDataModel;
                return _buildContent(data);
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
                    bottom: MediaQuery.of(context).viewInsets.bottom + 120,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: _buildDGSection(data),
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
                          Navigator.pop(context);
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
                          if (formData.isNotEmpty) {
                            await _submitForm();
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PmScreen7(
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
    );
  }
}