import 'package:app/repositories/auth_repository.dart';
import 'package:app/repositories/demo_repository.dart';
import 'package:app/repositories/dashboard_repository.dart';
import 'package:app/repositories/ticket_repository.dart';

import 'services/api_provider.dart';
import 'services/api_service.dart';
import 'services/ticket_service.dart';

class AppConfig {
  late final ApiService apiService;
  late final ApiProvider apiProvider;

  late final DemoRepository askRepository;
  late final AuthRepository authRepository;
  late final DashboardRepository dashboardRepository;
  late final TicketRepository ticketRepository;

  AppConfig({required String baseUrl}) {
    apiProvider = ApiProvider(baseUrl: baseUrl);
    apiService = ApiService(apiProvider);
  }

  void initialize() {
    askRepository = DemoRepository(apiService);
    authRepository = AuthRepository(apiService);
    dashboardRepository = DashboardRepository(apiService);
    
    // Initialize ticket service and repository
    final ticketService = TicketService(apiService: apiService);
    ticketRepository = TicketRepository(ticketService: ticketService);
  }
}
