import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/models/PmGetDataModel.dart';
import 'package:app/screens/preventive_maintainance/pm_pages/pm_page_6.dart';
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
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../constants/constants_strings.dart';
import '../../../enum/pm_ticket_type_enum.dart';
import '../../home_screen.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class PmScreen5 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;
  final PmGetDataModel? pmData;

  const PmScreen5({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
    this.pmData,
  });

  @override
  State<PmScreen5> createState() => _PmScreen5();
}

class _PmScreen5 extends State<PmScreen5> {
  bool hasUnsavedChanges = false;
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
        return "PM Telecom - Fire Extinguisher";
      case PmTicketTypeEnum.solar:
        return "PM Solar - Fire Extinguisher";
    }
  }

  String _getSuccessMessage() {
    final siteId = _getActualSiteId();
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "Fire Extinguisher section for Telecom Site (ID: $siteId) has been recorded and saved.";
      case PmTicketTypeEnum.solar:
        return "Fire Extinguisher section for Solar Site (ID: $siteId) has been recorded and saved.";
    }
  }

  String _getCancelMessage() {
    final siteId = _getActualSiteId();
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "Do you want to cancel the Fire Extinguisher section for Telecom Site (ID: $siteId) ?";
      case PmTicketTypeEnum.solar:
        return "Do you want to cancel the Fire Extinguisher section for Solar Site (ID: $siteId) ?";
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
        return "DG";
      case PmTicketTypeEnum.solar:
        return "DG";
    }
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
    print('Loading existing data for PM Page 5');
    setState(() {
      formData.clear();
      photoIds.clear();
      photoTimestamps.clear();
      loadedImageUrls.clear();
      _retryCounts.clear();

      final feData = data.responseData?.fireExtinguisher ?? [];
      print('Fire Extinguisher data count: ${feData.length}');
      print('Raw Fire Extinguisher data: $feData');

      for (final item in feData) {
        final key = '${item.pmItemType}_${item.clOrder}';
        print('Processing item: $key, resp: ${item.resp} (type: ${item.resp.runtimeType}), photoId: ${item.photoId} (type: ${item.photoId.runtimeType}), respType: ${item.respType}');

        if (item.resp != null) {
          final respValue = item.resp is int ? item.resp.toString() : item.resp.toString();
          formData[key] = respValue;
          print('Added to formData: $key = $respValue');
        }

        if (item.photoId != null) {
          final photoIdInt = int.tryParse(item.photoId.toString());
          if (photoIdInt != null) {
            photoIds[key] = photoIdInt;
            _retryCounts[photoIdInt.toString()] = 0; // Initialize retry count
            print('Added to photoIds: $key = $photoIdInt');
            _loadImageForPhotoId(photoIdInt.toString(), key);
          } else {
            print('Invalid photoId format: ${item.photoId}');
          }
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

  Widget _buildFormField(dynamic item) {
    final respType = item.respType ?? '';
    final checklistDesc = item.checklistDesc ?? '';
    final pmItemType = item.pmItemType ?? '';
    final key = '${pmItemType}_${item.clOrder}';

    if (respType.contains('DROPDOWN')) {
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
                    items: options,
                    initialValue: formData[key]?.toString() ?? '',
                    onChanged: (value) => _saveFormData(key, value),
                    isRequired: false,
                  ),
                  getHeight(10),
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
          items: options,
          initialValue: formData[key]?.toString() ?? '',
          onChanged: (value) => _saveFormData(key, value),
          isRequired: false,
        );
      }
    }

    return CustomDropdown(
      label: checklistDesc,
      items: ['OK', 'Corrected', 'Not OK - To be corrected', 'Not Applicable'],
      initialValue: formData[key]?.toString() ?? '',
      onChanged: (value) => _saveFormData(key, value),
      isRequired: false,
    );
  }

  Widget _buildFireExtinguisherSection(PmGetDataModel data) {
    final feData = data.responseData?.fireExtinguisher ?? [];

    if (feData.isEmpty) {
      return const Center(
        child: Text(
          'No Fire Extinguisher data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...feData.map((item) => Column(
          children: [
            _buildFormField(item),
            getHeight(15),
          ],
        )).toList(),
      ],
    );
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
                  print('PmGetLoaded triggered with fireExtinguisher data: ${state.pmGetDataModel.responseData?.fireExtinguisher}');
                  _loadExistingData(state.pmGetDataModel);
                } else if (state is PmPostSuccess) {
                  print('Post successful, clearing form data');
                  setState(() {
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
                      // Accept any non-empty imageData to allow for server-specific formats
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
                  print('PmGetLoaded triggered with fireExtinguisher data: ${state.pmGetDataModel.responseData?.fireExtinguisher}');
                  _loadExistingData(state.pmGetDataModel);
                } else if (state is PmPostSuccess) {
                  print('Post successful, clearing form data');
                  setState(() {
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
                      // Accept any non-empty imageData to allow for server-specific formats
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
                    child: _buildFireExtinguisherSection(data),
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
                        onPressed: () async {
                          if (formData.isNotEmpty) {
                            await _submitForm();
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PmScreen6(
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