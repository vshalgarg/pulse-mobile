import 'package:dio/dio.dart';

import '../app_root.dart';
import '../constants/constants_methods.dart';
import '../hive_local_database/hive_db.dart';
import '../routes/routes.dart';

class DioExceptions implements Exception {
  static String message = "";
  static int statusCode = -1;

  DioExceptions.fromDioError({required DioException dioError}) {
    switch (dioError.type) {
      case DioExceptionType.cancel:
        message = "Request to API server was cancelled";
        break;
      case DioExceptionType.connectionTimeout:
        message = "Connection timeout with API server";
        break;
      case DioExceptionType.receiveTimeout:
        message = "Receive timeout in connection with API server";
        break;
      case DioExceptionType.sendTimeout:
        message = "Send timeout in connection with API server";
        break;
      case DioExceptionType.badCertificate:
        message = "Handshake error in client CERTIFICATE_VERIFY_FAILED";
        break;
      case DioExceptionType.badResponse:
        if (dioError.response!.statusCode == 400) {
          message = dioError.response!.statusMessage!;
          break;
        }
        _handleError(dioError.response?.statusCode, dioError);
        break;
      case DioExceptionType.unknown:
        if (dioError.message.toString().contains("SocketException")) {
          message = 'No Internet';
          break;
        }
        message = "Receive timeout in connection with API server";
        break;
      default:
        message = "Something went wrong";
        break;
    }
  }

  _handleError(int? statusCode, dynamic error) {
    switch (statusCode) {
      case 401:
        // kDebugPrint('$error');
        // return sessionExpire(error);
        return error;
      case 500:
        return error;
      default:
        return error;
    }
  }

  sessionExpire(dynamic error) async {
    await HiveDB.clearAllData();
    // message = errorResponseModel.message ?? "";
    // return pushNamedAndRemoveUntil(navigatorKey.currentContext!, loginScreen);
  }

  String errorMessage() => message;

  int errorStatusCode() => statusCode;
}
