import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:app/utils.dart';
import 'package:app/utils/uppercase_text_formatter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/utils/CrashLogger.dart';
import 'package:app/utils/device_memory_helper.dart';
import 'package:app/utils/file_logger.dart';
import 'package:app/utils/image_compression_helper.dart';
import 'package:app/screens/qrScannerScreen.dart';
import 'package:app/services/image_upload_service.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/app_config.dart';

class AssetUploadFormComponent extends StatefulWidget {
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

  /// Callback when edit button is clicked on an item
  /// Passes the item that should be edited
  final Function(Map<String, dynamic>)? onEditItem;

  /// Custom validation function for serial number
  /// Returns true if valid, false if invalid
  final bool Function(String serialNumber, bool isScanned)? customValidator;

  /// Error message for custom validation failure
  final String? customValidationErrorMessage;

  /// Optional callback to suppress success toast (e.g. when parent will show duplicate message).
  /// Called with itemData before showing any success SnackBar. Return true to suppress.
  final bool Function(Map<String, dynamic> item)? shouldSuppressSuccessToast;

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

  /// Whether to show the form section (scan asset, photo, etc.)
  /// If false, only the table will be shown
  final bool showForm;

  

  const AssetUploadFormComponent({
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
    this.onEditItem,
    this.customValidator,
    this.customValidationErrorMessage,
    this.shouldSuppressSuccessToast,
    required this.siteAuditSchId,
    this.showTable = true,
    this.tableTitle,
    this.imageHeight = 150,
    this.enableImageCompression = true,
    this.onSerialNumberLookup,
    this.showForm = true,
  });

  static const _cameraQuality = 85;
  static const _maxWidthLowRam = 1280;
  static const _maxWidthNormal = 1920;

  @override
  State<AssetUploadFormComponent> createState() =>
      _AssetUploadFormComponentState();
}

class _AssetUploadFormComponentState extends State<AssetUploadFormComponent> {
  // Form state
  String? _selectedPhotoPath;
  bool _isQRCodeScanned = false;

  bool _isUploading = false;
  bool _isLoadingPhoto = false; // True while processing/displaying photo after camera
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
  void didUpdateWidget(AssetUploadFormComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal saved items when initialSavedItems changes from parent
    // This ensures the table reflects external updates (e.g., when items are updated elsewhere)
    if (oldWidget.initialSavedItems != widget.initialSavedItems) {
      setState(() {
        _savedItems = List<Map<String, dynamic>>.from(widget.initialSavedItems);
      });
    }
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

    return true;
  }

