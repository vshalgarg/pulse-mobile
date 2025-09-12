import 'dart:io';
import 'package:app/screens/preventive_maintainance/pm_solar_pages/pm_solar_page_10.dart';
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
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../constants/constants_strings.dart';
import '../../../repositories/audit_schedule_repository.dart';
import '../../home_screen.dart';

class PmSolarPage9 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;
  final PmGetDataModel pmData;

  const PmSolarPage9({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
    required this.pmData,
  });

  @override
  State<PmSolarPage9> createState() => _PmSolarPage9State();
}

class _PmSolarPage9State extends State<PmSolarPage9> {
  bool hasUnsavedChanges = false;
  bool isSubmitting = false;
  Map<String, dynamic> formData = {};
  Map<String, int> photoIds = {}; // Store photo IDs as integers
  Map<String, String> photoTimestamps = {};
  Map<String, String> loadedImageUrls = {}; // Store loaded image URLs
  Map<String, TextEditingController> textControllers = {};
  Map<String, TextEditingController> remarksControllers = {};
  String? _currentUploadKey;
  Map<String, String> _imageRequestKeys =
      {}; // Track which key corresponds to which photo_id request
  String? _lastRequestedPhotoId; // Track the last requested photo ID
  Map<String, int> _retryCounts = {}; // Track retry attempts for each photo ID
  int _dummyState = 0; // For forcing UI rebuilds
  List<Map<String, String>> _imageQueue = []; // Queue for serial image fetches
  bool _fetchingImage = false; // Flag for ongoing image fetch

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
    print('Saving form data - Key: $key, Value: $value');
    setState(() {
      formData[key] = value;
      hasUnsavedChanges = formData.isNotEmpty;
      _dummyState = DateTime.now().millisecondsSinceEpoch;
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
    return 'PM Solar - Performance Monitoring';
  }

  String _getSuccessMessage() {
    return 'Performance Monitoring section data saved successfully!';
  }

  String _getCancelMessage() {
    return 'Performance Monitoring section data cancelled!';
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
    if (widget.siteId != null &&
        widget.siteId!.isNotEmpty &&
        widget.siteId != "N/A") {
      return widget.siteId!;
    }
    return "N/A";
  }

  String _getButtonText() {
    return 'Cables';
  }

  Future<void> _submitForm() async {
    print('=== _submitForm called ===');
    print('formData.length: ${formData.length}');
    print(
      'Total available fields: ${widget.pmData.responseData?.performanceMonitoring?.length ?? 0}',
    );

    // Allow partial submissions - no field validation required
    final performanceMonitoringData =
        widget.pmData.responseData?.performanceMonitoring ?? [];
    print('Total available fields: ${performanceMonitoringData.length}');
    print('Fields filled by user: ${formData.length}');

    if (formData.isEmpty) {
      print('formData is empty, skipping submission');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No data to submit')));
      return;
    }

    print(
      'Submitting partial data is OK - user filled ${formData.length} fields',
    );

    final cubit = context.read<PmCubit>();
    final state = cubit.state;
    print('Current PmCubit state: $state');

    print(
      'Submitting formData: $formData, photoIds: $photoIds, photoTimestamps: $photoTimestamps, remarks: ${_getRemarksData()}',
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
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

  Future<void> _uploadPhoto(File? file, String key) async {
    if (file == null) return;
    _currentUploadKey = key;
    final photoCubit = context.read<AssetAuditPhotoUploadCubit>();
    await photoCubit.uploadPhoto(file: file, schId: widget.siteAuditSchId);
  }

  void _loadExistingData(PmGetDataModel data) {
    print(
      '=== Loading Existing Data for PM Solar Page 9 (Performance Monitoring) ===',
    );
    setState(() {
      formData.clear();
      photoIds.clear();
      photoTimestamps.clear();
      loadedImageUrls.clear();
      _retryCounts.clear();
      _imageQueue.clear();

      // Load Performance Monitoring section data
      final performanceData = data.responseData?.performanceMonitoring ?? [];
      print('Performance Monitoring data count: ${performanceData.length}');
      print('Raw Performance Monitoring data: $performanceData');

      for (final item in performanceData) {
        final key = '${item['pm_item_type']}_${item['cl_order']}';
        print(
          'Processing item: $key, resp: ${item['resp']} (type: ${item['resp'].runtimeType}), photoId: ${item['photo_id']} (type: ${item['photo_id'].runtimeType}), respType: ${item['resp_type']}',
        );

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
          photoTimestamps[key] = item['photo_taken_ts']!;
          print('Added to photoTimestamps: $key = ${item['photo_taken_ts']}');
        }

        // Load remarks data if available
        if (item['remarks'] != null && item['remarks'].toString().isNotEmpty) {
          _getRemarksController(key, item['remarks'].toString());
          print('Added to remarks: $key = ${item['remarks']}');
        }
      }

      _dummyState = DateTime.now().millisecondsSinceEpoch;
    });

    _fetchNextImage(); // Start processing the queue

    // Fallback: Re-fetch missing images after a delay
    Future.delayed(const Duration(seconds: 5), () {
      for (final key in photoIds.keys) {
        if (!loadedImageUrls.containsKey(key) && photoIds[key] != null) {
          print(
            'Fallback: Re-fetching image for key: $key, photoId: ${photoIds[key]}',
          );
          _imageQueue.add({'photoId': photoIds[key]!.toString(), 'key': key});
          _fetchNextImage();
        }
      }
    });
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
      print(
        'Retrying image load for photoId: $photoId, attempt: ${retryCount + 1}',
      );

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

  bool _isFieldEditable(dynamic item) {
    final respType = item.respType ?? '';

    if (respType.contains('RADIO')) {
      return true;
    }

    final performanceData =
        widget.pmData?.responseData?.performanceMonitoring ?? [];
    final bool isEditable = _checkPerformanceMonitoringDependencies(
      item,
      performanceData,
    );

    return isEditable;
  }

  bool _checkPerformanceMonitoringDependencies(
    dynamic item,
    List<dynamic> sectionData,
  ) {
    final itemDesc = item['checklist_desc']?.toLowerCase() ?? '';

    if (itemDesc.contains('rectification remarks')) {
      for (final dropdownItem in sectionData) {
        if (dropdownItem['resp_type']?.contains('DROPDOWN') == true) {
          final dropdownKey =
              '${dropdownItem['pm_item_type']}_${dropdownItem['cl_order']}';
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
      child: BlocListener<PmCubit, PmState>(
        listener: (context, state) {
          print('PmCubit state changed: $state');
          if (state is PmPosting) {
            print('Form submission in progress...');
            setState(() {
              isSubmitting = true;
            });
          } else if (state is PmPostSuccess) {
            print('Post successful, clearing form data');
            setState(() {
              formData.clear();
              photoIds.clear();
              photoTimestamps.clear();
              hasUnsavedChanges = false;
              isSubmitting = false;
            });
            // Don't call _saveAndExit() here - let the Next button handle navigation
          } else if (state is PmPostError) {
            print('Post failed with error: ${state.message}');
            setState(() {
              isSubmitting = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Submission failed: ${state.message}')),
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.message)));
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(state.message)));
                  }
                },
              ),
              BlocListener<
                AssetAuditPhotoUploadCubit,
                AssetAuditPhotoUploadState
              >(
                listener: (context, state) {
                  if (state is AssetAuditPhotoUploadSuccess) {
                    if (_currentUploadKey != null) {
                      final photoId = int.tryParse(state.response.imgId) ?? 0;
                      final timestamp = DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(DateTime.now());
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
                    if (photoId != null &&
                        _imageRequestKeys.containsKey(photoId)) {
                      final key = _imageRequestKeys[photoId]!;
                      setState(() {
                        loadedImageUrls[key] = state.imageData;
                      });
                      print('Image loaded successfully for key: $key');
                    }
                  } else if (state is AssetAuditGetImageFailure) {
                    final photoId = _lastRequestedPhotoId;
                    if (photoId != null &&
                        _imageRequestKeys.containsKey(photoId)) {
                      final key = _imageRequestKeys[photoId]!;
                      print(
                        'Image load error for photoId: $photoId - ${state.errorMessage}',
                      );
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
      ),
    );
  }

  Widget _buildContent(PmGetDataModel data) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Background image - full screen coverage
          Positioned.fill(
            child: SvgPicture.asset(AppImages.home, fit: BoxFit.cover),
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
                        _buildPerformanceMonitoringSection(data),
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

  Widget _buildPerformanceMonitoringSection(PmGetDataModel data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: (data.responseData?.performanceMonitoring ?? []).map((item) {
        return Column(
          children: [
            _buildFormField(item['checklist_desc'] ?? '', item['resp_type'] ?? 'TEXT', item),
            getHeight(15),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFormField(String label, String respType, dynamic item) {
    // Build the proper key format: pmItemType_clOrder
    final key = '${item['pm_item_type']}_${item['cl_order']}';
    final currentValue = formData[key] ?? '';
    final photoIds = <String, int?>{};

    // Extract photo ID if available
    if (item['photo_id'] != null) {
      photoIds[key] = item['photo_id'];
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
                  items: [
                    'OK',
                    'Corrected',
                    'Not OK - To be corrected',
                    'Not Applicable',
                  ],
                  initialValue: currentValue.isNotEmpty ? currentValue : null,
                  onChanged: (value) {
                    _saveFormData(key, value);
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
              ],
            ),
          ),
          getHeight(15),
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
        label: 'Status',
        items: options,
        initialValue: currentValue.isNotEmpty ? currentValue : null,
        onChanged: (value) {
          _saveFormData(key, value);
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
        controller: _getRemarksController(key, currentValue),
        onChanged: (value) {
          _saveFormData(key, value);
        },
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
        },
        isRequired: true,
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
                  print('=== Cables button pressed ===');
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
                  print('Navigating to PmSolarPage10');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PmSolarPage10(
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
    );
  }
}
