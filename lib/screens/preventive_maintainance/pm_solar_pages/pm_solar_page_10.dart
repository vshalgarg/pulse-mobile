import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/bloc/pm_bloc/pm_cubit.dart';
import 'package:app/bloc/pm_bloc/pm_state.dart';
import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_form_field.dart';
import 'package:app/commonWidgets/custom_dropdown.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:flutter/material.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/models/PmGetDataModel.dart';
import 'package:app/enum/pm_ticket_type_enum.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/constants/app_images.dart';

import '../../../constants/constants_strings.dart';

class PmSolarPage10 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;
  final PmGetDataModel pmData;

  const PmSolarPage10({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
    required this.pmData,
  });

  @override
  State<PmSolarPage10> createState() => _PmSolarPage10State();
}

class _PmSolarPage10State extends State<PmSolarPage10> {
  final Map<String, dynamic> formData = {};
  bool isEditable = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomFormAppbar(
        title: _getPmTitle(),
        onClose: () => Navigator.pop(context),
      ),
      body: BlocBuilder<PmCubit, PmState>(
        builder: (context, state) {
          if (state is PmGetLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is PmGetLoaded) {
            return _buildContent(state.pmGetDataModel);
          } else if (state is PmGetError) {
            return Center(child: Text(state.message));
          }
          return const Center(child: Text('No data available'));
        },
      ),
    );
  }

  Widget _buildContent(PmGetDataModel data) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Background image - full screen coverage
          Positioned.fill(
            child: SvgPicture.asset(
              AppImages.home,
              fit: BoxFit.cover,
            ),
          ),
          // Content overlay
          SafeArea(
            child: Column(
              children: [
                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCablesSection(data),
                        getHeight(30),
                        // Add bottom padding to account for fixed buttons
                        getHeight(100),
                      ],
                    ),
                  ),
                ),
                // Fixed navigation buttons at bottom
                Container(
                  padding: const EdgeInsets.all(16),
                  child: _buildNavigationButtons(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCablesSection(PmGetDataModel data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormField('Check cable condition and insulation', 'DROPDOWN,IMG'),
        getHeight(15),
        _buildFormField('Check cable connections and terminations', 'DROPDOWN,IMG'),
        getHeight(15),
        _buildFormField('Check cable routing and protection', 'DROPDOWN,IMG'),
        getHeight(15),
        _buildFormField('Check cable grounding and bonding', 'DROPDOWN,IMG'),
        getHeight(15),
        _buildFormField('Check cable labeling and identification', 'DROPDOWN,IMG'),
        getHeight(15),
        _buildFormField('Check cable support and strain relief', 'DROPDOWN,IMG'),
        getHeight(15),
        _buildFormField('Check cable environmental protection', 'DROPDOWN,IMG'),
      ],
    );
  }

  Widget _buildFormField(String label, String respType) {
    final currentValue = formData[label] ?? '';

    if (respType.contains('DROPDOWN') && respType.contains('IMG')) {
      // Both dropdown and image upload needed
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              fontFamily: fontFamilyMontserrat,
            ),
          ),
          getHeight(8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green7,
              borderRadius: BorderRadius.circular(8),
              // border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomDropdown(
                  label: 'Status',
                  items: isEditable ? ['OK', 'Corrected', 'Not OK - To be corrected', 'Not Applicable'] : [],
                  initialValue: currentValue.isNotEmpty ? currentValue : null,
                  onChanged: isEditable ? (value) => _saveFormData(label, value) : (_) {},
                  isRequired: true,
                ),
                getHeight(15),
                ImageUploadField(
                  label: "Add Photo",
                  onImageSelected: isEditable ? (image) => _saveFormData('${label}_image', image) : (image) {},
                  isRequired: true,
                ),
              ],
            ),
          ),
        ],
      );
    } else if (respType.contains('DROPDOWN')) {
      final options = ['OK', 'Corrected', 'Not OK - To be corrected', 'Not Applicable'];
      return CustomDropdown(
        label: 'Status',
        items: isEditable ? options : [],
        initialValue: currentValue.isNotEmpty ? currentValue : null,
        onChanged: isEditable ? (value) => _saveFormData(label, value) : (_) {},
        isRequired: true,
      );
    } else if (respType.contains('IMG')) {
      return ImageUploadField(
        label: label,
        onImageSelected: isEditable ? (image) => _saveFormData(label, image) : (image) {},
        isRequired: true,
      );
    } else if (respType.contains('TEXT')) {
      final controller = TextEditingController(text: currentValue);
      controller.addListener(() {
        _saveFormData(label, controller.text);
      });
      return CustomRemarksField(
        label: label,
        hintText: 'Enter remarks',
        controller: controller,
        maxLines: 4,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ArrowButton(
            text: 'Back',
            isLeftArrow: true,
            backgroundColor: AppColors.buttonColorBackBg,
            textColor: AppColors.buttonColorTextBg,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        getWidth(10),
        Expanded(
          child: ArrowButton(
            text: 'Complete',
            isLeftArrow: false,
            backgroundColor: AppColors.buttonColorBg,
            textColor: AppColors.buttonColorSite,
            onPressed: () {
              // Show completion message and navigate back to main screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Solar PM inspection completed successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              // Navigate back to the main screen
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ),
        // const SizedBox(width: 60), // Placeholder to maintain layout
      ],
    );
  }

  void _saveFormData(String key, dynamic value) {
    setState(() {
      formData[key] = value;
    });
  }

  void _handleNext() {
    // This is the last page, show completion message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getSuccessMessage()),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getPmTitle() {
    return 'PM Solar - Cables';
  }

  String _getSuccessMessage() {
    return 'Cables section data saved successfully! PM Solar completed!';
  }

  String _getCancelMessage() {
    return 'Cables section data cancelled!';
  }

  String _getButtonText() {
    return 'Complete';
  }
}
