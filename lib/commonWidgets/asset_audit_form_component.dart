import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:app/utils.dart';
import 'package:app/utils/uppercase_text_formatter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/utils/image_compression_helper.dart';
import 'package:app/screens/qrScannerScreen.dart';
import 'package:app/services/image_upload_service.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/app_config.dart';

class AssetAuditFormComponent extends StatefulWidget {
  /// Unique identifier for this component instance
  final String componentId;

  /// Label for the serial number field
  final String serialLabel;

  /// Hint text for the serial number field
  final String serialHintText;

  /// Label for the photo upload field
  final String photoLabel;

  /// Label for the disabled text field
  final String? disabledFieldLabel;

  /// Value for the disabled text field
  final String? disabledFieldValue;

  /// Label for the second disabled text field (optional)
  final String? secondDisabledFieldLabel;

  /// Value for the second disabled text field (optional)
  final String? secondDisabledFieldValue;

  /// Controller for the serial number field
  final TextEditingController serialController;

  /// Initial list of saved items (for display only)
  final List<dynamic> initialSavedItems;

  /// Callback when items are updated (passes complete list)
  final Function(List<Map<String, dynamic>>)? onItemSaved;

  /// Callback when status changes
  final Function(bool?) onStatusChanged;

  /// Custom validation function for serial number
  /// Returns true if valid, false if invalid
  final bool Function(String serialNumber, bool isScanned)? customValidator;

  /// Error message for custom validation failure
  final String? customValidationErrorMessage;

  /// Background color for the component (static)
  static const Color backgroundColor = AppColors.green7;

  /// Site audit schedule ID for API calls (optional)
  final String siteAuditSchId;

  /// Whether to show the table of saved items
  final bool showTable;

  /// Title for the table
  final String? tableTitle;

  /// Height for the image display
  final double imageHeight;

  /// Whether to enable image compression
  final bool enableImageCompression;

  /// Optional callback to lookup disabled field values based on serial number
  /// Returns a map with keys: 'capacity' (or disabledFieldLabel key) and 'manufacturing_year' (or secondDisabledFieldLabel key)
  final Map<String, String?>? Function(String serialNumber)?
  onSerialNumberLookup;

  /// Whether to show the status field (OK/Not OK)
  final bool showStatus;

  /// Whether to show the form section (scan asset, photo, etc.)
  /// If false, only the table will be shown
  final bool showForm;

  const AssetAuditFormComponent({
    super.key,
    required this.componentId,
    required this.serialLabel,
    required this.serialHintText,
    required this.photoLabel,
    this.disabledFieldLabel,
    this.disabledFieldValue,
    this.secondDisabledFieldLabel,
    this.secondDisabledFieldValue,
    required this.serialController,
    required this.initialSavedItems,
    this.onItemSaved,
    required this.onStatusChanged,
    this.customValidator,
    this.customValidationErrorMessage,
    required this.siteAuditSchId,
    this.showTable = true,
    this.tableTitle,
    this.imageHeight = 150,
    this.enableImageCompression = true,
    this.onSerialNumberLookup,
    this.showStatus = true,
    this.showForm = true,
  });

  @override
  State<AssetAuditFormComponent> createState() =>
      _AssetAuditFormComponentState();
}

class _AssetAuditFormComponentState extends State<AssetAuditFormComponent> {
  // Form state
  String? _selectedPhotoPath;
  bool? _selectedStatus;
  bool _isQRCodeScanned = false;

  bool _isUploading = false;
  String? qrCodeScannedTs = null;
  String? _uploadedImageId; // Photo ID from server
  String? _photoData; // Photo byte data or base64
  bool _hasNewPhotoSelected = false; // Track if user selected a new photo

  // Validation state
  bool _showValidationErrors = false;
  String? _validationErrorMessage;

  // Edit state
  bool _isEditing = false;
  Map<String, dynamic>? _editingItem;

  // Internal saved items state
  late List<Map<String, dynamic>> _savedItems;

  // Image upload service
  late ImageUploadService _imageUploadService;

  // Controllers for disabled fields to make them dynamic
  TextEditingController? _disabledFieldController;
  TextEditingController? _secondDisabledFieldController;

  @override
  void initState() {
    super.initState();
    // Initialize internal saved items list
    _savedItems = List<Map<String, dynamic>>.from(widget.initialSavedItems);

    // Initialize disabled field controllers with 'N/A' initially
    _disabledFieldController = TextEditingController(text: 'N/A');
    _secondDisabledFieldController = TextEditingController(text: 'N/A');

    // Listen to serial controller changes to detect manual input vs scanning
    widget.serialController.addListener(_onSerialChanged);
    // Initialize image upload service
    _imageUploadService = ImageUploadService(
      apiService: AppConfig.of(context).apiService,
    );
  }

