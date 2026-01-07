import 'package:flutter/material.dart';
import 'package:app/commonWidgets/asset_audit_form_component.dart';
import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/all_site_model.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/utils/logger.dart';
import 'package:flutter_svg/svg.dart';
import 'asset_type_mapper.dart';

class AUScanUploadScreen extends StatefulWidget {
  final AllSiteModel siteData;
  final BuildContext? parentContext;

  const AUScanUploadScreen({
    super.key,
    required this.siteData,
    this.parentContext,
  });

  @override
  State<AUScanUploadScreen> createState() => _AUScanUploadScreenState();
}

class _AUScanUploadScreenState extends State<AUScanUploadScreen> {
  // Map of asset type (display name) to list of assets
  final Map<String, List<Map<String, dynamic>>> _assetGroups = {};
  
  // Map of asset type to controller for each group
  final Map<String, TextEditingController> _serialControllers = {};
  
  // Map to track expanded/collapsed state of each section
  final Map<String, bool> _sectionExpandedState = {};
  
  // Set to track all scanned serial numbers (for duplicate prevention)
  final Set<String> _scannedSerialNumbers = {};
  
  // Total asset count
  int _totalAssetCount = 0;
  
  // Controller for the initial scan input section
  final TextEditingController _initialScanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingAssets();
  }

  @override
  void dispose() {
    // Dispose all controllers
    _initialScanController.dispose();
    for (var controller in _serialControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Load existing assets from storage
  Future<void> _loadExistingAssets() async {
    try {
      // TODO: Load from SQLite if needed
      // For now, start with empty state
      setState(() {});
    } catch (e) {
      Logger.errorLog('❌ Error loading existing assets: $e');
    }
  }

  /// Validates and parses scanned code
  /// Format: NG-<ACRONYM>-<SERIAL_NUMBER>
  /// Returns: Map with 'acronym', 'serialNumber', 'displayName' or null if invalid
  Map<String, String>? _parseScannedCode(String scannedCode) {
    if (scannedCode.isEmpty) return null;

    // Remove any whitespace
    final code = scannedCode.trim().toUpperCase();

    // Check if it starts with "NG-"
    if (!code.startsWith('NG-')) {
      return null;
    }

    // Remove "NG-" prefix
    final withoutPrefix = code.substring(3);

    // Split by "-" to get acronym and serial number
    final parts = withoutPrefix.split('-');
    if (parts.length < 2) {
      return null;
    }

    // First part is acronym, rest is serial number
    final acronym = parts[0];
    final serialNumber = parts.sublist(1).join('-'); // Join in case serial has dashes

    if (acronym.isEmpty || serialNumber.isEmpty) {
      return null;
    }

    // Get display name for the acronym
    final displayName = AssetTypeMapper.getDisplayName(acronym);

    return {
      'acronym': acronym,
      'serialNumber': serialNumber,
      'displayName': displayName,
    };
  }

  /// Creates a validator function for a specific asset type
  bool Function(String, bool) _createValidatorForAssetType(String assetType) {
    return (String serialNumber, bool isScanned) {
      if (serialNumber.isEmpty) return false;

      // If scanned, validate the format
      if (isScanned) {
        final parsed = _parseScannedCode(serialNumber);
        if (parsed == null) {
          return false;
        }

        final scannedAssetType = parsed['displayName']!;
        final acronym = parsed['acronym']!;
        final serialNum = parsed['serialNumber']!;
        final fullSerial = '$acronym-$serialNum';

        // Check for duplicates
        if (_scannedSerialNumbers.contains(fullSerial)) {
          return false;
        }

        // If it matches this asset type, add to scanned set and allow
        if (scannedAssetType == assetType) {
          _scannedSerialNumbers.add(fullSerial);
          return true;
        }

        // If it's a different asset type, create that group if it doesn't exist
        if (!_assetGroups.containsKey(scannedAssetType)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _assetGroups[scannedAssetType] = [];
              _sectionExpandedState[scannedAssetType] = true;
              final controller = TextEditingController();
              controller.text = serialNum; // Set the serial number
              _serialControllers[scannedAssetType] = controller;
              _scannedSerialNumbers.add(fullSerial);
            });
          });
          // Return false to prevent adding to current component, but group is created
          return false;
        }

        // Different asset type that already exists - don't allow in this component
        return false;
      }

      // Manual entry - just check if not empty
      return serialNumber.isNotEmpty;
    };
  }

  /// Handles when an item is saved from AssetAuditFormComponent
  void _onItemSaved(String assetType, List<Map<String, dynamic>> items) {
    setState(() {
      _assetGroups[assetType] = items;
      _updateTotalCount();
    });
  }

  /// Handles when an item is saved from the initial scan component
  void _onInitialItemSaved(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return;

    // Get the last saved item to determine its asset type
    final lastItem = items.last;
    final fullSerialNumber = lastItem['mfg_serial_no']?.toString() ?? '';

    // Try to parse the serial number to get asset type
    // If it's a scanned code, extract the asset type
    final parsed = _parseScannedCode(fullSerialNumber);
    if (parsed != null) {
      final assetType = parsed['displayName']!;
      final acronym = parsed['acronym']!;
      final serialNum = parsed['serialNumber']!;
      final fullSerial = '$acronym-$serialNum';

      // Check for duplicates
      if (_scannedSerialNumbers.contains(fullSerial)) {
        showCustomToast(context, 'This serial number has already been scanned');
        _initialScanController.clear();
        return;
      }

      // Create asset group if it doesn't exist
      if (!_assetGroups.containsKey(assetType)) {
        setState(() {
          _assetGroups[assetType] = [];
          _sectionExpandedState[assetType] = true;
          final controller = TextEditingController();
          _serialControllers[assetType] = controller;
        });
      }

      // Add the item to the appropriate group
      setState(() {
        // Update the serial number in the item to just the serial part (without NG-ACRONYM-)
        final updatedItem = Map<String, dynamic>.from(lastItem);
        updatedItem['mfg_serial_no'] = serialNum;
        // Preserve the full scanned code in a separate field for reference
        updatedItem['full_scanned_code'] = fullSerialNumber;
        _assetGroups[assetType]!.add(updatedItem);
        _scannedSerialNumbers.add(fullSerial);
        _updateTotalCount();
      });

      // Clear the initial scan controller
      _initialScanController.clear();

      // Show success message
      showCustomToast(context, 'Asset added to $assetType group');
    } else {
      // If it's not a scanned code format, we can't determine asset type
      // Show error message
      showCustomToast(context, 'Invalid format. Expected: NG-<ACRONYM>-<SERIAL>');
      Logger.errorLog('⚠️ Could not parse serial number to determine asset type: $fullSerialNumber');
    }
  }

  /// Updates total asset count
  void _updateTotalCount() {
    _totalAssetCount = _assetGroups.values
        .fold(0, (sum, items) => sum + items.length);
  }

  /// Handles status change (not used but required by component)
  void _onStatusChanged(String assetType, bool? status) {
    // Status change is handled internally by the component
  }

  /// Gets or creates controller for an asset type
  TextEditingController _getControllerForAssetType(String assetType) {
    if (!_serialControllers.containsKey(assetType)) {
      _serialControllers[assetType] = TextEditingController();
    }
    return _serialControllers[assetType]!;
  }

  /// Builds the initial scan section using AssetAuditFormComponent
  Widget _buildInitialScanSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AssetAuditFormComponent(
        componentId: 'initial_scan',
        serialLabel: 'Scan Asset',
        serialHintText: 'Serial Number',
        photoLabel: 'Add a Photo',
        serialController: _initialScanController,
        initialSavedItems: [],
        onItemSaved: _onInitialItemSaved,
        onStatusChanged: (status) {
          // Status change handled internally
        },
        showStatus: false, // Hide status field
        customValidator: (serialNumber, isScanned) {
          if (serialNumber.isEmpty) return false;

          // If scanned, validate the format
          if (isScanned) {
            final parsed = _parseScannedCode(serialNumber);
            if (parsed == null) {
              return false;
            }

            final acronym = parsed['acronym']!;
            final serialNum = parsed['serialNumber']!;
            final fullSerial = '$acronym-$serialNum';

            // Check for duplicates
            if (_scannedSerialNumbers.contains(fullSerial)) {
              return false;
            }

            // Valid scanned code
            return true;
          }

          // Manual entry - just check if not empty
          return serialNumber.isNotEmpty;
        },
        customValidationErrorMessage:
            'Invalid format. Expected: NG-<ACRONYM>-<SERIAL> or duplicate serial number',
        siteAuditSchId: widget.siteData.siteId.toString(),
        showTable: false, // Don't show table in initial scan section
        tableTitle: null,
      ),
    );
  }

  /// Builds the total assets summary
  Widget _buildTotalAssetsSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Assets',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          Text(
            '$_totalAssetCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a collapsible section for an asset type
  Widget _buildAssetTypeSection(String assetType, List<Map<String, dynamic>> items) {
    final isExpanded = _sectionExpandedState[assetType] ?? true;
    final itemCount = items.length;
    final controller = _getControllerForAssetType(assetType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          // Section header (collapsible)
          InkWell(
            onTap: () {
              setState(() {
                _sectionExpandedState[assetType] = !isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$assetType ($itemCount)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: fontFamilyMontserrat,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          
          // Section content (shown when expanded)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              child: AssetAuditFormComponent(
                componentId: assetType,
                serialLabel: 'Scan Asset',
                serialHintText: 'Serial Number',
                photoLabel: 'Add a Photo',
                serialController: controller,
                initialSavedItems: items,
                onItemSaved: (savedItems) => _onItemSaved(assetType, savedItems),
                onStatusChanged: (status) => _onStatusChanged(assetType, status),
                showStatus: false, // Hide status field
                showForm: false, // Hide form section, only show table
                customValidator: _createValidatorForAssetType(assetType),
                customValidationErrorMessage:
                    'Invalid format, wrong asset type, or duplicate serial number',
                siteAuditSchId: widget.siteData.siteId.toString(),
                showTable: true,
                tableTitle: null, // No title needed as we have section header
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the scanned assets list
  Widget _buildScannedAssetsList() {
    if (_assetGroups.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.green7,
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Center(
          child: Text(
            'No assets scanned yet.\nScan a QR code to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Scanned Assets',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: fontFamilyMontserrat,
              ),
            ),
          ),
        ),
        ..._assetGroups.entries.map((entry) {
          return _buildAssetTypeSection(entry.key, entry.value);
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'Asset Upload',
        onClose: () {
          navigateBackOrToHome(
            context,
            targetContext: widget.parentContext ?? context,
          );
        },
      ),
      body: Stack(
        children: [
          // Background
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
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildInitialScanSection(),
                        const SizedBox(height: 16),
                        _buildTotalAssetsSummary(),
                        _buildScannedAssetsList(),
                        const SizedBox(height: 100), // Space for bottom buttons
                      ],
                    ),
                  ),
                ),
                // Bottom buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            navigateBackOrToHome(
                              context,
                              targetContext: widget.parentContext ?? context,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: fontFamilyMontserrat,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: Implement save functionality
                            showCustomToast(context, 'Assets saved successfully');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          child: const Text(
                            'Save Asset',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: fontFamilyMontserrat,
                            ),
                          ),
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
}

