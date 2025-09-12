import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/models/PmGetDataModel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';

import '../../../bloc/pm_bloc/pm_cubit.dart';
import '../../../bloc/pm_bloc/pm_state.dart';
import '../../../bloc/audit_schedule_status_cubit.dart';
import '../../../commonWidgets/custom_dialogs/success_dialog.dart';
import '../../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../../commonWidgets/custom_form_appbar.dart';
import '../../../commonWidgets/custom_form_field.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_images.dart';
import '../../../constants/constants_methods.dart';
import '../../../enum/pm_ticket_type_enum.dart';
import '../../home_screen.dart';
import 'pm_page_2.dart';
import '../pm_solar_pages/pm_solar_pages.dart';

class PmScreen1 extends StatefulWidget {
  final PmTicketTypeEnum ticketType;
  final String auditSchId;
  final String siteAuditSchId;
  final String? siteId;

  const PmScreen1({
    super.key,
    required this.ticketType,
    required this.auditSchId,
    required this.siteAuditSchId,
    this.siteId,
  });

  @override
  State<PmScreen1> createState() => _PmScreen1();
}

class _PmScreen1 extends State<PmScreen1> {
  String? selectedStatus;
  String? selectedBatteryStatus;
  bool hasUnsavedChanges = false;

  void _onFormChanged() {
    setState(() {
      hasUnsavedChanges =
          selectedStatus != null || selectedBatteryStatus != null;
    });
  }

  Future<void> _updateAuditScheduleStatus(String status) async {
    try {
      print('Updating audit schedule status to: $status');
      await context.read<AuditScheduleStatusCubit>().updateStatus(
        status: status,
        siteAuditSchId: widget.siteAuditSchId,
      );
    } catch (e) {
      print('Error updating audit schedule status: $e');
    }
  }

  Future<void> _saveAndExit() async {
    print('Save and Exit called');
    await _updateAuditScheduleStatus("IN-PROGRESS");
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Fetch PM data
    context.read<PmCubit>().getPmData(
      siteType: widget.ticketType.value,
      auditSchId: widget.auditSchId,
      siteAuditSchId: widget.siteAuditSchId,
    );
  }
  // void _saveAndExit() {
  //   Navigator.of(context).pop();
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => SuccessDialog(
  //       ticketId: "UVORKJR00045",
  //       message: _getSuccessMessage(),
  //       onDone: () {
  //         Navigator.of(context).pop();
  //         Navigator.of(context).pop();
  //       },
  //     ),
  //   );
  // }

  String _getPmTitle() {
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "PM Telecom";
      case PmTicketTypeEnum.solar:
        return "PM Solar";
    }
  }

