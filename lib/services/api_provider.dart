import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../app_root.dart';
import '../constants/constants_methods.dart';
import '../hive_local_database/hive_constant.dart';
import '../hive_local_database/hive_db.dart';
import '../routes/routes.dart';

class ApiProvider {
  final String baseUrl;
  var boxes = Hive.box(HiveConstant.userCreds);

  final Dio _dio = Dio();

  ApiProvider({required this.baseUrl}) {
    BaseOptions options = BaseOptions(
      headers: {
        'content-Type': 'application/json',
        'accept': 'application/json',
      },
      baseUrl: baseUrl,
      receiveDataWhenStatusError: true,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    );

    _dio.options = options;
    _dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isAuthEndpoint = options.path.contains('authenticate/login');
          
          if (!isAuthEndpoint) {
            if (HiveDB.getToken != null) {
              options.headers['Authorization'] = 'Bearer ${HiveDB.getToken}';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Token is invalid or expired
            await _logoutUser();
            return handler.next(e);
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<void> _logoutUser() async {
    try {
      await HiveDB.logout();
      // Navigate to login screen
      if (navigatorKey.currentContext != null) {
        pushNamedAndRemoveUntil(navigatorKey.currentContext!, loginScreen);
      }
    } catch (e) {
      print('Logout failed: $e');
    }
  }

  Dio getClient() => _dio;
}
