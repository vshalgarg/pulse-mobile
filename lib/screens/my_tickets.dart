import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/models/sqlite/raw_api_data_model.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../commonWidgets/ticket_card.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../models/ticket_model.dart';
import '../routes/routes.dart';
import '../services/location_service.dart';
import 'energy_reading/energy_reading_screen.dart';
import 'preventive_maintainance/pm_page_render.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<RawApiDataModel> _downloadedTickets = [];
  List<RawApiDataModel> _filteredTickets = [];
  bool _isLoading = true;
  String? _errorMessage;
  ActivityTypeEnum? _selectedActivityType;

  @override
  void initState() {
    super.initState();
    _loadDownloadedTickets();
  }

  Future<void> _loadDownloadedTickets() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final tickets = await ServiceLocator().centralAssetAuditDataService
          .getAllDownloadedTickets();

      setState(() {
        _downloadedTickets = tickets;
        _selectedActivityType = ActivityTypeEnum.assetAudit;
        _filteredTickets = tickets
            .where(
              (ticket) => ticket.activityType == ActivityTypeEnum.assetAudit,
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterTicketsByActivityType(ActivityTypeEnum? activityType) {
    setState(() {
      _selectedActivityType = activityType;
      if (activityType == null) {
        _filteredTickets = _downloadedTickets;
      } else {
        _filteredTickets = _downloadedTickets
            .where((ticket) => ticket.activityType == activityType)
            .toList();
      }
    });
  }

  int _getTicketCountForActivityType(ActivityTypeEnum activityType) {
    return _downloadedTickets
        .where((ticket) => ticket.activityType == activityType)
        .length;
  }

  String _getActivityTypeDisplayName(ActivityTypeEnum activityType) {
    switch (activityType) {
      case ActivityTypeEnum.assetAudit:
        return "Asset Audit";
      case ActivityTypeEnum.preventiveMaintenance:
        return "Preventive Maintenance";
      case ActivityTypeEnum.correctiveMaintenance:
        return "Corrective Maintenance";
      case ActivityTypeEnum.energyReading:
        return "Energy Reading";
    }
  }

  Future<void> _navigateToWorkflow(RawApiDataModel ticket) async {
    try {
      LoaderWidget.showLoader(context);

      // Use ServiceLocator to get the service
      final service = ServiceLocator().centralAssetAuditService;
      final data = await service.getDataFromSqlite(
        siteAuditSchId: ticket.siteAuditSchId,
      );

      if (data == null) {
        Toastbar.showErrorToastbar("Failed to load data", context);
        return;
      }

      if (ticket.activityType == ActivityTypeEnum.preventiveMaintenance) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PMPageRender(pmData: data.apiData),
          ),
        );
      } else if (ticket.activityType == ActivityTypeEnum.energyReading) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnergyReadingScreen(
              siteType: ticket.siteType,
              auditSchId: ticket.auditSchId,
              siteAuditSchId: ticket.siteAuditSchId,
              siteId: ticket.siteAuditSchId,
            ),
          ),
        );
      } else {
        AssetAuditNavigationHelper.navigateToFirstAssetAuditScreen(
          siteType: ticket.siteType,
          auditSchId: ticket.auditSchId,
          siteAuditSchId: ticket.siteAuditSchId,
          context: context,
        );
      }
    } catch (e) {
      Toastbar.showErrorToastbar("Failed to load data", context);
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  void _navigateToAuditScreen(RawApiDataModel ticket) {
    // Check if ticket status is completed, closed, or missed deadline
    final status = ticket.status.toLowerCase();
    if (status == 'completed' ||
        status == 'closed' ||
        status == 'missed deadline') {
      Toastbar.showInfoToastbar(
        "Ticket can't be opened. Please download PDF.",
        context,
      );
      return;
    }

    switch (ticket.activityType) {
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

  // Convert RawApiDataModel to Ticket for display
  Ticket _convertToTicket(RawApiDataModel rawData) {
    return Ticket(
      ticketSchId: int.tryParse(rawData.siteAuditSchId) ?? 0,
      pvTicketId: rawData.pvTicketId,
      siteCode: rawData.siteCode,
      cluster: rawData.cluster,
      operator: rawData.operator,
      raisedDt: rawData.raisedDt,
      dueDt: rawData.dueDt,
      status: rawData.status,
      latitude: rawData.latitude,
      longitude: rawData.longitude,
      auditSchId: int.tryParse(rawData.auditSchId),
      siteDomainName: rawData.siteType,
    );
  }

  // download pdf report
  Future<void> _downloadReport(RawApiDataModel ticket) async {
    print("downloading pdf report for ${ticket.pvTicketId}");

    if (ticket.activityType != ActivityTypeEnum.preventiveMaintenance &&
        ticket.activityType != ActivityTypeEnum.assetAudit) {
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
        ticketSchId: ticket.siteAuditSchId,
        activityType: ticket.activityType,
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
              child: Column(
                children: [
                  _buildFilterBar(),
                  Expanded(child: _buildBody()),
                ],
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
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.only(
            left: 10,
            top: 12,
            right: 0,
            bottom: 10,
          ),
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
                  "My Tickets",
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

  Widget _buildFilterBar() {
    final activityTypes = [
      ActivityTypeEnum.assetAudit,
      ActivityTypeEnum.preventiveMaintenance,
      ActivityTypeEnum.correctiveMaintenance,
      ActivityTypeEnum.energyReading,
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: activityTypes.length,
        itemBuilder: (context, index) {
          final activityType = activityTypes[index];
          final count = _getTicketCountForActivityType(activityType);
          final isSelected = _selectedActivityType == activityType;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildFilterButton(
              activityType: activityType,
              count: count,
              isSelected: isSelected,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterButton({
    required ActivityTypeEnum activityType,
    required int count,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _filterTicketsByActivityType(activityType),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.myTicketsSelected : AppColors.myTickets,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '${_getActivityTypeDisplayName(activityType)} ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.dashboardTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    } else if (_errorMessage != null) {
      return _buildErrorWidget(_errorMessage!);
    } else if (_filteredTickets.isEmpty) {
      return Center(
        child: Text(
          _downloadedTickets.isEmpty
              ? 'No downloaded tickets found'
              : 'No tickets found for ${_selectedActivityType != null ? _getActivityTypeDisplayName(_selectedActivityType!) : 'selected filter'}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      return SingleChildScrollView(
        child: Column(
          children: [getHeight(15), _buildTicketList(), getHeight(20)],
        ),
      );
    }
  }

  Widget _buildTicketList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredTickets.length,
      itemBuilder: (context, index) {
        final rawTicket = _filteredTickets[index];
        final ticket = _convertToTicket(rawTicket);

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == _filteredTickets.length - 1 ? 0 : 10,
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
            statusText: ticket.status ?? 'N/A',
            isDownloadedFunc: (ticket) async =>
                true, // All tickets here are downloaded
            onPdfDownloadTap: () => _downloadReport(rawTicket),
            onTap: () => _navigateToAuditScreen(rawTicket),
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
              // This is not needed for downloaded tickets, but keeping for consistency
              Toastbar.showInfoToastbar("Ticket already downloaded", context);
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
              onPressed: _loadDownloadedTickets,
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
}