  /// Runs custom validation on serial number
  bool _validateSerialNumber() {
    // If we're editing an existing item, check if the serial number matches the editing item
    // If it does, skip validation (user is editing the same item)
    if (_isEditing && _editingItem != null) {
      final editingSerial = _editingItem!['mfg_serial_no']?.toString() ?? '';
      final editingFullCode = _editingItem!['full_scanned_code']?.toString() ?? '';
      final currentSerial = widget.serialController.text.trim();
      
      // Check if current serial matches the editing item's serial
      if (editingSerial == currentSerial || 
          editingFullCode == currentSerial ||
          (editingFullCode.isNotEmpty && currentSerial.contains(editingSerial)) ||
          (editingSerial.isNotEmpty && currentSerial.contains(editingSerial))) {
        // Same item being edited - skip validation
        return true;
      }
    }
    
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
    // Force a second rebuild so image shows on first tap (file may not be ready immediately on some devices)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _selectedPhotoPath != photoPath) return;
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && _selectedPhotoPath == photoPath) {
        setState(() {});
      }
    });
  }

  /// Picks image from camera (matching CustomInfoCard).
  /// Defers processing to next frame + short delay so Flutter view can restore after camera
  /// intent (fixes white screen on some devices when user taps Save in camera).
 Future<void> _pickImage() async {
  final picker = ImagePicker();

  bool isLowRam = await DeviceMemoryHelper.isLowRamDevice();
  final deviceInfo = await DeviceMemoryHelper.getDeviceSnapshot();

  await FileLogger.info('Opening camera', data: {
    "lowRam": isLowRam,
    "device": deviceInfo,
  });

  XFile? pickedFile;

  try {
    pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: AssetUploadFormComponent._cameraQuality,
      maxWidth: (isLowRam ? AssetUploadFormComponent._maxWidthLowRam : AssetUploadFormComponent._maxWidthNormal).toDouble(),
    );
  } catch (e, s) {
    await CrashLogger().logCrash(e, s);

    await FileLogger.error('Camera open failed', data: {
      "device": deviceInfo,
      "lowRam": isLowRam,
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Camera failed to open'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (pickedFile == null) return;

  final path = pickedFile.path;
  if (path.isEmpty) return;

  // Show "Loading image..." right away so user sees feedback after tapping tick
  if (mounted) setState(() => _isLoadingPhoto = true);

  // Defer heavy work to next frame to avoid crash when returning from camera (tick/save)
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!mounted) return;
    // Show image in one go (no second tap)
    try {
      _handlePhotoSelection(path);
      if (mounted) setState(() => _isLoadingPhoto = false);
    } catch (e, s) {
      await CrashLogger().logCrash(e, s);
      if (mounted) {
        setState(() => _isLoadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not show photo'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Then compress in background and replace when done
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    try {
      final originalFile = File(path);
      if (!await originalFile.exists()) return;

      final compressedFile = await Future(
        () => ImageCompressionHelper.compressImageTo2MB(originalFile),
      );
      if (!mounted) return;
      await FileLogger.info('Image processed', data: {
        "compressed": compressedFile != null,
        "path": path,
      });
      if (compressedFile != null) {
        _handlePhotoSelection(compressedFile.path);
      }
    } catch (e, s) {
      await CrashLogger().logCrash(e, s);
      await FileLogger.error('Compression failed', data: {
        "path": path,
        "device": deviceInfo,
      });
      if (!mounted) return;
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image compression failed, using original'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (_) {}
    }
  });
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
      } catch (e, s) {
        CrashLogger().logCrash(e, s);
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
      // File path (wrap in try-catch; path can be invalid on some devices after camera)
      try {
        final file = File(_selectedPhotoPath!);
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 150,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget('Failed to load image');
          },
        );
      } catch (e, s) {
        CrashLogger().logCrash(e, s);
        return _buildErrorWidget('Invalid image path');
      }
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
      final itemData = <String, dynamic>{
        'mfg_serial_no': widget.serialController.text,
        'qr_code_scanned': _isQRCodeScanned,
        'qr_code_scanned_ts': qrCodeScannedTs,
        'disabledFieldValue': _disabledFieldController?.text ?? '',
        'secondDisabledFieldValue': _secondDisabledFieldController?.text ?? '',
        'timestamp': Utils.getCurrentDateTimeForAPICall(),
      };
      
      // If editing, preserve original identifiers to maintain grey dot status
      if (_isEditing && _editingItem != null) {
        // Preserve aui_id to keep the item as "existing" (grey dot) - this is critical!
        if (_editingItem!['aui_id'] != null) {
          final auiIdValue = _editingItem!['aui_id'];
          // Only preserve if it's not 0 or "0" (0 means new item)
          if (auiIdValue != 0 && auiIdValue.toString() != '0') {
            itemData['aui_id'] = auiIdValue;
          }
        }
        // Preserve item_id and item_instance_id
        if (_editingItem!['item_id'] != null) {
          itemData['item_id'] = _editingItem!['item_id'];
        }
        if (_editingItem!['item_instance_id'] != null) {
          itemData['item_instance_id'] = _editingItem!['item_instance_id'];
        }
        // Update full_scanned_code based on current serial number (may have changed)
        final currentSerial = widget.serialController.text.trim();
        if (currentSerial.isNotEmpty) {
          // If current serial is in NG-ACRONYM-SERIAL format, use it
          if (currentSerial.startsWith('NG-')) {
            itemData['full_scanned_code'] = currentSerial;
            itemData['nexgen_serial_no'] = currentSerial;
          } else {
            // Otherwise, preserve original or reconstruct
            if (_editingItem!['full_scanned_code'] != null) {
              itemData['full_scanned_code'] = _editingItem!['full_scanned_code'];
            }
            if (_editingItem!['nexgen_serial_no'] != null) {
              itemData['nexgen_serial_no'] = _editingItem!['nexgen_serial_no'];
            }
          }
        } else {
          // Preserve original if serial is empty
          if (_editingItem!['full_scanned_code'] != null) {
            itemData['full_scanned_code'] = _editingItem!['full_scanned_code'];
          }
          if (_editingItem!['nexgen_serial_no'] != null) {
            itemData['nexgen_serial_no'] = _editingItem!['nexgen_serial_no'];
          }
        }
        // Preserve latitude and longitude if they exist
        if (_editingItem!['latitude'] != null) {
          itemData['latitude'] = _editingItem!['latitude'];
        }
        if (_editingItem!['longitude'] != null) {
          itemData['longitude'] = _editingItem!['longitude'];
        }
      }

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

      // Handle photo data properly - set photo_id and photoPath after upload
      // Store photo in assetUploadItemImages format for API
      List<Map<String, dynamic>> assetUploadItemImages = [];
      
      // IMPORTANT: Always prioritize new photo data if a new photo was selected and uploaded
      if (_hasNewPhotoSelected && _uploadedImageId != null && _uploadedImageId!.isNotEmpty) {
        // New photo was selected and uploaded - use the new photo data
        itemData['photo_id'] = _uploadedImageId;
        // Prioritize _photoData if it's base64 (set by _uploadPhoto), otherwise use _selectedPhotoPath
        if (_photoData != null && _photoData.toString().startsWith('data:image/')) {
          // We have cached base64 data from upload
          itemData['photoPath'] = _photoData;
        } else if (_selectedPhotoPath != null && _selectedPhotoPath!.startsWith('data:image/')) {
          // We have base64 image data in _selectedPhotoPath
          itemData['photoPath'] = _selectedPhotoPath;
        } else {
          // Fallback - use photo_id as string (shouldn't happen if upload was successful)
          itemData['photoPath'] = _uploadedImageId.toString();
        }
        
        // Add photo to assetUploadItemImages array
        // Keep LOCAL_IMAGE_ID as string, convert server IDs to int
        dynamic photoIdValue;
        if (_uploadedImageId!.contains("LOCAL_IMAGE_ID")) {
          // Keep LOCAL_IMAGE_ID as string for offline mode
          photoIdValue = _uploadedImageId!;
        } else {
          // Convert to int for server IDs
          photoIdValue = int.tryParse(_uploadedImageId!) ?? 0;
        }
        assetUploadItemImages.add({
          'auiiId': 0,
          'photoId': photoIdValue, // Can be string (LOCAL_IMAGE_ID) or int (server ID)
          'photoTakenTs': Utils.normalizeDateForAPICall(itemData['timestamp']?.toString()),
          'longitude': '',
          'latitude': '',
          'isActive': true,
          'remarks': '',
        });
      } else if (_uploadedImageId != null && _uploadedImageId!.isNotEmpty) {
        // We have a photo ID but no new photo was selected - preserve existing photoPath
        itemData['photo_id'] = _uploadedImageId;
        if (existingItem.isNotEmpty && existingItem['photoPath'] != null) {
          // Keep original photoPath (might be base64 or path)
          itemData['photoPath'] = existingItem['photoPath'];
        } else {
          // Fallback to photo_id as string
          itemData['photoPath'] = _uploadedImageId.toString();
        }
        
        // Preserve existing assetUploadItemImages or create from photo_id
        if (existingItem.isNotEmpty && existingItem['assetUploadItemImages'] != null) {
          assetUploadItemImages = List<Map<String, dynamic>>.from(existingItem['assetUploadItemImages']);
        } else {
          // Create from existing photo_id
          // Keep LOCAL_IMAGE_ID as string, convert server IDs to int
          dynamic photoIdValue;
          if (_uploadedImageId!.contains("LOCAL_IMAGE_ID")) {
            // Keep LOCAL_IMAGE_ID as string for offline mode
            photoIdValue = _uploadedImageId!;
          } else {
            // Convert to int for server IDs
            photoIdValue = int.tryParse(_uploadedImageId!) ?? 0;
          }
          assetUploadItemImages.add({
            'auiiId': 0,
            'photoId': photoIdValue, // Can be string (LOCAL_IMAGE_ID) or int (server ID)
            'photoTakenTs': Utils.normalizeDateForAPICall(
              existingItem['timestamp']?.toString() ?? 
              existingItem['qr_code_scanned_ts']?.toString(),
            ),
            'longitude': '',
            'latitude': '',
            'isActive': true,
            'remarks': '',
          });
        }
      } else if (_photoData != null) {
        // We have local photo data (base64 or local path) but no upload ID yet
        itemData['photo'] = null;
        itemData['photoPath'] = _photoData;
      } else if (existingItem.isNotEmpty && existingItem['photoPath'] != null) {
        // No new photo and no photoData - preserve existing photoPath
        itemData['photoPath'] = existingItem['photoPath'];
        if (existingItem['photo_id'] != null) {
          itemData['photo_id'] = existingItem['photo_id'];
        }
        // Preserve existing assetUploadItemImages
        if (existingItem['assetUploadItemImages'] != null) {
          assetUploadItemImages = List<Map<String, dynamic>>.from(existingItem['assetUploadItemImages']);
        }
      }
      
      // Store assetUploadItemImages in itemData for API submission
      itemData['assetUploadItemImages'] = assetUploadItemImages;

      // Debug logging for photo data

      // Step 5: Handle save (add new or update existing)
      if (_isEditing && _editingItem != null) {
        // Try to find existing item in the internal list
        // Match by normalized serial or full scanned code
        final editingSerial = _editingItem!['mfg_serial_no']?.toString() ?? '';
        final editingFullCode = _editingItem!['full_scanned_code']?.toString() ?? '';
        final currentSerial = widget.serialController.text;
        
        int existingIndex = -1;
        if (editingSerial.isNotEmpty) {
          existingIndex = _savedItems.indexWhere(
            (item) {
              final itemSerial = item['mfg_serial_no']?.toString() ?? '';
              final itemFullCode = item['full_scanned_code']?.toString() ?? '';
              return itemSerial == editingSerial || 
                     itemSerial == currentSerial ||
                     itemFullCode == editingFullCode ||
                     itemFullCode == currentSerial;
            },
          );
        }

        if (existingIndex != -1) {
          // Replace the existing item in the list with updated data (including new photo)
          _savedItems[existingIndex] = itemData;
        } else {
          // Item not found in internal list (e.g., editing from external source)
          // Add it to the list so it can be passed to parent callback
          _savedItems.add(itemData);
        }

        final suppress = widget.shouldSuppressSuccessToast?.call(itemData) ?? false;
        if (!suppress) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Check if item with same serial number already exists
        final existingIndex = _savedItems.indexWhere(
          (item) {
            final itemSerial = item['mfg_serial_no']?.toString() ?? '';
            final itemFullCode = item['full_scanned_code']?.toString() ?? '';
            return itemSerial == widget.serialController.text ||
                   itemFullCode == widget.serialController.text;
          },
        );

        if (existingIndex != -1) {
          // Update existing item instead of creating duplicate (preserve updated photo)
          _savedItems[existingIndex] = itemData;

          final suppress = widget.shouldSuppressSuccessToast?.call(itemData) ?? false;
          if (!suppress) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Item updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Add new item to the internal list
          _savedItems.add(itemData);

          final suppress = widget.shouldSuppressSuccessToast?.call(itemData) ?? false;
          if (!suppress) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Item saved successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
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
      // Store the original file path before we might modify _selectedPhotoPath
      final originalPhotoPath = _selectedPhotoPath!;
      
      // Check if _selectedPhotoPath is already base64 (shouldn't be, but handle it)
      String base64Image;
      
      if (originalPhotoPath.startsWith('data:image/')) {
        // Already base64 - extract the base64 part
        final parts = originalPhotoPath.split(',');
        if (parts.length == 2) {
          base64Image = parts[1];
        } else {
          throw Exception('Invalid base64 image format');
        }
      } else {
        // It's a file path - read and convert to base64
        final imageFile = File(originalPhotoPath);
        final bytes = await imageFile.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      // Upload using ImageUploadService
      final uniqueId = await _imageUploadService.uploadImage(
        base64Image,
        ActivityTypeEnum.assetAudit,
        false,
        widget.siteAuditSchId,
      );

      // Create data URL format for immediate display
      final dataUrl = 'data:image/jpeg;base64,$base64Image';

      setState(() {
        _isUploading = false;
        _uploadedImageId = uniqueId;
        // Update photo data with base64 for immediate display in table
        _photoData = dataUrl;
        _selectedPhotoPath = dataUrl; // Update to base64 format for display
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
      _isLoadingPhoto = false;
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

  /// Starts editing an item (public method for external editing)
  void startEditingItem(Map<String, dynamic> item) {
    _startEditing(item);
  }

  /// Starts editing an item
  void _startEditing(Map<String, dynamic> item) async {
    setState(() {
      _isEditing = true;
      _editingItem = item;
      // Use full_scanned_code if available (NG-ACRONYM-SERIAL), otherwise use mfg_serial_no
      final fullSerialNumber = item['full_scanned_code']?.toString();
      if (fullSerialNumber != null && fullSerialNumber.isNotEmpty) {
        widget.serialController.text = fullSerialNumber;
      } else {
        widget.serialController.text = item['mfg_serial_no']?.toString() ?? '';
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
    } catch (e) {
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
          enabled: !_isEditing, // Disable when editing
          inputFormatters: [UpperCaseTextFormatter()],
          onChanged: (value) {
            if (!_isEditing) {
              // Only allow changes when not editing
              setState(() {
                _isQRCodeScanned = false;
                qrCodeScannedTs = null;
              });
            }
          },
          decoration: InputDecoration(
            hintText: widget.serialHintText,
            hintStyle: TextStyle(
              fontWeight: FontWeight.w400,
              fontFamily: fontFamilyMontserrat,
              fontSize: 16,
              color: AppColors.color555555,
            ),
            suffixIcon: _isEditing
                ? null // Hide QR scanner button when editing
                : IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      try {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const QRScannerScreen()),
                        );
                        if (result != null && result is String) {
                          setState(() {
                            widget.serialController.text = result.toUpperCase();
                            _isQRCodeScanned = true;
                            qrCodeScannedTs =
                                Utils.getCurrentDateTimeForAPICall();
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
                                if (lookupResult.containsKey(
                                    'manufacturing_year')) {
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
            fillColor: _isEditing ? Colors.grey.shade200 : Colors.white, // Show disabled background when editing
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
            child: _isLoadingPhoto
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Loading image...',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: AppColors.color555555,
                            fontFamily: fontFamilyMontserrat,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _shouldShowImage()
                    ? Stack(
                        key: ValueKey(_selectedPhotoPath ?? ''),
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
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(vertical: 0),
      
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
                    _buildTableHeaderCell('Serial Number', 200, padding: const EdgeInsets.only(left: 0, right: 4)),
                    if (widget.showForm) ...[
                      // Only show these columns when form is visible (for backward compatibility)
                      if (showFirstDisabledFieldColumn)
                        _buildTableHeaderCell(widget.disabledFieldLabel ?? '', 100),
                      if (showSecondDisabledFieldColumn)
                        _buildTableHeaderCell(secondDisabledFieldHeader, 80),
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
  Widget _buildTableHeaderCell(String text, double width, {EdgeInsets? padding}) {
    return Container(
      width: width,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 0),
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

    // Create a unique key for the row to force rebuild when item changes.
    // Include aui_id (when present) so that two DB rows with the same
    // serial number but different IDs don't collide.
    final auiIdPart = item['aui_id']?.toString() ?? '';
    final itemKey = '$auiIdPart-' +
        (item['mfg_serial_no']?.toString() ??
            item['full_scanned_code']?.toString() ??
            item['timestamp']?.toString() ??
            'item_${item.hashCode}');
    final photoKey = item['photo_id']?.toString() ?? 
                    item['photoPath']?.toString() ?? 
                    '';
    final rowKey = '$itemKey-$photoKey';

    return Container(
      key: ValueKey(rowKey), // Force rebuild when photo changes
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          // Display full serial number if available (NG-ACRONYM-SERIAL), otherwise show mfg_serial_no
          // Check if item is existing (has aui_id) or new (no aui_id or aui_id is 0)
          _buildTableDataCell(
            item['full_scanned_code']?.toString() ?? item['mfg_serial_no']?.toString() ?? '', 
            200,
            isNewItem: _isNewItem(item),
          ),
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
          ],
          _buildTablePhotoCell(item, 80),
          _buildTableEditCell(item, 80),
        ],
      ),
    );
  }

  /// Checks if an item is new (not from API) or existing (from API)
  bool _isNewItem(Map<String, dynamic> item) {
    final auiId = item['aui_id'];
    // If aui_id is null, 0, or "0", it's a new item
    if (auiId == null) return true;
    if (auiId == 0) return true;
    if (auiId.toString() == '0') return true;
    // If aui_id exists and is not 0, it's an existing item from API
    return false;
  }

  /// Builds a table data cell
  Widget _buildTableDataCell(String text, double width, {bool? isScanned, bool? isNewItem}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: isNewItem != null ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          if (isScanned != null) ...[
            Icon(
              isScanned ? Icons.qr_code_scanner : Icons.close,
              color: isScanned ? Colors.blue : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 4),
          ],
          // Show dot indicator for serial number column
          if (isNewItem != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isNewItem ? AppColors.primaryGreen : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
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
              textAlign: isNewItem != null ? TextAlign.left : TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a table photo cell
  Widget _buildTablePhotoCell(Map<String, dynamic> item, double width) {
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

    // Determine which photo to show (prefer photoPath if it's base64 for immediate display, otherwise use photo_id)
    final photoToShow = (photoPathString != null && 
                        photoPathString.isNotEmpty && 
                        photoPathString.startsWith('data:image/'))
        ? photoPathString  // Use base64 photoPath for immediate display
        : (hasValidPhotoId
            ? photoIdString
            : (hasValidPhotoPath ? photoPathString : null));

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
          // If parent provided onEditItem callback, use it (for external editing)
          // Otherwise, edit within this component
          if (widget.onEditItem != null) {
            widget.onEditItem!(item);
          } else {
            _startEditing(item);
          }
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
              color: Colors.white.withOpacity(0.1),
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

                // Save button
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
      } catch (e) {
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