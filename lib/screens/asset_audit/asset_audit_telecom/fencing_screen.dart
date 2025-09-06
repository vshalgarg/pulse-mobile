import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/asset_audit/asset_audit_telecom/dg_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import '../../../models/asset_audit_model.dart';
import '../../../utils/asset_audit_post_helper.dart';
import '../../../bloc/asset_audit_cubit.dart';
import '../../../bloc/asset_audit_state.dart';
import '../../../bloc/asset_audit_get_image_cubit.dart';
import '../../../repositories/image_repository.dart';
import '../../../app_config.dart';
import '../../../commonWidgets/base64_image_widget.dart';

import '../../../commonWidgets/asset_type_card.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_radio_options.dart';
import '../../../commonWidgets/custom_remark.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_strings.dart';

class FencingScreen extends StatefulWidget {
  final CategoryData? fencingData;
  final AssetAuditModel? assetAuditData;
  final bool showSuccessMessage;

  final List<Map<String, dynamic>>? extinguisherItems;
  final List<Map<String, dynamic>>? solarPlatesItems;
  final List<Map<String, dynamic>>? surveillanceItems;

  const FencingScreen({
    super.key,
    this.fencingData,
    this.assetAuditData,
    this.showSuccessMessage = false, // Default to false
    this.extinguisherItems,
    this.solarPlatesItems,
    this.surveillanceItems,
  });

  @override
  State<FencingScreen> createState() => _FencingScreenState();
}

class _FencingScreenState extends State<FencingScreen> with WidgetsBindingObserver {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController serialController = TextEditingController();
  String? selectedBoundaryAvailability;
  bool hasUnsavedChanges = false;
  bool showValidationErrors = false;
  int totalBoundaryItems = 6;
  int currentScannedItems = 0;
  String? uploadedPhotoPath;
  int? overallSitePhotoId; // Store the photoId from API for Overall Site
  
  // List to store saved boundary items
  List<Map<String, dynamic>> _savedBoundaryItems = [];
  
  // Getter with debugging
  List<Map<String, dynamic>> get savedBoundaryItems {
    print('=== Debug: Accessing savedBoundaryItems ===');
    print('Current count: ${_savedBoundaryItems.length}');
    return _savedBoundaryItems;
  }
  
  // Setter with debugging
  set savedBoundaryItems(List<Map<String, dynamic>> value) {
    print('=== Debug: Setting savedBoundaryItems ===');
    print('Old count: ${_savedBoundaryItems.length}');
    print('New count: ${value.length}');
    _savedBoundaryItems = value;
  }
  
  // Separate controllers for each section to avoid conflicts
  final boundaryRemarksController = TextEditingController();
  final generalRemarksController = TextEditingController();

  // AssetTypeCard field values for Boundary
  String? boundarySerialNumber;
  String? boundaryPhoto;
  int? boundaryPhotoId; // Store the photoId from API
  String? boundaryStatus;

  // Controllers for CustomInfoCard
  final TextEditingController boundarySerialController = TextEditingController();

  // Keys to force rebuild of CustomInfoCard widgets
  int boundaryCardKey = 0;
  
  // Flag to track if Fencing screen has posted data
  bool _hasPostedFencingData = false;
  
  // ===== IMAGE LOADING INFRASTRUCTURE =====
  late ImageRepository _imageService;
  Map<int, String> _imageCache = {};
  // ===== END IMAGE LOADING INFRASTRUCTURE =====
  
