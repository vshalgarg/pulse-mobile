import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/constants_strings.dart';
import '../../services/image_upload_service.dart';
import '../../enum/activity_type_enum.dart';
import '../../app_config.dart';
import '../../commonWidgets/custom_remark.dart';
import '../../commonWidgets/custom_form_field.dart';
import '../../commonWidgets/custom_form_dropdown.dart';
import '../../commonWidgets/custom_image_upload_field.dart';
import '../../commonWidgets/custom_radio_options.dart';
import '../../utils/logger.dart';
import '../../utils/toastbar.dart';
import '../../utils.dart';
import '../../services/service_locator.dart';
import 'pm_dependent_element_helpers.dart';

class PMCustomWidget extends StatefulWidget {
  final Map<String, dynamic> pmItem;
  final List<String> readonlyFields;
  final Function(Map<String, dynamic>) onValueChanged;

  const PMCustomWidget({
    super.key,
    required this.pmItem,
    required this.readonlyFields,
    required this.onValueChanged,
  });

  @override
  State<PMCustomWidget> createState() => PMCustomWidgetState();
}

class PMCustomWidgetState extends State<PMCustomWidget> {
  late Map<String, dynamic> _currentItem;
  String? _selectedDropdownValue;
  String? _selectedRadioValue;
  String? _textValue;
  String? _imageData;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  
  // Dependent elements state - keyed by dependent element respType or a unique key
  Map<String, String?> _dependentImageIds = {}; // key -> imageId
  Map<String, String?> _dependentImageData = {}; // key -> imageDataUrl (for display)
  Map<String, String> _dependentRemarks = {}; // key -> remarks text
  Map<String, String> _dependentTextValues = {}; // key -> text value
  Map<String, TextEditingController> _dependentControllers = {}; // key -> controller
  Map<String, File?> _dependentImageFiles = {}; // key -> image file
  
  // Track which dependent fields should be highlighted (for validation errors)
  Set<String> _highlightedDependentFields = {};

