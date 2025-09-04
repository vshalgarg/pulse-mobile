import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app/bloc/pm_bloc/pm_cubit.dart';
import 'package:app/bloc/pm_bloc/pm_state.dart';
import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/custom_form_appbar.dart';
import 'package:app/commonWidgets/custom_dropdown.dart';
import 'package:app/commonWidgets/custom_image_upload_field.dart';
import 'package:app/commonWidgets/custom_remark.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/models/PmGetDataModel.dart';
import 'package:app/enum/pm_ticket_type_enum.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/screens/preventive_maintainance/pm_solar_pages/pm_solar_page_8.dart';

import '../../../constants/constants_strings.dart';

class PmSolarPage7 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;
  final PmGetDataModel pmData;

  const PmSolarPage7({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
    required this.pmData,
  });

  @override
  State<PmSolarPage7> createState() => _PmSolarPage7State();
}

class _PmSolarPage7State extends State<PmSolarPage7> {
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
                        _buildInvertersSection(data),
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

  Widget _buildInvertersSection(PmGetDataModel data) {
    final invertersData = data.responseData?.inverters ?? [];
    
    if (invertersData.isEmpty) {
      return const Center(
        child: Text(
          'No Inverters data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...invertersData.map((item) => Column(
          children: [
            _buildFormField(item),
            getHeight(15),
          ],
        )).toList(),
      ],
    );
  }

  Widget _buildFormField(dynamic item) {
    final key = item['checklist_desc'] ?? '';
    final respType = item['resp_type'] ?? '';
    final currentValue = formData[key] ?? '';

    if (respType.contains('DROPDOWN') && respType.contains('IMG')) {
      // Both dropdown and image upload needed
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key,
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
                  onChanged: isEditable ? (value) => _saveFormData(key, value) : (_) {},
                  isRequired: true,
                ),
                getHeight(15),
                ImageUploadField(
                  label: "Add Photo",
                  onImageSelected: isEditable ? (image) => _saveFormData('${key}_image', image) : (image) {},
                  isRequired: true,
                ),
              ],
            ),
          ),
          getHeight(15)
        ],
      );
    } else if (respType.contains('DROPDOWN')) {
      final options = ['OK', 'Corrected', 'Not OK - To be corrected', 'Not Applicable'];
      return CustomDropdown(
        label: key,
        items: isEditable ? options : [],
        initialValue: currentValue.isNotEmpty ? currentValue : null,
        onChanged: isEditable ? (value) => _saveFormData(key, value) : (_) {},
        isRequired: true,
      );
    } else if (respType.contains('IMG')) {
      return ImageUploadField(
        label: key,
        onImageSelected: isEditable ? (image) => _saveFormData(key, image) : (image) {},
        isRequired: true,
      );
    } else if (respType.contains('TEXT')) {
      final controller = TextEditingController(text: currentValue);
      controller.addListener(() {
        _saveFormData(key, controller.text);
      });
      return CustomRemarksField(
        label: key,
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
            text: _getButtonText(),
            isLeftArrow: false,
            backgroundColor: AppColors.buttonColorBg,
            textColor: AppColors.buttonColorSite,
            onPressed: _handleNext,
          ),
        ),
      ],
    );
  }

  void _saveFormData(String key, dynamic value) {
    setState(() {
      formData[key] = value;
    });
  }

  void _handleNext() {
    // Navigate to next page - Hygiene
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PmSolarPage8(
          ticketType: widget.ticketType,
          auditSchId: widget.auditSchId,
          siteAuditSchId: widget.siteAuditSchId,
          siteId: widget.siteId,
          pmData: widget.pmData,
        ),
      ),
    );
  }

  String _getPmTitle() {
    return 'PM Solar - Inverters';
  }

  String _getSuccessMessage() {
    return 'Inverters section data saved successfully!';
  }

  String _getCancelMessage() {
    return 'Inverters section data cancelled!';
  }

  String _getButtonText() {
    return 'Hygiene';
  }
}
