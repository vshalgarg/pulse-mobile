import 'package:app/commonWidgets/custom_er_form.dart';
import 'package:app/commonWidgets/custom_form_dropdown.dart';
import 'package:app/commonWidgets/custom_radio_options.dart';
import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';

import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_images.dart';
import '../../../constants/app_colors.dart';

class EnergyReadingDetailScreen extends StatefulWidget {
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;
  final String siteId;
  final BuildContext? parentContext;

  const EnergyReadingDetailScreen({
    super.key,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
    required this.siteId,
    this.parentContext,
  });

  @override
  State<EnergyReadingDetailScreen> createState() =>
      _EnergyReadingDetailScreenState();
}

class _EnergyReadingDetailScreenState extends State<EnergyReadingDetailScreen> {
  bool _hasFormDataChanges = false;
  bool _isLoadingData = true;
  String? _errorMessage;

  String? _ERImageID;
  Map<String, dynamic>? _energyReadingData;

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
  
  // New field controllers
  final TextEditingController _ccuEbReadingController = TextEditingController();
  final TextEditingController _ccuLoadController = TextEditingController();
  final TextEditingController _ccuSolarLoadController = TextEditingController();
  final TextEditingController _ccuBatteryLoadController = TextEditingController();
  final TextEditingController _dgRunHourController = TextEditingController();
  final TextEditingController _dieselStockController = TextEditingController();

  // Dropdowns
  String? _selectedStatus;
  String? _selectedMeterType;
  String? _selectedConnectionType;
  String? _selectedEbConnectionType;
  String? _selectedBatteryStatus;
  String? _selectedEbMeterDisplayStatus;
  String? _selectedDgAvailability;

  final List<String> _meterStatusOptions = ['OK', 'Faulty'];
  final List<String> _meterTypeOptions = ['Prepaid', 'Postpaid'];
  final List<String> _connectionTypeOptions = ['LT', 'HT'];
  final List<String> _ebConnectionTypeOptions = ['Single Phase', '3 Phase'];
  final List<String> _batteryStatusOptions = ['Yes', 'No'];