  @override
  void initState() {
    super.initState();
    _currentItem = Map<String, dynamic>.from(widget.pmItem);
    _initializeValues();

    // Add listener for remarks controller
    _remarksController.addListener(() {
      _onRemarksChanged(_remarksController.text);
    });
    
    // Check for images after a delay (in case they're being downloaded in background)
    // This handles the case where response_images is null initially but images are downloaded later
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check multiple times with increasing delays to catch images that are downloaded asynchronously
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _checkForDownloadedImages();
        }
      });
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) {
          _checkForDownloadedImages();
        }
      });
      Future.delayed(const Duration(milliseconds: 5000), () {
        if (mounted) {
          _checkForDownloadedImages();
        }
      });
    });
  }
  
  /// Check if images have been downloaded and cached, even if response_images is null
  Future<void> _checkForDownloadedImages() async {
    try {
      // If we already have image data, don't check again
      if (_imageData != null && _imageData!.isNotEmpty) {
        Logger.infoLog('[PM] Image already loaded, skipping check');
        print('[PM] Image already loaded, skipping check');
        return;
      }
      
      // Check response_images again (might have been updated)
      final responseImages = _currentItem['response_images'] ?? _currentItem['responseImages'];
      Logger.infoLog('[PM] 🔍 Checking for images - response_images: $responseImages');
      print('[PM] 🔍 Checking for images - response_images: $responseImages');
      
      if (responseImages != null && responseImages is List && responseImages.isNotEmpty) {
        final firstImage = responseImages[0];
        if (firstImage is Map) {
          final photoId = firstImage['photo_id'] ?? firstImage['photoId'];
          if (photoId != null && photoId.toString().trim().isNotEmpty) {
            Logger.infoLog('[PM] ✅ Found photo_id in delayed check: $photoId');
            print('[PM] ✅ Found photo_id in delayed check: $photoId');
            await _loadImageFromServerPhotoId(photoId.toString());
            return;
          }
        }
      }
      
      // Also check if photo_id exists directly on the item (might have been processed)
      final directPhotoId = _currentItem['photo_id'];
      if (directPhotoId != null && directPhotoId.toString().trim().isNotEmpty && 
          directPhotoId.toString() != '0' && directPhotoId.toString() != 'null') {
        Logger.infoLog('[PM] ✅ Found photo_id directly on item in delayed check: $directPhotoId');
        print('[PM] ✅ Found photo_id directly on item in delayed check: $directPhotoId');
        await _loadImageFromServerPhotoId(directPhotoId.toString());
        return;
      }
      
      Logger.infoLog('[PM] ⚠️ No images found - response_images is null and no photo_id on item');
      print('[PM] ⚠️ No images found - response_images is null and no photo_id on item');
    } catch (e) {
      Logger.errorLog('[PM] ❌ Error checking for downloaded images: $e');
      print('[PM] ❌ Error checking for downloaded images: $e');
    }
  }

  @override
  void didUpdateWidget(PMCustomWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if pmItem has changed
    if (widget.pmItem != oldWidget.pmItem) {
      Logger.infoLog('[PM] Widget updated with new pmItem data');
      
      // Get old and new response_images for comparison
      final oldResponseImages = oldWidget.pmItem['response_images'] ?? oldWidget.pmItem['responseImages'];
      final newResponseImages = widget.pmItem['response_images'] ?? widget.pmItem['responseImages'];
      
      // Update current item
      _currentItem = Map<String, dynamic>.from(widget.pmItem);
      
      // Check if response_images has changed (including null -> non-null)
      bool imagesChanged = false;
      if (oldResponseImages != newResponseImages) {
        // Clear current image data before loading new one
        setState(() {
          _imageData = null;
        });
        imagesChanged = true;
        Logger.infoLog('[PM] Response images changed, will reload image');
        Logger.infoLog('[PM] Old response_images: $oldResponseImages');
        Logger.infoLog('[PM] New response_images: $newResponseImages');
      }
      
      // Also check if response_images was null before but is now populated
      if (!imagesChanged && 
          (oldResponseImages == null || (oldResponseImages is List && oldResponseImages.isEmpty)) &&
          newResponseImages != null && 
          newResponseImages is List && 
          newResponseImages.isNotEmpty) {
        Logger.infoLog('[PM] Response images populated (was null/empty, now has data)');
        imagesChanged = true;
        setState(() {
          _imageData = null;
        });
      }
      
      // Reload values including images if they changed
      if (imagesChanged) {
        _initializeValues();
      } else {
        // Just update other values without reloading images
        _updateNonImageValues();
      }
    }
  }
  
  /// Update values without reloading images (used when only non-image data changes)
  void _updateNonImageValues() {
    final respValue = _currentItem['resp'];
    final respTypeList = _currentItem['resp_type'];

    // Handle resp_type as array or string
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = respTypeList.split(",");
    }

    // Update dropdown value
    if (respTypes.contains('DROPDOWN')) {
      _selectedDropdownValue = _getDisplayLabelForValue(respValue);
    }

    // Update radio value
    if (respTypes.contains('RADIO')) {
      if (respValue != null && respValue.toString().isNotEmpty) {
        _selectedRadioValue = respValue.toString();
      }
    }

    // Update text value
    _textValue = respValue?.toString();
    _textController.text = _textValue ?? '';

    // Update remarks value
    _remarksController.text = respValue?.toString() ?? '';
  }

  @override
  void dispose() {
    _textController.dispose();
    _remarksController.dispose();
    // Dispose all dependent element controllers
    for (final controller in _dependentControllers.values) {
      controller.dispose();
    }
    _dependentControllers.clear();
    super.dispose();
  }

  void _initializeValues() {
    Logger.infoLog('[PM] ========== _initializeValues called ==========');
    Logger.infoLog('[PM] pm_check_list_site_resp_id: ${_currentItem['pm_check_list_site_resp_id']}');
    Logger.infoLog('[PM] checklist_desc: ${_currentItem['checklist_desc']}');

    // here print complete currentItem
    print('[PM] currentItem: ${_currentItem}');
    
    final respValue = _currentItem['resp'];
    final respTypeList = _currentItem['resp_type'];

    // Handle resp_type as array or string
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = respTypeList.split(",");
    }

    // Initialize dropdown value - handle dynamic mapping
    if (respTypes.contains('DROPDOWN')) {
      _selectedDropdownValue = _getDisplayLabelForValue(respValue);
    }

    // Initialize radio value from resp
    if (respTypes.contains('RADIO')) {
      if (respValue != null && respValue.toString().isNotEmpty) {
        _selectedRadioValue = respValue.toString();
      }
      // Don't set a default value - let user select
    }

    // Initialize text value
    _textValue = respValue?.toString();
    _textController.text = _textValue ?? '';

    // Initialize remarks value
    _remarksController.text = respValue?.toString() ?? '';

    // Load image data from response_images array (snake_case from API) or responseImages (camelCase)
    final responseImages = _currentItem['response_images'] ?? _currentItem['responseImages'];
    
    Logger.infoLog('[PM] ========== _initializeValues - Image Loading ==========');
    print('[PM] ========== _initializeValues - Image Loading ==========');
    Logger.infoLog('[PM] Checking for images...');
    print('[PM] Checking for images...');
    Logger.infoLog('[PM] response_images type: ${responseImages}');
    Logger.infoLog('[PM] response_images value: $responseImages');
    print('[PM] response_images value: $responseImages');
    Logger.infoLog('[PM] response_images is List: ${responseImages is List}');
    print('[PM] response_images is List: ${responseImages is List}');
    if (responseImages is List) {
      Logger.infoLog('[PM] response_images isNotEmpty: ${responseImages.isNotEmpty}');
      print('[PM] response_images isNotEmpty: ${responseImages.isNotEmpty}');
      Logger.infoLog('[PM] response_images length: ${responseImages.length}');
      print('[PM] response_images length: ${responseImages.length}');
      if (responseImages.isNotEmpty) {
        Logger.infoLog('[PM] response_images[0]: ${responseImages[0]}');
        print('[PM] response_images[0]: ${responseImages[0]}');
      }
    }
    
    // Load images from response_images and map them to dependent elements by index
    final dependentElements = parseDependentElements(_currentItem);
    
    if (responseImages != null && responseImages is List && responseImages.isNotEmpty) {
      // Map each image in response_images to the corresponding IMG element by index
      int imgElementIndex = 0; // Track which IMG element we're on
      
      for (int i = 0; i < responseImages.length; i++) {
        final imageData = responseImages[i];
        if (imageData is Map) {
          final photoId = imageData['photo_id'] ?? imageData['photoId'];
          if (photoId != null && photoId.toString().trim().isNotEmpty && 
              photoId.toString() != '0' && photoId.toString() != 'null') {
            // Find the corresponding IMG element at this index
            String? dependentElementKey;
            if (dependentElements != null && dependentElements.isNotEmpty) {
              int currentImgIndex = 0;
              for (int j = 0; j < dependentElements.length; j++) {
                final element = dependentElements[j];
                if (element['resp_type']?.toString() == 'IMG') {
                  if (currentImgIndex == imgElementIndex) {
                    // This is the IMG element that corresponds to this image index
                    final checklistDesc = element['checklist_desc']?.toString() ?? '';
                    dependentElementKey = 'IMG_${checklistDesc}_$currentImgIndex';
                    Logger.infoLog('[PM] 🎯 Mapping response_images[$i] (photo_id: $photoId) to IMG element at index $currentImgIndex, key: $dependentElementKey');
                    print('[PM] 🎯 Mapping response_images[$i] (photo_id: $photoId) to IMG element at index $currentImgIndex, key: $dependentElementKey');
                    
                    // Load this image with the correct elementKey
                    final photoIdStr = photoId.toString();
                    _loadImageFromServerPhotoId(photoIdStr, dependentElementKey: dependentElementKey).then((_) {
                      Logger.infoLog('[PM] ✅ Image loading completed for photo_id: $photoIdStr, elementKey: $dependentElementKey');
                      print('[PM] ✅ Image loading completed for photo_id: $photoIdStr, elementKey: $dependentElementKey');
                    }).catchError((e) {
                      Logger.errorLog('[PM] ❌ Error loading image for photo_id $photoIdStr: $e');
                      print('[PM] ❌ Error loading image for photo_id $photoIdStr: $e');
                    });
                    break;
                  }
                  currentImgIndex++;
                }
              }
            }
            imgElementIndex++; // Move to next IMG element for next image
          }
        }
      }
      // Return early since we've handled all images from response_images
      Logger.infoLog('[PM] ========== _initializeValues completed ==========');
      print('[PM] ========== _initializeValues completed ==========');
      return;
    }
    
    // Fallback: check for direct photo_id on item (for non-dependent element images)
    String? photoIdToLoad;
    if (_currentItem['photo_id'] != null) {
      final directPhotoId = _currentItem['photo_id'].toString();
      if (directPhotoId.isNotEmpty && directPhotoId != '0' && directPhotoId != 'null') {
        photoIdToLoad = directPhotoId;
        Logger.infoLog('[PM] ✅ Found photo_id directly on item: $photoIdToLoad');
        print('[PM] ✅ Found photo_id directly on item: $photoIdToLoad');
      }
    }
    
    // Load image if we found a photo_id (for main field, not dependent elements)
    if (photoIdToLoad != null) {
      Logger.infoLog('[PM] 🚀 Starting image load for photo_id: $photoIdToLoad');
      print('[PM] 🚀 Starting image load for photo_id: $photoIdToLoad');
      
      // Load image asynchronously - don't await to avoid blocking UI
      _loadImageFromServerPhotoId(photoIdToLoad).then((_) {
        Logger.infoLog('[PM] ✅ Image loading completed for photo_id: $photoIdToLoad');
        print('[PM] ✅ Image loading completed for photo_id: $photoIdToLoad');
      }).catchError((e) {
        Logger.errorLog('[PM] ❌ Error loading image for photo_id $photoIdToLoad: $e');
        print('[PM] ❌ Error loading image for photo_id $photoIdToLoad: $e');
      });
    } else {
      Logger.infoLog('[PM] ❌ No response_images or photo_id found in item');
      print('[PM] ❌ No response_images or photo_id found in item');
      Logger.infoLog('[PM] Item keys: ${_currentItem.keys.toList()}');
      print('[PM] Item keys: ${_currentItem.keys.toList()}');
      Logger.infoLog('[PM] response_images value: ${_currentItem['response_images']}');
      print('[PM] response_images value: ${_currentItem['response_images']}');
      Logger.infoLog('[PM] responseImages value: ${_currentItem['responseImages']}');
      print('[PM] responseImages value: ${_currentItem['responseImages']}');
      Logger.infoLog('[PM] photo_id value: ${_currentItem['photo_id']}');
      print('[PM] photo_id value: ${_currentItem['photo_id']}');
    }
    
    Logger.infoLog('[PM] ========== _initializeValues completed ==========');
    print('[PM] ========== _initializeValues completed ==========');
  }

  /// Load image from photo_id (unique ID from database or server ID)
  /// Uses the same approach as asset audit - getImageAsDataUrl handles both server IDs and unique IDs
  /// If dependentElementKey is provided, also sets the image in _dependentImageData
  Future<void> _loadImageFromServerPhotoId(String photoId, {String? dependentElementKey}) async {
    try {
      if (photoId.isEmpty || photoId == '0' || photoId == 'null') {
        Logger.infoLog('[PM] Invalid photo ID: $photoId');
        print('Invalid photo ID: $photoId');
        return;
      }

      Logger.infoLog('[PM] 🔄 Loading image from photo_id: $photoId');

      print('photoId: $photoId');
      
      String? imageDataLocal;
      
      // Check if this is a numeric server ID (needs download) or unique ID (already cached)
      if (int.tryParse(photoId) != null && !photoId.contains("LOCAL_IMAGE_ID")) {
        // This is a numeric server ID - download it first to get unique ID
        Logger.infoLog('[PM] 📥 Detected numeric server ID: $photoId, checking cache first...');
        print('[PM] 📥 Detected numeric server ID: $photoId, checking cache first...');
        
        
        // First, check if already cached by server ID
        final cachedImage = await ServiceLocator()
            .imageUploadService
            .getImagesByServerId(photoId);
        
        if (cachedImage != null && cachedImage.imageData != null && cachedImage.imageData!.isNotEmpty) {
          // Found in cache
          imageDataLocal = cachedImage.imageData;
          Logger.infoLog('[PM] ✅ Image found in cache by server ID, data length: ${imageDataLocal?.length ?? 0}');
          print('[PM] ✅ Image found in cache by server ID, data length: ${imageDataLocal?.length ?? 0}');
        } else {
          // Not in cache, download from server
          Logger.infoLog('[PM] ⬇️ Image not in cache, downloading from server...');
          print('[PM] ⬇️ Image not in cache, downloading from server...');
          
          final uniqueId = await ServiceLocator()
              .imageUploadService
              .downloadImageUsingServerId(
                photoId,
                ActivityTypeEnum.preventiveMaintenance,
                _currentItem['site_audit_sch_id']?.toString() ?? '',
              );
          
          if (uniqueId != null) {
            Logger.infoLog('[PM] ✅ Image downloaded, uniqueId: $uniqueId');
            print('[PM] ✅ Image downloaded, uniqueId: $uniqueId');
            // Get image data using unique ID via getImageAsDataUrl (same as asset audit)
            imageDataLocal = await ServiceLocator()
                .centralAssetAuditService
                .getImageAsDataUrl(uniqueId);
            
            if (imageDataLocal == null || imageDataLocal.isEmpty) {
              // Fallback: try direct getImageUsingUniqueId
              Logger.infoLog('[PM] 🔄 Fallback: trying getImageUsingUniqueId with uniqueId');
              print('[PM] 🔄 Fallback: trying getImageUsingUniqueId with uniqueId');
              imageDataLocal = await ServiceLocator()
                  .imageUploadService
                  .getImageUsingUniqueId(uniqueId);
            }
          } else {
            Logger.errorLog('[PM] ❌ Failed to download image - uniqueId is null');
            print('[PM] ❌ Failed to download image - uniqueId is null');
          }
        }
      } else {
        // This is a unique ID (LOCAL_IMAGE_ID or processed unique ID) - use getImageAsDataUrl
        Logger.infoLog('[PM] 🔑 Using unique ID: $photoId, loading via getImageAsDataUrl');
        print('[PM] 🔑 Using unique ID: $photoId, loading via getImageAsDataUrl');
        
        imageDataLocal = await ServiceLocator()
            .centralAssetAuditService
            .getImageAsDataUrl(photoId);
        
        Logger.infoLog('[PM] 🔑 getImageAsDataUrl result: ${imageDataLocal != null ? "NOT NULL (${imageDataLocal.length} chars)" : "NULL"}');
        print('[PM] 🔑 getImageAsDataUrl result: ${imageDataLocal != null ? "NOT NULL (${imageDataLocal.length} chars)" : "NULL"}');
        
        if (imageDataLocal == null || imageDataLocal.isEmpty) {
          // Fallback: try direct getImageUsingUniqueId
          Logger.infoLog('[PM] 🔄 Fallback: trying getImageUsingUniqueId');
          print('[PM] 🔄 Fallback: trying getImageUsingUniqueId');
          imageDataLocal = await ServiceLocator()
              .imageUploadService
              .getImageUsingUniqueId(photoId);

          Logger.infoLog('[PM] 🔄 getImageUsingUniqueId result: ${imageDataLocal != null ? "NOT NULL (${imageDataLocal.length} chars)" : "NULL"}');
          print('[PM] 🔄 getImageUsingUniqueId result: ${imageDataLocal != null ? "NOT NULL (${imageDataLocal.length} chars)" : "NULL"}');
          
          if (imageDataLocal == null || imageDataLocal.isEmpty) {
            // Second fallback: try getImagesByServerId (in case it's stored by server ID)
            Logger.infoLog('[PM] 🔄 Second fallback: trying getImagesByServerId');
            print('[PM] 🔄 Second fallback: trying getImagesByServerId');
            final cachedImage = await ServiceLocator()
                .imageUploadService
                .getImagesByServerId(photoId);
            
            if (cachedImage != null && cachedImage.imageData != null && cachedImage.imageData!.isNotEmpty) {
              imageDataLocal = cachedImage.imageData;
              Logger.infoLog('[PM] 🔄 Found via getImagesByServerId, data length: ${imageDataLocal?.length ?? 0}');
              print('[PM] 🔄 Found via getImagesByServerId, data length: ${imageDataLocal?.length ?? 0}');
            }
          }
        }
      }
      
      // Format and set image data
      if (imageDataLocal != null && imageDataLocal.isNotEmpty) {
        // Clean the image data
        String cleanedData = imageDataLocal.trim();
        
        // Validate base64 data before formatting
        try {
          // Try to decode a small portion to validate it's valid base64
          String base64ToValidate = cleanedData;
          if (cleanedData.startsWith('data:image/')) {
            final parts = cleanedData.split(',');
            if (parts.length > 1) {
              base64ToValidate = parts[1];
            }
          }
          
          // Validate by trying to decode first 100 chars
          if (base64ToValidate.length > 100) {
            base64Decode(base64ToValidate.substring(0, 100));
          } else {
            base64Decode(base64ToValidate);
          }
          
          Logger.infoLog('[PM] ✅ Base64 data validated successfully');
          print('[PM] ✅ Base64 data validated successfully');
        } catch (e) {
          Logger.errorLog('[PM] ❌ Invalid base64 data: $e');
          print('[PM] ❌ Invalid base64 data: $e');
          Logger.errorLog('[PM] Data preview: ${cleanedData.length > 200 ? cleanedData.substring(0, 200) : cleanedData}');
          print('[PM] Data preview: ${cleanedData.length > 200 ? cleanedData.substring(0, 200) : cleanedData}');
          if (mounted) {
        setState(() {
              _imageData = null;
            });
          }
          return;
        }
        
        // Format as data URL if not already
        String formattedImageData;
        if (cleanedData.startsWith('data:image/')) {
          // Normalize image/jpg to image/jpeg for consistency
          if (cleanedData.startsWith('data:image/jpg')) {
            formattedImageData = cleanedData.replaceFirst('data:image/jpg', 'data:image/jpeg');
      } else {
            formattedImageData = cleanedData;
      }
        } else {
          formattedImageData = 'data:image/jpeg;base64,$cleanedData';
        }
        
        Logger.infoLog('[PM] ✅ Image data loaded successfully');
        print('[PM] ✅ Image data loaded successfully');
        Logger.infoLog('[PM] Original data length: ${imageDataLocal.length}');
        print('[PM] Original data length: ${imageDataLocal.length}');
        Logger.infoLog('[PM] Formatted data length: ${formattedImageData.length}');
        print('[PM] Formatted data length: ${formattedImageData.length}');
        Logger.infoLog('[PM] Formatted data starts with: ${formattedImageData.substring(0, formattedImageData.length > 100 ? 100 : formattedImageData.length)}');
        print('[PM] Formatted data starts with: ${formattedImageData.substring(0, formattedImageData.length > 100 ? 100 : formattedImageData.length)}');
        
        if (mounted) {
          Logger.infoLog('[PM] 🔄 About to set image data in state...');
          print('[PM] 🔄 About to set image data in state...');
          
          // Set image data and trigger rebuild
          setState(() {
            _imageData = formattedImageData;
            Logger.infoLog('[PM] 🔄 Inside setState: _imageData set to ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
            print('[PM] 🔄 Inside setState: _imageData set to ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
            
            // If this image is for a dependent element, also set it in _dependentImageData
            if (dependentElementKey != null && formattedImageData.isNotEmpty) {
              _dependentImageData[dependentElementKey] = formattedImageData;
              Logger.infoLog('[PM] 🎯 Also set _dependentImageData[$dependentElementKey] to ${formattedImageData.length} chars');
              print('[PM] 🎯 Also set _dependentImageData[$dependentElementKey] to ${formattedImageData.length} chars');
            }
          });
          
          Logger.infoLog('[PM] ✅ Image data set in state successfully');
          print('[PM] ✅ Image data set in state successfully');
          Logger.infoLog('[PM] _imageData is now: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
          print('[PM] _imageData is now: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
          
          // Force multiple rebuilds to ensure ImageUploadField gets the update
          // Sometimes Flutter needs multiple frames to properly update nested widgets
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Logger.infoLog('[PM] 🔄 PostFrameCallback 1: About to force rebuild');
              print('[PM] 🔄 PostFrameCallback 1: About to force rebuild');
              setState(() {
                Logger.infoLog('[PM] 🔄 PostFrameCallback 1: Inside setState, _imageData: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
                print('[PM] 🔄 PostFrameCallback 1: Inside setState, _imageData: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
              });
              
              // Second callback after a short delay
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  Logger.infoLog('[PM] 🔄 PostFrameCallback 2: About to force rebuild');
                  print('[PM] 🔄 PostFrameCallback 2: About to force rebuild');
                  setState(() {
                    Logger.infoLog('[PM] 🔄 PostFrameCallback 2: Inside setState, _imageData: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
                    print('[PM] 🔄 PostFrameCallback 2: Inside setState, _imageData: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
                  });
                }
              });
            }
          });
        } else {
          Logger.errorLog('[PM] ❌ Widget not mounted, cannot set state');
          print('[PM] ❌ Widget not mounted, cannot set state');
        }
      } else {
        Logger.errorLog('[PM] ❌ Failed to load image: No data retrieved');
        print('[PM] ❌ Failed to load image: No data retrieved');
        Logger.errorLog('[PM] imageDataLocal is: ${imageDataLocal != null ? "NOT NULL but empty (length: ${imageDataLocal.length})" : "NULL"}');
        print('[PM] imageDataLocal is: ${imageDataLocal != null ? "NOT NULL but empty (length: ${imageDataLocal.length})" : "NULL"}');
        if (mounted) {
          setState(() {
            _imageData = null;
          });
        }
      }
    } catch (e, stackTrace) {
      Logger.errorLog('[PM] ❌ Error loading image from photo_id: $e');
      Logger.errorLog('[PM] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _imageData = null;
        });
      }
    }
  }

  /// Add or update image in response_images array
  /// Supports both snake_case (response_images) and camelCase (responseImages) formats
  /// If replaceExisting is true, replaces all existing images; otherwise updates by photoId or adds new
  /// If elementIndex is provided, replaces/updates the image at that specific index
  void _addImageToResponseImages(String photoId, {bool replaceExisting = false, int? elementIndex}) {
    // Use snake_case for API compatibility (response_images)
    if (!_currentItem.containsKey('response_images') || 
        _currentItem['response_images'] == null) {
      _currentItem['response_images'] = [];
    }
    
    List<Map<String, dynamic>> responseImages = 
        List<Map<String, dynamic>>.from(_currentItem['response_images'] ?? []);
    
    // Store in snake_case format for API compatibility
    final imageData = {
      'photo_id': photoId,
      'photo_taken_ts': Utils.getCurrentDateTimeForAPICall(),
      'pclsri_id': 0, // Default to 0 for new uploads
    };
    
    if (replaceExisting) {
      if (elementIndex != null) {
        // Replace image at specific index
        // Ensure list is large enough
        while (responseImages.length <= elementIndex) {
          responseImages.add(<String, dynamic>{});
        }
        responseImages[elementIndex] = imageData;
        Logger.infoLog('[PM] 🔄 Replaced image at index $elementIndex with new image: $photoId');
        print('[PM] 🔄 Replaced image at index $elementIndex with new image: $photoId');
      } else {
        // Replace all existing images with the new one
        responseImages = [imageData];
        Logger.infoLog('[PM] 🔄 Replaced all existing images with new image: $photoId');
        print('[PM] 🔄 Replaced all existing images with new image: $photoId');
      }
    } else {
    // Check if photoId already exists, update it; otherwise add new
      // Check both snake_case and camelCase photo_id fields
    final existingIndex = responseImages.indexWhere(
        (img) => (img['photo_id'] ?? img['photoId'])?.toString() == photoId,
    );
    
      // Get pclsriId from existing image if found, otherwise use 0
    if (existingIndex >= 0) {
        final existingPclsriId = responseImages[existingIndex]['pclsri_id'] ?? 
                                 responseImages[existingIndex]['pclsriId'] ?? 0;
        imageData['pclsri_id'] = existingPclsriId;
      responseImages[existingIndex] = imageData;
        Logger.infoLog('[PM] 🔄 Updated existing image at index $existingIndex: $photoId');
        print('[PM] 🔄 Updated existing image at index $existingIndex: $photoId');
    } else {
      responseImages.add(imageData);
        Logger.infoLog('[PM] ➕ Added new image: $photoId');
        print('[PM] ➕ Added new image: $photoId');
      }
    }
    
    _currentItem['response_images'] = responseImages;
    // Also update camelCase version for backward compatibility
    _currentItem['responseImages'] = responseImages;
  }

  void _notifyValueChanged() {
    widget.onValueChanged(_currentItem);
  }

  /// Validate if all required fields are filled
  bool validateForm() {
    final respValue = _currentItem['resp'];
    final respTypeList = _currentItem['resp_type'];

    // Handle resp_type as array or string
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = respTypeList.split(",");
    }

    // Check if any required field is empty
    if (respTypes.contains('DROPDOWN') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return false;
    }

    if (respTypes.contains('RADIO') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return false;
    }

    if (respTypes.contains('TEXT') &&
        (respValue == null || respValue.toString().trim().isEmpty)) {
      return false;
    }

    if (respTypes.contains('IMG') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return false;
    }

    return true;
  }

  /// Get validation error message for this field
  String? getValidationError() {
    final respValue = _currentItem['resp'];
    final respTypeList = _currentItem['resp_type'];
    final checklistDesc =
        _currentItem['checklist_desc']?.toString() ?? 'This field';

    // Handle resp_type as array or string
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = respTypeList.split(",");
    }

    // Check if any required field is empty
    if (respTypes.contains('DROPDOWN') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return '$checklistDesc is required';
    }

    if (respTypes.contains('RADIO') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return '$checklistDesc is required';
    }

    if (respTypes.contains('TEXT') &&
        (respValue == null || respValue.toString().trim().isEmpty)) {
      return '$checklistDesc is required';
    }

    if (respTypes.contains('NUMERIC') &&
        (respValue == null || respValue.toString().trim().isEmpty)) {
      return '$checklistDesc is required';
    }

    if (respTypes.contains('IMG') &&
        (respValue == null || respValue.toString().isEmpty)) {
      return '$checklistDesc is required';
    }

    return null;
  }

  void _onDropdownChanged(String? value, [Map<String, String>? valueMap]) {
    setState(() {
      _selectedDropdownValue = value;
      // Use the mapped value for API if valueMap is provided, otherwise use the label
      if (valueMap != null && value != null && valueMap.containsKey(value)) {
        _currentItem['resp'] = valueMap[value];
      } else {
        _currentItem['resp'] = value;
      }
    });
    _notifyValueChanged();
    // Trigger rebuild to update dependent elements visibility
    setState(() {});
  }

  void _onRadioChanged(String? value) {
    setState(() {
      _selectedRadioValue = value;
      // Store the selected value directly (value comes from resp_type_value_map)
      _currentItem['resp'] = value;
    });
    _notifyValueChanged();
    // Trigger rebuild to update dependent elements visibility
    setState(() {});
  }

  void _onTextChanged(String value) {
    setState(() {
      _textValue = value;
      _currentItem['resp'] = value;
    });
    _notifyValueChanged();
    // Trigger rebuild to update dependent elements visibility
    setState(() {});
  }

  void _onRemarksChanged(String value) {
    setState(() {
      _currentItem['resp'] = value;
    });
    _notifyValueChanged();
  }

  /// Get display label for a given API value by reverse mapping
  String? _getDisplayLabelForValue(dynamic respValue) {
    if (respValue == null) return null;
    
    try {
      final respTypeValueMap = _currentItem['resp_type_value_map'];
      if (respTypeValueMap != null && respTypeValueMap is Map) {
        Map<String, dynamic> parsedMap;
        
        // Check if it's a nested structure with 'value' key (backward compatibility)
        if (respTypeValueMap.containsKey('value')) {
          final valueData = respTypeValueMap['value'];
          if (valueData is Map) {
            parsedMap = Map<String, dynamic>.from(valueData);
          } else if (valueData is String) {
            // Try to parse as JSON string
            parsedMap = Map<String, dynamic>.from(jsonDecode(valueData));
          } else {
            return respValue?.toString();
          }
        } 
        // resp_type_value_map is directly a Map (new format)
        else {
          parsedMap = Map<String, dynamic>.from(respTypeValueMap);
        }
        
        // Find the key (label) for the given value
        for (final entry in parsedMap.entries) {
          if (entry.value.toString() == respValue.toString()) {
            return entry.key;
          }
        }
      }
    } catch (e) {
      // If parsing fails, return the original value
      Logger.errorLog('[PM] Error in _getDisplayLabelForValue: $e');
    }
    
    return respValue?.toString();
  }

  Widget _buildDropdownField() {
    // Parse resp_type_value_map to get dynamic dropdown options
    List<String> dropdownOptions = [];
    Map<String, String> valueMap = {};
    
    try {
      final respTypeValueMap = _currentItem['resp_type_value_map'];
      if (respTypeValueMap != null && respTypeValueMap is Map) {
        Map<String, dynamic> parsedMap;
        
        // Check if it's a nested structure with 'value' key (backward compatibility)
        if (respTypeValueMap.containsKey('value')) {
          final valueData = respTypeValueMap['value'];
          if (valueData is Map) {
            parsedMap = Map<String, dynamic>.from(valueData);
          } else if (valueData is String) {
            // Try to parse as JSON string
            parsedMap = Map<String, dynamic>.from(jsonDecode(valueData));
          } else {
            parsedMap = {};
          }
        } 
        // resp_type_value_map is directly a Map (new format)
        else {
          parsedMap = Map<String, dynamic>.from(respTypeValueMap);
        }
        
        // Convert to label-value mapping
        if (parsedMap.isNotEmpty) {
        parsedMap.forEach((key, value) {
          dropdownOptions.add(key); // Label for display
          valueMap[key] = value.toString(); // Value for API
        });
        }
      }
    } catch (e) {
      Logger.errorLog('[PM] Error parsing resp_type_value_map: $e');
      // Fallback to static options if parsing fails
    }

    // If no dynamic options found, use static fallback
    if (dropdownOptions.isEmpty) {
      dropdownOptions = [
        'OK',
        'Corrected',
        'NOT OK - To be corrected',
        'Not Applicable',
      ];
    }

    return CustomDropdown(
      items: dropdownOptions,
      initialValue: _selectedDropdownValue,
      onChanged: (value) => _onDropdownChanged(value, valueMap),
      isRequired: _isFieldRequired(),
    );
  }

  /// Determine if a field is required based on mandatoryIfValue
  /// Returns false if mandatoryIfValue is null, false, or if checklist_desc contains "Remarks"
  bool _isFieldRequired() {
    // Check if checklist_desc contains "Remarks" (case-insensitive) - always non-mandatory
    // This handles cases like "Remarks, if any" where resp_type is TEXT but it's still a remarks field
    final checklistDesc = _currentItem['checklist_desc']?.toString().trim().toLowerCase() ?? '';
    if (checklistDesc.contains('remarks')) {
      return false; // Always non-mandatory if description contains "remarks"
    }
    
    // Check mandatoryIfValue - only required if explicitly true
    final mandatoryIfValue = _currentItem['mandatoryIfValue'];
    
    if (mandatoryIfValue == null) {
      return false; // Default to not mandatory if null
    }
    
    if (mandatoryIfValue is bool) {
      return mandatoryIfValue; // If true, required; if false, not required
    }
    
    // If mandatoryIfValue is a List, for main field we consider it as not mandatory
    // (List-based mandatoryIfValue is typically used for dependent elements based on parent response)
    if (mandatoryIfValue is List) {
      return false;
    }
    
    // Default to false for any other value
    return false;
  }

  Widget _buildRadioField() {
    // Parse resp_type_value_map to get radio options
    List<OptionItem> radioOptions = [];
    Map<String, String> valueMap = {};
    
    try {
      final respTypeValueMap = _currentItem['resp_type_value_map'];
      if (respTypeValueMap != null) {
        Map<String, dynamic>? parsedMap;
        
        // Try direct Map first (for RADIO types)
        if (respTypeValueMap is Map<String, dynamic>) {
          parsedMap = respTypeValueMap;
        } else if (respTypeValueMap is Map && respTypeValueMap.containsKey('value')) {
          // Try nested structure with 'value' key (for dropdown-style)
          final value = respTypeValueMap['value'];
          if (value is Map<String, dynamic>) {
            parsedMap = value;
          } else if (value is String) {
            parsedMap = Map<String, dynamic>.from(jsonDecode(value));
          }
        }
        
        if (parsedMap != null && parsedMap.isNotEmpty) {
          // Convert map entries to OptionItem list
          // For radio buttons, both key and value are the same (e.g., "OK": "OK")
          parsedMap.forEach((key, value) {
            final optionValue = value.toString();
            radioOptions.add(
              OptionItem(
                value: optionValue,
                label: key,
              ),
            );
            valueMap[key] = optionValue;
          });
        }
      }
    } catch (e) {
      // If parsing fails, use default options
    }
    
    // If no options found, use default Yes/No
    if (radioOptions.isEmpty) {
      radioOptions = [
        OptionItem(value: 'Yes', label: 'Yes'),
        OptionItem(value: 'No', label: 'No'),
      ];
      valueMap = {'Yes': 'Yes', 'No': 'No'};
    }
    
    return CustomRadioButton(
      options: radioOptions,
      initialValue: _selectedRadioValue,
      onChanged: (value) => _onRadioChanged(value),
      isRequired: _isFieldRequired(),
      horizontalSpacing: 30.0, // Reduced spacing between radio button options
    );
  }

  Widget _buildTextField() {
    return CustomFormField(
      initialValue: _textValue,
      controller: _textController,
      onChanged: _onTextChanged,
      isRequired: _isFieldRequired(),
    );
  }

  Widget _buildNumericField() {
    return CustomFormField(
      initialValue: _textValue,
      controller: _textController,
      onChanged: _onTextChanged,
      isRequired: _isFieldRequired(),
      inputType: InputType.number,
      hintText: 'Enter Number',
    );
  }

  Widget _buildImageField() {
    // Use a more reliable key that changes when image data changes
    // Include the length and first few chars to ensure uniqueness
    final imageKey = _imageData != null && _imageData!.isNotEmpty
        ? 'pm_image_${_currentItem['pm_check_list_site_resp_id']}_${_imageData!.length}_${_imageData!.substring(0, _imageData!.length > 20 ? 20 : _imageData!.length)}'
        : 'pm_image_${_currentItem['pm_check_list_site_resp_id']}_null';
    
    Logger.infoLog('[PM] 🖼️ Building ImageUploadField');
    print('[PM] 🖼️ Building ImageUploadField');
    Logger.infoLog('[PM] 🖼️ _imageData in _buildImageField: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    print('[PM] 🖼️ _imageData in _buildImageField: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    Logger.infoLog('[PM] 🖼️ externalImageUrl: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    print('[PM] 🖼️ externalImageUrl: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    if (_imageData != null && _imageData!.isNotEmpty) {
      Logger.infoLog('[PM] 🖼️ externalImageUrl preview: ${_imageData!.substring(0, _imageData!.length > 100 ? 100 : _imageData!.length)}...');
      print('[PM] 🖼️ externalImageUrl preview: ${_imageData!.substring(0, _imageData!.length > 100 ? 100 : _imageData!.length)}...');
    }
    Logger.infoLog('[PM] 🖼️ Image key: $imageKey');
    print('[PM] 🖼️ Image key: $imageKey');
    Logger.infoLog('[PM] 🖼️ pm_check_list_site_resp_id: ${_currentItem['pm_check_list_site_resp_id']}');
    print('[PM] 🖼️ pm_check_list_site_resp_id: ${_currentItem['pm_check_list_site_resp_id']}');
    
    // Force a unique key that changes when _imageData changes to ensure widget rebuilds
    // Use a combination of length and hash to create a stable but changing key
    // Also include a timestamp or counter to force rebuild when data changes
    final imageDataHash = _imageData != null && _imageData!.isNotEmpty
        ? '${_imageData!.length}_${_imageData!.substring(0, _imageData!.length > 50 ? 50 : _imageData!.length).hashCode}'
        : 'null';
    final uniqueKey = 'pm_img_${_currentItem['pm_check_list_site_resp_id']}_$imageDataHash';
    
    Logger.infoLog('[PM] 🖼️ Using unique key: $uniqueKey');
    print('[PM] 🖼️ Using unique key: $uniqueKey');
    Logger.infoLog('[PM] 🖼️ imageDataHash: $imageDataHash');
    print('[PM] 🖼️ imageDataHash: $imageDataHash');
    Logger.infoLog('[PM] 🖼️ _imageData is: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    print('[PM] 🖼️ _imageData is: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    
    // CRITICAL: Pass _imageData directly to externalImageUrl
    // The key will force a rebuild, but we also need to ensure the prop is passed correctly
    Logger.infoLog('[PM] 🖼️ About to create ImageUploadField with externalImageUrl: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    print('[PM] 🖼️ About to create ImageUploadField with externalImageUrl: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    if (_imageData != null && _imageData!.isNotEmpty) {
      Logger.infoLog('[PM] 🖼️ externalImageUrl preview (first 100 chars): ${_imageData!.substring(0, _imageData!.length > 100 ? 100 : _imageData!.length)}');
      print('[PM] 🖼️ externalImageUrl preview (first 100 chars): ${_imageData!.substring(0, _imageData!.length > 100 ? 100 : _imageData!.length)}');
    }
    
    // Create a StatefulBuilder to ensure the widget rebuilds when _imageData changes
    // Use a more aggressive key that includes actual data content to force rebuild
    final String finalImageData = _imageData ?? '';
    return ImageUploadField(
      key: ValueKey('${uniqueKey}_${finalImageData.length > 0 ? finalImageData.substring(0, finalImageData.length > 20 ? 20 : finalImageData.length).hashCode : 0}'),
      placeholder: 'Upload Photos',
      isRequired: _isFieldRequired(),
      externalImageUrl: _imageData,
      onImageSelected: (File? file) async {
        if (file != null) {
          try {
            final apiService = AppConfig.of(context).apiService;
            final imageUploadService = ImageUploadService(
              apiService: apiService,
            );

            final imageData = await file.readAsBytes();
            final photoId = await imageUploadService.uploadImage(
              base64Encode(imageData),
              ActivityTypeEnum.preventiveMaintenance,
              false,
              _currentItem['site_audit_sch_id']?.toString() ?? '',
            );

            if (photoId.isNotEmpty) {
              setState(() {
                // Replace existing images with the new one
                _addImageToResponseImages(photoId, replaceExisting: true);
                _imageData = 'data:image/jpeg;base64,${base64Encode(imageData)}';
              });

              _notifyValueChanged();

              if (mounted) {
                try {
                  Toastbar.showSuccessToastbar('Image uploaded successfully', context);
                } catch (err) {
                  Logger.errorLog('Error showing success toast: $err');
                }
              }
            }
          } catch (e) {
            if (mounted) {
              try {
                Toastbar.showErrorToastbar('Error uploading image', context);
              } catch (err) {
                Logger.errorLog('Error showing error toast: $err');
              }
            }
          }
        }
      },
    );
  }

  Widget _buildRemarksField() {
    return CustomRemarksField(
      hintText: 'Remarks',
      controller: _remarksController,
      isRequired: false, // REMARKS fields are always optional
    );
  }

  Widget _buildFieldByType(List<String> respTypesArr) {
    Logger.infoLog('[PM] 🔧 _buildFieldByType called with respTypesArr: $respTypesArr');
    print('[PM] 🔧 _buildFieldByType called with respTypesArr: $respTypesArr');
    final respTypes = respTypesArr.first.split(",");
    Logger.infoLog('[PM] 🔧 respTypes after split: $respTypes');
    print('[PM] 🔧 respTypes after split: $respTypes');
    Logger.infoLog('[PM] 🔧 _imageData in _buildFieldByType: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    print('[PM] 🔧 _imageData in _buildFieldByType: ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    // Handle combined types like DROPDOWN,IMG
    if (respTypes.contains('DROPDOWN') && respTypes.contains('IMG')) {
      Logger.infoLog('[PM] 🔧 Building DROPDOWN+IMG field');
      print('[PM] 🔧 Building DROPDOWN+IMG field');
      return Column(
        children: [
          _buildDropdownField(),

          if (_selectedDropdownValue != 'Not Applicable') ...[
            const SizedBox(height: 12),
            _buildImageField(),
          ],
        ],
      );
    } else if (respTypes.contains('RADIO') && respTypes.contains('IMG')) {
      Logger.infoLog('[PM] 🔧 Building RADIO+IMG field');
      print('[PM] 🔧 Building RADIO+IMG field');
      return Column(
        children: [
          _buildRadioField(),
          const SizedBox(height: 12),
          _buildImageField(),
        ],
      );
    } else if (respTypes.contains('TEXT') && respTypes.contains('IMG')) {
      return Column(
        children: [
          _buildTextField(),
          const SizedBox(height: 12),
          _buildImageField(),
        ],
      );
    } else if (respTypes.contains('NUMERIC') && respTypes.contains('IMG')) {
      return Column(
        children: [
          _buildNumericField(),
          const SizedBox(height: 12),
          _buildImageField(),
        ],
      );
    } else if (respTypes.contains('DROPDOWN')) {
      return _buildDropdownField();
    } else if (respTypes.contains('RADIO')) {
      return _buildRadioField();
    } else if (respTypes.contains('TEXT')) {
      return _buildTextField();
    } else if (respTypes.contains('NUMERIC')) {
      return _buildNumericField();
    } else if (respTypes.contains('IMG')) {
      Logger.infoLog('[PM] 🔧 Building IMG-only field');
      print('[PM] 🔧 Building IMG-only field');
      return _buildImageField();
    } else {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.colorF5F5F5,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderColorE0E0E0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'Unknown field type: ${respTypes}',
          style: const TextStyle(
            color: AppColors.white,
            fontFamily: fontFamilyMontserrat,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Logger.infoLog('[PM] 🔨 build() called for pm_check_list_site_resp_id: ${_currentItem['pm_check_list_site_resp_id']}');
    print('[PM] 🔨 build() called for pm_check_list_site_resp_id: ${_currentItem['pm_check_list_site_resp_id']}');
    Logger.infoLog('[PM] 🔨 _imageData in build(): ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    print('[PM] 🔨 _imageData in build(): ${_imageData != null ? "NOT NULL (${_imageData!.length} chars)" : "NULL"}');
    
    final isReadonlyFromList = widget.readonlyFields.contains(
      _currentItem['checklist_desc']?.toString(),
    );
    final isReadonlyFromItem = _currentItem['is_readonly'] == true;
    final isReadonly = isReadonlyFromList || isReadonlyFromItem;
    final respTypeList = _currentItem['resp_type'];
    final checklistDesc = _currentItem['checklist_desc']?.toString() ?? '';

    // Handle resp_type as array or string
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = [respTypeList];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: checklistDesc,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
                // Only show red asterisk if field is required
                if (_isFieldRequired())
                  const TextSpan(
                    text: " *",
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Field based on resp_type
          if (isReadonly)
            CustomFormField(
              initialValue: _currentItem['resp']?.toString() ?? 'N/A',
              isRequired: true,
              isEditable: false,
              inputType: respTypes.contains('NUMERIC') ? InputType.number : null,
              hintText: respTypes.contains('NUMERIC') ? 'Enter Number' : null,
            )
          else if (checklistDesc.toLowerCase().contains(
            'rectification remarks',
          ))
            _buildRemarksField()
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldByType(respTypes),
                // Render dependent elements (pass !isReadonly as isEditable)
                ..._buildDependentElements(!isReadonly),
              ],
            ),
        ],
      ),
    );
  }

  /// Get current main field response value for dependent elements visibility
  String? _getCurrentMainResponse() {
    final respTypeList = _currentItem['resp_type'];
    List<String> respTypes = [];
    if (respTypeList is List) {
      respTypes = respTypeList.map((e) => e.toString()).toList();
    } else if (respTypeList is String) {
      respTypes = respTypeList.split(",");
    }
    
    if (respTypes.contains('RADIO')) {
      return _selectedRadioValue;
    } else if (respTypes.contains('DROPDOWN')) {
      return _selectedDropdownValue;
    } else if (respTypes.contains('TEXT') || respTypes.contains('NUMERIC')) {
      return _textController.text;
    }
    
    return null;
  }

  /// Build dependent elements widgets
  List<Widget> _buildDependentElements(bool isEditable) {
    final dependentElements = parseDependentElements(_currentItem);
    if (dependentElements == null || dependentElements.isEmpty) {
      return [];
    }
    
    final currentMainResponse = _getCurrentMainResponse();
    List<Widget> widgets = [];
    
    // Count visible elements first
    int visibleCount = 0;
    for (int index = 0; index < dependentElements.length; index++) {
      final element = dependentElements[index];
      final shouldShow = shouldDependentElementBeVisible(element, currentMainResponse);
      if (shouldShow) visibleCount++;
    }
    
    // Build widgets with flag indicating if they're in a group
    final isGrouped = visibleCount > 1;
    for (int index = 0; index < dependentElements.length; index++) {
      final element = dependentElements[index];
      final shouldShow = shouldDependentElementBeVisible(element, currentMainResponse);
      if (!shouldShow) continue;
      
      widgets.add(_buildDependentElement(element, isEditable, currentMainResponse, index, isGrouped: isGrouped));
    }
    
    // If there are multiple dependent elements, wrap them in a single container with light background
    if (widgets.length > 1) {
      return [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), // Very light transparent background
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(12.0),
          margin: const EdgeInsets.only(top: 12.0, bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widgets,
          ),
        ),
      ];
    }
    
    return widgets;
  }

  /// Build a single dependent element widget
  Widget _buildDependentElement(
    Map<String, dynamic> element,
    bool isEditable,
    String? parentResponse,
    int elementIndex, {
    bool isGrouped = false,
  }) {
    final respType = element['resp_type']?.toString() ?? '';
    final checklistDesc = element['checklist_desc']?.toString() ?? '';
    // REMARKS fields are always non-mandatory, regardless of mandatoryIfValue
    // Also check if checklist_desc contains "Remarks" (case-insensitive) - always non-mandatory
    final isRemarksField = respType == 'REMARKS' || 
                          (checklistDesc.toLowerCase().contains('remarks'));
    // If mandatoryIfValue is not present (null), default to false (not mandatory)
    final mandatoryIfValue = element['mandatoryIfValue'];
    final isMandatory = isRemarksField || mandatoryIfValue == null
        ? false 
        : isDependentElementMandatory(element, parentResponse);
    // Include index to make key unique when multiple elements have same resp_type and checklist_desc
    final elementKey = '${respType}_${checklistDesc}_$elementIndex';
    final shouldHighlight = _highlightedDependentFields.contains(elementKey);
    
    if (respType == 'IMG') {
      // Check if image already exists (from server or newly uploaded)
      final imageId = _dependentImageIds[elementKey];
      final imageData = _dependentImageData[elementKey];
      final hasUploadedImage = (imageId != null && imageId.isNotEmpty) || 
                              (imageData != null && imageData.isNotEmpty);
      final responseImages = _currentItem['response_images'] ?? _currentItem['responseImages'];
      final hasServerImage = responseImages != null && 
                             responseImages is List && 
                             responseImages.isNotEmpty;
      final hasExistingImage = hasUploadedImage || hasServerImage;
      
      Logger.infoLog('[PM] 🎨 Building IMG element: $elementKey');
      Logger.infoLog('[PM] 🎨 hasUploadedImage: $hasUploadedImage (imageId: $imageId, imageData: ${imageData != null ? "exists" : "null"})');
      Logger.infoLog('[PM] 🎨 hasServerImage: $hasServerImage');
      Logger.infoLog('[PM] 🎨 hasExistingImage: $hasExistingImage');
      Logger.infoLog('[PM] 🎨 isMandatory: $isMandatory');
      Logger.infoLog('[PM] 🎨 shouldShowAsRequired: ${isMandatory && !hasExistingImage}');
      print('[PM] 🎨 Building IMG element: $elementKey');
      print('[PM] 🎨 hasExistingImage: $hasExistingImage, shouldShowAsRequired: ${isMandatory && !hasExistingImage}');
      
      // Show red asterisk when mandatory (regardless of whether image exists)
      // isRequired flag is used for validation, asterisk is shown when isMandatory is true
      final shouldShowAsRequired = isMandatory && !hasExistingImage;
      
      // Reduce padding when grouped in a container
      final padding = isGrouped 
          ? const EdgeInsets.only(top: 8.0, bottom: 8.0)
          : const EdgeInsets.only(top: 12.0, bottom: 16.0);
      
      return Padding(
        padding: padding,
        child: Container(
          decoration: shouldHighlight
              ? BoxDecoration(
                  border: Border.all(color: AppColors.errorColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.errorColor.withOpacity(0.1),
                )
              : null,
          padding: shouldHighlight ? const EdgeInsets.all(8.0) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    checklistDesc,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: shouldHighlight ? AppColors.errorColor : Colors.white,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                  if (isMandatory)
                    const Text(
                      ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ImageUploadField(
                key: ValueKey('${_currentItem['pm_check_list_site_resp_id']}_${elementKey}_image'),
                placeholder: checklistDesc,
                isRequired: shouldShowAsRequired,
                onImageSelected: isEditable
                    ? (File? file) {
                        if (file != null) {
                          _uploadDependentImage(elementKey, file);
                          // Clear highlight when image is added
                          _clearDependentFieldHighlight(elementKey);
                        } else {
                          setState(() {
                            _dependentImageIds[elementKey] = null;
                            _dependentImageFiles[elementKey] = null;
                            _dependentImageData[elementKey] = null;
                            // Also clear response_images if image is removed
                            _currentItem['response_images'] = [];
                            _currentItem['responseImages'] = [];
                            _notifyValueChanged();
                          });
                        }
                      }
                    : (File? file) {},
                externalImageUrl: _dependentImageData[elementKey],
                isDisabled: !isEditable,
              ),
            ],
          ),
        ),
      );
    } else if (respType == 'REMARKS' || respType == 'TEXT') {
      // Get or create controller for this dependent element
      if (!_dependentControllers.containsKey(elementKey)) {
        _dependentControllers[elementKey] = TextEditingController(
          text: respType == 'REMARKS'
              ? (_dependentRemarks[elementKey] ?? '')
              : (_dependentTextValues[elementKey] ?? ''),
        );
        _dependentControllers[elementKey]!.addListener(() {
          final value = _dependentControllers[elementKey]?.text ?? '';
          if (respType == 'REMARKS') {
            _dependentRemarks[elementKey] = value;
          } else {
            _dependentTextValues[elementKey] = value;
          }
          // Clear highlight when text is entered
          if (value.isNotEmpty) {
            _clearDependentFieldHighlight(elementKey);
          }
          _notifyValueChanged();
        });
      }
      
      // Reduce padding when grouped in a container
      final padding = isGrouped 
          ? const EdgeInsets.only(top: 8.0, bottom: 8.0)
          : const EdgeInsets.only(top: 12.0, bottom: 16.0);
      
      return Padding(
        padding: padding,
        child: Container(
          decoration: shouldHighlight
              ? BoxDecoration(
                  border: Border.all(color: AppColors.errorColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.errorColor.withOpacity(0.1),
                )
              : null,
          padding: shouldHighlight ? const EdgeInsets.all(8.0) : null,
          child: CustomRemarksField(
            label: checklistDesc,
            hintText: "Enter ${checklistDesc.toLowerCase()}",
            controller: _dependentControllers[elementKey]!,
            isDisabled: !isEditable,
            isRequired: isMandatory, // Show red asterisk when mandatoryIfValue condition is matched
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  /// Upload dependent image
  Future<void> _uploadDependentImage(String elementKey, File imageFile) async {
    try {
      setState(() {
        _dependentImageFiles[elementKey] = imageFile;
        _dependentImageData[elementKey] = null; // Clear previous image
      });

      // Get site data - we need siteId from current item
      final siteAuditSchId = _currentItem['site_audit_sch_id']?.toString() ?? '';
      
      if (siteAuditSchId.isEmpty) {
        if (mounted) {
          try {
            Toastbar.showErrorToastbar('Site ID not available', context);
          } catch (e) {
            // Context might be deactivated, ignore
          }
        }
        return;
      }

      // Use ImageUploadService like the main image field
      if (!mounted) return;
      final apiService = AppConfig.of(context).apiService;
      final imageUploadService = ImageUploadService(apiService: apiService);

      final imageData = await imageFile.readAsBytes();
      final photoId = await imageUploadService.uploadImage(
        base64Encode(imageData),
        ActivityTypeEnum.preventiveMaintenance,
        false,
        siteAuditSchId,
      );

      if (photoId.isNotEmpty) {
        // Extract index from elementKey (format: IMG_Add a photo_0, IMG_Add a photo_1, etc.)
        int? elementIndex;
        try {
          final parts = elementKey.split('_');
          if (parts.length >= 3) {
            elementIndex = int.tryParse(parts.last);
          }
        } catch (e) {
          Logger.errorLog('[PM] ❌ Error extracting index from elementKey $elementKey: $e');
          print('[PM] ❌ Error extracting index from elementKey $elementKey: $e');
        }
        
        setState(() {
          _dependentImageIds[elementKey] = photoId;
          // Store base64 image data for display
          _dependentImageData[elementKey] = 'data:image/jpeg;base64,${base64Encode(imageData)}';
          // Replace existing image at the specific index in responseImages array
          _addImageToResponseImages(photoId, replaceExisting: true, elementIndex: elementIndex);
          // Clear any validation highlight since image is now present
          _highlightedDependentFields.remove(elementKey);
        });
        
        _notifyValueChanged();
        
        // Show success message
        if (mounted) {
          try {
            Toastbar.showSuccessToastbar('Image uploaded successfully', context);
          } catch (e) {
            Logger.errorLog('Error showing success toast: $e');
          }
        }
      } else {
        Logger.errorLog('❌ Failed to get image ID after upload');
        if (mounted) {
          try {
            Toastbar.showErrorToastbar('Failed to upload photo', context);
          } catch (e) {
            Logger.errorLog('Error showing error toast: $e');
          }
        }
      }
    } catch (e) {
      Logger.errorLog('❌ Error uploading dependent image: $e');
      if (mounted) {
        setState(() {
          _dependentImageIds[elementKey] = null;
          _dependentImageData[elementKey] = null;
          _dependentImageFiles[elementKey] = null;
        });
      }
      if (mounted) {
        try {
          Toastbar.showErrorToastbar('Error uploading image', context);
        } catch (err) {
          Logger.errorLog('Error showing error toast: $err');
        }
      }
    }
  }

  /// Highlight a dependent field (called from parent validation)
  void highlightDependentField(String elementKey) {
    setState(() {
      _highlightedDependentFields.add(elementKey);
    });
  }
  
  /// Clear highlight for a dependent field
  void _clearDependentFieldHighlight(String elementKey) {
    setState(() {
      _highlightedDependentFields.remove(elementKey);
    });
  }

  /// Get dependent image ID by element key
  String? getDependentImageId(String elementKey) {
    return _dependentImageIds[elementKey];
  }
  
  /// Get dependent image data by element key
  String? getDependentImageData(String elementKey) {
    return _dependentImageData[elementKey];
  }
  
  /// Get current item data
  Map<String, dynamic> getCurrentItem() {
    return _currentItem;
  }
  
  /// Get dependent remarks by element key
  String? getDependentRemarks(String elementKey) {
    return _dependentRemarks[elementKey];
  }
  
  /// Get dependent text value by element key
  String? getDependentTextValue(String elementKey) {
    return _dependentTextValues[elementKey];
  }

  /// Validate dependent elements
  List<String> validateDependentElements(String? parentResponse) {
    final dependentElements = parseDependentElements(_currentItem);
    if (dependentElements == null || dependentElements.isEmpty) {
      return [];
    }
    
    List<String> errors = [];
    
    for (int index = 0; index < dependentElements.length; index++) {
      final element = dependentElements[index];
      final respType = element['resp_type']?.toString() ?? '';
      final checklistDesc = element['checklist_desc']?.toString() ?? '';
      // Include index to make key unique when multiple elements have same resp_type and checklist_desc
      final elementKey = '${respType}_${checklistDesc}_$index';
      
      // REMARKS fields are always non-mandatory, skip validation
      if (respType == 'REMARKS') continue;
      
      final isMandatory = isDependentElementMandatory(element, parentResponse);
      if (!isMandatory) continue;
      
      if (respType == 'IMG') {
        // Check if image exists in either:
        // 1. _dependentImageIds (newly uploaded ID)
        // 2. _dependentImageData (display data - newly uploaded or loaded from server)
        // 3. response_images (from server)
        final imageId = _dependentImageIds[elementKey];
        final imageData = _dependentImageData[elementKey];
        final hasUploadedImage = (imageId != null && imageId.isNotEmpty) || 
                                (imageData != null && imageData.isNotEmpty);
        
        // Check if image exists in response_images
        final responseImages = _currentItem['response_images'] ?? _currentItem['responseImages'];
        final hasServerImage = responseImages != null && 
                               responseImages is List && 
                               responseImages.isNotEmpty;
        
        Logger.infoLog('[PM] 🔍 Validation for IMG element: $elementKey');
        Logger.infoLog('[PM] 🔍 hasUploadedImage: $hasUploadedImage (imageId: $imageId, imageData: ${imageData != null ? "exists (${imageData.length} chars)" : "null"})');
        Logger.infoLog('[PM] 🔍 hasServerImage: $hasServerImage (response_images: $responseImages)');
        print('[PM] 🔍 Validation for IMG element: $elementKey');
        print('[PM] 🔍 hasUploadedImage: $hasUploadedImage');
        print('[PM] 🔍 hasServerImage: $hasServerImage');
        
        if (!hasUploadedImage && !hasServerImage) {
          errors.add('$checklistDesc is required');
          Logger.infoLog('[PM] ❌ Validation error: $checklistDesc is required');
          print('[PM] ❌ Validation error: $checklistDesc is required');
        } else {
          Logger.infoLog('[PM] ✅ Validation passed: Image exists');
          print('[PM] ✅ Validation passed: Image exists');
        }
      } else if (respType == 'TEXT') {
        // TEXT: Non-empty text required (REMARKS are optional)
        final value = _dependentTextValues[elementKey];
        if (value == null || value.trim().isEmpty) {
          errors.add('$checklistDesc is required');
        }
      }
      // REMARKS fields are optional - no validation needed
    }
    
    return errors;
  }

  /// Get current values including dependent elements for form submission
  Map<String, dynamic> getCurrentValuesWithDependentElements() {
    final values = Map<String, dynamic>.from(_currentItem);
    
    // Add dependent elements data to response_details or remarks
    final dependentElements = parseDependentElements(_currentItem);
    if (dependentElements != null && dependentElements.isNotEmpty) {
      List<String> remarksList = [];
      
      for (final element in dependentElements) {
        final respType = element['resp_type']?.toString() ?? '';
        final checklistDesc = element['checklist_desc']?.toString() ?? '';
        final elementKey = '${respType}_${checklistDesc}';
        
        if (respType == 'IMG') {
          final imageId = _dependentImageIds[elementKey];
          // Store dependent image ID - could be added to response_details if needed
          values['dependent_${elementKey}_image_id'] = imageId;
        } else if (respType == 'REMARKS') {
          final remarks = _dependentRemarks[elementKey];
          if (remarks != null && remarks.trim().isNotEmpty) {
            remarksList.add(remarks.trim());
          }
        } else if (respType == 'TEXT') {
          final textValue = _dependentTextValues[elementKey];
          values['dependent_${elementKey}_text'] = textValue;
        }
      }
      
      // Add remarks to current item if any exist
      if (remarksList.isNotEmpty) {
        final existingRemarks = values['remarks']?.toString() ?? '';
        final combinedRemarks = existingRemarks.isNotEmpty
            ? '$existingRemarks; ${remarksList.join("; ")}'
            : remarksList.join("; ");
        values['remarks'] = combinedRemarks;
      }
    }
    
    return values;
  }
}
