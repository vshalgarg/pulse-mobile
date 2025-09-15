import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/solar_plates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/asset_audit_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../utils/asset_audit_photo_upload_helper.dart';
import '../../../utils/asset_audit_navigation_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../repositories/image_repository.dart';
import '../../../app_config.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/base64_image_widget.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../home_screen.dart';

class ExtinguisherScreen extends StatefulWidget {
  final CategoryData? extinguisherData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage;
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;

  const ExtinguisherScreen({
    super.key,
    this.extinguisherData,
    this.assetAuditData,
    this.showSuccessMessage = false,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
  });

  @override
  State<ExtinguisherScreen> createState() => _ExtinguisherScreenState();
}

class _ExtinguisherScreenState extends State<ExtinguisherScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController remarksController = TextEditingController();
  bool hasUnsavedChanges = false;
  bool _isPostingData = false;

  @override
  void initState() {
    super.initState();
    if (widget.showSuccessMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSuccessMessage();
      });
    }
  }

  void _showSuccessMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SuccessDialog(
        ticketId: "EXTINGUISHER",
        message: "Extinguisher data saved successfully!",
        onDone: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  bool _hasDataToShow() {
    return widget.extinguisherData?.assets != null && 
           widget.extinguisherData!.assets.isNotEmpty;
  }

  void _navigateToNextScreen() {
    AssetAuditNavigationHelper.navigateToNextScreen(
      context,
      'Extinguisher',
      widget.siteType,
      widget.auditSchId,
      widget.siteAuditSchId,
      widget.assetAuditData,
    );
  }

  Future<void> _postCurrentScreenData() async {
    if (!_hasDataToShow()) return;

    setState(() {
      _isPostingData = true;
    });

    try {
      // For now, just navigate to next screen since we don't have specific extinguisher data to post
      _navigateToNextScreen();
    } catch (e) {
      print('Error posting extinguisher data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPostingData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AssetAuditCubit, AssetAuditState>(
          listener: (context, state) {
            if (state is AssetAuditPostSuccess) {
              _navigateToNextScreen();
            } else if (state is AssetAuditPostError) {
              showCustomToast(context, 'Failed to save extinguisher data. Please try again.');
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
                message: "Do you want to cancel the Asset Audit?",
                onSaveAndExit: () async {
                  await _postCurrentScreenData();
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
          appBar: CustomFormAppbar(
            title: "Extinguisher",
            onClose: () async {
              if (hasUnsavedChanges) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => UnsavedChangesDialog(
                    message: "Do you want to cancel the Asset Audit?",
                    onSaveAndExit: () async {
                      await _postCurrentScreenData();
                      Navigator.of(context).pop();
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
              SafeArea(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Container(
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: MediaQuery.of(context).viewInsets.bottom + 120,
                            ),
                            child: Column(
                              children: [
                                if (_hasDataToShow()) ...[
                                  // Show extinguisher data
                                  ...widget.extinguisherData!.assets.map((asset) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      child: CustomInfoCard(
                                        serialLabel: "Serial Number",
                                        photoLabel: "Photo",
                                        statusLabel: "Status",
                                        buttonLabel: "Save",
                                        serialController: TextEditingController(text: asset.nexgenSerialNo ?? asset.mfgSerialNo ?? ''),
                                        onSave: () {
                                          setState(() {
                                            hasUnsavedChanges = true;
                                          });
                                        },
                                        onPhotoTap: (photoPath) async {
                                          setState(() {
                                            hasUnsavedChanges = true;
                                          });
                                        },
                                        onStatusChanged: (val) {
                                          setState(() {
                                            hasUnsavedChanges = true;
                                          });
                                        },
                                        onSerialChanged: (serialNumber) {
                                          setState(() {
                                            hasUnsavedChanges = true;
                                          });
                                        },
                                        initialStatus: asset.assetStatus == 'OK',
                                        initialPhotoPath: asset.imageName,
                                        isEditable: false,
                                        isStatusEditable: false,
                                      ),
                                    );
                                  }).toList(),
                                ] else ...[
                                  // Show no data message
                                  Container(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No extinguisher data available',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                getHeight(15),
                                CustomRemarksField(
                                  label: "Remarks",
                                  hintText: "Enter remarks for extinguisher",
                                  controller: remarksController,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ArrowButton(
                                text: AssetAuditNavigationHelper.getPreviousScreenDisplayName(
                                  widget.assetAuditData, 
                                  'Extinguisher'
                                ),
                                isLeftArrow: true,
                                backgroundColor: AppColors.buttonColorBg,
                                textColor: AppColors.buttonColorSite,
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            getWidth(14),
                            Expanded(
                              child: ArrowButton(
                                text: _hasDataToShow() 
                                    ? AssetAuditNavigationHelper.getNextScreenDisplayName(
                                        widget.assetAuditData, 
                                        'Extinguisher'
                                      ) 
                                    : "Skip",
                                isLeftArrow: false,
                                backgroundColor: AppColors.buttonColorBackBg,
                                textColor: AppColors.buttonColorTextBg,
                                onPressed: () async {
                                  // If no data to show, just navigate to next screen
                                  if (!_hasDataToShow()) {
                                    _navigateToNextScreen();
                                    return;
                                  }

                                  // If there are unsaved changes, post them first
                                  if (hasUnsavedChanges) {
                                    await _postCurrentScreenData();
                                  } else {
                                    _navigateToNextScreen();
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
              // Loading overlay
              BlocBuilder<AssetAuditCubit, AssetAuditState>(
                builder: (context, state) {
                  if (state is AssetAuditPosting) {
                    return Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
