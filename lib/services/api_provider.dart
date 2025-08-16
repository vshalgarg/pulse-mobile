import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../app_root.dart';
import '../constants/api_codes.dart';
import '../constants/constants_methods.dart';
import '../hive_local_database/hive_constant.dart';
import '../hive_local_database/hive_db.dart';
import '../routes/routes.dart';

class ApiProvider {
  final String baseUrl;
  var boxes = Hive.box(HiveConstant.userCreds);

  final Dio _dio = Dio();

  // dio.options.headers['content-Type'] = 'application/json';
  // dio.options.headers["authorization"] = "token ${token}";
  ApiProvider({required this.baseUrl}) {
    BaseOptions options = BaseOptions(
      headers: {
        'content-Type': 'application/json',
        'accept': 'application/json',
      },
      baseUrl: baseUrl,
      receiveDataWhenStatusError: true,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    );

    // if (HiveDB.getUserId != null) _dio.options.headers["userId"] = "${HiveDB.getUserId}";
    // if (HiveDB.getToken != null) _dio.options.headers["Authorization"] = "Bearer ${HiveDB.getToken}";
    _dio.options = options;
    _dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add the access token to the request header
          // if (HiveDB.getUserId != null) options.headers["userId"] = "${HiveDB.getUserId}";
          // if (HiveDB.getToken != null) options.headers['Authorization'] = 'Bearer ${HiveDB.getToken}';

          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // If a 401 response is received, refresh the access token
           /* final newAccessToken = await refreshToken();
            if (newAccessToken == null) return;
            _dio.options.headers['Authorization'] = 'Bearer $newAccessToken';
            return handler.resolve(await _dio.fetch(e.requestOptions));*/
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio getClient() => _dio;

 /* // refresh token
  Future<String?> refreshToken() async {
    try {
      final result = await navigatorKey.currentContext?.read<RefreshTokenRepository>().refreshToken();
      if (result!.isSuccess) {
        final data = result.data;
        if (data?.responseCode == ApiCodes.recordFetched) {
          if (data?.data != null) {
            boxes.put(HiveConstant.token, data?.data?.access);
            final tokenGet = boxes.get('token');
            kDebugPrint("Bearer token- $tokenGet");
            return data?.data?.access;
          }
        }
      }
      //TODO not success case pending
    } catch (exception) {
      HiveDB.clearAllData();
      Future.delayed(const Duration(milliseconds: 10), () {
        // pushNamedAndRemoveUntil(context, loginScreen);
        pushNamedAndRemoveUntil(navigatorKey.currentContext!, mainScreen);
      });
    }
    return null;
  }*/
}
