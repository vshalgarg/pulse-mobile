import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'dart:async';

import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/selfie_upload_cubit.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../../hive_local_database/hive_db.dart';
import '../../../utils/asset_audit_form_persistence_helper.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../models/asset_audit_model.dart';
import '../../home_screen.dart';

class InvertorScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final AssetAuditModel? assetAuditData; // Complete asset audit data

  const InvertorScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.assetAuditData, // Complete asset audit data
  });

  @override
  State<InvertorScreen> createState() => _InvertorScreenState();
}

class _InvertorScreenState extends State<InvertorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  int totalItemsToScan = 6;
  int currentScannedItems = 0;
  List<Map<String, dynamic>> savedItems = [];

  // Invertor field values
  String? invertorSerialNumber;
  String? invertorPhoto;
  String? invertorStatus;
  final remarksController = TextEditingController();
  int invertorCardKey = 0;

  // Image loading variables
  String? _currentRequestedImageId;
  bool _isRequestingImage = false;
  List<Map<String, dynamic>> savedInvertorItems = [];

  // Controllers for CustomInfoCard
  final TextEditingController invertorSerialController = TextEditingController();
  int totalInvertorItems = 6;

  // API integration fields
  String? uploadedPhotoPath;
  String? uploadedImgId;
  String? fetchedImageData;
  bool _hasFormDataChanges = false;
  List<Map<String, String>> _imageQueue = [];
  bool _fetchingImage = false;
  String? _lastRequestedPhotoId;
  Map<String, int> _retryCounts = {};

  @override
  void initState() {
    super.initState();
    serialController.addListener(_onFormChanged);
    invertorSerialController.addListener(_onFormChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('=== Invertor didChangeDependencies called ===');

    context.read<AssetAuditCubit>().getAssetAuditData(
      siteType: widget.siteType,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );

    AssetAuditFormPersistenceHelper.ensureHiveBoxReady().then((_) {
      _loadStoredData();
      _checkPageHeaderForData();
    });
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    invertorSerialController.removeListener(_onFormChanged);
    serialController.dispose();
    invertorSerialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      final hasLocalPhoto = uploadedPhotoPath != null && uploadedPhotoPath!.isNotEmpty;
      final hasServerImage = uploadedImgId != null && uploadedImgId!.isNotEmpty && uploadedImgId != "0";
      final hasImageData = fetchedImageData != null && fetchedImageData!.isNotEmpty;

      hasUnsavedChanges = serialController.text.isNotEmpty ||
          invertorSerialController.text.isNotEmpty ||
          hasLocalPhoto ||
          hasServerImage ||
          hasImageData ||
          savedInvertorItems.isNotEmpty;

      _hasFormDataChanges = true;

      if (showValidationErrors && (serialController.text.isNotEmpty || invertorSerialController.text.isNotEmpty)) {
        showValidationErrors = false;
      }
    });
  }

  void _saveFormDataToHive() {
    if (!_hasFormDataChanges) return;

    final Map<String, dynamic> formData = {
      'uploadedPhotoPath': uploadedPhotoPath,
      'uploadedImgId': uploadedImgId,
      'serialController': serialController.text,
      'invertorSerialController': invertorSerialController.text,
      'savedInvertorItems': savedInvertorItems,
      'invertorSerialNumber': invertorSerialNumber,
      'invertorPhoto': invertorPhoto,
      'invertorStatus': invertorStatus,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    AssetAuditFormPersistenceHelper.saveFormData(
      siteAuditSchId: widget.siteAuditSchId,
      screenName: 'solar_invertor',
      formData: formData,
    );
    _hasFormDataChanges = false;
  }

  void _checkPageHeaderForData() {
    final assetAuditState = context.read<AssetAuditCubit>().state;
    if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
      final pageHeader = assetAuditState.assetAuditData.pageHeader.first;
      print('Invertor makerSelfieImageId: ${pageHeader.makerSelfieImageId}');

      if (pageHeader.makerSelfieImageId != null && pageHeader.makerSelfieImageId! > 0) {
        setState(() {
          uploadedImgId = pageHeader.makerSelfieImageId.toString();
          fetchedImageData = null;
        });

        _imageQueue.add({'photoId': pageHeader.makerSelfieImageId.toString(), 'key': 'invertor'});
        _fetchNextImage();
      }
    }
  }

  void _loadStoredData() async {
    final formData = await AssetAuditFormPersistenceHelper.loadFormData(
      siteAuditSchId: widget.siteAuditSchId,
      screenName: 'solar_invertor',
    );

    if (formData != null) {
      setState(() {
        uploadedImgId = formData['uploadedImgId'];
        uploadedPhotoPath = formData['uploadedPhotoPath'];
        if (formData['serialController'] != null) {
          serialController.text = formData['serialController'];
        }
        if (formData['invertorSerialController'] != null) {
          invertorSerialController.text = formData['invertorSerialController'];
        }
        if (formData['savedInvertorItems'] != null) {
          savedInvertorItems = List<Map<String, dynamic>>.from(formData['savedInvertorItems']);
        }
        invertorSerialNumber = formData['invertorSerialNumber'];
        invertorPhoto = formData['invertorPhoto'];
        invertorStatus = formData['invertorStatus'];
      });

      if (formData['uploadedImgId'] != null && formData['uploadedImgId'].toString().isNotEmpty) {
        final storedImage = HiveDB.getAssetAuditSelfie(widget.siteAuditSchId);
        if (storedImage != null && storedImage['imageData'] != null && storedImage['imageData'].toString().isNotEmpty) {
          setState(() {
            fetchedImageData = storedImage['imageData'] as String?;
          });
        } else {
          _imageQueue.add({'photoId': formData['uploadedImgId'].toString(), 'key': 'invertor'});
          _fetchNextImage();
        }
      }
    }
  }

  void _fetchNextImage() {
    if (_fetchingImage || _imageQueue.isEmpty) return;

    _fetchingImage = true;

    final image = _imageQueue.removeAt(0);
    final photoId = image['photoId']!;
    final key = image['key']!;

    print('Loading Invertor image for photoId: $photoId, key: $key, retry count: ${_retryCounts[photoId] ?? 0}');
    _lastRequestedPhotoId = photoId;
    _retryCounts[photoId] = _retryCounts[photoId] ?? 0;
    context.read<AssetAuditGetImageCubit>().getImage(
      imgId: photoId,
      schId: widget.siteAuditSchId,
    );
  }

  Future<void> _handleImageLoadRetry(String photoId, String key) async {
    const maxRetries = 5;
    const retryDelay = Duration(seconds: 3);

    final currentRetryCount = _retryCounts[photoId] ?? 0;
    if (currentRetryCount < maxRetries) {
      _retryCounts[photoId] = currentRetryCount + 1;
      print('Retrying Invertor image load for photoId: $photoId, key: $key, attempt: ${_retryCounts[photoId]} of $maxRetries');
      await Future.delayed(retryDelay);
      _imageQueue.insert(0, {'photoId': photoId, 'key': key});
      _fetchNextImage();
    } else {
      print('Max retries reached for Invertor photoId: $photoId, key: $key');
      _retryCounts.remove(photoId);
    }
  }

  void _uploadImage(File file) {
    final assetAuditState = context.read<AssetAuditCubit>().state;
    if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
      final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();
      final imgIdToUse = uploadedImgId != null && uploadedImgId!.isNotEmpty ? uploadedImgId! : "0";

      _hasFormDataChanges = true;
      context.read<SelfieUploadCubit>().uploadSelfie(
        file: file,
        imgId: imgIdToUse,
        schId: schId,
      );
    }
  }

  void _saveAndExit() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Post Invertor data to API first
      await _postInvertorData();
      
      // Update audit schedule status
      await _updateAuditScheduleStatus("In Progress");

      // Close loading dialog
      Navigator.of(context).pop();

      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => HomeScreen()
        ),
      );
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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

  // Helper method to get the next available screen based on data availability
  String? _getNextAvailableScreen() {
    return AssetAuditNavigationHelper.getNextAvailableScreen(widget.assetAuditData, 'Invertor');
  }

  // Helper method to get the previous available screen based on data availability
  String? _getPreviousAvailableScreen() {
    return AssetAuditNavigationHelper.getPreviousAvailableScreen(widget.assetAuditData, 'Invertor');
  }

  // Helper method to navigate to the next screen based on screen name
  void _navigateToNextScreen(BuildContext context, String screenName) {
    AssetAuditNavigationHelper.navigateToNextScreen(
      context,
      screenName,
      widget.siteType,
      widget.auditSchId,
      widget.siteAuditSchId,
      widget.assetAuditData,
    );
  }

  // Helper method to check if a string is numeric (photo ID)
  bool _isNumeric(String str) {
    return int.tryParse(str) != null;
  }

  Future<void> _postInvertorData() async {
    try {
      final assetAuditState = context.read<AssetAuditCubit>().state;
      if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
        
        if (savedInvertorItems.isNotEmpty) {
          // Enhance saved items with additional data
          final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
            savedItems: savedInvertorItems,
            screenName: 'solar_invertor',
          );

          // Convert to AssetAuditPostRequest
          final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
            savedItems: enhancedItems,
            assetAuditData: assetAuditState.assetAuditData,
            itemType: 'Invertor',
            itemTypeId: 14, // Invertor item type ID
            screenName: 'solar_invertor',
            context: context,
            auditSchId: widget.auditSchId,
          );

          if (requests.isNotEmpty) {
            print('Posting Invertor data: ${requests.length} requests');
            context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
          }
        }
      }
    } catch (e) {
      print('Error posting Invertor data: $e');
    }
  }

  bool _isFormValid() {
    if (invertorSerialController.text.isEmpty) {
      return false;
    }

    if (invertorPhoto == null || invertorPhoto!.isEmpty) {
      return false;
    }

    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    if (invertorSerialController.text.isEmpty) {
      return false;
    }

    if (invertorPhoto == null || invertorPhoto!.isEmpty) {
      return false;
    }

    return true;
  }

  void _saveInvertorForm() {
    if (savedInvertorItems.length > totalInvertorItems) {
      showCustomToast(context, 'Maximum number of Invertor items ($totalInvertorItems) already added.');
      return;
    }

    if (_isFormValid()) {
      setState(() {
        Map<String, dynamic> currentFormData = {
          'serialNumber': invertorSerialNumber,
          'photo': invertorPhoto,
          'status': invertorStatus ?? "OK",
          'timestamp': DateTime.now(),
        };

        savedInvertorItems.add(currentFormData);
        currentScannedItems++;

        invertorSerialNumber = null;
        invertorPhoto = null;
        invertorStatus = null;

        invertorSerialController.clear();

        invertorCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      int remainingInvertor = totalInvertorItems - savedInvertorItems.length;
    }
  }

  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }

  void _editItem(Map<String, dynamic> item) {
    setState(() {
      invertorSerialNumber = item["serialNumber"];
      invertorStatus = item["status"];

      invertorSerialController.text = item["serialNumber"] ?? "";

      savedItems.remove(item);
      currentScannedItems--;

      hasUnsavedChanges = true;
    });

    // Handle photo data - check if it's base64 data or photo ID
    String? photoData = item["photo"];
    if (photoData != null && photoData.isNotEmpty) {
      if (photoData.startsWith('data:image/')) {
        // It's already base64 image data
        setState(() {
          invertorPhoto = photoData;
        });
      } else if (_isNumeric(photoData)) {
        // It's a photo ID, load the image
        setState(() {
          _currentRequestedImageId = photoData;
          _isRequestingImage = true;
        });
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: photoData,
          schId: widget.siteAuditSchId,
        );
      } else {
        // It's a file path or other format
        setState(() {
          invertorPhoto = photoData;
        });
      }
    }
  }

  void _deleteItem(Map<String, dynamic> item) {
    setState(() {
      savedInvertorItems.remove(item);
      currentScannedItems--;
      hasUnsavedChanges = true;
    });

  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditError) {
              showCustomToast(context, state.message);
            } else if (state is AssetAuditPostError) {

                showCustomToast(context, 'Error saving Invertor data: ${state.message}');

            }
          },
        ),
        BlocListener<SelfieUploadCubit, SelfieUploadState>(
          listener: (context, state) {
            if (state is SelfieUploadSuccess) {
              setState(() {
                uploadedImgId = state.response.imgId;
                _hasFormDataChanges = true;
              });

            } else if (state is SelfieUploadFailure) {
              showCustomToast(context, state.errorMessage);
            }
          },
        ),
        BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
          listener: (context, state) async {
            if (state is AssetAuditGetImageSuccess) {

              // Handle edit case
              if (_isRequestingImage && _currentRequestedImageId != null) {
                final finalImageData = state.imageData.startsWith('data:image/')
                    ? state.imageData
                    : 'data:image/jpeg;base64,${state.imageData}';
                setState(() {
                  invertorPhoto = finalImageData;
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });
                return;
              }
              
              final assetAuditState = context.read<AssetAuditCubit>().state;
              if (assetAuditState is AssetAuditLoaded && assetAuditState.assetAuditData.pageHeader.isNotEmpty) {
                final schId = assetAuditState.assetAuditData.pageHeader.first.siteAuditSchId.toString();

                if (state.imageData.isNotEmpty) {
                  HiveDB.updateAssetAuditSelfie(
                    siteAuditSchId: schId,
                    newImageId: _lastRequestedPhotoId ?? '',
                    newImageData: state.imageData,
                  );

                  setState(() {
                    fetchedImageData = state.imageData;
                    _hasFormDataChanges = true;
                  });

                  _fetchingImage = false;
                  _fetchNextImage();
                } else {
                  print('Empty image data received for Invertor photoId: $_lastRequestedPhotoId');
                  await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'invertor');
                }
              } else {
                print('AssetAuditCubit state is not AssetAuditLoaded or pageHeader is empty');
                _fetchingImage = false;
                _fetchNextImage();
              }
            } else if (state is AssetAuditGetImageFailure) {
              print('Failed to load Invertor image for photoId: $_lastRequestedPhotoId, error: ${state.errorMessage}');
              
              // Handle edit case failure
              if (_isRequestingImage && _currentRequestedImageId != null) {
                setState(() {
                  _isRequestingImage = false;
                  _currentRequestedImageId = null;
                });
                return;
              }
              
              await _handleImageLoadRetry(_lastRequestedPhotoId ?? '', 'invertor');
            }
          },
        ),
      ],
      child: PopScope(
        canPop: !hasUnsavedChanges,
        onPopInvoked: (didPop) async {
          if (didPop) return;

          if (hasUnsavedChanges) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => UnsavedChangesDialog(
                message:
                    "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                onSaveAndExit: () async {
                  Navigator.of(context).pop(); // Close the dialog first
                  _saveAndExit();
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
            title: "Asset Audit",
            onClose: () async {
              if (hasUnsavedChanges) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => UnsavedChangesDialog(
                    message:
                        "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                    onSaveAndExit: () async {
                      Navigator.of(context).pop(); // Close the dialog first
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
          body: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: SvgPicture.asset(
                  AppImages.home,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              SafeArea(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                          ),
                          child: Container(
                            padding: const EdgeInsets.only(
                              top: 20,
                              left: 16,
                              right: 16,
                              bottom: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Invertor form
                                // AssetTypeCard(
                                //   key: ValueKey(invertorCardKey),
                                //   title: "Invertor",
                                //   serialController: invertorSerialController,
                                //   onSerialChanged: (value) {
                                //     setState(() {
                                //       invertorSerialNumber = value;
                                //     });
                                //   },
                                //   onStatusChanged: (value) {
                                //     setState(() {
                                //       invertorStatus = value;
                                //     });
                                //   },
                                //   onPhotoSelected: (file) {
                                //     if (file != null) {
                                //       setState(() {
                                //         invertorPhoto = file.path;
                                //         hasUnsavedChanges = true;
                                //       });
                                //       _uploadImage(file);
                                //     } else {
                                //       setState(() {
                                //         invertorPhoto = null;
                                //       });
                                //     }
                                //   },
                                //   onSave: _saveInvertorForm,
                                //   isFormValid: _isFormValid(),
                                //   showValidationErrors: showValidationErrors,
                                // ),

                                // Saved Invertor items
                                if (savedInvertorItems.isNotEmpty) ...[
                                  getHeight(20),
                                  Text(
                                    "Saved Invertor Items (${savedInvertorItems.length}/$totalInvertorItems)",
                                    style: const TextStyle(
                                      color: AppColors.color555555,
                                      fontSize: 16,
                                      fontFamily: fontFamilyMontserrat,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  getHeight(10),
                                  ...savedInvertorItems.map((item) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _formatSerialNumber(item["serialNumber"] ?? ""),
                                              style: const TextStyle(
                                                color: AppColors.color555555,
                                                fontSize: 14,
                                                fontFamily: fontFamilyMontserrat,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _editItem(item),
                                                child: const Icon(
                                                  Icons.edit,
                                                  color: AppColors.primaryGreen,
                                                  size: 20,
                                                ),
                                              ),
                                              getWidth(10),
                                              GestureDetector(
                                                onTap: () => _deleteItem(item),
                                                child: const Icon(
                                                  Icons.delete,
                                                  color: AppColors.errorColor,
                                                  size: 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],

                                // Remarks section
                                getHeight(20),
                                // CustomRemarksField(
                                //   controller: remarksController,
                                //   onChanged: (value) {
                                //     setState(() {
                                //       hasUnsavedChanges = true;
                                //     });
                                //   },
                                // ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom navigation buttons
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ArrowButton(
                                text: "SPV",
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            getWidth(14),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final nextScreen = _getNextAvailableScreen();
                                  if (nextScreen == null) {
                                    // No more screens with data, show Submit button
                                    return ArrowButton(
                                      text: "Submit",
                                      isLeftArrow: false,
                                      backgroundColor: AppColors.buttonColorBg,
                                      textColor: AppColors.buttonColorSite,
                                      onPressed: () async {
                                        _saveFormDataToHive();
                                        await _postInvertorData();
                                        // Navigate to final submission or back to main screen
                                        Navigator.pop(context);
                                      },
                                    );
                                  } else {
                                    return ArrowButton(
                                      text: nextScreen,
                                      isLeftArrow: false,
                                      backgroundColor: AppColors.buttonColorBg,
                                      textColor: AppColors.buttonColorSite,
                                      onPressed: () async {
                                        print('=== Invertor Navigation to $nextScreen ===');
                                        print('Passing asset audit data: ${widget.assetAuditData != null}');
                                        
                                        _saveFormDataToHive();
                                        await _postInvertorData();
                                        
                                        // Navigate to the next available screen
                                        _navigateToNextScreen(context, nextScreen);
                                      },
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
