import 'package:app/commonWidgets/custom_asset_audit_form_section.dart';
import 'package:app/commonWidgets/custom_er_form.dart';
import 'package:app/commonWidgets/custom_radio_options.dart';
import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/screens/pulse_dashboard.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';

import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../commonWidgets/custom_dropdown.dart';
import '../../../constants/app_images.dart';
import '../../../constants/app_colors.dart';

class EnergyReadingDetailScreen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;
  final String siteId;

  const EnergyReadingDetailScreen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
    required this.siteId,
  });

  @override
  State<EnergyReadingDetailScreen> createState() =>
      _EnergyReadingDetailScreenState();
}

class _EnergyReadingDetailScreenState extends State<EnergyReadingDetailScreen> {
  bool _hasFormDataChanges = false;

  String? _ERImageID;

  // Form controllers
  final TextEditingController _consumerNoController = TextEditingController();
  final TextEditingController _meterNoController = TextEditingController();
  final TextEditingController _ebMeterReadingController =
      TextEditingController();
  final TextEditingController _ebKwhInSebMeterController =
      TextEditingController();
  final TextEditingController _ebKwhInCcuController = TextEditingController();
  final TextEditingController _ebKvhInCcuController = TextEditingController();
  final TextEditingController _voltageController = TextEditingController();
  final TextEditingController _loadController = TextEditingController();
  final TextEditingController _ebKvaInSebMeterController =
      TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // Dropdowns
  String? _selectedStatus;
  String? _selectedMeterType;
  String? _selectedConnectionType;
  String? _selectedEbConnectionType;
  String? _selectedBatteryStatus;

  final List<String> _meterStatusOptions = ['OK', 'Faulty'];
  final List<String> _meterTypeOptions = ['Prepaid', 'Postpaid'];
  final List<String> _connectionTypeOptions = ['LT', 'HT'];
  final List<String> _ebConnectionTypeOptions = ['Single Phase', '3 Phase'];
  final List<String> _batteryStatusOptions = ['Yes', 'No'];

  @override
  void initState() {
    super.initState();

    _consumerNoController.addListener(_onFormChanged);
    _meterNoController.addListener(_onFormChanged);
    _ebMeterReadingController.addListener(_onFormChanged);
    _ebKwhInSebMeterController.addListener(_onFormChanged);
    _ebKwhInCcuController.addListener(_onFormChanged);
    _ebKvhInCcuController.addListener(_onFormChanged);
    _voltageController.addListener(_onFormChanged);
    _loadController.addListener(_onFormChanged);
    _ebKvaInSebMeterController.addListener(_onFormChanged);
    _remarksController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (!_hasFormDataChanges) {
      setState(() {
        _hasFormDataChanges = true;
      });
    }
  }

  Future<void> postCurrentScreenData() async {
    try {
      final energyReading = {
        "energyReadingId": 0,
        "auditSchId": widget.auditSchId,
        "siteAuditSchId": widget.siteAuditSchId,
        "siteId": widget.siteId,
        "connectionType": _selectedConnectionType ?? "",
        "consumerNo": _consumerNoController.text,
        "ebMeterStatus": _selectedStatus ?? "",
        "ebConnectionType": _selectedEbConnectionType ?? "",
        "ebMeterType": _selectedMeterType ?? "",
        "ebMeterNo": _meterNoController.text,
        "ebMeterReading":
            double.tryParse(_ebMeterReadingController.text) ?? 0.0,
        "ebKwhInSebMeter":
            double.tryParse(_ebKwhInSebMeterController.text) ?? 0.0,
        "ebKwhInCcu": double.tryParse(_ebKwhInCcuController.text) ?? 0.0,
        "ebKvaInCcu": double.tryParse(_ebKvhInCcuController.text) ?? 0.0,
        "voltage": double.tryParse(_voltageController.text) ?? 0.0,
        "load": double.tryParse(_loadController.text) ?? 0.0,
        "ebKvaInSebMeter":
            double.tryParse(_ebKvaInSebMeterController.text) ?? 0.0,
        "documentName": "",
        "anyMajorHazardousPunchPoint": _selectedBatteryStatus ?? "",
        "ebAttachmentFileId": _ERImageID,
        "isActive": true,
        "remarks": _remarksController.text,
      };

      Logger.debugLog("📤 EnergyReading: $energyReading");
      print("📤 EnergyReading: $energyReading");

      await ServiceLocator().assetAuditPostService
          .postAssetAuditDataWithPhotoReplacement(
            requests: [energyReading],
            isLastPage: true,
            activityType: ActivityTypeEnum.energyReading,
          );

      Logger.debugLog("✅ Energy Reading posted successfully");
      print("✅ Energy Reading posted successfully");
    } catch (e) {
      Logger.errorLog("❌ Error posting Energy Reading: $e");
      print("❌ Error posting Energy Reading: $e");
      // Re-throw the error so it can be caught by the calling method
      rethrow;
    }
  }

