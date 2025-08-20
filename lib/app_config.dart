import 'package:app/repositories/auth_repository.dart';
import 'package:app/repositories/demo_repository.dart';

import 'services/api_provider.dart';
import 'services/api_service.dart';

class AppConfig {
  late final ApiService apiService;
  late final ApiProvider apiProvider;

  late final DemoRepository askRepository;
  late final AuthRepository authRepository;

  AppConfig({required String baseUrl}) {
    apiProvider = ApiProvider(baseUrl: baseUrl);
    apiService = ApiService(apiProvider);
  }

  void initialize() {
    askRepository = DemoRepository(apiService);
    authRepository = AuthRepository(apiService);
  }
}
