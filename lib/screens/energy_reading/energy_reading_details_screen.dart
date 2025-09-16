import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/custom_file_upload.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:app/bloc/energy_reading_detail_cubit.dart';
import 'package:app/models/energy_reading_detail_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/services/local_storage_db.dart';

import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';
import '../../commonWidgets/custom_form_dropdown.dart';

class EnergyDetailScreen extends StatefulWidget {
  final String auditSchId;
  final String siteAuditSchId;
  final String siteId;

  const EnergyDetailScreen({
    super.key,
    required this.auditSchId,
    required this.siteAuditSchId,
    required this.siteId,
  });

  @override
  State<EnergyDetailScreen> createState() => _EnergyDetailScreenState();
}

class _EnergyDetailScreenState extends State<EnergyDetailScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedFile;
  String? selectedStatus;
  String? selectedBatteryStatus;
  String? selectedType;
  String? selectedMeterType;
  String? selectedConnectionType;
  String? selectedEbConnectionType;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false; // Control when to show validation errors
  int totalRectifierItems = 6; // Total rectifier items to scan
  int totalMPPTItems = 6; // Total MPPT items to scan
  int currentScannedItems = 0; // Number of items already scanned
  List<Map<String, dynamic>> savedRectifierItems =
      []; // List to store saved rectifier items
  List<Map<String, dynamic>> savedMPPTItems =
      []; // List to store saved MPPT items
  Map<String, dynamic> currentFormData = {}; // Current form data
  String? uploadedPhotoPath;

  // File upload related variables
  File? selectedUploadFile;
  String? selectedFileName;
  String? selectedFileSize;
  String? uploadedFileId; // Store the uploaded file ID from API
  bool isEditMode = false; // Track if this is edit mode
  String? editId; // Store the ID for edit mode

  // AssetTypeCard field values for Rectifier
  String? rectifierSerialNumber;
  String? rectifierPhoto;
  String? rectifierStatus;
  final remarksController = TextEditingController();

  // AssetTypeCard field values for MPPT
  String? mpptSerialNumber;
  String? mpptPhoto;
  String? mpptStatus;

  // Controllers for CustomInfoCard
  final TextEditingController rectifierSerialController =
      TextEditingController();
  final TextEditingController mpptSerialController = TextEditingController();

  // Controllers for form fields
  final TextEditingController ebMeterNumberController = TextEditingController();
  final TextEditingController ebMeterReadingController = TextEditingController();
  final TextEditingController consumerNumberController = TextEditingController();
  final TextEditingController ebKwhInSebMeterController = TextEditingController();
  final TextEditingController ebKwhInCcuController = TextEditingController();
  final TextEditingController ebKvhInCcuController = TextEditingController();
  final TextEditingController voltageController = TextEditingController();
  final TextEditingController loadAmpsController = TextEditingController();
  final TextEditingController powerFactorController = TextEditingController();
  final TextEditingController frequencyController = TextEditingController();
  final TextEditingController powerController = TextEditingController();
  final TextEditingController energyController = TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int rectifierCardKey = 0;
  int mpptCardKey = 0;

  @override
  void initState() {
    super.initState();
    
    // Listen to form changes
    serialController.addListener(_onFormChanged);
    
    // Add listeners to form field controllers
    ebMeterNumberController.addListener(_onFormChanged);
    ebMeterReadingController.addListener(_onFormChanged);
    consumerNumberController.addListener(_onFormChanged);
    ebKwhInSebMeterController.addListener(_onFormChanged);
    ebKwhInCcuController.addListener(_onFormChanged);
    ebKvhInCcuController.addListener(_onFormChanged);
    voltageController.addListener(_onFormChanged);
    loadAmpsController.addListener(_onFormChanged);
    powerFactorController.addListener(_onFormChanged);
    frequencyController.addListener(_onFormChanged);
    powerController.addListener(_onFormChanged);
    energyController.addListener(_onFormChanged);
    
    // Load saved form data
    _loadSavedFormData();
  }

  // Load saved form data from local storage
  void _loadSavedFormData() {
    try {
      final savedData = LocalStorageDB.getEnergyReadingFormData;
      if (savedData != null) {
        setState(() {
          // Load dropdown selections
          selectedStatus = savedData['selectedStatus']?.toString();
          selectedBatteryStatus = savedData['selectedBatteryStatus']?.toString();
          selectedType = savedData['selectedType']?.toString();
          selectedMeterType = savedData['selectedMeterType']?.toString();
          selectedConnectionType = savedData['selectedConnectionType']?.toString();
          selectedEbConnectionType = savedData['selectedEbConnectionType']?.toString();
          
          // Load text controller values
          ebMeterNumberController.text = savedData['ebMeterNumber']?.toString() ?? '';
          ebMeterReadingController.text = savedData['ebMeterReading']?.toString() ?? '';
          consumerNumberController.text = savedData['consumerNumber']?.toString() ?? '';
          ebKwhInSebMeterController.text = savedData['ebKwhInSebMeter']?.toString() ?? '';
          ebKwhInCcuController.text = savedData['ebKwhInCcu']?.toString() ?? '';
          ebKvhInCcuController.text = savedData['ebKvhInCcu']?.toString() ?? '';
          voltageController.text = savedData['voltage']?.toString() ?? '';
          loadAmpsController.text = savedData['loadAmps']?.toString() ?? '';
          powerFactorController.text = savedData['powerFactor']?.toString() ?? '';
          frequencyController.text = savedData['frequency']?.toString() ?? '';
          powerController.text = savedData['power']?.toString() ?? '';
          energyController.text = savedData['energy']?.toString() ?? '';
          remarksController.text = savedData['remarks']?.toString() ?? '';
          
          // Load file information
          selectedFileName = savedData['selectedFileName']?.toString();
          selectedFileSize = savedData['selectedFileSize']?.toString();
          uploadedFileId = savedData['uploadedFileId']?.toString();
          
          hasUnsavedChanges = false;
        });
      
              // Show message that data was restored
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Previous form data has been restored!',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 14,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              backgroundColor: Colors.white,
              duration: Duration(seconds: 3),
            ),
          );
        });
      }
    } catch (e) {
      // If there's an error loading saved data, just continue with empty form
      print('Error loading saved form data: $e');
    }
  }

  // Save current form data to local storage
  Future<void> _saveFormDataLocally() async {
    final formData = {
      // Dropdown selections
      'selectedStatus': selectedStatus,
      'selectedBatteryStatus': selectedBatteryStatus,
      'selectedType': selectedType,
      'selectedMeterType': selectedMeterType,
      'selectedConnectionType': selectedConnectionType,
      'selectedEbConnectionType': selectedEbConnectionType,
      
      // Text controller values
      'ebMeterNumber': ebMeterNumberController.text,
      'ebMeterReading': ebMeterReadingController.text,
      'consumerNumber': consumerNumberController.text,
      'ebKwhInSebMeter': ebKwhInSebMeterController.text,
      'ebKwhInCcu': ebKwhInCcuController.text,
      'ebKvhInCcu': ebKvhInCcuController.text,
      'voltage': voltageController.text,
      'loadAmps': loadAmpsController.text,
      'powerFactor': powerFactorController.text,
      'frequency': frequencyController.text,
      'power': powerController.text,
      'energy': energyController.text,
      'remarks': remarksController.text,
      
      // File information
      'selectedFileName': selectedFileName,
      'selectedFileSize': selectedFileSize,
      'uploadedFileId': uploadedFileId,
    };
    
    await LocalStorageDB.saveEnergyReadingFormData(formData);
    await LocalStorageDB.saveEnergyReadingIds(
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
      siteId: widget.siteId,
    );
  }

  @override
  void dispose() {
    serialController.removeListener(_onFormChanged);
    serialController.dispose();
    rectifierSerialController.dispose();
    mpptSerialController.dispose();
    
    // Dispose form field controllers
    ebMeterNumberController.dispose();
    ebMeterReadingController.dispose();
    consumerNumberController.dispose();
    ebKwhInSebMeterController.dispose();
    ebKwhInCcuController.dispose();
    ebKvhInCcuController.dispose();
    voltageController.dispose();
    loadAmpsController.dispose();
    powerFactorController.dispose();
    frequencyController.dispose();
    powerController.dispose();
    energyController.dispose();
    
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges =
          selectedFile != null ||
          selectedStatus != null ||
          selectedBatteryStatus != null ||
          selectedType != null ||
          selectedMeterType != null ||
          selectedConnectionType != null ||
          selectedEbConnectionType != null ||
          serialController.text.isNotEmpty ||
          selectedUploadFile != null ||
          ebMeterNumberController.text.isNotEmpty ||
          ebMeterReadingController.text.isNotEmpty ||
          consumerNumberController.text.isNotEmpty ||
          ebKwhInSebMeterController.text.isNotEmpty ||
          ebKwhInCcuController.text.isNotEmpty ||
          ebKvhInCcuController.text.isNotEmpty ||
          voltageController.text.isNotEmpty ||
          loadAmpsController.text.isNotEmpty ||
          powerFactorController.text.isNotEmpty ||
          frequencyController.text.isNotEmpty ||
          powerController.text.isNotEmpty ||
          energyController.text.isNotEmpty ||
          remarksController.text.isNotEmpty;

      // Hide validation errors when user starts filling the form
      if (showValidationErrors &&
          selectedFile != null &&
          selectedBatteryStatus != null &&
          selectedType != null &&
          serialController.text.isNotEmpty) {
        showValidationErrors = false;
      }
    });
  }

  // File upload functionality
  Future<void> _handleFileUpload() async {
    try {
      // Open file picker for documents, files, and photos
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        
        if (pickedFile.path == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error: Could not access file path',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              backgroundColor: AppColors.errorColor,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        final file = File(pickedFile.path!);
        final fileName = pickedFile.name;
        final fileSize = pickedFile.size;

        // Check if file exists
        if (!await file.exists()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error: Selected file not found',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              backgroundColor: AppColors.errorColor,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        // Check file size (5MB limit for documents)
        if (fileSize > 5 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'File size must be less than 5MB',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              backgroundColor: AppColors.errorColor,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        setState(() {
          selectedUploadFile = file;
          selectedFileName = fileName;
          selectedFileSize = _formatFileSize(fileSize);
          hasUnsavedChanges = true;
        });

        // Upload file to server
        context.read<EnergyReadingDetailCubit>().uploadFile(
          file: file,
          id: isEditMode ? (editId ?? '0') : '0',
        );
        
      } else {
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error uploading file: ${e.toString()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          backgroundColor: AppColors.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Delete uploaded file
  void _deleteUploadedFile() {
    setState(() {
      selectedUploadFile = null;
      selectedFileName = null;
      selectedFileSize = null;
      hasUnsavedChanges = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'File removed successfully',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: fontFamilyMontserrat,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _saveAndExit() async {
    // First close the unsaved changes dialog
    Navigator.of(context).pop();

    // Check if there's any data to save
    if (_hasAnyDataToSave()) {
      // // Show loading indicator
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text(
      //       'Saving data...',
      //       style: TextStyle(
      //         color: Colors.white,
      //         fontSize: 14,
      //         fontFamily: fontFamilyMontserrat,
      //       ),
      //     ),
      //     backgroundColor: Colors.blue,
      //     duration: Duration(seconds: 1),
      //   ),
      // );

      // Save data locally
      await _saveFormDataLocally();
      
      // Wait a moment to show the loading message
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Show success dialog (data saved locally)
      _showSuccessDialog();
    } else {
      // No data to save, just show success dialog
      _showSuccessDialog();
    }
  }

  // Check if there's any data filled in the form
  bool _hasAnyDataToSave() {
    return selectedStatus != null ||
           selectedBatteryStatus != null ||
           selectedType != null ||
           selectedMeterType != null ||
           selectedConnectionType != null ||
           selectedEbConnectionType != null ||
           ebMeterNumberController.text.isNotEmpty ||
           ebMeterReadingController.text.isNotEmpty ||
           consumerNumberController.text.isNotEmpty ||
           ebKwhInSebMeterController.text.isNotEmpty ||
           ebKwhInCcuController.text.isNotEmpty ||
           ebKvhInCcuController.text.isNotEmpty ||
           voltageController.text.isNotEmpty ||
           loadAmpsController.text.isNotEmpty ||
           powerFactorController.text.isNotEmpty ||
           frequencyController.text.isNotEmpty ||
           powerController.text.isNotEmpty ||
           energyController.text.isNotEmpty ||
           remarksController.text.isNotEmpty ||
           selectedUploadFile != null;
  }

  // Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => SuccessDialog(
        ticketId: "ER-${DateTime.now().millisecondsSinceEpoch}",
        message: "Energy Reading data has been saved locally! You can continue later.",
        onDone: () {
          Navigator.of(context).pop(); // Close dialog
          // Navigate to home screen
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/homeScreen',
            (route) => false,
          );
        },
      ),
    );
  }

  // Validate required fields for saved items only
  bool _isFormValid() {

    String? serialNumber = rectifierSerialController.text.isNotEmpty
        ? rectifierSerialController.text
        : mpptSerialController.text.isNotEmpty
        ? mpptSerialController.text
        : null;

    if (serialNumber == null || serialNumber.isEmpty) {
      return false;
    }

    String? photo = rectifierPhoto ?? mpptPhoto;
    if (photo == null || photo.isEmpty) {
      return false;
    }


    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });
    
    // Check if all required form fields are filled
    if (ebMeterNumberController.text.trim().isEmpty) {
      return false;
    }
    
    if (ebMeterReadingController.text.trim().isEmpty) {
      return false;
    }
    
    if (consumerNumberController.text.trim().isEmpty) {
      return false;
    }
    
    if (ebKwhInSebMeterController.text.trim().isEmpty) {
      return false;
    }
    
    if (ebKwhInCcuController.text.trim().isEmpty) {
      return false;
    }
    
    if (ebKvhInCcuController.text.trim().isEmpty) {
      return false;
    }
    
    if (voltageController.text.trim().isEmpty) {
      return false;
    }
    
    if (loadAmpsController.text.trim().isEmpty) {
      return false;
    }
    
    if (powerFactorController.text.trim().isEmpty) {
      return false;
    }
    
    if (frequencyController.text.trim().isEmpty) {
      return false;
    }
    
    if (powerController.text.trim().isEmpty) {
      return false;
    }
    
    if (energyController.text.trim().isEmpty) {
      return false;
    }

    // Check if file is uploaded (required field)
    if (selectedUploadFile == null) {
      return false;
    } else {
    }

    return true;
  }


  // Handle form submission
  void _handleSubmit() async {
    if (_validateForm()) {
      // Form is valid, proceed with submission
      
      // Collect form data
      final formData = _collectFormData();
      
      // Save data to server
      final energyReadingRequest = EnergyReadingDetailRequest(
        energyReadingId: formData['energyReadingId'] as int,
        auditSchId: formData['auditSchId'] as int,
        siteAuditSchId: formData['siteAuditSchId'] as int,
        siteId: formData['siteId'] as int,
        connectionType: formData['connectionType'] as String,
        consumerNo: formData['consumerNo'] as String,
        ebMeterStatus: formData['ebMeterStatus'] as String,
        ebConnectionType: formData['ebConnectionType'] as String,
        ebMeterType: formData['ebMeterType'] as String,
        ebMeterNo: formData['ebMeterNo'] as String,
        ebMeterReading: formData['ebMeterReading'] as double,
        ebKwhInSebMeter: formData['ebKwhInSebMeter'] as double,
        ebKvaInSebMeter: formData['ebKvaInSebMeter'] as double,
        ebKwhInCcu: formData['ebKwhInCcu'] as double,
        ebKvaInCcu: formData['ebKvaInCcu'] as double,
        voltage: formData['voltage'] as double,
        load: formData['load'] as double,
        documentName: formData['documentName'] as String,
        anyMajorHazardousPunchPoint: formData['anyMajorHazardousPunchPoint'] as String,
        ebAttachmentFileId: formData['ebAttachmentFileId'] as int,
        isActive: formData['isActive'] as bool,
        remarks: formData['remarks'] as String,
      );
      
      context.read<EnergyReadingDetailCubit>().saveEnergyReadingData(
        energyReadingData: energyReadingRequest,
      );
      
      // BlocListener will handle the success/error messages
    } else {
      // Form validation failed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all required fields',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          backgroundColor: AppColors.errorColor,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Collect all form data
  Map<String, dynamic> _collectFormData() {
    final formData = {
      "energyReadingId": isEditMode ? int.tryParse(editId ?? '0') ?? 0 : 0,
      "auditSchId": int.tryParse(widget.auditSchId) ?? 0,
      "siteAuditSchId": int.tryParse(widget.siteAuditSchId) ?? 0,
      "siteId": int.tryParse(widget.siteId) ?? 0,
      "connectionType": selectedConnectionType ?? '',
      "consumerNo": consumerNumberController.text.trim(),
      "ebMeterStatus": selectedStatus ?? '',
      "ebConnectionType": selectedEbConnectionType ?? '',
      "ebMeterType": selectedMeterType ?? '',
      "ebMeterNo": ebMeterNumberController.text.trim(),
      "ebMeterReading": double.tryParse(ebMeterReadingController.text.trim()) ?? 0.0,
      "ebKwhInSebMeter": double.tryParse(ebKwhInSebMeterController.text.trim()) ?? 0.0,
      "ebKvaInSebMeter": 0.0, // Set appropriate value if needed
      "ebKwhInCcu": double.tryParse(ebKwhInCcuController.text.trim()) ?? 0.0,
      "ebKvaInCcu": double.tryParse(ebKvhInCcuController.text.trim()) ?? 0.0,
      "voltage": double.tryParse(voltageController.text.trim()) ?? 0.0,
      "load": double.tryParse(loadAmpsController.text.trim()) ?? 0.0,
      "documentName": selectedFileName ?? '',
      "anyMajorHazardousPunchPoint": selectedBatteryStatus ?? '',
      "ebAttachmentFileId": int.tryParse(uploadedFileId ?? '0') ?? 0,
      "isActive": true,
      "remarks": remarksController.text.trim(),
    };
    
    return formData;
  }

  // Clear all form fields
  Future<void> _clearFormFields() async {
    setState(() {
      // Clear dropdown selections
      selectedStatus = null;
      selectedType = null;
      selectedMeterType = null;
      selectedConnectionType = null;
      selectedEbConnectionType = null;
      selectedBatteryStatus = null;
      
      // Clear file upload
      selectedUploadFile = null;
      selectedFileName = null;
      selectedFileSize = null;
      uploadedFileId = null;
      
      // Clear all text controllers
      ebMeterNumberController.clear();
      ebMeterReadingController.clear();
      consumerNumberController.clear();
      ebKwhInSebMeterController.clear();
      ebKwhInCcuController.clear();
      ebKvhInCcuController.clear();
      voltageController.clear();
      loadAmpsController.clear();
      powerFactorController.clear();
      frequencyController.clear();
      powerController.clear();
      energyController.clear();
      remarksController.clear();
      
      // Reset flags
      hasUnsavedChanges = false;
      showValidationErrors = false;
    });
    
    // Clear saved data from local storage
    await LocalStorageDB.clearEnergyReadingData();
  }

  // Initialize edit mode with existing data
  void initializeEditMode(String id, Map<String, dynamic> existingData) {
    setState(() {
      isEditMode = true;
      editId = id;
      
      // Populate form fields with existing data
      selectedStatus = existingData['ebMeterStatus'];
      selectedMeterType = existingData['ebMeterType'];
      selectedConnectionType = existingData['connectionType'];
      selectedEbConnectionType = existingData['ebConnectionType'];
      selectedBatteryStatus = existingData['hazardousPunchPoint'];
      
      ebMeterNumberController.text = existingData['ebMeterNumber'] ?? '';
      ebMeterReadingController.text = existingData['ebMeterReading'] ?? '';
      consumerNumberController.text = existingData['consumerNumber'] ?? '';
      ebKwhInSebMeterController.text = existingData['ebKwhInSebMeter'] ?? '';
      ebKwhInCcuController.text = existingData['ebKwhInCcu'] ?? '';
      ebKvhInCcuController.text = existingData['ebKvhInCcu'] ?? '';
      voltageController.text = existingData['voltage'] ?? '';
      loadAmpsController.text = existingData['loadAmps'] ?? '';
      powerFactorController.text = existingData['powerFactor'] ?? '';
      frequencyController.text = existingData['frequency'] ?? '';
      powerController.text = existingData['power'] ?? '';
      energyController.text = existingData['energy'] ?? '';
      remarksController.text = existingData['remarks'] ?? '';
      
      // Set file information if exists
      uploadedFileId = existingData['fileId'];
      selectedFileName = existingData['fileName'];
      selectedFileSize = existingData['fileSize'];
      
      hasUnsavedChanges = false;
    });
  }

  // Edit a specific Rectifier item from the saved list
  void _editItem(Map<String, dynamic> item) {
    setState(() {
      // Load the item data back into the form
      rectifierSerialNumber = item["serialNumber"];
      rectifierPhoto = item["photo"];
      rectifierStatus = item["status"];

      // Set the serial controller text
      rectifierSerialController.text = item["serialNumber"] ?? "";

      // Remove the item from saved rectifier items
      savedRectifierItems.remove(item);
      currentScannedItems--;

      // Force rebuild of the CustomInfoCard widget with new data
      rectifierCardKey++;

      hasUnsavedChanges = true;
    });

  }


  @override
  Widget build(BuildContext context) {
    return BlocListener<EnergyReadingDetailCubit, EnergyReadingDetailState>(
      listener: (context, state) async {
        if (state is FileUploadSuccess) {
          setState(() {
            uploadedFileId = state.fileId;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File "${selectedFileName ?? 'Unknown'}" uploaded successfully!',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 14,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              backgroundColor: Colors.white,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (state is EnergyReadingDetailSaveSuccess) {
          // Clear saved data since it was successfully submitted to server
          await LocalStorageDB.clearEnergyReadingData();
          
          // Show success dialog for both normal submission and save-and-exit
          _showSuccessDialog();
        } else if (state is EnergyReadingDetailFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              backgroundColor: AppColors.errorColor,
              duration: Duration(seconds: 3),
            ),
          );
        }
      },
      child: PopScope(
        canPop: !hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (hasUnsavedChanges) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => UnsavedChangesDialog(
              message: "Do you want to save the current data and exit, or discard all changes?",
              onSaveAndExit: () async {
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
          title: "Energy Reading",
          onClose: () async {
            if (hasUnsavedChanges) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => UnsavedChangesDialog(
                  message: "Do you want to save the current data and exit, or discard all changes?",
                  onSaveAndExit: () async {
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
                          bottom:
                              MediaQuery.of(context).viewInsets.bottom + 120,
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
                              CustomDropdown(
                                label: "EB Meter Status",
                                items: ["OK", "Faulty"],
                                initialValue: selectedStatus,
                                onChanged: (value) {
                                  setState(() {
                                    selectedStatus = value;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
                              CustomDropdown(
                                label: "EB Meter Type",
                                items: ["Prepaid", "Postpaid"],
                                initialValue: selectedMeterType,
                                onChanged: (value) {
                                  setState(() {
                                    selectedMeterType = value;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
                              CustomDropdown(
                                label: "Connection Type",
                                items: ["LT", "HT"],
                                initialValue: selectedConnectionType,
                                onChanged: (value) {
                                  setState(() {
                                    selectedConnectionType = value;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
                              CustomDropdown(
                                label: "EB Connection Type",
                                items: ["Single Phase", "3 Phase"],
                                initialValue: selectedEbConnectionType,
                                onChanged: (value) {
                                  setState(() {
                                    selectedEbConnectionType = value;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "EB Meter Number",
                                hintText: 'Number',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: ebMeterNumberController,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "EB Meter Reading",
                                hintText: 'Number',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: ebMeterReadingController,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Consumer Number",
                                hintText: 'Number',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: consumerNumberController,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "EB KWH in SEB Meter",
                                hintText: 'Text',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: ebKwhInSebMeterController,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "EB KWH in CCU",
                                hintText: 'Text',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: ebKwhInCcuController,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "EB KVH in CCU",
                                hintText: 'Text',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: ebKvhInCcuController,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Voltage",
                                hintText: 'Text',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: voltageController,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Load (Amps)",
                                hintText: 'Text',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: loadAmpsController,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Power Factor",
                                hintText: '0.00 - 1.00',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: powerFactorController,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Frequency (Hz)",
                                hintText: '50 or 60',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: frequencyController,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Power (kW)",
                                hintText: 'Text',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: powerController,
                              ),
                              getHeight(15),
                              CustomFormField(
                                label: "Energy (kWh)",
                                hintText: 'Text',
                                initialValue: "",
                                isRequired: true,
                                isEditable: true,
                                controller: energyController,
                              ),
                              getHeight(15),
                              CustomOptionSelector(
                                label: "Any Major Hazardous Punch Point",
                                isRequired: true,
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
                                onChanged: (value) {
                                  setState(() {
                                    selectedBatteryStatus = value;
                                    hasUnsavedChanges = true;
                                  });
                                },
                              ),


                              // ImageUploadField(
                              //   label: "Add Photo of Battery Modules *",
                              //   placeholder: "Add Photo",
                              //   isRequired: true,
                              //   onImageSelected: (file) {
                              //     if (file != null) {
                              //       debugPrint(
                              //         "Selected image path: ${file.path}",
                              //       );
                              //       setState(() {
                              //         uploadedPhotoPath = file.path;
                              //         hasUnsavedChanges = true;
                              //       });
                              //     } else {
                              //       setState(() {
                              //         uploadedPhotoPath = null;
                              //       });
                              //     }
                              //   },
                              // ),
                              getHeight(15),
                              FileUploadBox(
                                onUploadTap: _handleFileUpload,
                                selectedFile: selectedUploadFile,
                                selectedFileName: selectedFileName,
                                selectedFileSize: selectedFileSize,
                                onDelete: _deleteUploadedFile,
                                label: 'Add a Photo',
                                isRequired: true,
                              ),
                              getHeight(15),
                              CustomRemarksField(
                                label: "Add Remarks",
                                hintText: "Remarks",
                                controller: remarksController,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      child: Row(
                        children: [
                          Expanded(
                            child: ArrowButton(
                              text: "General",
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
                            child: BlocBuilder<EnergyReadingDetailCubit, EnergyReadingDetailState>(
                              builder: (context, state) {
                                return ArrowButton(
                                  text: state is EnergyReadingDetailLoading ? "Saving..." : "Submit",
                                  isLeftArrow: false,
                                  backgroundColor: AppColors.buttonColorBg,
                                  textColor: AppColors.buttonColorSite,
                                  onPressed: state is EnergyReadingDetailLoading ? () {} : _handleSubmit,
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
            ),
          ],
        ),
      ),
      )
    );
  }
}
