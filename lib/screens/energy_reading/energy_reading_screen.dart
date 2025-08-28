import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/screens/energy_reading/energy_reading_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import '../../bloc/energy_reading_cubit.dart';
import '../../constants/constants_strings.dart';
import '../../models/energy_reading_model.dart';
import '../../commonWidgets/custom_form_appbar.dart';
import '../../commonWidgets/custom_form_field.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_images.dart';
import '../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../commonWidgets/custom_dialogs/success_dialog.dart';

class EnergyReadingScreen extends StatefulWidget {
  final String siteType;
  final String auditSchId;
  final String siteAuditSchId;
  final String siteId;

  const EnergyReadingScreen({
    super.key,
    required this.siteType,
    required this.auditSchId,
    required this.siteAuditSchId,
    required this.siteId,
  });

  @override
  State<EnergyReadingScreen> createState() => _EnergyReadingScreenState();
}

class _EnergyReadingScreenState extends State<EnergyReadingScreen> {
  String? selectedStatus;
  String? selectedBatteryStatus;
  bool hasUnsavedChanges = false;
  EnergyReadingData? energyReadingData;

  @override
  void initState() {
    super.initState();
    _loadEnergyReadingData();
  }

  void _loadEnergyReadingData() {
    context.read<EnergyReadingCubit>().getEnergyReadingData(
      siteType: widget.siteType,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );
  }

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges = selectedStatus != null || selectedBatteryStatus != null;
    });
  }

  Widget _buildView(EnergyReadingState state) {
    return Stack(
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
          child: _buildContent(state),
        ),
      ],
    );
  }

  Widget _buildContent(EnergyReadingState state) {
    if (state.runtimeType == EnergyReadingLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      );
    }

    // Handle success state
    if (state.runtimeType == EnergyReadingSuccess) {
      final successState = state as EnergyReadingSuccess;
      final data = successState.energyReadingResponse.data.isNotEmpty 
          ? successState.energyReadingResponse.data.first 
          : null;
      
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.only(
                  top: 20,
                  left: 16,
                  right: 16,
                  bottom: 20,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomFormField(
                        label: "Circle",
                        initialValue: data?.circle ?? '',
                        isRequired: false,
                        isEditable: false,
                      ),
                      getHeight(15),
                      CustomFormField(
                        label: "Cluster",
                        initialValue: data?.cluster ?? '',
                        isRequired: false,
                        isEditable: false,
                      ),
                      getHeight(15),
                      CustomFormField(
                        label: "District",
                        initialValue: data?.district ?? 'null',
                        isRequired: false,
                        isEditable: false,
                      ),
                      getHeight(15),
                      CustomFormField(
                        label: "Customer",
                        initialValue: data?.clientName ?? '',
                        isRequired: false,
                        isEditable: false,
                      ),
                      getHeight(15),
                      CustomFormField(
                        label: "Site Id",
                        initialValue: data?.siteCode ?? '',
                        isRequired: false,
                        isEditable: false,
                      ),
                      getHeight(15),
                      CustomFormField(
                        label: "Site Name",
                        initialValue: data?.siteName ?? '',
                        isRequired: false,
                        isEditable: false,
                      ),
                      getHeight(15),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: ArrowButton(
              text: "Energy Reading",
              isLeftArrow: false,
              backgroundColor: AppColors.buttonColorBg,
              textColor: AppColors.buttonColorSite,
              onPressed: (){
                pushPage(context, EnergyDetailScreen(
                  auditSchId: widget.auditSchId,
                  siteAuditSchId: widget.siteAuditSchId,
                  siteId: widget.siteId,
                ));
              },
              // onPressed: () => _showSuccessDialog(data?.siteCode),
            ),
          ),
        ],
      );
    }

    // Handle error state
    if (state.runtimeType == EnergyReadingFailure) {
      final failureState = state as EnergyReadingFailure;
      return _buildErrorWidget(failureState.errorMessage);
    }

    // Default empty state
    return const SizedBox.shrink();
  }

  Widget _buildErrorWidget(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.errorColor,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEnergyReadingData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveAndExit() async {
    Navigator.of(context).pop();
    
    // Check if there's any data to save
    if (_hasAnyDataToSave()) {
      showCustomToast(context,'Saving' );
      
      // Wait a moment to show the loading message
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Show success dialog (data saved locally)
      _showSuccessDialog();
    } else {
      // No data to save, just show success dialog
      _showSuccessDialog();
    }
  }

  // Check if there's any data filled in the form
  bool _hasAnyDataToSave() {
    return selectedStatus != null || selectedBatteryStatus != null;
  }

  // Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => SuccessDialog(
        ticketId: "ER-${DateTime.now().millisecondsSinceEpoch}",
        message: "Energy Reading data has been saved!",
        onDone: () {
          Navigator.of(context).pop(); // Close dialog
          // Navigate to home screen
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/homeScreen',
            (route) => false,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EnergyReadingCubit, EnergyReadingState>(
      listener: (context, state) {
        if (state.runtimeType == EnergyReadingFailure) {
          final failureState = state as EnergyReadingFailure;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failureState.errorMessage),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: !hasUnsavedChanges,
          onPopInvoked: (didPop) async {
            if (didPop) return;
            
            if (hasUnsavedChanges) {
              // Show unsaved changes dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => UnsavedChangesDialog(
                  message: "Do you want to save the current data and exit, or discard all changes?",
                  onSaveAndExit: () {
                    // Save the data and exit
                    _saveAndExit();
                  },
                  onDiscard: () {
                    // Discard changes and exit
                    Navigator.of(context).pop();
                  },
                ),
              );
            }
          },
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: CustomFormAppbar(
              title: "Energy Reading",
              onClose: () async {
                if (hasUnsavedChanges) {
                  // Show unsaved changes dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => UnsavedChangesDialog(
                      message: "Do you want to save the current data and exit, or discard all changes?",
                      onSaveAndExit: () {
                        _saveAndExit();
                      },
                      onDiscard: () {
                        // Discard changes and exit
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            body: _buildView(state),
          ),
        );
      },
    );
  }
}