  void _showUnsavedChangesDialog() {
    if (_hasFormDataChanges) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => UnsavedChangesDialog(
          siteAuditSchId: widget.siteAuditSchId,
          section: "Energy Reading",
          parentContext: context,
          onSaveAndExit: () async {
            await postCurrentScreenData();
          },
          onDiscard: () {},
        ),
      );
    } else {
      AssetAuditNavigationHelper.navigateToHomeScreen(context);
    }
  }

  @override
  void dispose() {
    _consumerNoController.dispose();
    _meterNoController.dispose();
    _ebMeterReadingController.dispose();
    _ebKwhInSebMeterController.dispose();
    _ebKwhInCcuController.dispose();
    _ebKvhInCcuController.dispose();
    _voltageController.dispose();
    _loadController.dispose();
    _ebKvaInSebMeterController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  bool _validateFormFields() {
    // Check dropdown selections
    if (_selectedStatus == null || _selectedStatus!.isEmpty) {
      Toastbar.showErrorToastbar("EB Meter Status is required", context);
      return false;
    }

    if (_selectedMeterType == null || _selectedMeterType!.isEmpty) {
      Toastbar.showErrorToastbar("EB Meter Type is required", context);
      return false;
    }

    if (_selectedConnectionType == null || _selectedConnectionType!.isEmpty) {
      Toastbar.showErrorToastbar("Connection Type is required", context);
      return false;
    }

    if (_selectedEbConnectionType == null ||
        _selectedEbConnectionType!.isEmpty) {
      Toastbar.showErrorToastbar("EB Connection Type is required", context);
      return false;
    }

    // Check text fields
    if (_meterNoController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar("EB Meter No is required", context);
      return false;
    }

    if (_ebMeterReadingController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar("EB Meter Reading is required", context);
      return false;
    }

    if (_consumerNoController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar("Consumer No is required", context);
      return false;
    }

    if (_ebKwhInSebMeterController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar("EB KWH in SEB Meter is required", context);
      return false;
    }

    if (_ebKvaInSebMeterController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar("EB KVH in SEB Meter is required", context);
      return false;
    }

    if (_ebKwhInCcuController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar("EB KWH in CCU is required", context);
      return false;
    }

    if (_ebKvhInCcuController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar("EB KVH in CCU is required", context);
      return false;
    }

    if (_voltageController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar("Voltage is required", context);
      return false;
    }

    if (_loadController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar("Load (Amps) is required", context);
      return false;
    }

    if (_selectedBatteryStatus == null || _selectedBatteryStatus!.isEmpty) {
      Toastbar.showErrorToastbar(
        "Any Major Hazardous Punch Point is required",
        context,
      );
      return false;
    }

    // Check if photo is selected
    if (_ERImageID == null || _ERImageID!.isEmpty) {
      Toastbar.showErrorToastbar("Energy Reading photo is required", context);
      return false;
    }

     

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'Energy Reading',
        onClose: _showUnsavedChangesDialog,
      ),
      body: Stack(
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
                      padding: const EdgeInsets.all(16),
                      child: _buildFormFields(),
                    ),
                  ),
                ),
                // Bottom buttons matching AssetAuditTelecomBottomButtons design
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Row(
                    children: [
                      Expanded(
                        child: ArrowButton(
                          text: "Back",
                          isLeftArrow: true,
                          backgroundColor: AppColors.buttonColorBackBg,
                          textColor: AppColors.buttonColorTextBg,
                          onPressed: () {
                            AssetAuditNavigationHelper.navigateToHomeScreen(
                              context,
                            );
                          },
                        ),
                      ),
                      getWidth(14),
                      Expanded(
                        child: ArrowButton(
                          text: "Submit",
                          isLeftArrow: false,
                          backgroundColor: AppColors.buttonColorBg,
                          textColor: AppColors.buttonColorSite,
                          onPressed: () async {
                            // Validate form fields first
                            if (!_validateFormFields()) {
                              return; // Stop execution if validation fails
                            }

                            if (_hasFormDataChanges) {
                              LoaderWidget.showLoader(context);
                              bool dataSavedSuccessfully = false;
                              
                              try {
                                await postCurrentScreenData();
                                dataSavedSuccessfully = true;
                              } catch (e) {
                                Toastbar.showErrorToastbar(
                                  "Error saving data: $e",
                                  context,
                                );
                                // Don't navigate on error - stay on current screen
                                return;
                              } finally {
                                LoaderWidget.hideLoader();
                              }
                              
                              // Only navigate if data was saved successfully
                              if (dataSavedSuccessfully) {
                                AssetAuditNavigationHelper.navigateToHomeScreen(
                                  context,
                                );
                              }
                            } else {
                              // No changes, just navigate
                              AssetAuditNavigationHelper.navigateToHomeScreen(
                                context,
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
        ],
      ),
    );
  }

  void _onFencingImageSelected(String? imageId) {
    setState(() {
      _ERImageID = imageId;
      _hasFormDataChanges = true;
    });
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomDropdown(
          label: "EB Meter Status",
          items: _meterStatusOptions,
          initialValue: _selectedStatus,
          onChanged: (value) {
            setState(() {
              _selectedStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        CustomDropdown(
          label: "EB Meter Type",
          items: _meterTypeOptions,
          initialValue: _selectedMeterType,
          onChanged: (value) {
            setState(() {
              _selectedMeterType = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        CustomDropdown(
          label: "Connection Type",
          items: _connectionTypeOptions,
          initialValue: _selectedConnectionType,
          onChanged: (value) {
            setState(() {
              _selectedConnectionType = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        CustomDropdown(
          label: "EB Connection Type",
          items: _ebConnectionTypeOptions,
          initialValue: _selectedEbConnectionType,
          onChanged: (value) {
            setState(() {
              _selectedEbConnectionType = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),
        CustomFormField(
          label: "EB Meter No",
          controller: _meterNoController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.text,
          hintText: 'EB Meter No',
        ),
        getHeight(15),
        CustomFormField(
          label: "EB Meter Reading",
          controller: _ebMeterReadingController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'EB Meter Reading',
        ),
        getHeight(15),
        CustomFormField(
          label: "Consumer No",
          controller: _consumerNoController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.text,
          hintText: 'Consumer No',
        ),
        getHeight(15),
        CustomFormField(
          label: "EB KWH in SEB Meter",
          controller: _ebKwhInSebMeterController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'EB KWH in SEB Meter',
        ),
        CustomFormField(
          label: "EB KVH in SEB Meter",
          controller: _ebKvaInSebMeterController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'EB KVH in SEB Meter',
        ),

        getHeight(15),
        CustomFormField(
          label: "EB KWH in CCU",
          controller: _ebKwhInCcuController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'EB KWH in CCU',
        ),
        getHeight(15),
        CustomFormField(
          label: "EB KVH in CCU",
          controller: _ebKvhInCcuController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'EB KVH in CCU',
        ),
        getHeight(15),
        CustomFormField(
          label: "Voltage",
          controller: _voltageController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'Voltage',
        ),
        getHeight(15),
        CustomFormField(
          label: "Load (Amps)",
          controller: _loadController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'Load (Amps)',
        ),
        getHeight(15),

        getHeight(15),
        CustomOptionSelector(
          label: "Any Major Hazardous Punch Point",
          isRequired: true,
          options: _batteryStatusOptions
              .map(
                (e) => OptionItem(
                  value: e.toLowerCase(),
                  label: e,
                  selectedIcon: Icons.check_circle,
                  unselectedIcon: Icons.circle_outlined,
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedBatteryStatus = value;
              _onFormChanged();
            });
          },
        ),
        getHeight(15),

        CustomErForm(
          sectionTitle: "Energy Reading",
          showTitle: false,
          isInputEditable: false,
          inputInitialValue: '',

          photoLabel: "Add a Photo",
          isPhotoRequired: true,
          uploadedImageId: _ERImageID,
          onImageSelected: _onFencingImageSelected,
          statusLabel: "Status",
          isStatusRequired: true,

          siteAuditSchId: widget.siteAuditSchId,
          showStatus: false,
        ),
        getHeight(15),
        CustomRemarksField(
          label: "Remarks",
          hintText: "Remarks",
          controller: _remarksController,
          initialValue: "",
        ),
      ],
    );
  }
}
