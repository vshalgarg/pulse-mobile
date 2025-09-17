
import 'package:app/constants/constants_methods.dart';
import 'package:app/enum/pm_ticket_type_enum.dart';
import 'package:app/screens/preventive_maintainance/pm_pages/pm_page_1.dart';
import 'package:app/services/asset_audit/central_asset_audit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';

import '../bloc/ticket_cubit.dart';
import '../bloc/ticket_state.dart';
import '../commonWidgets/ticket_card.dart';
import '../constants/app_colors.dart';
import '../constants/app_images.dart';
import '../constants/constants_strings.dart';
import '../models/ticket_model.dart';
import '../routes/routes.dart';
import '../services/location_service.dart';
import 'asset_audit/asset_audit_telecom/asset_audit_telecom_page_1.dart';
import 'asset_audit/asset_audit_solar/asset_audit_solar.dart';
import 'asset_audit/asset_audit_solar_v2/asset_audit_solar_v2_screen.dart';
import 'asset_audit/asset_audit_telecom_v2/asset_audit_telecom_v2_screen.dart';
import '../services/asset_audit/central_service_initializer.dart';
import 'energy_reading/energy_reading_screen.dart';

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
  late CentralAssetAuditService _service;
  late String _currentTicketType;
  late String _currentActivityType;

  @override
  void initState() {
    super.initState();
    _service = CentralAssetAuditServiceInitializer.getService();
    _currentTicketType = _getInitialTicketTypeFromStatus(widget.status);
    _currentActivityType = _getActivityTypeFromAuditName(widget.auditName);
    _loadTickets();
  }

  void _loadTickets() {
    print("🔍 Loading tickets with parameters:");
    print("   Activity Type: $_currentActivityType");
    print("   Ticket Type: $_currentTicketType");
    print("   Page Size: 50");
    print("   Page No: 1");
    
    context.read<TicketCubit>().getTickets(
      activityType: _currentActivityType,
      ticketType: _currentTicketType,
      pageSize: 50,
      pageNo: 1,
    );
  }

  String _getActivityTypeFromAuditName(String auditName) {
    switch (auditName) {
      case "Asset Audit":
        return ActivityType.assetAudit;
      case "PM":
        return ActivityType.preventiveMaintenance;
      case "ER":
        return ActivityType.energyReading;
      default:
        return ActivityType.assetAudit;
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

  /// Navigate to Solar Asset Audit V2 with data fetching
  Future<void> _navigateToSolarAssetAuditV2(Ticket? ticket) async {
    if (ticket == null) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading asset audit data...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Initialize service if not already done
      if (!CentralAssetAuditServiceInitializer.isInitialized) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Central Asset Audit service not initialized'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get the service and fetch data
      final service = CentralAssetAuditServiceInitializer.getService();
      final data = await service.getAssetAuditData(
        siteType: "Solar",
        auditSchId: ticket.auditSchId?.toString() ?? "",
        siteAuditSchId: ticket.ticketSchId.toString(),
      );

      // Close loading dialog
      Navigator.pop(context);

      if (data != null) {
        // Navigate to the screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssetAuditSolarV2Screen(
              siteType: "Solar",
              auditSchId: ticket.auditSchId?.toString() ?? "",
              siteAuditSchId: ticket.ticketSchId.toString(),
            ),
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load asset audit data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Navigate to Telecom Asset Audit V2 with data fetching
  Future<void> _navigateToTelecomAssetAuditV2(Ticket? ticket) async {
    if (ticket == null) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading asset audit data...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Initialize service if not already done
      if (!CentralAssetAuditServiceInitializer.isInitialized) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Central Asset Audit service not initialized'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get the service and fetch data
      final service = CentralAssetAuditServiceInitializer.getService();
      final data = await service.getAssetAuditData(
        siteType: "Telecom",
        auditSchId: ticket.auditSchId?.toString() ?? "",
        siteAuditSchId: ticket.ticketSchId.toString(),
      );

      // Close loading dialog
      Navigator.pop(context);

      if (data != null) {
        // Navigate to the screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssetAuditTelecomV2Screen(
              siteType: "Telecom",
              auditSchId: ticket.auditSchId?.toString() ?? "",
              siteAuditSchId: ticket.ticketSchId.toString(),
            ),
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load asset audit data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToAuditScreen(Ticket? ticket) {
    if (widget.auditName == "Asset Audit") {
      // Check site domain to determine which screen to navigate to
      if (ticket?.siteDomainName == "Telecom") {
        // Navigate to Telecom Asset Audit V2
        _navigateToTelecomAssetAuditV2(ticket);
      } else {
        // Navigate to Solar Asset Audit V2
        _navigateToSolarAssetAuditV2(ticket);
      }
    } else {
      switch (widget.auditName) {
        case "PM":
          print("🔍 DEBUG: Navigating to PM with ticket data:");
          print("🔍 siteDomainName: ${ticket?.siteDomainName}");
          print("🔍 auditSchId: ${ticket?.auditSchId}");
          print("🔍 siteAuditSchId: ${ticket?.ticketSchId}");
          print("🔍 Parsed ticketType: ${PmTicketTypeEnum.fromString(ticket?.siteDomainName)}");
          
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => PmScreen1(
              ticketType: PmTicketTypeEnum.fromString(ticket?.siteDomainName),
              auditSchId: ticket?.auditSchId?.toString() ?? "",
              siteAuditSchId: ticket?.ticketSchId.toString() ?? "",
              siteId: ticket?.ticketSchId.toString() ?? "0",
            ),
          ));
          break;
        case "CM":
          Navigator.pushNamed(context, correctiveMaintenanceScreen);
          break;
        case "ER":
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnergyReadingScreen(
                siteType: ticket?.siteDomainName ?? "Telecom",
                auditSchId: ticket?.auditSchId?.toString() ?? "",
                siteAuditSchId: ticket?.ticketSchId.toString() ?? "",
                siteId: ticket?.ticketSchId.toString() ?? "0", // Using ticketSchId as siteId for now
              ),
            ),
          );
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No specific audit screen for ${widget.auditName}'),
              backgroundColor: AppColors.errorColor,
            ),
          );
      }
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
        
        // Debug logging to see actual status values
        print("🔍 Ticket ${ticket.pvTicketId}: API status='${ticket.status}', final status='$statusText'");
        
        return Padding(
          padding: EdgeInsets.only(bottom: index == ticketResponse.tickets.length - 1 ? 0 : 10),
          child: TicketCard(
            ticketId: ticket.pvTicketId,
            siteCode: ticket.siteCode ?? 'N/A',
            siteId: ticket.cluster ?? 'N/A',
            location: ticket.cluster ?? 'N/A',
            company: ticket.operator ?? 'N/A',
            raisedOn: ticket.raisedDt,
            dueDate: ticket.dueDt,
            statusText: statusText,
            onTap: () => _navigateToAuditScreen(ticket),
            onDirectionTap: () {
              if (ticket.longitude != null && ticket.latitude != null) {
                print("Opening Google Maps for ${ticket.pvTicketId} at ${ticket.longitude}, ${ticket.latitude}");
                
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
                    content: Text('No location coordinates available for this site'),
                    backgroundColor: AppColors.errorColor,
                  ),
                );
              }
            },
            onDownloadTap: () {
              _showClearDatabaseDialog();
            },
          ),
        );
      },
    );
  }


  void _showClearDatabaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Database'),
        content: const Text(
          'This will clear all cached data from the database. This action cannot be undone.\n\n'
              'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearDatabase();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearDatabase() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Clearing database...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Clear the database
      await _service.clearAllData();

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error clearing database: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                fontFamily: fontFamilyMontserrat
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTickets,
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
}
