import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/constants_methods.dart';
import 'custom_form_appbar.dart';
import 'custom_buttons/arrow_botton.dart';
import 'custom_form_field.dart';
import '../utils/pm_navigation_helper.dart';

class PMPageHeader extends StatelessWidget {
  final Map<String, dynamic>? pageHeader;
  final Map<String, dynamic>? pmData;
  final VoidCallback onNext;
  final VoidCallback? onClose;
  final bool isLoading;
  final String? errorMessage;

  const PMPageHeader({
    super.key,
    this.pageHeader,
    this.pmData,
    required this.onNext,
    this.onClose,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'Preventive Maintenance',
        onClose: () => AssetAuditNavigationHelper.navigateToHomeScreen(context),
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
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        )
                      : errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  getHeight(20),
                                  ElevatedButton(
                                    onPressed: () {
                                      // Retry logic can be added here
                                    },
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 16,
                                bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 20,
                                  left: 16,
                                  right: 16,
                                  bottom: 20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // State (Solar)
                                    CustomFormField(
                                      label: 'State (Solar)',
                                      initialValue: pageHeader?['circle']?.toString() ?? '',
                                      isEditable: false,
                                    ),
                                    getHeight(16),
                                    
                                    // District (Solar)
                                    CustomFormField(
                                      label: 'District (Solar)',
                                      initialValue: pageHeader?['cluster']?.toString() ?? '',
                                      isEditable: false,
                                    ),
                                    getHeight(16),
                                    
                                    // Customer
                                    CustomFormField(
                                      label: 'Customer',
                                      initialValue: pageHeader?['client_name']?.toString() ?? '',
                                      isEditable: false,
                                    ),
                                    getHeight(16),
                                    
                                    // Site Id
                                    CustomFormField(
                                      label: 'Site Id',
                                      initialValue: pageHeader?['site_code']?.toString() ?? '',
                                      isEditable: false,
                                    ),
                                    getHeight(16),
                                    
                                    // Site Name
                                    CustomFormField(
                                      label: 'Site Name',
                                      initialValue: pageHeader?['site_name']?.toString() ?? '',
                                      isEditable: false,
                                    ),
                                    getHeight(16),
                                    
                                    // Site Type
                                    CustomFormField(
                                      label: 'Site Type',
                                      initialValue: pageHeader?['site_type_name']?.toString() ?? '',
                                      isEditable: false,
                                    ),
                                    getHeight(16),
                                    
                                    // Due Date of PM
                                    CustomFormField(
                                      label: 'Due Date of PM',
                                      initialValue: _formatDate(pageHeader?['audit_due_dt']?.toString()),
                                      isEditable: false,
                                    ),
                                    
                                    // Add some bottom padding
                                    getHeight(20),
                                  ],
                                ),
                              ),
                            ),
                ),
                // Bottom button - matching asset audit style
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: ArrowButton(
                    text: PMNavigationHelper.getNextScreenName(pmData, 'Site Info'),
                    isLeftArrow: false,
                    backgroundColor: AppColors.buttonColorBg,
                    textColor: AppColors.buttonColorSite,
                    onPressed: isLoading ? null : onNext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      
      final day = date.day.toString().padLeft(2, '0');
      final month = months[date.month - 1];
      final year = date.year;
      
      return '$day-$month-$year';
    } catch (e) {
      return dateString;
    }
  }
}
