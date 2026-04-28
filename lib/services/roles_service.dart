import 'package:flutter/foundation.dart';

import '../models/user_role_screen.dart';
import 'api_service.dart';

class RolesService {
  final ApiService _apiService;

  RolesService({required ApiService apiService}) : _apiService = apiService;

  static const String _modulesScreensPath =
      'api/v1/admin/loggedInUser/modules-screens';

  Future<ResponseResult<List<UserRoleScreen>>> getUserRoles() async {
    try {
      final response = await _apiService.get<dynamic>(
        path: _modulesScreensPath,
        queryParameters: {'screenType': 'MOBILE'},
      );

      if (response.errorMessage != null) {
        return ResponseResult.error(
          errorMessage: response.errorMessage!,
          dioErrorType: response.dioErrorType,
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      if (data is! List<dynamic>) {
        debugPrint(
          '❌ RolesService.getUserRoles: unexpected body type ${data.runtimeType}',
        );
        return ResponseResult.error(
          errorMessage: 'Unexpected response format',
          statusCode: response.statusCode,
        );
      }

      final List<UserRoleScreen> screens = [];
      for (final module in data) {
        if (module is Map) {
          final moduleMap = Map<String, dynamic>.from(module);
          final moduleScreens = moduleMap['screens'];
          if (moduleScreens is List<dynamic>) {
            for (final screen in moduleScreens) {
              if (screen is Map) {
                final parsed = UserRoleScreen.fromJson(
                  Map<String, dynamic>.from(screen),
                );
                if (parsed.screenId > 0) {
                  screens.add(parsed);
                }
              }
            }
          }
        }
      }

      return ResponseResult.success(screens, response.statusCode);
    } catch (e) {
      debugPrint('❌ RolesService.getUserRoles: $e');
      return ResponseResult.error(
        errorMessage: 'Exception occurred: ${e.toString()}',
      );
    }
  }
}
