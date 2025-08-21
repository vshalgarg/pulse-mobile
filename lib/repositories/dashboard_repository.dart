import 'package:app/constants/constants_methods.dart';
import 'package:app/models/dashboard_model.dart';

import '../services/api_service.dart';

class DashboardRepository {
  ApiService apiService;

  DashboardRepository(this.apiService);

  // Dashboard count api
  Future<ResponseResult<DashboardModel?>> getDashboardCount() async {
    try {
      final result = await apiService.get<Map<String, dynamic>>(
        path: "api/v1/mobile/mobile-dashboard",
      );
      if (result.isSuccess) {
        kDebugPrint("Dashboard data is here $result.data");
        return ResponseResult.success(DashboardModel.fromJson(result.data), result.statusCode);
      } else {
        return ResponseResult.error(errorMessage: result.errorMessage);
      }
    } catch (e) {
      return const ResponseResult.error(
        errorMessage: 'We could not process your request',
      );
    }
  }
}