  @override
  void dispose() {
    widget.serialController.removeListener(_onSerialChanged);
    _disabledFieldController?.dispose();
    _secondDisabledFieldController?.dispose();
    super.dispose();
  }

  void _onSerialChanged() {
    // If text is manually typed, mark as not scanned
    if (!_isQRCodeScanned) {
      setState(() {
        _isQRCodeScanned = false;
        qrCodeScannedTs = null;
      });
    }

    final serialNumber = widget.serialController.text;
    
    // If serial number is empty, reset fields to 'N/A'
    if (serialNumber.isEmpty) {
      setState(() {
        _disabledFieldController?.text = 'N/A';
        _secondDisabledFieldController?.text = 'N/A';
      });
      return;
    }

    // Validate serial number if custom validator is provided
    bool isValid = true;
    if (widget.customValidator != null) {
      isValid = widget.customValidator!(serialNumber, _isQRCodeScanned);
    }

    if (!isValid) {
      // If serial number is invalid, clear fields (blank, not 'N/A')
      setState(() {
        _disabledFieldController?.text = '';
        _secondDisabledFieldController?.text = '';
      });
      return;
    }

    // Serial number is valid - look up disabled field values if callback is provided
    if (widget.onSerialNumberLookup != null) {
      final lookupResult = widget.onSerialNumberLookup!(serialNumber);
      if (lookupResult != null) {
        setState(() {
          // Update first disabled field only if value exists
          if (lookupResult.containsKey('capacity') && 
              lookupResult['capacity'] != null && 
              lookupResult['capacity'].toString().isNotEmpty) {
            _disabledFieldController?.text = lookupResult['capacity'].toString();
          } else {
            _disabledFieldController?.text = '';
          }
          // Update second disabled field only if value exists
          if (lookupResult.containsKey('manufacturing_year') && 
              lookupResult['manufacturing_year'] != null && 
              lookupResult['manufacturing_year'].toString().isNotEmpty) {
            _secondDisabledFieldController?.text = 
                lookupResult['manufacturing_year'].toString();
          } else {
            _secondDisabledFieldController?.text = '';
          }
        });
      } else {
        // No lookup result - clear fields
        setState(() {
          _disabledFieldController?.text = '';
          _secondDisabledFieldController?.text = '';
        });
      }
    } else {
      // No lookup callback - clear fields
      setState(() {
        _disabledFieldController?.text = '';
        _secondDisabledFieldController?.text = '';
      });
    }
  }

  /// Validates all mandatory fields
  bool _validateAllFields() {
    setState(() {
      _showValidationErrors = true;
      _validationErrorMessage = null;
    });

    // Check serial number
    if (widget.serialController.text.isEmpty) {
      _validationErrorMessage = 'Please enter a serial number';
      return false;
    }

    // Check photo
    if (_selectedPhotoPath == null || _selectedPhotoPath!.isEmpty) {
      _validationErrorMessage = 'Please select a photo';
      return false;
    }

    // Check status (only if showStatus is true)
    if (widget.showStatus && _selectedStatus == null) {
      _validationErrorMessage = 'Please select a status';
      return false;
    }
    return true;
  }

  /// Runs custom validation on serial number
  bool _validateSerialNumber() {
    if (widget.customValidator != null) {
      final isValid = widget.customValidator!(
        widget.serialController.text,
        _isQRCodeScanned,
      );

      if (!isValid) {
        _validationErrorMessage =
            widget.customValidationErrorMessage ??
            'Invalid serial number. Please check and try again.';

        return false;
      }
    } else {}
    return true;
  }

  /// Handles photo selection
  void _handlePhotoSelection(String? photoPath) {
    setState(() {
      _selectedPhotoPath = photoPath;
      _photoData = photoPath; // Store the photo data
      _uploadedImageId = null; // Reset photo ID since we have new photo data
      _hasNewPhotoSelected = true; // Mark that user selected a new photo
      _showValidationErrors = false;
    });
    // Photo selection is handled internally, no parent callback needed
  }

  /// Picks image from camera (matching CustomInfoCard)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      final originalFile = File(pickedFile.path);

