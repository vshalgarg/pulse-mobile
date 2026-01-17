import 'package:app/commonWidgets/asset_audit_telecom_bottom_buttons.dart';
import 'package:app/routes/route_generator.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../services/service_locator.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../utils/logger.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';

class SiteInfoV2Screen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final BuildContext parentContext;

  const SiteInfoV2Screen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    required this.parentContext,
  });

  @override
  State<SiteInfoV2Screen> createState() => _SiteInfoV2ScreenState();
}

class _SiteInfoV2ScreenState extends State<SiteInfoV2Screen> {
  late CentralAssetAuditService _service;

  // Loading states
  bool _isLoadingData = true;
  String? _errorMessage;

  // Form controllers
  final TextEditingController _siteTypeController = TextEditingController();
  final TextEditingController _indoorOutdoorController = TextEditingController();
  final TextEditingController _ebNonEbController = TextEditingController();
  final TextEditingController _operator1Controller = TextEditingController();
  final TextEditingController _operator2Controller = TextEditingController();

  // Asset audit data
  Map<String, dynamic>? _assetAuditData;
  Map<String, dynamic>? _displayFormData;

  // Screen name for navigation
  final String _screenName = 'Site Info';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
  }

  void _initializeServices() {
    Logger.debugLog('🔧 Initializing Central Asset Audit service for Site Info');
    _service = ServiceLocator().centralAssetAuditService;

    Logger.debugLog('✅ Central Asset Audit service initialized successfully for Site Info');
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _errorMessage = null;
      });

      Logger.debugLog('🔄 Loading site info data for site ${widget.siteAuditSchId}');

      // Use the actual service to load data
      final data = await _service.getActualDataFromSqlite(
        siteAuditSchId: widget.siteAuditSchId,
      );

      if (data != null) {
        Logger.debugLog('📊 Received site info data from service');
        Logger.debugLog('📊 Data keys: ${data.keys.toList()}');

        // Extract page header data for form fields
        final pageHeaders = data['pageHeader'] as List<dynamic>?;
        final pageHeader = pageHeaders?.isNotEmpty == true ? pageHeaders!.first as Map<String, dynamic> : null;
        final formData = <String, String>{};

        if (pageHeader != null) {
          // Site info specific fields
          formData['siteType'] = pageHeader['site_type_name']?.toString() ?? "N/A";
          formData['indoorOutdoor'] = pageHeader['indoor_outdoor']?.toString() ?? "N/A";
          formData['ebNonEb'] = pageHeader['eb_non_eb']?.toString() ?? "N/A";
          formData['operator1'] = pageHeader['op1_name']?.toString() ?? "N/A";
          formData['operator2'] = pageHeader['op2_name']?.toString() ?? "N/A";
        } else {
          Logger.errorLog('❌ No page header data found!');
        }

        setState(() {
          _isLoadingData = false;
          _assetAuditData = data; // Store the full asset audit data for navigation
          _displayFormData = formData; // Store the extracted form data for display
        });
        Logger.debugLog('✅ Site info data loaded successfully');
        Logger.debugLog('📊 Form data: $formData');
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'No data available for this site';
        });
        Logger.errorLog('❌ No data available for site ${widget.siteAuditSchId}');
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading site info data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  @override
  void dispose() {
    _siteTypeController.dispose();
    _indoorOutdoorController.dispose();
    _ebNonEbController.dispose();
    _operator1Controller.dispose();
    _operator2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'Site Info',
        onClose: () {
          _showUnsavedChangesDialog();
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
                          // Show loading indicator
                          if (_isLoadingData)
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: const Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: AppColors.primaryGreen,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Loading site data...',
                                      style: TextStyle(
                                        color: AppColors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Show error message
                          if (_errorMessage != null && !_isLoadingData)
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.errorColor,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: AppColors.errorColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Failed to load site data',
                                          style: TextStyle(
                                            color: AppColors.errorColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: AppColors.errorColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _loadData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.errorColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),

                          // Show form fields only when data is loaded and no error
                          if (!_isLoadingData && _errorMessage == null)
                            _buildFormFields(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom button container
                AssetAuditTelecomBottomButtons(
                  isLoading: _isLoadingData,
                  errorMessage: _errorMessage,
                  onNextButtonClick: () async {
                    // Handle next button click
                  },
                  assetAuditData: _assetAuditData,
                  auditSchId: widget.auditSchId,
                  siteType: widget.siteType,
                  siteAuditSchId: widget.siteAuditSchId,
                  screenName: _screenName,

                  parentContext: widget.parentContext,
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Site Type field
        CustomFormField(
          label: "Site Type",
          initialValue: _displayFormData?['siteType'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),

        // Indoor / Outdoor field
        CustomFormField(
          label: "Indoor / Outdoor",
          initialValue: _displayFormData?['indoorOutdoor'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),

        // EB / N-EB field
        CustomFormField(
          label: "EB / N-EB",
          initialValue: _displayFormData?['ebNonEb'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),

        // Operator 1 field
        CustomFormField(
          label: "Operator 1",
          initialValue: _displayFormData?['operator1'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),

        // Operator 2 field
        CustomFormField(
          label: "Operator 2",
          initialValue: _displayFormData?['operator2'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        getHeight(15),
      ],
    );
  }

  void _showUnsavedChangesDialog() {
    navigateBackOrToHome(
      context,
      targetContext: widget.parentContext,
    );
  }
}
