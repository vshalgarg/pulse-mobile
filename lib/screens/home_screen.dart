import 'dart:convert';
import 'package:app/app_config.dart';
import 'package:app/bloc/dashboard_cubit.dart';
import 'package:app/bloc/login_bloc/auth_cubit.dart';
import 'package:app/commonWidgets/dashBoard_appBar.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/app_sizes.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/screens/corrective_maintainece/corrective_maintenance_screen.dart';
import 'package:app/screens/corrective_maintainece/cm_all_sites.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/ticket_screen.dart';
import 'package:app/screens/sqlite_query_screen.dart';
import 'package:app/screens/debug/log_viewer_screen.dart';
import 'package:app/services/image_upload_service.dart';
import 'package:app/services/asset_audit_post_service.dart';
import 'package:app/services/pending_requests_service.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils.dart';
import 'package:app/utils/connectivity_helper.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../commonWidgets/custom_ticket_status_card.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../utils/user_name_utils.dart';

class HomeScreen extends StatefulWidget {
  final String? selectedActivity;

  const HomeScreen({super.key, this.selectedActivity});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardCubit>().getDashboardCount();
  }

  /// Loads sites data for corrective maintenance
  Future<void> _loadSitesAndNavigateToCM() async {
    try {
      // LoaderWidget.showLoader(context);
      // final sites = await ServiceLocator().cmRepository.getCMSitesDropdown();

      if (mounted) {
        LoaderWidget.hideLoader();
        // Navigate to corrective maintenance screen with sites data
        pushPage(context, CMAllSitesScreen());
      }
    } catch (e) {
      if (mounted) {
        LoaderWidget.hideLoader();
        Toastbar.showErrorToastbar('Failed to load sites: $e', context);
      }
    }
  }

  /// Syncs offline data by checking pending requests and posting them to the server
  Future<void> _syncOfflineData() async {
    try {
      Logger.infoLog('🔄 HomeScreen: Starting offline data sync');

      // Get pending requests
      final pendingRequestsService = ServiceLocator().pendingRequestService;
      final pendingRequests = await pendingRequestsService.getPendingRequests();

      Logger.infoLog(
        'HomeScreen: Found ${pendingRequests.length} pending requests',
      );

      if (pendingRequests.isEmpty) {
        Logger.infoLog('HomeScreen: No pending requests found');
        Toastbar.showInfoToastbar('No pending requests to sync', context);
        return;
      }
      int successCount = 0;
      int totalCount = pendingRequests.length;
      // Process each pending request
      for (final request in pendingRequests) {
        try {
          await ServiceLocator().assetAuditPostService
              .syncRequestsWhenUserComesOnline(
                request['url'],
                jsonDecode(request['request_data']),
                request['request_id'],
              );
          successCount++;
        } catch (e) {
          Logger.errorLog(
            'HomeScreen: Failed to sync request ${request['request_id']}: $e',
          );
        }
      }

      // Show sync result
      final message =
          'Sync completed: $successCount successful, out of $totalCount';
      Logger.infoLog('HomeScreen: $message');
      Toastbar.showSuccessToastbar(message, context);
    } catch (e) {
      Logger.errorLog('HomeScreen: Error during sync: $e');
      Toastbar.showErrorToastbar('Sync failed: $e', context);
    }
  }

  PreferredSizeWidget _buildCustomAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 10, top: 20, right: 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_sharp,
                  color: AppColors.backgroundColorapp,
                  size: 25,
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.selectedActivity ?? "",
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    fontFamily: poppins,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildCustomAppBar(),
      extendBodyBehindAppBar: true,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // this will appear only if the user is a CM
          if (widget.selectedActivity == "Corrective Maintenance") ...[
            FloatingActionButton(
              onPressed: () {
                _loadSitesAndNavigateToCM();
              },
              backgroundColor: AppColors.bellColor,
              heroTag: "add_cm_fab",
              child: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Add CM',
            ),
            const SizedBox(height: 16),
          ],

          FloatingActionButton(
            onPressed: () {
              _syncOfflineData();
            },
            backgroundColor: Colors.blue,
            heroTag: "sync_fab",
            child: const Icon(Icons.sync, color: Colors.white),
            tooltip: 'Sync Offline Data',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              pushPage(context, const LogViewerScreen());
            },
            backgroundColor: Colors.orange,
            heroTag: "log_viewer_fab",
            child: const Icon(Icons.description, color: Colors.white),
            tooltip: 'Log Viewer',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              pushPage(context, const SQLiteQueryScreen());
            },
            backgroundColor: AppColors.auditColor,
            heroTag: "sqlite_query_fab",
            child: const Icon(Icons.storage, color: Colors.white),
            tooltip: 'SQLite Query Executor',
          ),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          return Stack(
            children: [
              // Background
              Positioned.fill(
                child: SvgPicture.asset(AppImages.home, fit: BoxFit.cover),
              ),
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: state is DashboardLoading
                      ? const Center(child: CircularProgressIndicator())
                      : state is DashboardFailure
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Failed to load dashboard data',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  context
                                      .read<DashboardCubit>()
                                      .getDashboardCount();
                                },
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            context.read<DashboardCubit>().getDashboardCount();
                          },
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Container(
                              constraints: BoxConstraints(
                                minHeight:
                                    MediaQuery.of(context).size.height - 200,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              child: Column(
                                children: [
                                  // Asset Audit Section - Only show if data exists
                                  if (_hasAssetAuditData(state) &&
                                      widget.selectedActivity ==
                                          "Asset Audit") ...[
                                    const SizedBox(height: 5),
                                    assetAuditTicketStatus(state),
                                    const SizedBox(height: 15),
                                  ],

                                  // Preventive Maintenance Section - Only show if data exists
                                  if (_hasPreventiveMaintenanceData(state) &&
                                      widget.selectedActivity ==
                                          "Preventive Maintenance") ...[
                                    const SizedBox(height: 5),
                                    pmAuditTicketStatus(state),
                                    const SizedBox(height: 15),
                                  ],

                                  // Corrective Maintenance Section - Always show
                                  if (widget.selectedActivity ==
                                      "Corrective Maintenance") ...[
                                    const SizedBox(height: 5),
                                    correctiveMaintenanceTicketStatus(state),
                                    const SizedBox(height: 15),
                                  ],
                                  // Energy Reading Section - Always show
                                  if (widget.selectedActivity ==
                                      "Energy Reading") ...[
                                    const SizedBox(height: 5),
                                    energyReadingTicketStatus(state),
                                    const SizedBox(height: 15),

                                    const SizedBox(height: 20),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget assetAuditTicketStatus(DashboardState state) {
    String allTicketsCount = "0";
    String dueCount = "0";
    String inProgressCount = "0";
    String completedCount = "0";
    String closedCount = "0";
    String missedDeadlineCount = "0";

    if (state is DashboardSuccess) {
      final assetAuditData = state.dashboardModel.data?["Asset Audit"];
      if (assetAuditData != null) {
        for (var ticket in assetAuditData) {
          switch (ticket.ticketCode) {
            case "All Tickets":
              allTicketsCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Due":
              dueCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "In Progress":
              inProgressCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Completed":
              completedCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Closed":
              closedCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Missed Deadline":
              missedDeadlineCount = ticket.ticketCnt?.toString() ?? "0";
              break;
          }
        }
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: allTicketsCount,
                title: "All Tickets",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(
                      auditName: "Asset Audit",
                      status: "All Tickets",
                    ),
                  );
                  print("All Tickets clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: inProgressCount,
                title: "In Progress",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(
                      auditName: "Asset Audit",
                      status: "In Progress",
                    ),
                  );
                  print("In Progress clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: completedCount,
                title: "Completed",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "Asset Audit", status: "Completed"),
                  );
                  print("Completed clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: closedCount,
                title: "Closed",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "Asset Audit", status: "Closed"),
                  );
                  print("Closed clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: missedDeadlineCount,
                title: "Missed DeadLine",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(
                      auditName: "Asset Audit",
                      status: "Missed Deadline",
                    ),
                  );
                  print("Missed Deadline clicked");
                },
              ),
            ),
            Expanded(child: getWidth(10)),
          ],
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  Widget pmAuditTicketStatus(DashboardState state) {
    String allTicketsCount = "0";
    String dueCount = "0";
    String inProgressCount = "0";
    String completedCount = "0";
    String closedCount = "0";
    String missedDeadlineCount = "0";

    if (state is DashboardSuccess) {
      final pmData = state.dashboardModel.data?["Preventive Maintenance"];
      if (pmData != null) {
        for (var ticket in pmData) {
          switch (ticket.ticketCode) {
            case "All Tickets":
              allTicketsCount = ticket.ticketCnt?.toString() ?? "0";
              break;

            case "In Progress":
              inProgressCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Completed":
              completedCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Closed":
              closedCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Missed Deadline":
              missedDeadlineCount = ticket.ticketCnt?.toString() ?? "0";
              break;
          }
        }
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: allTicketsCount,
                title: "All Tickets",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "PM", status: "All Tickets"),
                  );
                  print("PM All Tickets clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: inProgressCount,
                title: "In Progress",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "PM", status: "In Progress"),
                  );
                  print("PM In Progress clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: completedCount,
                title: "Completed",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "PM", status: "Completed"),
                  );
                  print("PM Completed clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: closedCount,
                title: "Closed",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "PM", status: "Closed"),
                  );
                  print("PM Closed clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: missedDeadlineCount,
                title: "Missed DeadLine",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "PM", status: "Missed Deadline"),
                  );
                  print("PM Missed Deadline clicked");
                },
              ),
            ),
            Expanded(child: getWidth(10)),
          ],
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  Widget energyReadingTicketStatus(DashboardState state) {
    String allTicketsCount = "0";
    String dueCount = "0";
    String completedCount = "0";
    String closedCount = "0";
    String missedDeadlineCount = "0";

    if (state is DashboardSuccess) {
      final erData = state.dashboardModel.data?["Energy Reading"];
      if (erData != null) {
        for (var ticket in erData) {
          switch (ticket.ticketCode) {
            case "All Tickets":
              allTicketsCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Due":
              dueCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Completed":
              completedCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Closed":
              closedCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Missed Deadline":
              missedDeadlineCount = ticket.ticketCnt?.toString() ?? "0";
              break;
          }
        }
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: allTicketsCount,
                title: "All Tickets",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "ER", status: "All Tickets"),
                  );
                  print("Energy Reading All Tickets clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: dueCount,
                title: "Due",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "ER", status: "Due"),
                  );
                  print("Energy Reading Due clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: completedCount,
                title: "Completed",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "ER", status: "Completed"),
                  );
                  print("Energy Reading Completed clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: closedCount,
                title: "Closed",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "ER", status: "Closed"),
                  );
                  print("Energy Reading Closed clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: missedDeadlineCount,
                title: "Missed DeadLine",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "ER", status: "Missed Deadline"),
                  );
                  print("Energy Reading Missed Deadline clicked");
                },
              ),
            ),
            Expanded(child: getWidth(10)),
          ],
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  Widget correctiveMaintenanceTicketStatus(DashboardState state) {
    String allTicketsCount = "0";
    String inProgressCount = "0";
    String assignedToMeCount = "0";
    String closedCount = "0";

    if (state is DashboardSuccess) {
      final cmData = state.dashboardModel.data?["Corrective Maintenance"];
      if (cmData != null) {
        for (var ticket in cmData) {
          switch (ticket.ticketCode) {
            case "All Tickets":
              allTicketsCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "In Progress":
              inProgressCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Assigned to Me":
              assignedToMeCount = ticket.ticketCnt?.toString() ?? "0";
              break;
            case "Closed":
              closedCount = ticket.ticketCnt?.toString() ?? "0";
              break;
          }
        }
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: allTicketsCount,
                title: "All Tickets",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "CM", status: "All Tickets"),
                  );
                  print("Corrective Maintenance All Tickets clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: inProgressCount,
                title: "In Progress",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "CM", status: "In Progress"),
                  );
                  print("Corrective Maintenance In Progress clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: StatusCard(
                count: assignedToMeCount,
                title: "Assigned to Me",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "CM", status: "Assigned to Me"),
                  );
                  print("Corrective Maintenance Assigned to Me clicked");
                },
              ),
            ),
            getWidth(5),
            Expanded(
              child: StatusCard(
                count: closedCount,
                title: "Closed",
                onTap: () {
                  pushPage(
                    context,
                    TicketScreen(auditName: "CM", status: "Closed"),
                  );
                  print("Corrective Maintenance Closed clicked");
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  // Helper methods to check if data exists for each section
  bool _hasAssetAuditData(DashboardState state) {
    if (state is DashboardSuccess) {
      final assetAuditData = state.dashboardModel.data?["Asset Audit"];
      return assetAuditData != null && assetAuditData.isNotEmpty;
    }
    return false;
  }

  bool _hasPreventiveMaintenanceData(DashboardState state) {
    if (state is DashboardSuccess) {
      final pmData = state.dashboardModel.data?["Preventive Maintenance"];
      return pmData != null && pmData.isNotEmpty;
    }
    return false;
  }

  bool _hasEnergyReadingData(DashboardState state) {
    if (state is DashboardSuccess) {
      final erData = state.dashboardModel.data?["Energy Reading"];
      return erData != null && erData.isNotEmpty;
    }
    return false;
  }

  bool _hasCorrectiveMaintenanceData(DashboardState state) {
    if (state is DashboardSuccess) {
      // For now, we'll check if there's any CM data in the response
      // You can update this when the API includes CM data
      final cmData = state.dashboardModel.data?["Corrective Maintenance"];
      return cmData != null && cmData.isNotEmpty;
    }
    return false;
  }
}