      try {
        // Run compression in background to avoid blocking UI
        final compressedFile = await Future(
          () => ImageCompressionHelper.compressImageTo2MB(originalFile),
        );

        if (mounted) {
          if (compressedFile != null) {
            _handlePhotoSelection(compressedFile.path);
          } else {
            _handlePhotoSelection(originalFile.path);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error compressing image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Checks if image should be shown
  bool _shouldShowImage() {
    return _selectedPhotoPath != null && _selectedPhotoPath!.isNotEmpty;
  }

  /// Builds image widget (matching CustomInfoCard)
  Widget _buildImageWidget() {
    if (_selectedPhotoPath == null || _selectedPhotoPath!.isEmpty) {
      return Container();
    }

    if (_selectedPhotoPath!.startsWith('data:image')) {
      // Base64 image data
      try {
        final parts = _selectedPhotoPath!.split(',');
        if (parts.length == 2 && parts[1].isNotEmpty) {
          final base64Data = parts[1];
          final bytes = base64Decode(base64Data);

          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 150,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorWidget('Image display error');
            },
          );
        }
      } catch (e) {
        return _buildErrorWidget('Image decode error');
      }
    } else if (int.tryParse(_selectedPhotoPath!) != null) {
      // Photo ID - show loading indicator while fetching
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGreen,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Loading image...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // File path
      return Image.file(
        File(_selectedPhotoPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 150,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget('Failed to load image');
        },
      );
    }

    return _buildErrorWidget('Unsupported image type');
  }

  /// Builds error widget (matching CustomInfoCard)
  Widget _buildErrorWidget(String message) {
    return Container(
      color: Colors.grey.shade300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: fontFamilyMontserrat,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Handles status change
  void _handleStatusChange(bool? status) {
    setState(() {
      _selectedStatus = status;
      _showValidationErrors = false;
    });
    widget.onStatusChanged(status);
  }

  /// Handles save button click
  Future<void> _handleSave() async {
    try {
      // Reset validation state
      setState(() {
        _showValidationErrors = false;
        _validationErrorMessage = null;
      });

      // Step 1: Run mandatory checks

      if (!_validateAllFields()) {
        _showValidationError();
        return;
      }

      // Step 2: Run custom validation on serial number

      if (!_validateSerialNumber()) {
        _showValidationError();
        return;
      }

      // Step 3: Handle photo upload
      // Use _editingItem if we're editing, otherwise look for existing item
      final existingItem = _isEditing && _editingItem != null
          ? _editingItem!
          : _savedItems.firstWhere(
              (item) => item['mfg_serial_no'] == widget.serialController.text,
              orElse: () => {},
            );

      if (_hasNewPhotoSelected &&
          _selectedPhotoPath != null &&
          _selectedPhotoPath!.isNotEmpty) {
        // User actually selected a new photo - upload it

        await _uploadPhoto();
      } else {
        // No new photo selected by user
        if (_isEditing && _uploadedImageId != null) {
          // If we're editing and have a preserved photo ID, use it
        } else if (existingItem.isNotEmpty &&
            existingItem['photo'] != null &&
            existingItem['photo'].toString().isNotEmpty) {
          // If editing existing item with photo, preserve it

          _uploadedImageId = existingItem['photo'];
        }
      }

      // Step 4: Create item data and add to saved items
      final itemData = {
        'mfg_serial_no': widget.serialController.text,
        'asset_status': widget.showStatus && _selectedStatus != null
            ? (_selectedStatus! ? 'OK' : 'Not OK')
            : null,
        'photo_id': _uploadedImageId, // Photo ID from server
        'photoPath': _selectedPhotoPath, // Local photo path
        'qr_code_scanned': _isQRCodeScanned,
        'qr_code_scanned_ts': qrCodeScannedTs,
        'disabledFieldValue': _disabledFieldController?.text ?? '',
        'secondDisabledFieldValue': _secondDisabledFieldController?.text ?? '',
        'timestamp': Utils.getCurrentDateTimeForAPICall(),
      };

      // Preserve original capacity field if it exists in the existing item
      // This is needed for total capacity calculation
      if (existingItem.isNotEmpty && existingItem['capacity'] != null) {
        itemData['capacity'] = existingItem['capacity'];
      } else if (_disabledFieldController?.text != null &&
          _disabledFieldController!.text.isNotEmpty) {
        // If no original capacity, use the disabled field value as capacity
        try {
          final capacityValue = double.tryParse(_disabledFieldController!.text);
          if (capacityValue != null) {
            itemData['capacity'] = capacityValue;
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }

      // Handle photo data properly
      if (_uploadedImageId != null) {
        // We have a photo ID from server
        itemData['photo_id'] = _uploadedImageId;
        // Store photoPath - if we have base64 image data, keep it; otherwise use photo_id
        if (_selectedPhotoPath != null &&
            _selectedPhotoPath!.startsWith('data:image/')) {
          // We have base64 image data - store it for instant display next time
          itemData['photoPath'] = _selectedPhotoPath;
        } else if (_photoData != null &&
            _photoData.toString().startsWith('data:image/')) {
          // We have cached base64 data
          itemData['photoPath'] = _photoData;
        } else if (existingItem.isNotEmpty &&
            existingItem['photoPath'] != null) {
          // Keep original photoPath (might be base64 or path)
          itemData['photoPath'] = existingItem['photoPath'];
        } else {
          // Fallback to photo_id as string
          itemData['photoPath'] = _uploadedImageId.toString();
        }
      } else if (_photoData != null) {
        // We have local photo data (base64 or local path)
        itemData['photo'] = null;
        itemData['photoPath'] = _photoData;
      }

      // Debug logging for photo data

      // Step 5: Handle save (add new or update existing)
      if (_isEditing && _editingItem != null) {
        // Update existing item in the internal list
        final existingIndex = _savedItems.indexWhere(
          (item) => item['mfg_serial_no'] == _editingItem!['mfg_serial_no'],
        );

        if (existingIndex != -1) {
          // Replace the existing item in the list
          _savedItems[existingIndex] = itemData;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Check if item with same serial number already exists
        final existingIndex = _savedItems.indexWhere(
          (item) => item['mfg_serial_no'] == widget.serialController.text,
        );

        if (existingIndex != -1) {
          // Update existing item instead of creating duplicate
          _savedItems[existingIndex] = itemData;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Add new item to the internal list
          _savedItems.add(itemData);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Notify parent with the complete updated list
      widget.onItemSaved?.call(List.from(_savedItems));

      // Force a rebuild to ensure the table updates
      setState(() {});

      // Step 6: Clear form
      _clearForm();
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handles photo upload using ImageUploadService
  Future<void> _uploadPhoto() async {
    if (_selectedPhotoPath == null || _selectedPhotoPath!.isEmpty) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Read image file and convert to base64
      final imageFile = File(_selectedPhotoPath!);
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Upload using ImageUploadService
      final uniqueId = await _imageUploadService.uploadImage(
        base64Image,
        ActivityTypeEnum.assetAudit,
        false,
        widget.siteAuditSchId,
      );

      setState(() {
        _isUploading = false;
        _uploadedImageId = uniqueId;
      });

      if (uniqueId.isEmpty) {
        setState(() {
          _isUploading = false;
        });
        throw Exception('Photo upload failed - no unique ID returned');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      throw Exception('Photo upload failed: $e');
    }
  }

  /// Shows validation error
  void _showValidationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _validationErrorMessage ?? 'Please fill all required fields',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Clears the form
  void _clearForm() {
    setState(() {
      widget.serialController.clear();
      _selectedPhotoPath = null;
      _selectedStatus = null;
      _isQRCodeScanned = false;
      qrCodeScannedTs = null;
      _uploadedImageId = null;
      _photoData = null;
      _hasNewPhotoSelected = false;
      _showValidationErrors = false;
      _validationErrorMessage = null;
      _isEditing = false;
      _editingItem = null;
      _disabledFieldController?.clear();
      _secondDisabledFieldController?.clear();
    });
  }

  /// Starts editing an item
  void _startEditing(Map<String, dynamic> item) async {
    setState(() {
      _isEditing = true;
      _editingItem = item;
      widget.serialController.text = item['mfg_serial_no'] ?? '';
      if (widget.showStatus) {
        _selectedStatus = item['asset_status'] == 'OK' ? true : false;
      }
      _isQRCodeScanned = item['qr_code_scanned'] ?? false;
      qrCodeScannedTs = item['qr_code_scanned'] == true
          ? item['qr_code_scanned_ts']
          : null;
      _hasNewPhotoSelected = false; // Reset flag when starting to edit
      // Populate disabled fields from saved item
      _disabledFieldController?.text =
          item['disabledFieldValue']?.toString() ?? '';
      _secondDisabledFieldController?.text =
          item['secondDisabledFieldValue']?.toString() ?? '';
    });

    // Handle photo loading for editing
    final photoId =
        item['photo_id']; // This could be numeric (server ID) or string (local ID)
    final photoPath =
        item['photoPath']; // This is the local path or base64 data

    // Check if photoPath is base64 data first (faster, no fetch needed)
    final photoPathString = photoPath != null ? photoPath.toString() : null;
    if (photoPathString != null &&
        photoPathString.isNotEmpty &&
        photoPathString.startsWith('data:image/')) {
      // We have base64 image data - use it immediately

      _uploadedImageId = photoId != null ? photoId.toString() : null;
      _photoData = photoPathString;
      setState(() {
        _selectedPhotoPath = photoPathString;
        _isUploading = false;
      });

      return; // Exit early - no need to fetch
    }

    // Convert photo_id to string if it's numeric
    final uniqueIdString = photoId != null ? photoId.toString() : null;

    if (uniqueIdString != null &&
        uniqueIdString.isNotEmpty &&
        uniqueIdString != "null" &&
        uniqueIdString != "0") {
      _uploadedImageId = uniqueIdString; // Store the unique ID as string
      _photoData = null; // No local photo data
      await _fetchAndDisplayServerImage(uniqueIdString);
    } else if (photoPathString != null && photoPathString.isNotEmpty) {
      // Local photo path (not base64)

      _uploadedImageId = null; // No server photo ID
      _photoData = photoPathString; // Store the photo data as string
      setState(() {
        _selectedPhotoPath = photoPathString; // Convert to string
        _isUploading = false;
      });
    } else {
      _uploadedImageId = null;
      _photoData = null;
      setState(() {
        _selectedPhotoPath = null;
        _isUploading = false;
      });
    }
  }

  /// Fetches and displays server image for editing using ImageUploadService
  Future<void> _fetchAndDisplayServerImage(String uniqueId) async {
    try {
      // Show loading indicator
      setState(() {
        _isUploading = true;
      });

      String? imageData;
      String? finalUniqueId = uniqueId;

      // Check if this is a server ID (numeric, not LOCAL_IMAGE_ID)
      // If so, try to get from local first, then download from server if not found
      if (!uniqueId.contains("LOCAL_IMAGE_ID") &&
          int.tryParse(uniqueId) != null) {
        // Try to get from local SQLite (checks both unique_id and server_id)
        imageData = await _imageUploadService.getImageUsingUniqueId(uniqueId);

        if (imageData == null || imageData.isEmpty) {
          // Not found locally, download from server

          finalUniqueId = await _imageUploadService.downloadImageUsingServerId(
            uniqueId,
            ActivityTypeEnum.assetAudit,
            widget.siteAuditSchId,
          );

          // After download, get the image data
          if (finalUniqueId != null) {
            imageData = await _imageUploadService.getImageUsingUniqueId(
              finalUniqueId,
            );
          }
        } else {}
      } else {
        // Not a server ID, get directly

        imageData = await _imageUploadService.getImageUsingUniqueId(uniqueId);
      }

      if (mounted && imageData != null && imageData.isNotEmpty) {
        // Ensure the image data has proper data URL format
        final finalImageData = imageData.startsWith('data:image/')
            ? imageData
            : 'data:image/jpeg;base64,$imageData';

        setState(() {
          _selectedPhotoPath =
              finalImageData; // Store as base64 data for display
          _isUploading = false; // Clear loading state
        });
      } else {
        setState(() {
          _selectedPhotoPath = null; // Clear photo path on failure
          _isUploading = false; // Clear loading state
        });
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _selectedPhotoPath =
              null; // Don't set to uniqueId - keep null to show error
          _isUploading = false; // Clear loading state
        });
      }
    }
  }

  /// Builds the serial number field with QR scanner (matching CustomInfoCard design)
  Widget _buildSerialNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with asterisk (matching CustomInfoCard)
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: widget.serialLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: fontFamilyMontserrat,
                  fontSize: 16,
                  color: AppColors.white,
                ),
              ),
              const TextSpan(
                text: " *",
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: fontFamilyMontserrat,
                  fontSize: 16,
                  color: AppColors.errorColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // TextFormField (matching CustomInfoCard)
        TextFormField(
          controller: widget.serialController,
          inputFormatters: [UpperCaseTextFormatter()],
          onChanged: (value) {
            setState(() {
              _isQRCodeScanned = false;
              qrCodeScannedTs = null;
            });
          },
          decoration: InputDecoration(
            hintText: widget.serialHintText,
            hintStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontFamily: fontFamilyMontserrat,
              fontSize: 16,
              color: AppColors.color555555,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () async {
                try {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                  );
                  if (result != null && result is String) {
                    setState(() {
                      widget.serialController.text = result.toUpperCase();
                      _isQRCodeScanned = true;
                      qrCodeScannedTs = Utils.getCurrentDateTimeForAPICall();
                      _showValidationErrors = false;
                    });
                    // Explicitly trigger lookup after QR scan to ensure fields are populated
                    // The listener should also trigger this, but this ensures it happens
                    if (widget.onSerialNumberLookup != null &&
                        widget.serialController.text.isNotEmpty) {
                      final lookupResult = widget.onSerialNumberLookup!(
                        widget.serialController.text,
                      );
                      if (lookupResult != null) {
                        setState(() {
                          if (lookupResult.containsKey('capacity')) {
                            _disabledFieldController?.text =
                                lookupResult['capacity'] ?? '';
                          }
                          if (lookupResult.containsKey('manufacturing_year')) {
                            _secondDisabledFieldController?.text =
                                lookupResult['manufacturing_year'] ?? '';
                          }
                        });
                      }
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error scanning QR code: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        // Validation error
        if (_showValidationErrors && widget.serialController.text.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Serial number is required',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),

        // QR scan indicator
        if (_isQRCodeScanned)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text(
                  'Scanned via QR Code',
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Builds the photo upload field (matching CustomInfoCard design)
  Widget _buildPhotoUploadField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with asterisk (matching CustomInfoCard)
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: widget.photoLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: fontFamilyMontserrat,
                  fontSize: 16,
                  color: AppColors.white,
                ),
              ),
              const TextSpan(
                text: " *",
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: fontFamilyMontserrat,
                  fontSize: 16,
                  color: AppColors.errorColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Photo picker container (matching CustomInfoCard)
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: _shouldShowImage()
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: _buildImageWidget(),
                      ),
                    ],
                  )
                : Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          size: 20,
                          color: AppColors.color555555,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.photoLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            color: AppColors.color555555,
                            fontFamily: fontFamilyMontserrat,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // Validation error
        if (_showValidationErrors &&
            (_selectedPhotoPath == null || _selectedPhotoPath!.isEmpty))
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Photo is required',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// Builds the disabled text field (matching CustomInfoCard design)
  Widget _buildDisabledField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label (matching CustomInfoCard)
        Text(
          widget.disabledFieldLabel ?? "",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontFamily: fontFamilyMontserrat,
          ),
        ),
        const SizedBox(height: 5),

        // Input field (matching CustomInfoCard)
        TextFormField(
          controller: _disabledFieldController ??= TextEditingController(),
          readOnly: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.borderColorE0E0E0, // Grey when not editable
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide.none,
            ),
            hintText: '',
            hintStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontFamily: fontFamilyMontserrat,
              fontSize: 16,
              color: AppColors.color555555.withOpacity(0.6),
            ),
          ),
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontFamily: fontFamilyMontserrat,
            fontSize: 16,
            color: AppColors.color555555,
          ),
        ),
      ],
    );
  }

  /// Builds the second disabled text field (matching CustomInfoCard design)
  Widget _buildSecondDisabledField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label (matching CustomInfoCard)
        Text(
          widget.secondDisabledFieldLabel ?? "",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontFamily: fontFamilyMontserrat,
          ),
        ),
        const SizedBox(height: 5),

        // Input field (matching CustomInfoCard)
        TextFormField(
          controller: _secondDisabledFieldController ??=
              TextEditingController(),
          readOnly: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.borderColorE0E0E0, // Grey when not editable
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide.none,
            ),
            hintText: '',
            hintStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontFamily: fontFamilyMontserrat,
              fontSize: 16,
              color: AppColors.color555555.withOpacity(0.6),
            ),
          ),
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontFamily: fontFamilyMontserrat,
            fontSize: 16,
            color: AppColors.color555555,
          ),
        ),
      ],
    );
  }

  /// Builds the status radio buttons (matching CustomInfoCard design)
  Widget _buildStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with asterisk (matching CustomInfoCard)
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "Status",
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: fontFamilyMontserrat,
                  fontSize: 16,
                  color: AppColors.white,
                ),
              ),
              const TextSpan(
                text: " *",
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: fontFamilyMontserrat,
                  fontSize: 16,
                  color: AppColors.errorColor,
                ),
              ),
            ],
          ),
        ),

        // Radio buttons (matching CustomInfoCard) - more compact layout
        Wrap(
          spacing: 20,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _selectedStatus,
                  onChanged: _handleStatusChange,
                  activeColor: const Color(0xFF5678BA),
                  fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF5678BA);
                    }
                    return Colors.white;
                  }),
                ),
                const SizedBox(width: 4),
                const Text(
                  "Ok",
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<bool>(
                  value: false,
                  groupValue: _selectedStatus,
                  onChanged: _handleStatusChange,
                  activeColor: const Color(0xFF5678BA),
                  fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return const Color(0xFF5678BA);
                    }
                    return Colors.white;
                  }),
                ),
                const SizedBox(width: 4),
                const Text(
                  "Not Ok",
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Validation error
        if (_showValidationErrors && _selectedStatus == null)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Status is required',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// Builds the save button (matching CustomInfoCard design exactly)
  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isUploading
          ? null
          : _handleSave, // Disable button when uploading
      style: ElevatedButton.styleFrom(
        backgroundColor: _isUploading
            ? Colors.grey.shade400
            : const Color(0xFFDBE2F0),
        foregroundColor: _isUploading
            ? Colors.grey.shade600
            : const Color(0xFF2D426E),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      child: _isUploading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D426E)),
              ),
            )
          : Text("Save"),
    );
  }

  /// Gets the dynamic label for the second disabled field column header
  String _getSecondDisabledFieldTableHeader() {
    if (widget.secondDisabledFieldLabel == null) {
      return '';
    }
    final label = widget.secondDisabledFieldLabel!.toLowerCase();
    if (label.contains('year') && label.contains('manufactur')) {
      return 'MFG Year';
    }
    // Default: extract first word or use a shortened version
    final words = widget.secondDisabledFieldLabel!.split(' ');
    return words.isNotEmpty ? words.first : widget.secondDisabledFieldLabel!;
  }

  /// Builds the table of saved items
  Widget _buildSavedItemsTable() {
    if (!widget.showTable || _savedItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final secondDisabledFieldHeader = _getSecondDisabledFieldTableHeader();
    final showSecondDisabledFieldColumn =
        widget.secondDisabledFieldLabel != null &&
        secondDisabledFieldHeader.isNotEmpty;

    // Show first disabled field column if disabledFieldLabel is provided
    final showFirstDisabledFieldColumn =
        widget.disabledFieldLabel != null &&
        widget.disabledFieldLabel!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AssetAuditFormComponent.backgroundColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.tableTitle != null) ...[
            Text(
              widget.tableTitle!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: fontFamilyMontserrat,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                // Table header
                Row(
                  children: [
                    _buildTableHeaderCell('Serial No.', 200),
                    if (widget.showForm) ...[
                      // Only show these columns when form is visible (for backward compatibility)
                      if (showFirstDisabledFieldColumn)
                        _buildTableHeaderCell(widget.disabledFieldLabel ?? '', 100),
                      if (showSecondDisabledFieldColumn)
                        _buildTableHeaderCell(secondDisabledFieldHeader, 80),
                      if (widget.showStatus)
                        _buildTableHeaderCell('Status', 80),
                      _buildTableHeaderCell('Scanned', 80),
                    ],
                    _buildTableHeaderCell('Photo', 80),
                    _buildTableHeaderCell('Edit', 80),
                  ],
                ),
                const SizedBox(height: 8),
                // Table rows
                ..._savedItems.map((item) => _buildTableRow(item)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a table header cell
  Widget _buildTableHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: fontFamilyMontserrat,
          fontWeight: FontWeight.w400,
        ),
        maxLines: 1,
      ),
    );
  }

  /// Builds a table row
  Widget _buildTableRow(Map<String, dynamic> item) {
    final showSecondDisabledFieldColumn =
        widget.secondDisabledFieldLabel != null;
    final showFirstDisabledFieldColumn =
        widget.disabledFieldLabel != null &&
        widget.disabledFieldLabel!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          _buildTableDataCell(item['mfg_serial_no'] ?? '', 200),
          if (widget.showForm) ...[
            // Only show these columns when form is visible (for backward compatibility)
            if (showFirstDisabledFieldColumn)
              _buildTableDataCell(
                item['disabledFieldValue'] ?? 
                item['capacity']?.toString() ?? 
                'N/A', 
                100
              ),
            if (showSecondDisabledFieldColumn)
              _buildTableDataCell(item['secondDisabledFieldValue'] ?? 'N/A', 80),
            if (widget.showStatus)
              _buildTableDataCell(item['asset_status'] ?? '', 80),
            _buildTableDataCell(
              item['qr_code_scanned'] == true ? 'Yes' : 'No',
              80,
              isScanned: item['qr_code_scanned'] == true,
            ),
          ],
          _buildTablePhotoCell(item, 80),
          _buildTableEditCell(item, 80),
        ],
      ),
    );
  }

  /// Builds a table data cell
  Widget _buildTableDataCell(String text, double width, {bool? isScanned}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isScanned != null) ...[
            Icon(
              isScanned ? Icons.qr_code_scanner : Icons.close,
              color: isScanned ? Colors.blue : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.color555555,
                fontSize: 14,
                fontFamily: fontFamilyMontserrat,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a table photo cell
  Widget _buildTablePhotoCell(Map<String, dynamic> item, double width) {
    // Debug logging for table photo cell

    // Convert photo_id to string if it's numeric, and check if valid
    final photoId = item['photo_id'];
    final photoIdString = photoId != null ? photoId.toString() : null;
    final hasValidPhotoId =
        photoIdString != null &&
        photoIdString.isNotEmpty &&
        photoIdString != "null" &&
        photoIdString != "0";

    // Check photoPath
    final photoPath = item['photoPath'];
    final photoPathString = photoPath != null ? photoPath.toString() : null;
    final hasValidPhotoPath =
        photoPathString != null && photoPathString.isNotEmpty;

    // Determine which photo to show (prefer photo_id over photoPath)
    final photoToShow = hasValidPhotoId
        ? photoIdString
        : (hasValidPhotoPath ? photoPathString : null);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(
          Icons.camera_alt,
          color: (hasValidPhotoId || hasValidPhotoPath)
              ? AppColors.color555555
              : Colors.grey,
        ),
        onPressed: photoToShow != null
            ? () => _showPhotoViewer(context, photoToShow)
            : null,
      ),
    );
  }

  /// Builds a table edit cell
  Widget _buildTableEditCell(Map<String, dynamic> item, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: const Icon(
          Icons.edit_calendar_outlined,
          color: AppColors.color555555,
        ),
        onPressed: () {
          _startEditing(item);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main form container matching CustomInfoCard design (only if showForm is true)
        if (widget.showForm)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AssetAuditFormComponent.backgroundColor,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Serial Number field
                _buildSerialNumberField(),
                const SizedBox(height: 16),

                // Second disabled field (if provided) - placed just below serial number
                if (widget.secondDisabledFieldLabel != null &&
                    widget.secondDisabledFieldLabel!.isNotEmpty) ...[
                  _buildSecondDisabledField(),
                  const SizedBox(height: 16),
                ],

                // Photo Picker
                _buildPhotoUploadField(),
                const SizedBox(height: 16),

                // Disabled field (if needed)
                if (widget.disabledFieldLabel != null) ...[
                  _buildDisabledField(),
                  const SizedBox(height: 16),
                ],

                // Status field with save button inline (matching CustomInfoCard layout)
                if (widget.showStatus)
                  Row(
                    children: [
                      Expanded(flex: 3, child: _buildStatusField()),
                      const SizedBox(width: 16),
                      Flexible(flex: 1, child: _buildSaveButton()),
                    ],
                  )
                else
                  // Just save button when status is hidden
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildSaveButton(),
                    ],
                  ),
              ],
            ),
          ),

        // Saved items table
        _buildSavedItemsTable(),
      ],
    );
  }

  /// Shows photo viewer dialog
  Future<void> _showPhotoViewer(BuildContext context, String? photo) async {
    // Debug logging for photo viewer

    if (photo == null || photo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No photo available to view.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? imageData;

    // Case 1: Photo is a base64 data URL
    if (photo.startsWith('data:image/')) {
      imageData = photo;
    }
    // Case 2: Photo is a local file path
    else if (await File(photo).exists()) {
      imageData = photo;
    }
    // Case 3: Photo is a unique ID from ImageUploadService (can be numeric server ID or string local ID)
    else {
      // Show loading dialog while fetching from ImageUploadService
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );

      try {
        String? finalUniqueId = photo;

        // Check if this is a server ID (numeric, not LOCAL_IMAGE_ID)
        // If so, try to get from local first, then download from server if not found
        if (!photo.contains("LOCAL_IMAGE_ID") && int.tryParse(photo) != null) {
          // Try to get from local SQLite (checks both unique_id and server_id)
          imageData = await _imageUploadService.getImageUsingUniqueId(photo);

          if (imageData == null || imageData.isEmpty) {
            // Not found locally, download from server

            finalUniqueId = await _imageUploadService
                .downloadImageUsingServerId(
                  photo,
                  ActivityTypeEnum.assetAudit,
                  widget.siteAuditSchId,
                );

            // After download, get the image data
            if (finalUniqueId != null) {
              imageData = await _imageUploadService.getImageUsingUniqueId(
                finalUniqueId,
              );
            }
          } else {}
        } else {
          // Use ImageUploadService to get image data (handles both numeric and string IDs)
          imageData = await _imageUploadService.getImageUsingUniqueId(photo);
        }

        if (imageData != null && imageData.isNotEmpty) {
          // Ensure proper data URL format
          imageData = imageData.startsWith('data:image/')
              ? imageData
              : 'data:image/jpeg;base64,$imageData';
        } else {}

        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } catch (e, stackTrace) {
        // Close loading dialog on error
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load image: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Show photo viewer for valid image data
    if (imageData != null && imageData.isNotEmpty) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => Dialog(
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.8,
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    child: imageData!.startsWith('data:image/')
                        ? Image.memory(
                            base64Decode(imageData.split(',').last),
                            fit: BoxFit.contain,
                          )
                        : Image.file(File(imageData), fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load photo.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}