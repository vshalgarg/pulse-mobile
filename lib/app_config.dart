import 'package:app/bloc/global_loading_cubit.dart';
import 'package:app/repositories/auth_repository.dart';
import 'package:app/repositories/demo_repository.dart';
import 'package:app/repositories/dashboard_repository.dart';
import 'package:app/repositories/pmis_repository.dart';
import 'package:app/repositories/pmis_activities_repository.dart';
import 'package:app/repositories/pmis_module_repository.dart';
import 'package:app/repositories/pmis_submodule_repository.dart';
import 'package:app/repositories/pmis_site_repository.dart';
import 'package:app/repositories/pmis_state_repository.dart';
import 'package:app/repositories/ticket_repository.dart';
import 'package:app/repositories/energy_reading_repository.dart';

import 'package:app/repositories/selfie_upload_repository.dart';
import 'package:app/repositories/asset_audit_photo_upload_repository.dart';
import 'package:app/repositories/image_repository.dart';
import 'package:app/repositories/audit_schedule_repository.dart';

import 'services/api_provider.dart';
import 'services/api_service.dart';
import 'services/pmis_service.dart';
import 'services/pmis_activities_service.dart';
import 'services/pmis_module_service.dart';
import 'services/pmis_submodule_service.dart';
import 'services/pmis_site_service.dart';
import 'services/pmis_state_service.dart';
import 'services/ticket_service.dart';
import 'services/user_details_service.dart';

import 'bloc/demo_bloc_cubit.dart';
import 'bloc/login_bloc/auth_cubit.dart';
import 'bloc/dashboard_cubit.dart';
import 'bloc/ticket_cubit.dart';

import 'bloc/selfie_upload_cubit.dart';
import 'bloc/asset_audit_photo_upload_cubit.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';

class AppConfig {
  late final ApiService apiService;
  late final ApiProvider apiProvider;
  final GlobalLoadingCubit globalLoadingCubit;

  late final DemoRepository askRepository;
  late final AuthRepository authRepository;
  late final DashboardRepository dashboardRepository;
  late final TicketRepository ticketRepository;
  late final PmisRepository pmisRepository;
  late final PmisActivitiesRepository pmisActivitiesRepository;
  late final PmisStateRepository pmisStateRepository;
  late final PmisSiteRepository pmisSiteRepository;
  late final PmisModuleRepository pmisModuleRepository;
  late final PmisSubModuleRepository pmisSubModuleRepository;
  late final EnergyReadingRepository energyReadingRepository;

  late final SelfieUploadRepository selfieUploadRepository;
  late final AssetAuditPhotoUploadRepository assetAuditPhotoUploadRepository;
  late final ImageRepository imageRepository;
  late final AuditScheduleRepository auditScheduleRepository;

  // Cubits
  late final DemoBlocCubit demoBlocCubit;
  late final AuthCubit authCubit;
  late final DashboardCubit dashboardCubit;
  late final TicketCubit ticketCubit;

  late final SelfieUploadCubit selfieUploadCubit;
  late final AssetAuditPhotoUploadCubit assetAuditPhotoUploadCubit;

  AppConfig({required String baseUrl, required GlobalLoadingCubit loadingCubit}) 
      : globalLoadingCubit = loadingCubit {
    
    // Create single ApiProvider instance
    apiProvider = ApiProvider(baseUrl: baseUrl, loadingCubit: loadingCubit);
    apiService = ApiService(apiProvider);
    auditScheduleRepository = AuditScheduleRepository(apiService);

    // Initialize ticket service
    final ticketService = TicketService(apiService: apiService);
    final pmisService = PmisService(apiService: apiService);

    // Initialize repositories
    askRepository = DemoRepository(apiService);
    authRepository = AuthRepository(apiService);
    dashboardRepository = DashboardRepository(apiService);
    ticketRepository = TicketRepository(ticketService: ticketService);
    pmisRepository = PmisRepository(pmisService: pmisService);
    final pmisActivitiesService =
        PmisActivitiesService(apiService: apiService);
    pmisActivitiesRepository =
        PmisActivitiesRepository(pmisService: pmisActivitiesService);
    final pmisStateService = PmisStateService(apiService: apiService);
    pmisStateRepository =
        PmisStateRepository(pmisStateService: pmisStateService);
    final pmisSiteService = PmisSiteService(apiService: apiService);
    pmisSiteRepository =
        PmisSiteRepository(pmisSiteService: pmisSiteService);
    final pmisModuleService = PmisModuleService(apiService: apiService);
    pmisModuleRepository =
        PmisModuleRepository(pmisModuleService: pmisModuleService);
    final pmisSubModuleService = PmisSubModuleService(apiService: apiService);
    pmisSubModuleRepository =
        PmisSubModuleRepository(pmisSubModuleService: pmisSubModuleService);

    // Initialize user details service
    UserDetailsService.instance.initialize(apiService);
    energyReadingRepository = EnergyReadingRepository(apiService);
    
    selfieUploadRepository = SelfieUploadRepository(apiService);
    assetAuditPhotoUploadRepository = AssetAuditPhotoUploadRepository(apiService);
    imageRepository = ImageRepository(apiProvider);

    // Initialize cubits
    demoBlocCubit = DemoBlocCubit(askRepository);
    authCubit = AuthCubit(authRepository);
    dashboardCubit = DashboardCubit(dashboardRepository);
    ticketCubit = TicketCubit(ticketRepository: ticketRepository);
    
    selfieUploadCubit = SelfieUploadCubit(selfieUploadRepository);
    assetAuditPhotoUploadCubit = AssetAuditPhotoUploadCubit(assetAuditPhotoUploadRepository);
  }

  static AppConfig of(BuildContext context) {
    return context.read<AppConfig>();
  }
}
