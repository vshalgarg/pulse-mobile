import 'dart:convert';
import 'package:app/app_config.dart';
import 'package:app/bloc/dashboard_cubit.dart';
import 'package:app/bloc/login_bloc/auth_cubit.dart';
import 'package:app/commonWidgets/dashBoard_appBar.dart';
import 'package:app/constants/app_sizes.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/screens/login_screen.dart';
import 'package:app/screens/ticket_screen.dart';
import 'package:app/screens/sqlite_query_screen.dart';
import 'package:app/screens/debug/log_viewer_screen.dart';
import 'package:app/services/image_upload_service.dart';
import 'package:app/services/asset_audit_post_service.dart';
import 'package:app/services/pending_requests_service.dart';
import 'package:app/utils.dart';
import 'package:app/utils/connectivity_helper.dart';
import 'package:app/utils/data_transformation_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../commonWidgets/custom_ticket_status_card.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../utils/user_name_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Utils.getCurrentDateTimeForAPICall();
    context.read<DashboardCubit>().getDashboardCount();
  }

  /// Syncs offline data by checking pending requests and posting them to the server
  Future<void> _syncOfflineData() async {
    try {
      // Get pending requests
      final pendingRequestsService = PendingRequestsService();
      final pendingRequests = await pendingRequestsService.getPendingRequests();

      int successCount = 0;
      int failureCount = 0;

      // Process each pending request
      for (final request in pendingRequests) {
        try {
          await _processPendingRequest(request);
          successCount++;
          print('✅ Successfully synced request: ${request['request_id']}');
        } catch (e) {
          failureCount++;
          print('❌ Failed to sync request ${request['request_id']}: $e');
          Logger.errorLog(
            '❌ HomeScreen: Failed to sync request ${request['request_id']}: $e',
          );
        }
      }

      // Show sync result
      final message =
          'Sync completed: $successCount successful, $failureCount failed';
      print('📊 $message');
      Logger.infoLog('📊 HomeScreen: $message');
      _showSyncMessage(message);
    } catch (e) {
      print('❌ Error during sync: $e');
      Logger.errorLog('❌ HomeScreen: Error during sync: $e');
      _showSyncMessage('Sync failed: $e');
    }
  }

  /// Processes a single pending request
  Future<void> _processPendingRequest(Map<String, dynamic> request) async {
    try {
      final requestId = request['request_id'] as String;
      final url = request['url'] as String;
      final headersJson = request['headers'] as String?;
      final requestDataJson = request['request_data'] as String;

      List<dynamic> requestData;
      try {
        requestData = jsonDecode(requestDataJson);
      } catch (e) {
        throw Exception('Failed to parse request data: $e');
      }

      print('🔄 Processing request: $requestId');
      print('📍 URL: $url');

      // Parse headers
      Map<String, String> headers = {};
      if (headersJson != null && headersJson.isNotEmpty) {
        try {
          headers = Map<String, String>.from(jsonDecode(headersJson));
        } catch (e) {
          print('⚠️ Failed to parse headers: $e');
          headers = {'Content-Type': 'application/json'};
        }
      } else {
        headers = {'Content-Type': 'application/json'};
      }

      // Initialize AssetAuditPostService
      final apiService = AppConfig.of(context).apiService;
      final imageUploadService = ImageUploadService(apiService: apiService);
      final postService = AssetAuditPostService(
        apiService: apiService,
        imageUploadService: imageUploadService,
      );
      // added offline sync code

      List<Map<String, dynamic>> processedRequests = [];

      for (int i = 0; i < requestData.length; i++) {
        final processedRequest = await postService.processAssetAuditRequest(
          requestDataJson[i],
        );

        // Add location data to each reques

        // Add required fields
        processedRequest['auditSchId'] = 0;
        processedRequest['localCreatedDt'] =
            Utils.getCurrentDateTimeForAPICall();
        processedRequest['localModifiedDt'] =
            Utils.getCurrentDateTimeForAPICall();

        if (processedRequest['record_type'] == 'Remarks') {
          processedRequest['asset_Status'] = 'ok';
        }

        processedRequests.add(processedRequest);
      }

      // Parse request data

      // Convert to transformed requests (camelCase)
      final transformedRequests =
          DataTransformationHelper.transformAssetAuditData(processedRequests);
      print('🔄 Data transformed to camelCase');

      // Get API service from AppConfig

      // Make the API call
      print('📤 Making API call to: $url');
      print('📤 Headers: $headers');
      final response = await apiService.post<List<dynamic>>(
        path: url,
        data: transformedRequests,
        headers: headers,
      );

      if (response.isSuccess) {
        print('✅ API call successful for request: $requestId');

        // Update request status to completed
        final pendingRequestsService = PendingRequestsService();
        await pendingRequestsService.updateRequestStatus(
          requestId: requestId,
          status: 'completed',
        );

        Logger.infoLog('✅ HomeScreen: Successfully synced request $requestId');
      } else {
        throw Exception('API call failed: ${response.errorMessage}');
      }
    } catch (e) {
      print('❌ Error processing request ${request['request_id']}: $e');

      // Update request status to failed and increment retry count
      final pendingRequestsService = PendingRequestsService();
      await pendingRequestsService.incrementRetryCount(
        request['request_id'] as String,
      );

      throw e;
    }
  }

  /// Shows sync message to user
  void _showSyncMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: message.contains('successful')
              ? Colors.green
              : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              _syncOfflineData();
            },
            backgroundColor: Colors.blue,
            child: const Icon(Icons.sync, color: Colors.white),
            tooltip: 'Sync Offline Data',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              pushPage(context, const LogViewerScreen());
            },
            backgroundColor: Colors.orange,
            child: const Icon(Icons.description, color: Colors.white),
            tooltip: 'Log Viewer',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              pushPage(context, const SQLiteQueryScreen());
            },
            backgroundColor: AppColors.auditColor,
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

              const DashBoardAppBar(),

              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: SafeArea(child: userDetail()),
              ),

              // Scrollable content below
              Positioned(
                top: 200,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.green7,
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
                                  if (_hasAssetAuditData(state)) ...[
                                    assetAudit(),
                                    const SizedBox(height: 5),
                                    assetAuditTicketStatus(state),
                                    const SizedBox(height: 15),
                                  ],

                                  // Preventive Maintenance Section - Only show if data exists
                                  if (_hasPreventiveMaintenanceData(state)) ...[
                                    pmAudit(),
                                    const SizedBox(height: 5),
                                    pmAuditTicketStatus(state),
                                    const SizedBox(height: 15),
                                  ],

                                  // Corrective Maintenance Section - Always show
                                  correctiveMaintenance(),
                                  const SizedBox(height: 5),
                                  correctiveMaintenanceTicketStatus(state),
                                  const SizedBox(height: 15),
                                  // Energy Reading Section - Always show
                                  energyReading(),
                                  const SizedBox(height: 5),
                                  energyReadingTicketStatus(state),
                                  const SizedBox(height: 15),

                                  const SizedBox(height: 20),
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

  Widget userDetail() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: UserNameUtils.getUserDisplayNameEnhanced(),
              builder: (context, snapshot) {
                final displayName = snapshot.data ?? 'User';
                return Text(
                  'Hello $displayName,',
                  style: TextStyle(
                    fontSize: AppSizes.twentyFour,
                    fontFamily: dmSans,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                );
              },
            ),
            Text(
              'Here\'s a quick look at your tasks.',
              style: TextStyle(
                fontSize: AppSizes.sixteen,
                fontFamily: dmSans,
                fontWeight: FontWeight.w400,
                color: AppColors.white,
              ),
            ),
          ],
        ),

        // Profile image with popup
        PopupMenuButton<int>(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          offset: const Offset(0, 50),
          color: Colors.white,
          onSelected: (value) async {
            if (value == 1) {
              // Clear all authentication data before navigating to login
              await context.read<AuthCubit>().forceClearAllData();
              pushReplacementPage(context, LoginScreen());
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 1,
              child: SizedBox(
                width: 130,
                height: 20,
                child: Text(
                  "Log Out",
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: fontFamilyInter,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
          child: const CircleAvatar(
            radius: 20,
            backgroundImage: AssetImage(AppImages.userPlaceholder),
          ),
        ),
      ],
    );
  }

  Widget assetAudit() {
    return Container(
      height: 45,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.auditColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        ),
      ),
      child: Text(
        "Asset Audit",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          fontFamily: dmSans,
          color: AppColors.white,
        ),
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

  // PM AUDIT------------
  Widget pmAudit() {
    return Container(
      height: 45,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.auditColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        ),
      ),
      child: Text(
        "Preventive Maintenance",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          fontFamily: dmSans,
          color: AppColors.white,
        ),
      ),
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

  // Energy Reading---------------
  Widget energyReading() {
    return Container(
      height: 45,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.auditColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(5),
          bottomRight: Radius.circular(5),
        ),
      ),
      child: Text(
        "Energy Reading",
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          fontFamily: dmSans,
          color: AppColors.white,
        ),
      ),
    );
  }

  // Corrective Maintenance---------------
  Widget correctiveMaintenance() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 45,
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            decoration: BoxDecoration(
              color: AppColors.auditColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(5),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(5),
              ),
            ),
            child: Text(
              "Corrective Maintenance",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                fontFamily: dmSans,
                color: AppColors.white,
              ),
            ),
          ),
        ),
        getWidth(8), // Distance between containers
        Container(
          height: 45,
          width: 45,
          decoration: BoxDecoration(
            color: AppColors.auditColor,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(10),
              topLeft: Radius.circular(5),
              bottomRight: Radius.circular(5),
              bottomLeft: Radius.circular(5),
            ),
          ),
          child: IconButton(
            onPressed: () {
              // pushPage(context, CorrectiveMaintenanceScreen());
            },
            icon: Icon(Icons.add, color: AppColors.white, size: 24),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ),
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
