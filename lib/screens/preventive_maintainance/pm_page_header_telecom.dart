import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/utils/pm_navigation_helper.dart';
import '../../routes/route_generator.dart';

class PMPageHeaderTelecom extends StatelessWidget {
  final Map<String, dynamic>? pageHeader;
  final Map<String, dynamic>? pmData;
  final Future<void> Function() onNext;
  final bool isLoading;
  final String? errorMessage;
  final BuildContext parentContext;

  const PMPageHeaderTelecom({
    Key? key,
    this.pageHeader,
    this.pmData,
    required this.onNext,
    this.isLoading = false,
    this.errorMessage,
    required this.parentContext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: CustomFormAppbar(
        title: 'Preventive Maintenance',
        onClose: () {
          navigateBackOrToHome(
            context,
            targetContext: parentContext,
          );
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
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Circle
                                  CustomFormField(
                                    label: 'Circle',
                                    initialValue: pageHeader?['circle']?.toString() ?? '',
                                    isEditable: false,
                                  ),
                                  getHeight(16),
                                  
                                  // Cluster
                                  CustomFormField(
                                    label: 'Cluster',
                                    initialValue: pageHeader?['cluster']?.toString() ?? '',
                                    isEditable: false,
                                  ),
                                  getHeight(16),
                                  
                                  // State
                                  CustomFormField(
                                    label: 'State',
                                    initialValue: pageHeader?['district']?.toString() ?? '',
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
                                  
                                  // Due Date of PM
                                  CustomFormField(
                                    label: 'Due Date of PM',
                                    initialValue: _formatDate(pageHeader?['due_dt']?.toString()),
                                    isEditable: false,
                                  ),
                                ],
                              ),
                            ),
                ),
                // Bottom navigation
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
                    onPressed: isLoading ? null : () async {
                      await onNext();
                    },
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
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
