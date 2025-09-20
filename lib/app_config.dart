import 'package:app/bloc/global_loading_cubit.dart';
import 'package:app/repositories/auth_repository.dart';
import 'package:app/repositories/demo_repository.dart';
import 'package:app/repositories/dashboard_repository.dart';
import 'package:app/repositories/pm_repository.dart';
import 'package:app/repositories/ticket_repository.dart';
import 'package:app/repositories/energy_reading_repository.dart';
import 'package:app/repositories/energy_reading_detail_repository.dart';
import 'package:app/repositories/selfie_upload_repository.dart';
import 'package:app/repositories/asset_audit_photo_upload_repository.dart';
import 'package:app/repositories/image_repository.dart';
import 'package:app/repositories/audit_schedule_repository.dart';

import 'services/api_provider.dart';
import 'services/api_service.dart';
import 'services/ticket_service.dart';
import 'services/user_details_service.dart';

import 'bloc/demo_bloc_cubit.dart';
import 'bloc/login_bloc/auth_cubit.dart';
import 'bloc/dashboard_cubit.dart';
import 'bloc/ticket_cubit.dart';
import 'bloc/energy_reading_cubit.dart';
import 'bloc/energy_reading_detail_cubit.dart';
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
  late final EnergyReadingRepository energyReadingRepository;
  late final EnergyReadingDetailRepository energyReadingDetailRepository;
  late final SelfieUploadRepository selfieUploadRepository;
  late final AssetAuditPhotoUploadRepository assetAuditPhotoUploadRepository;
  late final ImageRepository imageRepository;
  late final PmRepository pmRepository;
  late final AuditScheduleRepository auditScheduleRepository;

  // Cubits
  late final DemoBlocCubit demoBlocCubit;
  late final AuthCubit authCubit;
  late final DashboardCubit dashboardCubit;
  late final TicketCubit ticketCubit;
  late final EnergyReadingCubit energyReadingCubit;
  late final EnergyReadingDetailCubit energyReadingDetailCubit;
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

    // Initialize repositories
    askRepository = DemoRepository(apiService);
    authRepository = AuthRepository(apiService);
    dashboardRepository = DashboardRepository(apiService);
    ticketRepository = TicketRepository(ticketService: ticketService);

    // Initialize user details service
    UserDetailsService.instance.initialize(apiService);
    energyReadingRepository = EnergyReadingRepository(apiService);
    energyReadingDetailRepository = EnergyReadingDetailRepository(apiService);
    selfieUploadRepository = SelfieUploadRepository(apiService);
    assetAuditPhotoUploadRepository = AssetAuditPhotoUploadRepository(apiService);
    imageRepository = ImageRepository(apiProvider);
    pmRepository = PmRepository(apiService: apiService);

    // Initialize cubits
    demoBlocCubit = DemoBlocCubit(askRepository);
    authCubit = AuthCubit(authRepository);
    dashboardCubit = DashboardCubit(dashboardRepository);
    ticketCubit = TicketCubit(ticketRepository: ticketRepository);
    energyReadingCubit = EnergyReadingCubit(energyReadingRepository);
    energyReadingDetailCubit = EnergyReadingDetailCubit(energyReadingDetailRepository);
    selfieUploadCubit = SelfieUploadCubit(selfieUploadRepository);
    assetAuditPhotoUploadCubit = AssetAuditPhotoUploadCubit(assetAuditPhotoUploadRepository);
  }

  static AppConfig of(BuildContext context) {
    return context.read<AppConfig>();
  }
}