  // Focus node to detect when screen is focused
  late FocusNode _focusNode;



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when returning to the screen
    if (mounted && widget.fencingData != null) {
      print('=== Fencing Screen: didChangeDependencies - Refreshing data ===');
      _loadFencingData();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode = FocusNode();
    serialController.addListener(_onFormChanged);
    
    // Initialize image service
    _imageService = ImageRepository(AppConfig.of(context).apiProvider);
    
    print('=== Fencing Screen: initState ===');
    print('fencingData: ${widget.fencingData}');
    print('assetAuditData: ${widget.assetAuditData}');
    
    // Check if we have data to show, if not, skip this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasDataToShow()) {
        print('Fencing Screen: No data to show, skipping to DG screen');
        _navigateToDgScreen();
      } else {
        // Load Fencing data if available
        _loadFencingData();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    serialController.removeListener(_onFormChanged);
    serialController.dispose();
    boundaryRemarksController.dispose();
    generalRemarksController.dispose();
    boundarySerialController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      print('=== Fencing Screen: App resumed - Refreshing data ===');
      // Refresh data when app becomes visible
      if (widget.fencingData != null) {
        _loadFencingData();
      }
    }
  }

  /// Check if there is data to show on the screen
  bool _hasDataToShow() {
    if (widget.fencingData == null) {
      print('Fencing Screen: No fencing data available');
      return false;
    }
    
    print('=== Fencing Screen: _hasDataToShow Debug ===');
    print('fencingData type: ${widget.fencingData.runtimeType}');
    print('fencingData assets: ${widget.fencingData!.assets}');
    print('fencingData assets length: ${widget.fencingData!.assets?.length ?? 0}');
    print('fencingData subCategories: ${widget.fencingData!.subCategories}');
    print('fencingData subCategories length: ${widget.fencingData!.subCategories?.length ?? 0}');
    print('fencingData remarks: ${widget.fencingData!.remarks}');
    print('fencingData remarks length: ${widget.fencingData!.remarks.length}');
    
    // Check if we have any assets
    final hasAssets = widget.fencingData!.assets.isNotEmpty;
    
    // Check if we have any subcategories with data (especially Boundary)
    final hasSubCategories = widget.fencingData!.subCategories != null && 
        widget.fencingData!.subCategories!.values.any((items) => items.isNotEmpty);
    
    // Check specifically for Boundary data
    final hasBoundaryData = widget.fencingData!.subCategories != null && 
        widget.fencingData!.subCategories!.containsKey('Boundary') &&
        widget.fencingData!.subCategories!['Boundary']!.isNotEmpty;
    
    // Check if fencingData itself is a direct array (direct structure)
    final hasDirectArray = widget.fencingData!.assets.isEmpty && 
        widget.fencingData!.subCategories == null &&
        widget.fencingData!.remarks.isEmpty &&
        (widget.fencingData as dynamic) is List;
    
    // Check if we have any remarks
    final hasRemarks = widget.fencingData!.remarks.isNotEmpty;
    
    final hasData = hasAssets || hasSubCategories || hasRemarks || hasBoundaryData || hasDirectArray;
    
    print('Fencing Screen: Data availability check:');
    print('  - Assets: $hasAssets (${widget.fencingData!.assets.length})');
    print('  - Subcategories: $hasSubCategories');
    print('  - Boundary Data: $hasBoundaryData');
    print('  - Direct Array: $hasDirectArray');
    print('  - Remarks: $hasRemarks (${widget.fencingData!.remarks.length})');
    print('  - Has data to show: $hasData');
    
    return hasData;
  }

  void _navigateToDgScreen() {
    print('Fencing Screen: Navigating to DG screen');
    pushPage(context, DgScreen(
      dgData: widget.assetAuditData?.responseData.dg,
      assetAuditData: widget.assetAuditData,
      showSuccessMessage: false,
      extinguisherItems: widget.extinguisherItems ?? [],
      solarPlatesItems: widget.solarPlatesItems ?? [],
      surveillanceItems: widget.surveillanceItems ?? [],
      fencingItems: [],
    ));
  }

  void _loadFencingData() {
    if (widget.fencingData != null) {
              setState(() {
          print('=== Fencing Screen: Loading Boundary Data ===');
          print('fencingData type: ${widget.fencingData.runtimeType}');
          print('Before loading - savedBoundaryItems count: ${savedBoundaryItems.length}');
        
        // Load Boundary data from the correct location
        List<dynamic> boundaryAssets = [];
        List<dynamic> boundarySubCategories = [];
        
        // Check if fencingData itself is the Boundary array (direct structure)
        if (widget.fencingData!.assets.isEmpty && 
            widget.fencingData!.subCategories == null &&
            widget.fencingData!.remarks.isEmpty) {
          // This might be a direct array structure
          print('Fencing Screen: Detected direct array structure in _loadFencingData');
          print('FencingData runtime type: ${widget.fencingData.runtimeType}');
          
          try {
            // Check if the fencingData itself contains Boundary items
            final directItems = widget.fencingData as dynamic;
            print('Direct items type: ${directItems.runtimeType}');
            print('Direct items: $directItems');
            
            if (directItems is List) {
              boundaryAssets = directItems;
              print('Fencing Screen: Found ${boundaryAssets.length} Boundary items in direct array');
            } else {
              print('Fencing Screen: Direct items is not a List, it is: ${directItems.runtimeType}');
            }
          } catch (e) {
            print('Fencing Screen: Error accessing direct array: $e');
          }
        } else {
          // Standard structure
          boundaryAssets = widget.fencingData!.assets ?? [];
          boundarySubCategories = widget.fencingData!.subCategories?['Boundary'] ?? [];
        }
        
        print('boundaryAssets: $boundaryAssets');
        print('boundaryAssets length: ${boundaryAssets.length}');
        print('boundarySubCategories: $boundarySubCategories');
        print('boundarySubCategories length: ${boundarySubCategories.length}');
        
        // Count items from both sources
        int boundaryCount = 0;
        
        // Count from assets array
        if (boundaryAssets.isNotEmpty) {
          for (int i = 0; i < boundaryAssets.length; i++) {
            var item = boundaryAssets[i];
            print('Boundary Asset Item $i:');
            print('  - itemType: ${item.itemType}');
            print('  - recordType: ${item.recordType}');
            print('  - assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
            print('  - nexgenSerialNo: ${item.nexgenSerialNo}');
            print('  - mfgSerialNo: ${item.mfgSerialNo}');
            print('  - photoId: ${item.photoId}');
            print('  - assetStatus: ${item.assetStatus}');
            
            // Count items with item_type "Boundary" (this matches the API response)
            if (item.itemType == "Boundary") {
              boundaryCount++;
              print('  - This is a Fencing item (${item.itemType}) - counted');
            } else {
              print('  - This is not a Fencing item (${item.itemType}) - not counted');
            }
          }
        }
        
        // Count from subCategories array
        if (boundarySubCategories.isNotEmpty) {
          for (int i = 0; i < boundarySubCategories.length; i++) {
            var item = boundarySubCategories[i];
            print('Boundary SubCategory Item $i:');
            print('  - itemType: ${item.itemType}');
            print('  - recordType: ${item.recordType}');
            print('  - assetAuditSiteRespId: ${item.assetAuditSiteRespId}');
            print('  - photoId: ${item.photoId}');
            print('  - assetStatus: ${item.assetStatus}');
            
            // Count all items in Boundary subCategory
            boundaryCount++;
            print('  - This is a Fencing item from subCategories - counted');
          }
        }
        
        // Update total count based on Boundary items
        totalBoundaryItems = boundaryCount;
        print('Total Fencing items (Boundary): $totalBoundaryItems');
        
        // Also update currentScannedItems to reflect existing data
        currentScannedItems = boundaryCount;
        print('Updated currentScannedItems to: $currentScannedItems');
        
                  print('After loading - savedBoundaryItems count: ${savedBoundaryItems.length}');
          print('After loading - totalBoundaryItems: $totalBoundaryItems');
          print('After loading - currentScannedItems: $currentScannedItems');
          
          // Load saved items from API - this populates the savedBoundaryItems list
          _loadSavedItemsFromAPI();
          
          // Load images for saved items after they are loaded
          _loadImagesForSavedItems();
          
          // Debug: Check if items were loaded successfully
          print('=== Items loaded from API ===');
          print('savedBoundaryItems count: ${savedBoundaryItems.length}');
          print('totalBoundaryItems: $totalBoundaryItems');
          print('currentScannedItems: $currentScannedItems');
          
          // Force a rebuild to ensure UI updates
          if (mounted) {
            setState(() {});
            print('Forced UI rebuild after loading data');
          }

        // Load remarks and populate the CustomRemarksField
        final remarks = widget.fencingData!.remarks;
        print('boundaryRemarks: $remarks');
        print('boundaryRemarks length: ${remarks.length}');
        
        if (remarks.isNotEmpty) {
          // Process remarks and populate the CustomRemarksField
          for (int i = 0; i < remarks.length; i++) {
            var remark = remarks[i];
            print('Boundary Remark $i:');
            print('  - itemType: ${remark.itemType}');
            print('  - recordType: ${remark.recordType}');
            print('  - assetAuditSiteRespId: ${remark.assetAuditSiteRespId}');
            
            // Populate the CustomRemarksField with the first valid remark
            if (remark.itemTypeRemark != null &&
                remark.itemTypeRemark!.isNotEmpty) {
              generalRemarksController.text = remark.itemTypeRemark!;
              print('Fencing Screen: Loaded remark from API: ${remark.itemTypeRemark}');
              break; // Use the first valid remark
            }
          }
        } else {
          print('No Boundary remarks found');
        }
        
        print('=== Fencing Screen: Data Summary ===');
        print('Total expected Boundary items: $totalBoundaryItems');
        print('Total remarks: ${remarks.length}');
        print('==========================================');
        
        // Check if we have any data to show
        if (!_hasDataToShow()) {
          print('Fencing Screen: No data available, will show "No Data" message');
        }
      });
    } else {
      print('Fencing Screen: No fencingData available');
    }
  }

  /// Load saved items from API - only items with complete data (serial, photo, status)
  void _loadSavedItemsFromAPI() {
    if (widget.fencingData == null) {
      print('Fencing Screen: No fencing data available');
      return;
    }

    print('Fencing Screen: Loading saved items from API...');
    
    setState(() {
      // Clear existing saved items to avoid duplicates
      savedBoundaryItems.clear();
      currentScannedItems = 0;

      // Load Boundary assets from the correct location in API response
      // According to API structure: responseData["Boundary"] is a direct array
      List<dynamic> boundaryAssets = [];
      
      // Debug: Check the actual structure of fencingData
      print('=== Fencing Screen: Data Structure Debug ===');
      print('fencingData type: ${widget.fencingData.runtimeType}');
      print('fencingData keys: ${widget.fencingData!.subCategories?.keys.toList()}');
      print('fencingData assets length: ${widget.fencingData!.assets.length}');
      print('fencingData subCategories length: ${widget.fencingData!.subCategories?.length ?? 0}');
      
      // Check if fencingData itself is the Boundary array (direct structure)
      if (widget.fencingData!.assets.isEmpty && 
          widget.fencingData!.subCategories == null &&
          widget.fencingData!.remarks.isEmpty) {
        // This might be a direct array structure
        print('Fencing Screen: Detected direct array structure');
        print('FencingData runtime type: ${widget.fencingData.runtimeType}');
        
        // Try to access the data directly
        try {
          // Check if the fencingData itself contains Boundary items
          final directItems = widget.fencingData as dynamic;
          print('Direct items type: ${directItems.runtimeType}');
          print('Direct items: $directItems');
          
          if (directItems is List) {
            boundaryAssets = directItems;
            print('Fencing Screen: Found ${boundaryAssets.length} Boundary items in direct array');
          } else {
            print('Fencing Screen: Direct items is not a List, it is: ${directItems.runtimeType}');
          }
        } catch (e) {
          print('Fencing Screen: Error accessing direct array: $e');
        }
      }
      
      // If no direct array found, try the standard structure
      if (boundaryAssets.isEmpty) {
        // First try to get from the direct Boundary array in responseData
        if (widget.fencingData!.subCategories != null && 
            widget.fencingData!.subCategories!.containsKey('Boundary')) {
          boundaryAssets = widget.fencingData!.subCategories!['Boundary'] ?? [];
          print('Fencing Screen: Found ${boundaryAssets.length} Boundary items in subCategories["Boundary"]');
        } else {
          // Fallback: check if there are any assets with itemType == "Boundary"
          final allAssets = widget.fencingData!.assets ?? [];
          boundaryAssets = allAssets.where((item) => item.itemType == "Boundary").toList();
          print('Fencing Screen: Found ${boundaryAssets.length} Boundary items in assets array');
        }
      }
      
      print('==========================================');
      print('Fencing Screen: Total Boundary assets to process: ${boundaryAssets.length}');
      
      for (var item in boundaryAssets) {
        // For fencing items, we accept items with photo and status, even if serial is null
        if (item.photoId != null && item.assetStatus != null) {
          
          // Generate a meaningful identifier since serial numbers are null
          String identifier = 'Boundary_${item.assetAuditSiteRespId}_${item.photoId}';
          
          Map<String, dynamic> savedItem = {
            'serialNumber': identifier, // Use generated identifier instead of null serial
            'photo': null, // Will be populated when we fetch the actual image
            'photoId': item.photoId,
            'status': item.assetStatus ?? 'OK',
            'timestamp': DateTime.now(),
            'isQRCodeScanned': item.qrCodeScanned ?? false,
            'itemType': item.itemType ?? 'Boundary',
            'remarks': item.itemTypeRemark ?? 'Boundary Item',
            'assetStatus': item.assetStatus,
            'assetAuditSiteRespId': item.assetAuditSiteRespId,
            'capacity': item.capacity ?? 'N/A',
            
            // Full API response details
            'asset_audit_site_resp_id': item.assetAuditSiteRespId,
            'site_audit_sch_id': item.siteAuditSchId,
            'item_instance_id': item.itemInstanceId,
            'oem_name': item.oemName,
            'nexgen_serial_no': item.nexgenSerialNo,
            'mfg_serial_no': item.mfgSerialNo,
            'qr_code_scanned': item.qrCodeScanned ?? false,
            'qr_code_scanned_ts': item.qrCodeScannedTs,
            'image_name': item.imageName,
            'longitude': item.longitude,
            'latitude': item.latitude,
            'item_type_group': item.itemTypeGroup,
            'record_type': item.recordType,
            'item_type_remark': item.itemTypeRemark,
          };
          savedBoundaryItems.add(savedItem);
          currentScannedItems++;
          print('Fencing Screen: Added Boundary item: $identifier with photoId: ${item.photoId}');
        }
      }

      print('Fencing Screen: Loaded ${savedBoundaryItems.length} Boundary items');
      print('Fencing Screen: Current scanned items: $currentScannedItems');
      print('Fencing Screen: savedBoundaryItems content: $savedBoundaryItems');
      print('Fencing Screen: savedBoundaryItems length after setState: ${savedBoundaryItems.length}');
      print('Fencing Screen: Triggering rebuild...');
    });
  }



  /// Get asset audit site response ID from GET API response for a specific item type
  int _getAssetAuditSiteRespId(String itemType) {
    print('=== Fencing Screen: Getting AssetAuditSiteRespId for $itemType ===');
    
    if (widget.fencingData == null) {
      print('fencingData is null, returning default ID');
      return 0; // Default ID
    }
    
    print('fencingData is not null, searching for $itemType...');
    
    // First check in assets
    final boundaryAssets = widget.fencingData!.assets ?? [];
    if (boundaryAssets.isNotEmpty) {
      print('Found ${boundaryAssets.length} assets in CategoryData.assets');
              for (var asset in boundaryAssets) {
          print('Asset: ${asset.itemType} - recordType: ${asset.recordType} - ID: ${asset.assetAuditSiteRespId}');
          // Look for items with item_type "Boundary" since that's what the API returns
          if (asset.itemType == "Boundary") {
            print('Found Fencing item (${asset.itemType}) by itemType with ID: ${asset.assetAuditSiteRespId}');
            return asset.assetAuditSiteRespId ?? 0;
          }
        }
    } else {
      print('No assets found in CategoryData.assets');
    }
    
    // If not found in assets, check subcategories
    if (widget.fencingData!.subCategories != null) {
      print('Checking subcategories for $itemType...');
      for (var entry in widget.fencingData!.subCategories!.entries) {
        String key = entry.key;
        List<AssetItem> items = entry.value;
        print('Subcategory $key: ${items.length} items');
        for (var item in items) {
          print('Item in $key: ${item.itemType} - recordType: ${item.recordType} - ID: ${item.assetAuditSiteRespId}');
          // Look for items with item_type "Boundary" since that's what the API returns
          if (item.itemType == "Boundary") {
            print('Found Fencing item (${item.itemType}) in subcategory $key by itemType with ID: ${item.assetAuditSiteRespId}');
            return item.assetAuditSiteRespId ?? 0;
          }
        }
      }
    } else {
      print('No subcategories found');
    }
    
    // Try specific subcategory helper methods if they exist
    try {
      // Check if there are specific helper methods for Boundary
      if (itemType == 'Boundary') {
        // Try to find Boundary in the main assets or any available structure
        final allAssets = widget.fencingData!.assets ?? [];
        if (allAssets.isNotEmpty) {
                  // Look for the first item with item_type "Boundary"
        for (var asset in allAssets) {
          if (asset.itemType == "Boundary") {
            print('Found Fencing item (${asset.itemType}) by itemType in helper method with ID: ${asset.assetAuditSiteRespId}');
            return asset.assetAuditSiteRespId ?? 0;
          }
        }
        // If no Fencing items found, use the first available asset
        final firstAsset = allAssets.first;
        print('No Fencing items found, using first available asset ID: ${firstAsset.assetAuditSiteRespId}');
        return firstAsset.assetAuditSiteRespId ?? 0;
        }
      }
    } catch (e) {
      print('Error accessing helper methods: $e');
    }
    
    print('No $itemType found in any structure, returning default ID');
    return 0; // Default ID
  }

  /// Auto-save Boundary item when photo is uploaded
  void _autoSaveBoundaryItem() {
    print('=== Fencing Screen: Auto-saving Boundary item ===');
    
    // Check if we have the required data
    if (boundaryPhoto == null || boundaryPhoto!.isEmpty) {
      print('No photo available for auto-saving Boundary item');
      return;
    }
    
    // Check if serial number is entered
    String actualSerialNumber = boundarySerialController.text.isNotEmpty 
        ? boundarySerialController.text 
        : '';
    
    if (actualSerialNumber.isEmpty) {
      print('No serial number entered, cannot auto-save Boundary item');
      // Please enter a serial number before uploading photo
      return;
    }
    
    // Check if status is set
    if (boundaryStatus == null) {
      print('No status set, cannot auto-save Boundary item');
      // Please set the status before uploading photo
      return;
    }
    
    // Check if we've reached the maximum limit from backend
    if (savedBoundaryItems.length >= totalBoundaryItems) {
      print('Maximum limit reached for Boundary items (${savedBoundaryItems.length}/$totalBoundaryItems)');
      // Maximum limit reached! You can still manually save items using the Save button
      return;
    }
    
    print('Fencing Screen: Serial number from controller: "$actualSerialNumber"');
    print('Fencing Screen: Status: "$boundaryStatus"');
    
    // Create a map of current form data
    Map<String, dynamic> boundaryData = {
      'serialNumber': actualSerialNumber, // Use the actual serial number from controller
      'photo': boundaryPhoto,
      'photoId': boundaryPhotoId,
      'photoTakenTs': DateTime.now().toString(),
      'itemType': 'Boundary',
      'remarks': 'Fencing Item',
      'assetStatus': boundaryStatus!, // Status is guaranteed to be set at this point
      'assetAuditSiteRespId': _getAssetAuditSiteRespId('Boundary'),
      'timestamp': DateTime.now(),
      'isQRCodeScanned': false,
    };

    print('Auto-saving Boundary item: $boundaryData');
    print('Current savedBoundaryItems count: ${savedBoundaryItems.length}');

    // Add to saved boundary items list
    savedBoundaryItems.add(boundaryData);
    currentScannedItems++;

    print('After auto-saving - savedBoundaryItems count: ${savedBoundaryItems.length}');
    print('currentScannedItems: $currentScannedItems');

    // Clear form for next entry
    boundarySerialNumber = null;
    boundaryPhoto = null;
    boundaryStatus = null;
    boundaryPhotoId = null;

    // Clear the controller
    boundarySerialController.clear();

    // Force rebuild of the CustomInfoCard widget
    boundaryCardKey++;

    hasUnsavedChanges = false;
    showValidationErrors = false;
    
    // Show success message
    int remainingBoundaries = totalBoundaryItems - savedBoundaryItems.length;
    showCustomToast(
      context,
      'Fencing item auto-saved! ${remainingBoundaries > 0 ? '(${remainingBoundaries} remaining)' : '(All items added)'}',
    );
  }



  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges = selectedBoundaryAvailability != null || 
                          serialController.text.isNotEmpty ||
                          boundarySerialController.text.isNotEmpty ||
                          boundaryPhoto != null ||
                          boundaryStatus != null;

      if (showValidationErrors && 
          selectedBoundaryAvailability != null && 
          serialController.text.isNotEmpty &&
          boundarySerialController.text.isNotEmpty &&
          boundaryPhoto != null &&
          boundaryStatus != null) {
        showValidationErrors = false;
      }
    });
  }

  void _saveAndExit() async {
    Navigator.of(context).pop();
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (context) => SuccessDialog(
          ticketId: "UVORKJR00044",
          message: "Asset Audit for Site (ID: SITE-38974) has been recorded and saved.",
          onDone: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        ),
      );
    }
  }

  bool _isFormValid() {
    print('=== Fencing Screen: Form Validation ===');
    
    // Check if serial number is entered
    String? serialNumber = boundarySerialController.text.isNotEmpty ? boundarySerialController.text : null;
    print('Serial number: "$serialNumber"');
    if (serialNumber == null || serialNumber.isEmpty) {
      print('❌ Serial number validation failed');
      return false;
    } else {
      print('✅ Serial number validation passed');
    }

    // Check if photo is added
    String? photo = boundaryPhoto;
    print('Photo: $photo');
    if (photo == null || photo.isEmpty) {
      print('❌ Photo validation failed');
      return false;
    } else {
      print('✅ Photo validation passed');
    }

    // Check if status is set
    String? status = boundaryStatus;
    print('Status: $status');
    if (status == null) {
      print('❌ Status validation failed');
      return false;
    } else {
      print('✅ Status validation passed');
    }

    print('✅ All validations passed!');
    return true;
  }

  bool _validateForm() {
    setState(() {
      showValidationErrors = true;
    });

    print('=== Fencing Screen: Form Validation (_validateForm) ===');
    
    // Check if serial number is entered
    String? serialNumber = boundarySerialController.text.isNotEmpty ? boundarySerialController.text : null;
    print('Serial number: "$serialNumber"');
    if (serialNumber == null || serialNumber.isEmpty) {
      print('❌ Serial number validation failed');
      return false;
    } else {
      print('✅ Serial number validation passed');
    }

    // Check if photo is added
    String? photo = boundaryPhoto;
    print('Photo: $photo');
    if (photo == null || photo.isEmpty) {
      print('❌ Photo validation failed');
      return false;
    } else {
      print('✅ Photo validation passed');
    }

    // Check if status is set
    String? status = boundaryStatus;
    print('Status: $status');
    if (status == null) {
      print('❌ Status validation failed');
      return false;
    } else {
      print('✅ Status validation passed');
    }

    print('✅ All validations passed!');
    return true;
  }

  // Save current form data for Boundary
  void _saveBoundaryForm() {
    print('=== Fencing Screen: Manual Save Attempt ===');
    print('Current saved items: ${savedBoundaryItems.length}');
    print('Total allowed items: $totalBoundaryItems');
    
    // Allow manual saves even if auto-save limit is reached
    // This gives users control over their data
    if (savedBoundaryItems.length >= totalBoundaryItems) {
      print('Auto-save limit reached, but allowing manual save');
      // Auto-save limit reached, but manual saves are still allowed
    }

    if (_isFormValid()) {
      setState(() {
        // Get the actual serial number from the controller
        String actualSerialNumber = boundarySerialController.text.isNotEmpty 
            ? boundarySerialController.text 
            : 'Unknown';
            
        Map<String, dynamic> currentFormData = {
          'serialNumber': actualSerialNumber, // Use the actual serial number from controller
          'photo': boundaryPhoto,
          'photoId': boundaryPhotoId, // Include the photoId from API
          'photoTakenTs': DateTime.now().toString(),
          'itemType': 'Boundary',
          'remarks': 'Fencing Item',
          'assetStatus': boundaryStatus ?? "OK",
          'assetAuditSiteRespId': _getAssetAuditSiteRespId('Boundary'),
          'timestamp': DateTime.now(),
          'isQRCodeScanned': false, // Track if this was QR scanned or manual entry (false for manual entry)
        };

        print('Saving Fencing item: $currentFormData');
        print('Current savedBoundaryItems count: ${savedBoundaryItems.length}');

        savedBoundaryItems.add(currentFormData);
        currentScannedItems++;

        print('After saving - savedBoundaryItems count: ${savedBoundaryItems.length}');
        print('currentScannedItems: $currentScannedItems');

        // Clear form for next entry
        boundarySerialNumber = null;
        boundaryPhoto = null;
        boundaryPhotoId = null;
        boundaryStatus = null;
        boundarySerialController.clear();
        boundaryCardKey++;

        hasUnsavedChanges = false;
        showValidationErrors = false;
      });

      // Fencing item saved successfully
    } else {
      print('Form validation failed - cannot save fencing item');
      // Please fill all required fields before saving
    }
  }

  // Check if all items are scanned
  bool _isAllItemsScanned() {
    return savedBoundaryItems.length >= totalBoundaryItems;
  }

  // Check if user can proceed to next screen (minimum 1 item required)
  bool _canProceedToNextScreen() {
    // If no data to show, always allow proceeding
    if (!_hasDataToShow()) {
      print('Fencing Screen: No data to show, allowing navigation');
      return true;
    }
    
    // Check if we have at least one item saved
    bool hasBoundaryItems = savedBoundaryItems.isNotEmpty;
    
    print('Fencing Screen: Checking if can proceed to next screen...');
    print('Fencing Screen: savedBoundaryItems: ${savedBoundaryItems.length}');
    print('Fencing Screen: Total allowed items: $totalBoundaryItems');
    print('Fencing Screen: Can proceed: $hasBoundaryItems');
    
    if (!hasBoundaryItems) {
      print('Fencing Screen: No items saved yet. User needs to:');
      print('  1. Enter a Boundary/Perimeter identifier');
      print('  2. Upload a photo');
      print('  3. Set the status');
      print('  4. Click the Save button');
      print('  Note: Auto-save limit may be reached, but manual saves are always allowed');
    } else {
      print('Fencing Screen: Has saved items, allowing navigation');
      print('Fencing Screen: Items saved: ${savedBoundaryItems.map((item) => '${item['serialNumber']} (${item['assetStatus']})').join(', ')}');
    }
    
    return hasBoundaryItems;
  }

  /// Validate serial number against API data
  /// Returns true if valid, false if invalid
  bool _validateSerialNumber(String serialNumber, bool isQRCodeScanned) {
    print('=== Fencing Screen: Validating Serial Number ===');
    print('Serial number to validate: $serialNumber');
    
    if (widget.fencingData == null) {
      print('fencingData is null, validation failed');
      return false;
    }
    
    // For Fencing items (Boundary + Overall Site), since they don't have serial numbers in the API,
    // users can enter any serial number they want - this is by design
    print('Fencing items (Boundary + Overall Site) don\'t have serial numbers in API, allowing any manual entry');
    
    if (isQRCodeScanned) {
      // For QR code scans, we can't validate against API since serial numbers are null
      // QR Code scanning not supported for Fencing items. Please use manual entry
      return false;
    } else {
      // For manual entries, allow any serial number since API doesn't have them
      // This is the intended behavior for fencing items
              // Manual entry accepted for Fencing item
      return true;
    }
  }

  int? _getRemarksAssetAuditSiteRespId() {
    print('=== Fencing Screen: Getting Remarks AssetAuditSiteRespId ===');
    
    if (widget.fencingData == null) {
      print('fencingData is null, cannot get remarks ID');
      return null;
    }
    
    // Check if there are remarks in the backend data
    final remarks = widget.fencingData!.remarks;
    if (remarks.isNotEmpty) {
      print('Found ${remarks.length} remarks in backend data');
      
      // First try to find a general remarks entry (Boundary category is usually the main one)
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null && 
            remark.assetAuditSiteRespId > 0 && 
            remark.itemType == 'Boundary') {
          print('Using Boundary remarks ID: ${remark.assetAuditSiteRespId}');
          return remark.assetAuditSiteRespId;
        }
      }
      
      // Fallback: find any remarks entry with a valid ID
      for (var remark in remarks) {
        if (remark.assetAuditSiteRespId != null && remark.assetAuditSiteRespId > 0) {
          print('Using fallback remarks ID: ${remark.assetAuditSiteRespId} for itemType: ${remark.itemType}');
          return remark.assetAuditSiteRespId;
        }
      }
    }
    
    print('No valid remarks ID found in backend data');
    return null;
  }

  /// Post current screen data to API before navigating to next screen
  Future<bool> _postCurrentScreenData() async {
    if (widget.assetAuditData == null) {
      print('Fencing Screen: No asset audit data available for posting');
      return false;
    }

    try {
      print('Fencing Screen: Starting to prepare data for posting...');
      print('Fencing Screen: savedBoundaryItems count: ${savedBoundaryItems.length}');
      
      // Debug: Print each saved item
      for (int i = 0; i < savedBoundaryItems.length; i++) {
        var item = savedBoundaryItems[i];
        print('Fencing Screen: Saved item $i:');
        print('  - serialNumber: ${item['serialNumber']}');
        print('  - photo: ${item['photo']}');
        print('  - photoId: ${item['photoId']}');
        print('  - itemType: ${item['itemType']}');
        print('  - remarks: ${item['remarks']}');
        print('  - assetStatus: ${item['assetStatus']}');
        print('  - assetAuditSiteRespId: ${item['assetAuditSiteRespId']}');
      }
      
      // Create a list to hold all items to post
      List<Map<String, dynamic>> allItemsToPost = [];

      // Enhance saved items with additional data
      final enhancedItems = AssetAuditPostHelper.enhanceSavedItems(
        savedItems: savedBoundaryItems,
        screenName: 'Boundary',
      );
      allItemsToPost.addAll(enhancedItems);

      // Add user's general remarks if entered
      if (generalRemarksController.text.isNotEmpty) {
        // Find the appropriate remarks entry from backend data
        int? remarksAssetAuditSiteRespId = _getRemarksAssetAuditSiteRespId();
        
        if (remarksAssetAuditSiteRespId != null) {
          Map<String, dynamic> remarksData = {
            'itemType': 'Boundary', // Use the main screen category
            'remarks': generalRemarksController.text, // User's actual remarks text
            'recordType': 'Remarks',
            'timestamp': DateTime.now(),
            'assetAuditSiteRespId': remarksAssetAuditSiteRespId, // Use backend remarks ID
            'status': 'OK', // Default status for remarks
            'serialNumber': 'REMARKS', // Default serial for remarks
            'photo': null, // No photo file for remarks
            'photoTakenTs': DateTime.now().toString(), // Current timestamp
            'isQRCodeScanned': false, // Remarks are not QR scanned
            'localQrCodeScannedTs': DateTime.now().toString(), // Local timestamp for QR scan
            'localCreatedDt': DateTime.now().toString(), // Local creation timestamp
            'localModifiedDt': DateTime.now().toString(), // Local modification timestamp
          };
          allItemsToPost.add(remarksData);
          print('Fencing Screen: Added user remarks to post with ID: $remarksAssetAuditSiteRespId, text: "${generalRemarksController.text}"');
        } else {
          print('Fencing Screen: Could not find remarks ID from backend data');
        }
      }

      if (allItemsToPost.isEmpty) {
        print('Fencing Screen: No items to post');
        return false;
      }

      // Convert to POST request format
      final requests = await AssetAuditPostHelper.convertSavedItemsToPostRequest(
        savedItems: allItemsToPost,
        assetAuditData: widget.assetAuditData!,
        itemType: 'Boundary',
        itemTypeId: AssetAuditPostHelper.getItemTypeId('Boundary'),
        screenName: 'Boundary',
        context: context,
      );

      if (requests.isEmpty) {
        print('Fencing Screen: Failed to create POST requests');
        return false;
      }

      // Set flag BEFORE making the API call to ensure it's set when success state is received
      setState(() {
        _hasPostedFencingData = true;
      });
      print('Fencing Screen: Set _hasPostedFencingData flag to true BEFORE API call');
      print('Fencing Screen: Flag value after setting: $_hasPostedFencingData');

      // Use the existing cubit to post data
      print('Fencing Screen: Posting ${requests.length} items to API...');
      context.read<AssetAuditCubit>().postAssetAuditData(requests: requests);
      
      // Return true to indicate data is being posted
      return true;
    } catch (e) {
      print('Fencing Screen: Error preparing data: $e');
      return false;
    }
  }

  // Format serial number to show first 5 digits + ...
  String _formatSerialNumber(String serialNumber) {
    if (serialNumber.length <= 7) {
      return serialNumber;
    }
    return "${serialNumber.substring(0, 5)}...";
  }

  // Edit a specific Boundary item from the saved list
  void _editItem(Map<String, dynamic> item) {
    setState(() {
      boundarySerialNumber = item["serialNumber"];
      boundaryPhoto = item["photo"];
      boundaryStatus = item["status"];
      boundarySerialController.text = item["serialNumber"] ?? "";
      savedBoundaryItems.remove(item);
      currentScannedItems--;
      boundaryCardKey++;
      hasUnsavedChanges = true;
    });

          // Boundary item loaded for editing. Make changes and save again
  }

  /// Edit a saved item based on its type
  void _editSavedItem(Map<String, dynamic> item, String itemType) {
    // Debug: Print the item data to see what's actually stored
    print('=== EDITING $itemType ITEM ===');
    print('Item data: $item');
    print('Serial Number: ${item['serialNumber']}');
    print('Status: ${item['status']}');
    print('Photo: ${item['photo']}');
    print('Photo ID: ${item['photoId']}');
    print('=============================');
    
    setState(() {
      // Populate the form fields with the item's data for editing
      switch (itemType) {
        case 'boundary':
          // Populate boundary form with item data
          boundarySerialController.text = item['serialNumber'] ?? '';
          boundarySerialNumber = item['serialNumber'] ?? ''; // Also set the variable
          boundaryStatus = item['status'] ?? 'OK';
          boundaryPhotoId = item['photoId'];
          boundaryPhoto = item['photo'];
          
          // Debug: Print what we're setting
          print('Setting boundary form:');
          print('  - Controller text: ${boundarySerialController.text}');
          print('  - Serial Number: $boundarySerialNumber');
          print('  - Status: $boundaryStatus');
          print('  - Photo: $boundaryPhoto');
          print('  - Photo ID: $boundaryPhotoId');
          
          // Remove the item from saved list since it's now in the form for editing
          savedBoundaryItems.remove(item);
          currentScannedItems--;
          break;
      }
      
      // Mark that there are unsaved changes
      hasUnsavedChanges = true;
      
      // Show a message to the user
      showCustomToast(
        context,
        'Item loaded for editing. Make your changes and save.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus && mounted) {
          print('=== Fencing Screen: Gained focus - Refreshing data ===');
          // Refresh data when screen gains focus
          if (widget.fencingData != null) {
            _loadFencingData();
          }
        }
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<AssetAuditCubit, AssetAuditState>(
            listener: (context, state) {
              print('Fencing Screen: BlocListener received state: $state');
              print('Fencing Screen: State type: ${state.runtimeType}');
              
              if (state is AssetAuditPostSuccess) {
                print('Fencing Screen: AssetAuditPostSuccess received!');
                print('Fencing Screen: State details: $state');
                print('Fencing Screen: _hasPostedFencingData flag: $_hasPostedFencingData');
                
                // Check if this success state contains Fencing-related items
                bool isBoundaryData = false;
                print('Fencing Screen: Total responses received: ${state.responses.length}');
                for (var response in state.responses) {
                  print('Fencing Screen: Full response object: $response');
                  print('Fencing Screen: Checking response itemTypeRemark: ${response.itemTypeRemark}');
                  print('Fencing Screen: Checking response itemTypeId: ${response.itemTypeId}');
                  print('Fencing Screen: Checking response nexgenSerialNo: ${response.nexgenSerialNo}');
                  print('Fencing Screen: Checking response assetStatus: ${response.assetStatus}');
                  print('Fencing Screen: Checking response remarks: ${response.remarks}');
                  
                  // Primary check: itemTypeRemark contains Fencing-related text
                  if (response.itemTypeRemark != null && 
                      (response.itemTypeRemark!.contains('Boundary') || 
                       response.itemTypeRemark!.contains('Fencing') ||
                       response.itemTypeRemark!.contains('Perimeter'))) {
                    isBoundaryData = true;
                    print('Fencing Screen: Found Boundary-related item by itemTypeRemark: ${response.itemTypeRemark}');
                    break;
                  }
                  
                  // Fallback check: Check if this is a response to Fencing screen data by looking at the flag
                  if (_hasPostedFencingData) {
                    isBoundaryData = true;
                    print('Fencing Screen: Found Boundary-related item by flag check (fallback)');
                    break;
                  }
                  
                  print('Fencing Screen: itemTypeRemark "${response.itemTypeRemark}" does not match Boundary patterns');
                }
                
                // Only process this success state if it contains Fencing screen data
                if (isBoundaryData) {
                  print('Fencing Screen: Confirmed this is Boundary screen data, proceeding with data refresh...');
                  
                  // Show success message
                  // Boundary data saved successfully

                  // Refresh data from API before navigating
                  print('Fencing Screen: Refreshing data from API...');
                  try {
                    // Trigger a refresh of the asset audit data
                    context.read<AssetAuditCubit>().getAssetAuditData(
                      siteType: "telecom",
                      auditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
                      siteAuditSchId: widget.assetAuditData?.pageHeader.first.siteAuditSchId.toString() ?? "0",
                    );
                     
                    // Wait for data to refresh, then navigate
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) {
                        print('Fencing Screen: Data refreshed, navigating to next screen...');
                        pushPage(context, DgScreen(
                          dgData: widget.assetAuditData?.responseData.dg,
                          assetAuditData: widget.assetAuditData,
                          showSuccessMessage: false, // Don't show success message when skipping fencing screen
                          extinguisherItems: widget.extinguisherItems ?? [],
                          solarPlatesItems: widget.solarPlatesItems ?? [],
                          surveillanceItems: widget.surveillanceItems ?? [],
                          fencingItems: [
                            ...savedBoundaryItems,
                          ],
                        ));
                         
                        // Reset the flag after successful navigation
                        setState(() {
                          _hasPostedFencingData = false;
                        });
                        print('Fencing Screen: Reset _hasPostedFencingData flag to false after navigation');
                      }
                    });
                  } catch (e) {
                    print('Fencing Screen: Error refreshing data: $e');
                    // Fallback: navigate anyway after delay
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) {
                        pushPage(context, DgScreen(
                          dgData: widget.assetAuditData?.responseData.dg,
                          assetAuditData: widget.assetAuditData,
                          showSuccessMessage: false,
                          extinguisherItems: widget.extinguisherItems ?? [],
                          solarPlatesItems: widget.solarPlatesItems ?? [],
                          surveillanceItems: widget.surveillanceItems ?? [],
                          fencingItems: [
                            ...savedBoundaryItems,
                          ],
                        ));
                        setState(() {
                          _hasPostedFencingData = false;
                        });
                        print('Fencing Screen: Reset _hasPostedFencingData flag to false after error');
                      }
                    });
                  }
                } else {
                  print('Fencing Screen: Success state received but not for Boundary screen data, ignoring...');
                  print('Fencing Screen: _hasPostedFencingData flag: $_hasPostedFencingData');
                }
              } else if (state is AssetAuditPostError) {
                // Only show error message if this error belongs to Fencing screen data
                if (_hasPostedFencingData) {
                  print('Fencing Screen: AssetAuditPostError received for Fencing data');
                  // Show error message and block navigation
                  // Failed to save Boundary data. Please try again
                  
                  // Reset the flag on error
                  setState(() {
                    _hasPostedFencingData = false;
                  });
                  print('Fencing Screen: Reset _hasPostedFencingData flag to false after error');
                } else {
                  print('Fencing Screen: AssetAuditPostError received but not for Fencing data, ignoring...');
                }
              }
            },
          ),
          BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
            listener: (context, state) {
              if (state is AssetAuditGetImageSuccess) {
                print('=== Fencing Screen: Image fetch success ===');
                print('Image data length: ${state.imageData.length}');
                
                // Find the item that corresponds to this image and update it
                final imgId = state.imageData.isNotEmpty ? '${state.imageData.hashCode}' : null; // Use hash as temporary ID
                
                if (imgId != null) {
                  // Update the item with the actual image data
                  for (int i = 0; i < savedBoundaryItems.length; i++) {
                    if (savedBoundaryItems[i]['photoId']?.toString() == imgId.toString()) {
                      setState(() {
                        savedBoundaryItems[i]['photo'] = 'data:image/jpeg;base64,${state.imageData}';
                        print('Updated item $i with image data');
                      });
                      break;
                    }
                  }
                }
              } else if (state is AssetAuditGetImageFailure) {
                print('=== Fencing Screen: Image fetch failed ===');
                print('Error: ${state.errorMessage}');
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
                  message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                  onSaveAndExit: () {
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
                      message: "Do you want to cancel the Asset Audit for Site (ID: SITE-38974) ?",
                      onSaveAndExit: () {
                        _saveAndExit();
                      },
                      onDiscard: () {
                        Navigator.pop(context);
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
                              bottom: MediaQuery.of(context).viewInsets.bottom + 120,
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
                                  if (_hasDataToShow()) ...[
                                    CustomOptionSelector(
                                      label: "Boundary/Fencing Available",
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
                                          selectedBoundaryAvailability = value;
                                          hasUnsavedChanges = true;
                                        });
                                      },
                                    ),
                                    getHeight(15),
                                    Text(
                                      "Instructions: Existing Boundary items are loaded from API. You can add new items or edit existing ones.",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white70,
                                        fontFamily: fontFamilyMontserrat,
                                      ),
                                    ),
                                    getHeight(8),
                                    CustomInfoCard(
                                      key: ValueKey(boundaryCardKey),
                                      serialLabel: "Boundary/Perimeter Identifier",
                                      photoLabel: "Add a Photo",
                                      statusLabel: "Status",
                                      buttonLabel: "Save",
                                      serialController: boundarySerialController,
                                      serialHintText: "Enter any identifier (e.g., Gate-1, Fence-A, etc.)",
                                      onPhotoTap: (photoPath) {
                                        setState(() {
                                          boundaryPhoto = photoPath;
                                          hasUnsavedChanges = true;
                                        });
                                      },
                                      onStatusChanged: (status) {
                                        setState(() {
                                          boundaryStatus = status ? "OK" : "Not OK";
                                          hasUnsavedChanges = true;
                                        });
                                      },
                                      onSerialChanged: (value) {
                                        setState(() {
                                          boundarySerialNumber = value;
                                          hasUnsavedChanges = true;
                                        });
                                      },
                                      onSave: () {
                                        if (_validateForm()) {
                                          _saveBoundaryForm();
                                        }
                                      },
                                      initialStatus: boundaryStatus == "OK" ? true : (boundaryStatus == "Not OK" ? false : null),
                                      initialPhotoPath: boundaryPhoto,
                                      isEditable: true,
                                      isStatusEditable: true,
                                      showSaveButton: true,
                                    ),
                                    getHeight(15),
                                    _buildBoundarySavedItemsList(),
                                    getHeight(15),
                                    CustomRemarksField(
                                      label: "Add Remarks",
                                      hintText: "Remarks",
                                      controller: generalRemarksController,
                                    ),
                                  ],
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
                                   text: "Surveillance",
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
                                   text: _hasDataToShow() ? "DG" : "Skip Fencing",
                                   isLeftArrow: false,
                                   backgroundColor: AppColors.buttonColorBg,
                                   textColor: AppColors.buttonColorSite,
                                   onPressed: () async {
                                     // If no data to show, just navigate to next screen
                                     if (!_hasDataToShow()) {
                                       pushPage(context, DgScreen(
                                         dgData: widget.assetAuditData?.responseData.dg,
                                         assetAuditData: widget.assetAuditData,
                                         showSuccessMessage: false,
                                         extinguisherItems: widget.extinguisherItems ?? [],
                                         solarPlatesItems: widget.solarPlatesItems ?? [],
                                         surveillanceItems: widget.surveillanceItems ?? [],
                                         fencingItems: [],
                                       ));
                                       return;
                                     }
                                      
                                     // Check if user has saved at least one item
                                     if (!_canProceedToNextScreen()) {
                                               // Please save at least 1 fencing item before proceeding
                                       return;
                                     }
                                      
                                     // Navigate to next screen with accumulated data
                                     pushPage(context, DgScreen(
                                       dgData: widget.assetAuditData?.responseData.dg,
                                       assetAuditData: widget.assetAuditData,
                                       showSuccessMessage: false,
                                       extinguisherItems: widget.extinguisherItems ?? [],
                                       solarPlatesItems: widget.solarPlatesItems ?? [],
                                       surveillanceItems: widget.surveillanceItems ?? [],
                                       fencingItems: [
                                         ...savedBoundaryItems,
                                       ],
                                     ));
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
       ),
     );
   }

  // Build Boundary saved items list
  Widget _buildBoundarySavedItemsList() {
    print('=== Debug: Building saved items list ===');
    print('savedBoundaryItems count: ${savedBoundaryItems.length}');
    print('savedBoundaryItems isEmpty: ${savedBoundaryItems.isEmpty}');
    if (savedBoundaryItems.isNotEmpty) {
      print('First item: ${savedBoundaryItems.first}');
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Identifier",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Scanned",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Photo",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Capacity",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Status",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    "Edit",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: fontFamilyMontserrat,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          getHeight(10),
          // Debug information
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                getWidth(8),
                Expanded(
                  child: Text(
                    'Saved Items: ${savedBoundaryItems.length} | Current Scanned: $currentScannedItems | Total Expected: $totalBoundaryItems',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (savedBoundaryItems.isNotEmpty) ...[
            // Debug: Log the items being built
            Builder(
              builder: (context) {
                print('=== Building Boundary Saved Items List ===');
                print('savedBoundaryItems count: ${savedBoundaryItems.length}');
                print('savedBoundaryItems: $savedBoundaryItems');
                return Container(); // Empty container for debugging
              },
            ),
            ...savedBoundaryItems
                .map(
                  (item) {
                    print('=== Building item: $item ===');
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: Text(
                                item['serialNumber'] ?? 'N/A',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontFamily: fontFamilyMontserrat,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: Icon(
                                item['isQRCodeScanned'] == true
                                    ? Icons.check
                                    : Icons.close,
                                color: item['isQRCodeScanned'] == true
                                    ? Colors.green
                                    : Colors.red,
                                size: 20,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: _buildPhotoColumn(item),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: Text(
                                item['capacity'] ?? 'N/A',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontFamily: fontFamilyMontserrat,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: Text(
                                item['status'] ?? 'N/A',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontFamily: fontFamilyMontserrat,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: IconButton(
                                onPressed: () =>
                                    _editSavedItem(item, 'boundary'),
                                icon: const Icon(
                                  Icons.edit,
                                  color: AppColors.blue,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                )
                .toList(),]
          else
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 16),
                  getWidth(8),
                  Expanded(
                    child: Text(
                      'No saved items found. Items will appear here after they are saved with complete data (serial, photo, status).',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],

      ),
    );
  }
  
  /// Load images for saved Boundary items
  void _loadImagesForSavedItems() {
    if (savedBoundaryItems.isEmpty) {
      print('Fencing Screen: No saved items to load images for');
      return;
    }
    
    print('Fencing Screen: Loading images for ${savedBoundaryItems.length} saved items...');
    
    // Collect all photo IDs from saved items
    final Set<int> photoIds = {};
    for (final item in savedBoundaryItems) {
      final photoId = item['photoId'];
      if (photoId != null && photoId.toString().isNotEmpty && photoId.toString() != "0") {
        photoIds.add(photoId);
        print('Fencing Screen: Found photoId: $photoId for item: ${item['serialNumber'] ?? 'No Serial'}');
      }
    }
    
    if (photoIds.isEmpty) {
      print('Fencing Screen: No photo IDs found to load images');
      return;
    }
    
    print('Fencing Screen: Loading ${photoIds.length} images...');
    
    try {
      // Fetch images from API
      _imageService.fetchImagesByIds(photoIds.toList()).then((imageMap) {
        // Update cache
        setState(() {
          _imageCache.addAll(imageMap);
        });
        
        print('Fencing Screen: Successfully loaded ${imageMap.length} images');
      }).catchError((e) {
        print('Fencing Screen: Error loading images: $e');
      });
    } catch (e) {
      print('Fencing Screen: Error in image loading: $e');
    }
  }

  /// Build photo column for saved items list
  Widget _buildPhotoColumn(Map<String, dynamic> item) {
    final photoId = item['photoId'];
    
    if (photoId == null) {
      return Icon(
        Icons.photo_camera_outlined,
        color: AppColors.greyColor,
        size: 20,
      );
    }
    
    // Check if image is cached
    final imageData = _imageCache[photoId];
    if (imageData != null) {
      return GestureDetector(
        onTap: () => _showImageDialog(imageData),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.green7, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Base64ImageWidget(
              base64Data: imageData,
              width: 30,
              height: 30,
              boxFit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    
    // Show camera icon while loading or if no image data
    return Icon(
      Icons.photo_camera,
      color: AppColors.greyColor,
      size: 20,
    );
  }

  /// Show image in full screen dialog
  void _showImageDialog(String imageData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              AppBar(
                title: Text('Image View'),
                actions: [
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: Base64ImageWidget(
                  base64Data: imageData,
                  boxFit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
