import 'package:app/repositories/demo_repository.dart';

import 'services/api_provider.dart';
import 'services/api_service.dart';

class AppConfig {
  final ApiService apiService;

  late final DemoRepository askRepository;

  AppConfig({required String baseUrl})
      : apiService = ApiService(
          ApiProvider(baseUrl: baseUrl),
        );

  void initialize() {
    askRepository = DemoRepository(apiService);
  }
}
