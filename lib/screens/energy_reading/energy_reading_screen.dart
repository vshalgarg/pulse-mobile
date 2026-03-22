import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../routes/route_generator.dart';
import 'energy_reading_details_screen.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';

class EnergyReadingScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final String siteId;
  final BuildContext? parentContext;

  const EnergyReadingScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    required this.siteId,
    this.parentContext,
  });

  @override
  State<EnergyReadingScreen> createState() => _EnergyReadingScreenState();
}

class _EnergyReadingScreenState extends State<EnergyReadingScreen> {
  bool _isLoadingData = true;
  String? _errorMessage;
  bool isSubmitting = false;

  Map<String, dynamic>? _displayFormData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _errorMessage = null;
      });

      Logger.debugLog(
        '🔄 Loading Site Audit data for site ${widget.siteAuditSchId}',
      );

      final completeData = await ServiceLocator().centralAssetAuditService
          .getActualDataFromSqlite(siteAuditSchId: widget.siteAuditSchId);
      final data = completeData?['EBPageData']?.first ?? {};

      if (data != null) {
        final formData = <String, String>{};
        formData['circle'] = data['circle']?.toString() ?? "N/A";
        formData['cluster'] = data['cluster']?.toString() ?? "N/A";
        formData['district'] = data['district']?.toString() ?? "N/A";
        formData['clientName'] = data['client_name']?.toString() ?? "N/A";
        formData['siteCode'] = data['site_code']?.toString() ?? "N/A";
        formData['siteName'] = data['site_name']?.toString() ?? "N/A";
        formData['siteType'] = data['site_type_name']?.toString() ?? "N/A";
        formData['siteId'] = data['site_id']?.toString() ?? "N/A";
        formData['indoorOutdoor'] = data['indoor_outdoor']?.toString() ?? "N/A";
        formData['ebNonEb'] = data['eb_non_eb']?.toString() ?? "N/A";
        formData['operator1'] = data['op1_name']?.toString() ?? "N/A";
        formData['operator2'] = data['op2_name']?.toString() ?? "N/A";
        formData['auditDueDate'] = data['audit_due_dt']?.toString() ?? "N/A";
        formData['siteDomainName'] =
            data['site_domain_name']?.toString() ?? "N/A";
        formData['status'] = data['status']?.toString() ?? "N/A";

        formData['infra_district_engineer_name'] = data['infra_district_engineer_name']?.toString() ?? "N/A";
        formData['infra_district_engineer_contact_no'] = data['infra_district_engineer_contact_no']?.toString() ?? "N/A";
        formData['cluster_incharge_name'] = data['cluster_incharge_name']?.toString() ?? "N/A";
        formData['cluster_incharge_contact_no'] = data['cluster_incharge_contact_no']?.toString() ?? "N/A";

        setState(() {
          _isLoadingData = false;
          _displayFormData = formData;
        });

        Logger.debugLog("✅ Site Audit Data loaded: $formData");
      } else {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'No Site Audit data available for this site';
        });
        Logger.errorLog(
          '❌ No Site Audit data available for site ${widget.siteAuditSchId}',
        );
      }
    } catch (e) {
      Logger.errorLog('❌ Error loading Site Audit data: $e');
      setState(() {
        _isLoadingData = false;
        _errorMessage = 'Failed to load Site Audit data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: "Energy Reading",
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
            child: SafeSvgPicture.asset(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isLoadingData) _buildLoading(),
                          if (_errorMessage != null && !_isLoadingData)
                            _buildError(),
                          if (!_isLoadingData && _errorMessage == null)
                            _buildFormFields(),
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
                          text: "Energy Detail",
                          isLeftArrow: false,
                          backgroundColor: AppColors.buttonColorBg,
                          textColor: AppColors.buttonColorSite,
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  pushPage(
                                    context,
                                    EnergyReadingDetailScreen(
                                      auditSchId: widget.auditSchId,
                                      siteAuditSchId: widget.siteAuditSchId,
                                      siteType: widget.siteType,
                                      siteId:
                                          _displayFormData?['siteId'] ?? "0",
                                      parentContext:
                                          widget.parentContext ?? context,
                                    ),
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
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            SizedBox(height: 16),
            Text(
              'Loading site data...',
              style: TextStyle(color: AppColors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.errorColor, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.errorColor, size: 20),
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
            style: const TextStyle(color: AppColors.errorColor, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        CustomFormField(
          label: "Circle",
          initialValue: _displayFormData?['circle'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),
        CustomFormField(
          label: "Cluster",
          initialValue: _displayFormData?['cluster'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),
        CustomFormField(
          label: "District",
          initialValue: _displayFormData?['district'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),
        CustomFormField(
          label: "Customer",
          initialValue: _displayFormData?['clientName'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),
        CustomFormField(
          label: "Site Code",
          initialValue: _displayFormData?['siteCode'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
        const SizedBox(height: 15),
        CustomFormField(
          label: "Site Name",
          initialValue: _displayFormData?['siteName'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),

        const SizedBox(height: 15),
        CustomFormField(
          label: "Infra Engineer Name",
          initialValue: _displayFormData?['infra_district_engineer_name'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),

        const SizedBox(height: 15),
        CustomFormField(
          label: "Infra Engineer Contact No.",
          initialValue: _displayFormData?['infra_district_engineer_contact_no'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),

        const SizedBox(height: 15),
        CustomFormField(
          label: "Cluster Incharge Name",
          initialValue: _displayFormData?['cluster_incharge_name'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),

        const SizedBox(height: 15),
        CustomFormField(
          label: "Cluster Incharge Contact No.",
          initialValue: _displayFormData?['cluster_incharge_contact_no'] ?? "N/A",
          isRequired: false,
          isEditable: false,
        ),
      ],
    );
  }
}