    String _getSuccessMessage() {
    final siteId = _getActualSiteId();
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "Preventive Maintenance for Telecom Site (ID: $siteId) has been recorded and saved.";
      case PmTicketTypeEnum.solar:
        return "Preventive Maintenance for Solar Site (ID: $siteId) has been recorded and saved.";
    }
  }

  String _getCancelMessage() {
    final siteId = _getActualSiteId();
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "Do you want to cancel the Preventive Maintenance for Telecom Site (ID: $siteId) ?";
      case PmTicketTypeEnum.solar:
        return "Do you want to cancel the Preventive Maintenance for Solar Site (ID: $siteId) ?";
    }
  }

  Widget _buildSolarSectionCard(String sectionName, int itemCount) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "$sectionName ($itemCount items)",
        style: TextStyle(
          fontSize: 16,
          color: Colors.white,
        ),
      ),
    );
  }

  void _navigateToFirstSolarSection(PmGetDataModel data) {
    // Find the first available solar section
    String? firstSection;
    
    if (data.responseData?.earthing != null && data.responseData!.earthing!.isNotEmpty) {
      firstSection = 'Earthing';
    } else if (data.responseData?.civilStructures != null && data.responseData!.civilStructures!.isNotEmpty) {
      firstSection = 'Civil & Structures';
    } else if (data.responseData?.bos != null && data.responseData!.bos!.isNotEmpty) {
      firstSection = 'BOS (Balance of system)';
    } else if (data.responseData?.transformer != null && data.responseData!.transformer!.isNotEmpty) {
      firstSection = 'Transformer';
    } else if (data.responseData?.safetySystems != null && data.responseData!.safetySystems!.isNotEmpty) {
      firstSection = 'Safety Systems';
    } else if (data.responseData?.spv != null && data.responseData!.spv!.isNotEmpty) {
      firstSection = 'SPV';
    } else if (data.responseData?.inverters != null && data.responseData!.inverters!.isNotEmpty) {
      firstSection = 'Inverters';
    } else if (data.responseData?.performanceMonitoring != null && data.responseData!.performanceMonitoring!.isNotEmpty) {
      firstSection = 'Performance Monitoring';
    } else if (data.responseData?.cables != null && data.responseData!.cables!.isNotEmpty) {
      firstSection = 'Cables';
    } else if (data.responseData?.hygiene != null && data.responseData!.hygiene!.isNotEmpty) {
      firstSection = 'Hygiene';
    }

    if (firstSection != null) {
      // Navigate to the appropriate solar PM page
      _navigateToSolarPage(firstSection, data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No solar PM sections available"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToSolarPage(String sectionName, PmGetDataModel data) {
    // Map section names to their corresponding solar PM pages
    switch (sectionName) {
      case 'Earthing':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PmSolarPage1(
              ticketType: widget.ticketType,
              auditSchId: widget.auditSchId,
              siteAuditSchId: widget.siteAuditSchId,
              siteId: widget.siteId,
              pmData: data,
            ),
          ),
        );
        break;
      case 'Civil & Structures':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PmSolarPage2(
              ticketType: widget.ticketType,
              auditSchId: widget.auditSchId,
              siteAuditSchId: widget.siteAuditSchId,
              siteId: widget.siteId,
              pmData: data,
            ),
          ),
        );
        break;
      case 'BOS (Balance of system)':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PmSolarPage3(
              ticketType: widget.ticketType,
              auditSchId: widget.auditSchId,
              siteAuditSchId: widget.siteAuditSchId,
              siteId: widget.siteId,
              pmData: data,
            ),
          ),
        );
        break;
      case 'Transformer':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PmSolarPage4(
              ticketType: widget.ticketType,
              auditSchId: widget.auditSchId,
              siteAuditSchId: widget.siteAuditSchId,
              siteId: widget.siteId,
              pmData: data,
            ),
          ),
        );
        break;
      case 'Safety Systems':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PmSolarPage5(
              ticketType: widget.ticketType,
              auditSchId: widget.auditSchId,
              siteAuditSchId: widget.siteAuditSchId,
              siteId: widget.siteId,
              pmData: data,
            ),
          ),
        );
        break;
      case 'SPV':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PmSolarPage6(
              ticketType: widget.ticketType,
              auditSchId: widget.auditSchId,
              siteAuditSchId: widget.siteAuditSchId,
              siteId: widget.siteId,
              pmData: data,
            ),
          ),
        );
        break;
      case 'Inverters':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PmSolarPage7(
              ticketType: widget.ticketType,
              auditSchId: widget.auditSchId,
              siteAuditSchId: widget.siteAuditSchId,
              siteId: widget.siteId,
              pmData: data,
            ),
          ),
        );
        break;
      case 'Performance Monitoring':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PmSolarPage8(
              ticketType: widget.ticketType,
              auditSchId: widget.auditSchId,
              siteAuditSchId: widget.siteAuditSchId,
              siteId: widget.siteId,
              pmData: data,
            ),
          ),
        );
        break;
      case 'Cables':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PmSolarPage9(
              ticketType: widget.ticketType,
              auditSchId: widget.auditSchId,
              siteAuditSchId: widget.siteAuditSchId,
              siteId: widget.siteId,
              pmData: data,
            ),
          ),
        );
        break;
      case 'Hygiene':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PmSolarPage10(
              ticketType: widget.ticketType,
              auditSchId: widget.auditSchId,
              siteAuditSchId: widget.siteAuditSchId,
              siteId: widget.siteId,
              pmData: data,
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unknown solar section: $sectionName"),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  // Helper method to get the actual site ID from PM data
  String _getActualSiteId() {
    try {
      final state = context.read<PmCubit>().state;
      if (state is PmGetLoaded && 
          state.pmGetDataModel.pageHeader != null && 
          state.pmGetDataModel.pageHeader!.isNotEmpty &&
          state.pmGetDataModel.pageHeader!.first.siteCode != null &&
          state.pmGetDataModel.pageHeader!.first.siteCode!.isNotEmpty) {
        final siteCode = state.pmGetDataModel.pageHeader!.first.siteCode!;
        return siteCode;
      }
    } catch (e) {
      // Error getting site ID from PM data
    }

    if (widget.siteId != null && widget.siteId!.isNotEmpty && widget.siteId != "N/A") {
      return widget.siteId!;
    }
    return "N/A";
  }

  String _getFieldLabel(String baseLabel) {
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "$baseLabel (Telecom)";
      case PmTicketTypeEnum.solar:
        return "$baseLabel (Solar)";
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return "N/A";
    }
    
    try {
      // Try to parse the date string - handle different possible formats
      DateTime? date;
      
      // Try parsing as ISO 8601 format first
      try {
        date = DateTime.parse(dateString);
      } catch (e) {
        // Try parsing as timestamp (milliseconds since epoch)
        try {
          final timestamp = int.tryParse(dateString);
          if (timestamp != null) {
            date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
        } catch (e2) {
          // Try parsing as seconds since epoch
          try {
            final timestamp = int.tryParse(dateString);
            if (timestamp != null) {
              date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            }
          } catch (e3) {
            // If all parsing fails, return the original string
            return dateString;
          }
        }
      }
      
      if (date != null) {
        // Format the date as "dd MMM yyyy" (e.g., "15 Jan 2024")
        return DateFormat('dd MMM yyyy').format(date);
      }
      
      return dateString;
    } catch (e) {
      // If any error occurs, return the original string
      return dateString;
    }
  }

  String _getButtonText() {
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:
        return "CT";
      case PmTicketTypeEnum.solar:
        return "Earthing";
    }
  }

  bool _isFieldRequired(String fieldName) {
    switch (widget.ticketType) {
      case PmTicketTypeEnum.telecom:

        return fieldName == "PM Name"; // Example
      case PmTicketTypeEnum.solar:
        return fieldName == "PM Name"; // Example
    }
  }

  Widget _buildConditionalWidget() {
    if (widget.ticketType.isTelecom) {
      // Telecom-specific widget
      return Container(
        child: Text("Telecom-specific content"),
      );
    } else if (widget.ticketType.isSolar) {
      // Solar-specific widget
      return Container(
        child: Text("Solar-specific content"),
      );
    }
    return Container(); // Default case
  }

  @override
  Widget build(BuildContext context) {
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
              // title: "Unsaved Changes",
              message: _getCancelMessage(),
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
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        appBar: CustomFormAppbar(
          title: _getPmTitle(),
          onClose: () async {
            if (hasUnsavedChanges) {
              // Show unsaved changes dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => UnsavedChangesDialog(
                  // title: "Unsaved Changes",
                  message: _getCancelMessage(),
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
            } else {
              Navigator.pop(context);
            }
          },
        ),
        body: MultiBlocListener(
          listeners: [
            BlocListener<AuditScheduleStatusCubit, AuditScheduleStatusState>(
              listener: (context, state) {
                if (state is AuditScheduleStatusSuccess) {
                  print('Status updated successfully to ${state.message}');
                  // No snackbar shown - removed as requested
                } else if (state is AuditScheduleStatusError) {
                  print('Status update failed: ${state.error}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update status: ${state.error}')),
                  );
                }
              },
            ),
          ],
          child: BlocBuilder<PmCubit, PmState>(
            builder: (context, state) {
              if (state is PmGetLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is PmGetLoaded) {
                final data = state.pmGetDataModel;
                
                return buildContent(data);
              } else if (state is PmGetError) {
                return Center(child: Text("Error: ${state.message}"));
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget buildContent(PmGetDataModel data) {
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
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 120,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // getHeight(60),
                        CustomFormField(
                          label: widget.ticketType == PmTicketTypeEnum.solar ? "State(Solar)" : "Circle",
                          initialValue: data.pageHeader != null
                              ? data.pageHeader?.first.circle
                              : "N/A",
                          isRequired: false,
                          isEditable: false,
                        ),
                        getHeight(15),
                        CustomFormField(
                          label: "Cluster",
                          initialValue: data.pageHeader!.isNotEmpty
                              ? data.pageHeader?.first.cluster
                              : "N/A",
                          isRequired: false,
                          isEditable: false,
                        ),
                        getHeight(15),
                        CustomFormField(
                          label:widget.ticketType == PmTicketTypeEnum.solar ? "District (Solar)" : "District" ,
                          initialValue: data.pageHeader!.isNotEmpty
                              ? data.pageHeader?.first.district ??
                                    "N/A"
                              : "N/A",
                          isRequired: false,
                          isEditable: false,
                        ),
                        getHeight(15),
                        CustomFormField(
                          label: "Customer",
                          initialValue: data.pageHeader!.isNotEmpty
                              ? data.pageHeader?.first.clientName
                              : "N/A",
                          isRequired: false,
                          isEditable: false,
                        ),
                        getHeight(15),
                        CustomFormField(
                          label: "Site Id",
                          initialValue: data.pageHeader!.isNotEmpty
                              ? data.pageHeader?.first.siteCode
                              : "N/A",
                          isRequired: false,
                          isEditable: false,
                        ),
                        getHeight(15),
                        CustomFormField(
                          label: "Site Name",
                          initialValue: data.pageHeader!.isNotEmpty
                              ? data.pageHeader!.first.siteName
                              : "N/A",
                          isRequired: false,
                          isEditable: false,
                        ),
                        getHeight(15),
                        CustomFormField(
                          label: "Audit Due Date",
                          initialValue: data.pageHeader!.isNotEmpty
                              ? _formatDate(data.pageHeader!.first.auditDueDt)
                              : "N/A",
                          isRequired: false,
                          isEditable: false,
                        ),
                        getHeight(15),
          
                        // Show available sections for solar tickets
                        // if (widget.ticketType == PmTicketTypeEnum.solar && data.responseData != null) ...[
                        //   getHeight(15),
                        //   Text(
                        //     "Solar PM Sections Available:",
                        //     style: TextStyle(
                        //       fontSize: 18,
                        //       fontWeight: FontWeight.bold,
                        //       color: Colors.white,
                        //     ),
                        //   ),
                        //   getHeight(10),
                        //   _buildSolarSectionCard("Earthing", data.responseData!.earthing?.length ?? 0),
                        //   _buildSolarSectionCard("Civil & Structures", data.responseData!.civilStructures?.length ?? 0),
                        //   _buildSolarSectionCard("BOS (Balance of system)", data.responseData!.bos?.length ?? 0),
                        //   _buildSolarSectionCard("Transformer", data.responseData!.transformer?.length ?? 0),
                        //   _buildSolarSectionCard("Safety Systems", data.responseData!.safetySystems?.length ?? 0),
                        //   _buildSolarSectionCard("SPV", data.responseData!.spv?.length ?? 0),
                        //   _buildSolarSectionCard("Inverters", data.responseData!.inverters?.length ?? 0),
                        //   _buildSolarSectionCard("Performance Monitoring", data.responseData!.performanceMonitoring?.length ?? 0),
                        //   _buildSolarSectionCard("Cables", data.responseData!.cables?.length ?? 0),
                        //   _buildSolarSectionCard("Hygiene", data.responseData!.hygiene?.length ?? 0),
                        // ],
                      ],
                    ),
                  ),
          
                ),
          
          
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ArrowButton(
                        text: _getButtonText(),
                        isLeftArrow: false,
                        backgroundColor: AppColors.buttonColorBg,
                        textColor: AppColors.buttonColorSite,
                        onPressed: () {
                          if (widget.ticketType == PmTicketTypeEnum.solar) {
                            _navigateToFirstSolarSection(data);
                          } else {
                            // For telecom tickets, navigate to next page (CT)
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PmScreen2(
                                  ticketType: widget.ticketType,
                                  auditSchId: widget.auditSchId,
                                  siteAuditSchId: widget.siteAuditSchId,
                                  siteId: widget.siteId,
                                  pmData: data, // Pass the PM data
                                ),
                              ),
                            );
                          }
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
        );
  }
}
