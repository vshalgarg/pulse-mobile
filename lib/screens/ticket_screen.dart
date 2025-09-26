import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/sqlite/raw_api_data_model.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import '../bloc/ticket_cubit.dart';
import '../bloc/ticket_state.dart';
import '../commonWidgets/ticket_card.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../models/ticket_model.dart';
import '../routes/routes.dart';
import '../services/location_service.dart';
import 'energy_reading/energy_reading_screen.dart';
import 'preventive_maintainance/pm_page_render.dart';

class TicketScreen extends StatefulWidget {
  final String auditName;
  final String status;

  const TicketScreen({
    super.key,
    required this.auditName,
    required this.status,
  });

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  late String _currentTicketType;
  late ActivityTypeEnum _currentActivityType;
  final Set<int> _downloadedTicketIds = <int>{};
  bool _isInitializingDownloadedTickets = false;

  @override
  void initState() {
    super.initState();
    _currentTicketType = _getInitialTicketTypeFromStatus(widget.status);
    _currentActivityType = _getActivityTypeFromAuditName(widget.auditName);
    _loadTickets();

    // Initialize downloaded tickets state after a short delay to ensure tickets are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        final currentState = context.read<TicketCubit>().state;
        if (currentState is TicketSuccess &&
            currentState.ticketResponse.tickets.isNotEmpty) {
          _initializeDownloadedTickets(currentState.ticketResponse.tickets);
        }
      });
    });
  }

  void _loadTickets() {
    context.read<TicketCubit>().getTickets(
      activityType: _currentActivityType.value,
      ticketType: _currentTicketType,
      pageSize: 50,
      pageNo: 1,
    );
  }

  void _initializeDownloadedTickets(List<Ticket> tickets) async {
    // Prevent multiple initializations
    if (_isInitializingDownloadedTickets) return;
    _isInitializingDownloadedTickets = true;

    try {
      bool hasChanges = false;
      // Check which tickets are already downloaded and populate local state
      for (final ticket in tickets) {
        final isDownloaded = await _isTicketDownloaded(ticket);
        if (isDownloaded &&
            !_downloadedTicketIds.contains(ticket.ticketSchId)) {
          _downloadedTicketIds.add(ticket.ticketSchId);
          hasChanges = true;
        }
      }
      // Only trigger UI update if there were actual changes
      if (hasChanges && mounted) {
        setState(() {});
      }
    } finally {
      _isInitializingDownloadedTickets = false;
    }
  }

  ActivityTypeEnum _getActivityTypeFromAuditName(String auditName) {
    switch (auditName) {
      case "Asset Audit":
        return ActivityTypeEnum.assetAudit;
      case "PM":
        return ActivityTypeEnum.preventiveMaintenance;
      case "ER":
        return ActivityTypeEnum.energyReading;
      default:
        return ActivityTypeEnum.correctiveMaintenance;
    }
  }

  String _getInitialTicketTypeFromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'allocated':
        return TicketType.all;
      case 'in progress':
        return TicketType.open;
      case 'due':
        return TicketType.open;
      case 'completed':
        return TicketType.completed;
      case 'closed':
        return TicketType.closed;
      case 'missed deadline':
        return TicketType.missedDeadline;
      default:
        return TicketType.all;
    }
  }

  String _getStatusFromTicketType(String ticketType) {
    switch (ticketType) {
      case TicketType.open:
        return 'In Progress';
      case TicketType.completed:
        return 'Completed';
      case TicketType.closed:
        return 'Closed';
      case TicketType.missedDeadline:
        return 'Missed Deadline';
      case TicketType.all:
      default:
        return 'Allocated';
    }
  }

  Future<void> _navigateToWorkflow(Ticket? ticket) async {
    if (ticket == null) return;

    try {
      LoaderWidget.showLoader(context);
      // Determine site type - check if it's solar or telecom
      final siteType = ticket.siteDomainName ?? 'Solar';
      Logger.debugLog("🔍 PM Ticket Site Type: $siteType");

      // Use ServiceLocator - no initialization check needed!
      final service = ServiceLocator().centralAssetAuditService;
      final isAvailable = await service.getDataFromApiAndSaveToSqlite(
        siteType: siteType,
        auditSchId: ticket.auditSchId?.toString() ?? "",
        siteAuditSchId: ticket.ticketSchId.toString(),
        latitude: ticket.latitude ?? 0,
        longitude: ticket.longitude ?? 0,
        activityType: _currentActivityType,
      );
      if (!isAvailable) {
        Toastbar.showErrorToastbar("Failed to load data", context);
        return;
      }
      final data = await service.getDataFromSqlite(
        siteAuditSchId: ticket.ticketSchId.toString(),
      );
      if (data == null) {
        Toastbar.showErrorToastbar("Failed to load data", context);
        return;
      }
      if (_currentActivityType == ActivityTypeEnum.preventiveMaintenance) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PMPageRender(pmData: data.apiData),
          ),
        );
      } else if (_currentActivityType == ActivityTypeEnum.energyReading) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnergyReadingScreen(
              siteType: ticket.siteDomainName ?? "Telecom",
              auditSchId: ticket.auditSchId?.toString() ?? "",
              siteAuditSchId: ticket.ticketSchId.toString(),
              siteId: ticket.ticketSchId.toString(),
            ),
          ),
        );
      } else {
        AssetAuditNavigationHelper.navigateToFirstAssetAuditScreen(
          siteType: siteType,
          auditSchId: ticket.auditSchId?.toString() ?? "",
          siteAuditSchId: ticket.ticketSchId.toString(),
          context: context,
        );
      }
    } catch (e) {
      Toastbar.showErrorToastbar("Failed to load data", context);
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  void _navigateToAuditScreen(Ticket? ticket) {
    if (ticket == null) return;

    // Check if ticket status is completed, closed, or missed deadline
    final status = ticket.status?.toLowerCase() ?? '';
    if (status == 'completed' ||
        status == 'closed' ||
        status == 'missed deadline') {
      Toastbar.showInfoToastbar(
        "Ticket can't be opened. Please download PDF.",
        context,
      );
      return;
    }

    switch (_currentActivityType) {
      case ActivityTypeEnum.assetAudit:
        _navigateToWorkflow(ticket);
        break;
      case ActivityTypeEnum.preventiveMaintenance:
        _navigateToWorkflow(ticket);
        break;
      case ActivityTypeEnum.correctiveMaintenance:
        Navigator.pushNamed(context, correctiveMaintenanceScreen);
        break;
      case ActivityTypeEnum.energyReading:
        _navigateToWorkflow(ticket);
        break;
    }
  }

  Future<bool> _isTicketDownloaded(Ticket ticket) async {
    // Check local state first (for recently downloaded tickets)
    if (_downloadedTicketIds.contains(ticket.ticketSchId)) {
      return true;
    }

    // Check database for existing downloads
    RawApiDataModel? data = await ServiceLocator().centralAssetAuditService
        .getDataFromSqlite(siteAuditSchId: ticket.ticketSchId.toString());
    return data != null && data.isDownloaded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildCustomAppBar(),
      body: Stack(
        children: [
          // Background image that fully covers the screen
          Positioned.fill(
            child: SvgPicture.asset(
              AppImages.home,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Content overlay
          SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height,
              child: BlocBuilder<TicketCubit, TicketState>(
                bloc: context.read<TicketCubit>(),
                builder: (context, state) {
                  if (state is TicketLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryGreen,
                      ),
                    );
                  } else if (state is TicketSuccess) {
                    if (state.ticketResponse.tickets.isEmpty) {
                      // Show "no tickets" message in center of screen
                      return const Center(
                        child: Text(
                          'No tickets found for this selection',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    } else {
                      // Show ticket list
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            getHeight(15),
                            _buildTicketList(state.ticketResponse),
                            getHeight(20),
                          ],
                        ),
                      );
                    }
                  } else if (state is TicketFailure) {
                    return _buildErrorWidget(state.errorMessage);
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, right: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "${widget.auditName} - ${widget.status}",
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    fontFamily: poppins,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close,
                  color: AppColors.errorColor,
                  size: 30,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketList(TicketResponse ticketResponse) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ticketResponse.tickets.length,
      itemBuilder: (context, index) {
        final ticket = ticketResponse.tickets[index];
        // Use dynamic status from ticket data, fallback to filter-based status only if no status available
        final statusText = ticket.status?.isNotEmpty == true
            ? ticket.status!
            : _getStatusFromTicketType(_currentTicketType);

        // Debug logging removed to prevent loop

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == ticketResponse.tickets.length - 1 ? 0 : 10,
          ),
          child: TicketCard(
            ticket: ticket,
            ticketId: ticket.pvTicketId,
            siteCode: ticket.siteCode ?? 'N/A',
            siteId: ticket.cluster ?? 'N/A',
            location: ticket.cluster ?? 'N/A',
            company: ticket.operator ?? 'N/A',
            raisedOn: ticket.raisedDt,
            dueDate: ticket.dueDt,
            statusText: statusText,
            isDownloadedFunc: _isTicketDownloaded,
            onPdfDownloadTap: () => _downloadReport(ticket),
            onTap: () => _navigateToAuditScreen(ticket),
            onDirectionTap: () {
              if (ticket.longitude != null && ticket.latitude != null) {
                print(
                  "Opening Google Maps for ${ticket.pvTicketId} at ${ticket.longitude}, ${ticket.latitude}",
                );

                // Open Google Maps with directions to the site
                LocationService.openDirectionsToSite(
                  siteLat: ticket.latitude!,
                  siteLng: ticket.longitude!,
                  siteName: ticket.pvTicketId,
                  context: context,
                );
              } else {
                print("No coordinates available for ${ticket.pvTicketId}");

                // Show a message to the user
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No location coordinates available for this site',
                    ),
                    backgroundColor: AppColors.errorColor,
                  ),
                );
              }
            },
            onDownloadTap: () async {
              try {
                LoaderWidget.showLoader(context);
                // Use ServiceLocator - no initialization check needed!
                final service = ServiceLocator().centralAssetAuditService;
                final isDownloaded = await service.downloadData(
                  siteType: ticket.siteDomainName ?? 'Solar',
                  auditSchId: ticket.auditSchId?.toString() ?? "",
                  siteAuditSchId: ticket.ticketSchId.toString(),
                  latitude: ticket.latitude ?? 0,
                  longitude: ticket.longitude ?? 0,
                  activityType: _currentActivityType,
                );

                if (isDownloaded) {
                  // Add to local state and trigger UI update
                  setState(() {
                    _downloadedTicketIds.add(ticket.ticketSchId);
                  });

                  // Re-initialize downloaded tickets state to ensure consistency
                  final currentState = context.read<TicketCubit>().state;
                  if (currentState is TicketSuccess) {
                    _initializeDownloadedTickets(
                      currentState.ticketResponse.tickets,
                    );
                  }

                  Toastbar.showSuccessToastbar(
                    "Data downloaded successfully",
                    context,
                  );
                } else {
                  Toastbar.showErrorToastbar(
                    "Failed to download data, please try again",
                    context,
                  );
                }
              } finally {
                LoaderWidget.hideLoader();
              }
            },
          ),
        );
      },
    );
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
              'Error loading tickets',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontFamily: fontFamilyMontserrat,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTickets,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // download pdf report
  Future<void> _downloadReport(Ticket ticket) async {
    print("downloading pdf report for ${ticket.pvTicketId}");

    if (_currentActivityType != ActivityTypeEnum.preventiveMaintenance) {
      Toastbar.showErrorToastbar(
        'PDF report not available for this activity type',
        context,
      );
      return;
    }

    try {
      LoaderWidget.showLoader(context);

      // Use CentralApiService to download PDF
      final service = ServiceLocator().centralApiService;
      final filePath = await service.downloadPdfReport(
        ticketId: ticket.pvTicketId,
        ticketSchId: ticket.ticketSchId.toString(),
        activityType: _currentActivityType,
      );

      if (filePath != null) {
        // Check if it's in public Downloads or app storage
        String locationMessage;
        if (filePath.contains('/Download/')) {
          locationMessage =
              'PDF saved to Downloads folder! Open file manager → Downloads to view';
        } else {
          locationMessage =
              'PDF saved to app storage. Check Android → data → com.rapadit.flutter_template_rad → files → Downloads';
        }

        Toastbar.showSuccessToastbar(locationMessage, context);
        print('PDF saved to: $filePath');

        // Show additional info about file location
        Future.delayed(const Duration(seconds: 2), () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File saved to: $filePath'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        });
      } else {
        Toastbar.showErrorToastbar('Failed to download PDF', context);
      }
    } catch (e) {
      print('PDF Download Error: $e');
      String errorMessage = 'Error downloading PDF';

      if (e.toString().contains('Storage permission denied')) {
        errorMessage =
            'Storage permission denied. Please grant storage permission in app settings.';
      } else if (e.toString().contains('Network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('404')) {
        errorMessage = 'PDF report not found. Please try again later.';
      }

      Toastbar.showErrorToastbar(errorMessage, context);
    } finally {
      LoaderWidget.hideLoader();
    }
  }
}