  @override
  void initState() {
    super.initState();

    // Load data first, then add listeners
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _errorMessage = null;
      });

      Logger.debugLog(
        '🔄 Loading Energy Reading data for site ${widget.siteAuditSchId}',
      );

      // Load energy reading data from SQLite
      final data = await ServiceLocator().centralAssetAuditService
          .getActualDataFromSqlite(siteAuditSchId: widget.siteAuditSchId);

      final erData = data?['EnergyReadingData'] ?? {};
      
      // Also check EBPageData for DG availability if not found in EnergyReadingData
      final ebPageData = data?['EBPageData']?.first as Map<String, dynamic>?;

      if (erData != null) {
        Logger.debugLog('✅ Initializing form with saved data: $erData');
        print('🔍 DEBUG: Initializing form with: $erData');

        // Initialize all form fields with loaded data
        _consumerNoController.text = erData['consumerNo']?.toString() ?? '';
        _meterNoController.text = erData['ebMeterNo']?.toString() ?? '';
        _ebMeterReadingController.text =
            erData['ebMeterReading']?.toString() ?? '';
        _ebKwhInSebMeterController.text =
            erData['ebKwhInSebMeter']?.toString() ?? '';
        _ebKwhInCcuController.text = erData['ebKwhInCcu']?.toString() ?? '';
        _ebKvhInCcuController.text = erData['ebKvaInCcu']?.toString() ?? '';
        _voltageController.text = erData['voltage']?.toString() ?? '';
        _loadController.text = erData['load']?.toString() ?? '';
        _ebKvaInSebMeterController.text =
            erData['ebKvaInSebMeter']?.toString() ?? '';
        _remarksController.text = erData['remarks']?.toString() ?? '';
        
        // Initialize new field controllers
        _ccuEbReadingController.text = erData['ccuEbReading']?.toString() ?? '';
        _ccuLoadController.text = erData['ccuLoad']?.toString() ?? '';
        _ccuSolarLoadController.text = erData['ccuSolarLoad']?.toString() ?? '';
        _ccuBatteryLoadController.text = erData['ccuBatteryLoad']?.toString() ?? '';
        _dgRunHourController.text = erData['dgRunHour']?.toString() ?? '';
        _dieselStockController.text = erData['dieselStock']?.toString() ?? '';

        // Initialize dropdowns
        _selectedStatus = erData['ebMeterStatus']?.toString();
        _selectedMeterType = erData['ebMeterType']?.toString();
        _selectedConnectionType = erData['connectionType']?.toString();
        _selectedEbConnectionType = erData['ebConnectionType']?.toString();
        _selectedBatteryStatus = erData['anyMajorHazardousPunchPoint']
            ?.toString();
        _selectedEbMeterDisplayStatus = erData['ebBillReadingDisplayStatus']?.toString();
        
        // Initialize DG Availability - convert boolean to Yes/No
        // Check from multiple possible sources (backend might store it differently)
        // First check EnergyReadingData, then EBPageData, then other possible keys
        dynamic dgAvailability = erData['dgAvailability'] ?? 
                                erData['dg_availability'] ?? 
                                erData['dgAvailable'];
        
        // If not found in EnergyReadingData, check EBPageData
        if (dgAvailability == null && ebPageData != null) {
          dgAvailability = ebPageData['dg_availability'] ?? 
                          ebPageData['dgAvailability'] ?? 
                          ebPageData['dgAvailable'];
        }
        
        if (dgAvailability != null) {
          // Handle boolean, string 'true'/'false', or 'Yes'/'No'
          if (dgAvailability == true || 
              dgAvailability == 'true' || 
              dgAvailability == 'True' || 
              dgAvailability == 'Yes' ||
              dgAvailability == 1) {
            _selectedDgAvailability = 'Yes';
          } else {
            // Explicitly set to 'No' when false, 0, 'false', 'False', 'No', etc.
            _selectedDgAvailability = 'No';
          }
        } else {
          // Default to 'No' if not found, so fields are hidden
          _selectedDgAvailability = 'No';
        }

        // Initialize image ID
        _ERImageID = erData['ebAttachmentFileId']?.toString();

        Logger.debugLog('✅ Form fields initialized successfully');
        print(
          '🔍 DEBUG: Form initialized - ConsumerNo: ${_consumerNoController.text}, Status: $_selectedStatus',
        );
      } else {
        Logger.debugLog(
          'ℹ️ No existing energy reading form data found - fresh form',
        );
        print('🔍 DEBUG: No form data found - showing fresh form');
        
        // Check EBPageData for DG availability even when EnergyReadingData is empty
        if (ebPageData != null) {
          final dgAvailability = ebPageData['dg_availability'] ?? 
                                 ebPageData['dgAvailability'] ?? 
                                 ebPageData['dgAvailable'];
          if (dgAvailability != null) {
            if (dgAvailability == true || 
                dgAvailability == 'true' || 
                dgAvailability == 'True' || 
                dgAvailability == 'Yes' ||
                dgAvailability == 1) {
              _selectedDgAvailability = 'Yes';
            } else {
              _selectedDgAvailability = 'No';
            }
          } else {
            _selectedDgAvailability = 'No';
          }
        } else {
          // Default to 'No' if no data found anywhere
          _selectedDgAvailability = 'No';
        }
      }

      setState(() {
        _energyReadingData = data;
        _isLoadingData = false;
      });

      // Add listeners after loading data to avoid triggering change flag
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
      _ccuEbReadingController.addListener(_onFormChanged);
      _ccuLoadController.addListener(_onFormChanged);
      _ccuSolarLoadController.addListener(_onFormChanged);
      _ccuBatteryLoadController.addListener(_onFormChanged);
      _dgRunHourController.addListener(_onFormChanged);
      _dieselStockController.addListener(_onFormChanged);
    } catch (e) {
      Logger.errorLog('❌ Error loading Energy Reading data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  void _onFormChanged() {
    if (!_hasFormDataChanges) {
      setState(() {
        _hasFormDataChanges = true;
      });
    }
  }

  // Helper method to parse double values, handling empty strings and whitespace
  double? _parseDouble(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  Future<void> postCurrentScreenData() async {
    try {
      final energyReading = {
        "createdby": null,
        "createddt": null,
        "modifiedby": null,
        "modifieddt": null,
        "tenantId": null,
        "energyReadingId": 0,
        "auditSchId": widget.auditSchId,
        "siteAuditSchId": widget.siteAuditSchId,
        "siteId": widget.siteId,
        "connectionType": _selectedConnectionType?.isNotEmpty == true ? _selectedConnectionType : null,
        "consumerNo": _consumerNoController.text.trim().isNotEmpty ? _consumerNoController.text.trim() : null,
        "ebMeterStatus": _selectedStatus?.isNotEmpty == true ? _selectedStatus : null,
        "ebConnectionType": _selectedEbConnectionType?.isNotEmpty == true ? _selectedEbConnectionType : null,
        "ebMeterType": _selectedMeterType?.isNotEmpty == true ? _selectedMeterType : null,
        "ebMeterNo": _meterNoController.text.trim().isNotEmpty ? _meterNoController.text.trim() : null,
        "ebMeterReading": _parseDouble(_ebMeterReadingController.text),
        "ebKwhInSebMeter": _parseDouble(_ebKwhInSebMeterController.text),
        "ebKvaInSebMeter": _parseDouble(_ebKvaInSebMeterController.text),
        "ebKwhInCcu": _parseDouble(_ebKwhInCcuController.text),
        "ebKvaInCcu": _parseDouble(_ebKvhInCcuController.text),
        "voltage": _parseDouble(_voltageController.text),
        "yPhaseVoltagePn": null,
        "bPhaseVoltagePn": null,
        "loadInRPhaseAmpsInEbMeter": null,
        "loadInYPhaseAmpsInEbMeter": null,
        "load": _parseDouble(_loadController.text),
        "rectificationRequired": null,
        "anyMajorHazardousPunchPoint": _selectedBatteryStatus?.isNotEmpty == true ? _selectedBatteryStatus : null,
        "ebAttachmentFileId": _ERImageID,
        "ebBillReadingDisplayStatus": _selectedEbMeterDisplayStatus?.isNotEmpty == true ? _selectedEbMeterDisplayStatus : null,
        "ccuEbReading": _parseDouble(_ccuEbReadingController.text),
        "ccuLoad": _parseDouble(_ccuLoadController.text),
        "ccuSolarLoad": _parseDouble(_ccuSolarLoadController.text),
        "ccuBatteryLoad": _parseDouble(_ccuBatteryLoadController.text),
        "dgRunHour": _dgRunHourController.text.trim().isNotEmpty ? _dgRunHourController.text.trim() : null,
        "dieselStock": _parseDouble(_dieselStockController.text),
        "isActive": true,
        "documentName": null,
        "remarks": _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
        "dgAvailability": _selectedDgAvailability == 'Yes',
      };

      Logger.debugLog("📤 EnergyReading: $energyReading");
      print("📤 EnergyReading: $energyReading");

      // Get the current full data from SQLite or use existing
      final updatedData = Map<String, dynamic>.from(_energyReadingData ?? {});

      print(
        "🔍 DEBUG: Current _energyReadingData before save: $_energyReadingData",
      );

      // Merge the energy reading form data into the existing structure
      // Store under 'energyReading' key to keep it separate from site info
      updatedData['energyReading'] = energyReading;

      // Also store at root level for backward compatibility
      updatedData.addAll(energyReading);

      Logger.debugLog("💾 Saving Energy Reading data to SQLite...");
      Logger.debugLog(
        "💾 Updated data structure: ${updatedData.keys.toList()}",
      );
      print(
        "🔍 DEBUG: Updated data structure keys: ${updatedData.keys.toList()}",
      );
      print("🔍 DEBUG: Updated data structure: $updatedData");

      // Update data in SQLite before posting to server
      final success = await ServiceLocator().centralAssetAuditService
          .updateDataInSqlite(
            siteAuditSchId: widget.siteAuditSchId,
            updatedData: updatedData,
          );

      if (success) {
        Logger.debugLog("✅ Energy Reading data saved to SQLite successfully");
        print("✅ Energy Reading data saved to SQLite successfully");
        print("🔍 DEBUG: Data saved successfully, updating local state");
        // Update local state with saved data
        setState(() {
          _energyReadingData = updatedData;
        });
      } else {
        Logger.errorLog("⚠️ Failed to save Energy Reading data to SQLite");
        print("⚠️ Failed to save Energy Reading data to SQLite");
      }

      // Post data to server
      Logger.debugLog("📤 Posting Energy Reading data to server...");
      await ServiceLocator().assetAuditPostService
          .postAssetAuditDataWithPhotoReplacement(
            requests: [energyReading],
            isLastPage: true,
            activityType: ActivityTypeEnum.energyReading,
          );

      Logger.debugLog("✅ Energy Reading posted to server successfully");
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
          parentContext: widget.parentContext ?? context,
          onSaveAndExit: () async {
            await postCurrentScreenData();
          },
          onDiscard: () {},
        ),
      );
    } else {
      navigateBackOrToHome(
        context,
        targetContext: widget.parentContext ?? context,
      );
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
    _ccuEbReadingController.dispose();
    _ccuLoadController.dispose();
    _ccuSolarLoadController.dispose();
    _ccuBatteryLoadController.dispose();
    _dgRunHourController.dispose();
    _dieselStockController.dispose();
    super.dispose();
  }

  bool _validateFormFields() {
    // Check dropdown selections
    if (_selectedStatus == null || _selectedStatus!.isEmpty) {
      Toastbar.showErrorToastbar("EB Meter Status is required", context);
      return false;
    }

    if (_selectedStatus == 'OK') {
      if (_ERImageID == null || _ERImageID!.isEmpty) {
        Toastbar.showErrorToastbar("EB Meter photo is required", context);
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

      if (_ebKwhInCcuController.text.trim().isEmpty) {
        Toastbar.showErrorToastbar("EB KWH in CCU is required", context);
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

    if (_remarksController.text.trim().isEmpty) {
      Toastbar.showErrorToastbar("Remarks is required", context);
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
            child: _isLoadingData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading energy reading data...',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.errorColor,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 100,
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
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ArrowButton(
                                text: "Back",
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
                                      navigateBackOrToHome(
                                        context,
                                        targetContext:
                                            widget.parentContext ?? context,
                                      );
                                    }
                                  } else {
                                    navigateBackOrToHome(
                                      context,
                                      targetContext:
                                          widget.parentContext ?? context,
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
          label: "EB Meter Display Status",
          items: _meterStatusOptions,
          initialValue: _selectedEbMeterDisplayStatus,
          onChanged: (value) {
            setState(() {
              _selectedEbMeterDisplayStatus = value;
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

        // new addition of fields
        CustomFormField(
          label: "CCU EB Reading(kWh)",
          controller: _ccuEbReadingController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'Numeric',
        ),
        getHeight(15),

        CustomFormField(
          label: "CCU Load(kWh)",
          controller: _ccuLoadController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'Numeric',
        ),
        getHeight(15),

        CustomFormField(
          label: "CCU Solar Load(kWh)",
          controller: _ccuSolarLoadController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'Numeric',
        ),
        getHeight(15),

        CustomFormField(
          label: "CCU Battery Load(kWh)",
          controller: _ccuBatteryLoadController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'Numeric',
        ),
        getHeight(15),

        CustomFormField(
          label: "DG Availability",
          initialValue: _selectedDgAvailability ?? 'No',
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),

        if (_selectedDgAvailability == 'Yes') ...[
          CustomFormField(
            label: "DG Run Hour",
            controller: _dgRunHourController,
            isRequired: true,
            isEditable: true,
            keyboardType: TextInputType.text,
            hintText: 'Text',
          ),
          getHeight(15),

          CustomFormField(
            label: "Diesel Stock",
            controller: _dieselStockController,
            isRequired: true,
            isEditable: true,
            keyboardType: TextInputType.number,
            hintText: 'Numeric',
          ),
          getHeight(15),
        ],

        //end
        CustomFormField(
          label: "Consumer No",
          controller: _consumerNoController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.number,
          hintText: 'Numeric',
        ),
        getHeight(15),

        //new fields
        CustomFormField(
          label: "EB KWH in SEB Meter",
          controller: _ebKwhInSebMeterController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.text,
          hintText: 'Text',
        ),
        getHeight(15),

        CustomFormField(
          label: "EB KVA in SEB Meter",
          controller: _ebKvaInSebMeterController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.text,
          hintText: 'Text',
        ),
        getHeight(15),

        // text
        CustomFormField(
          label: "EB KWH in CCU",
          controller: _ebKwhInCcuController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.text,
          hintText: 'Text',
        ),
        getHeight(15),

        //nre field
        CustomFormField(
          label: "EB KVA in CCU",
          controller: _ebKvhInCcuController,
          isRequired: true,
          isEditable: true,
          keyboardType: TextInputType.text,
          hintText: 'Text',
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
        CustomRadioButton(
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
          initialValue: _selectedBatteryStatus,
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
