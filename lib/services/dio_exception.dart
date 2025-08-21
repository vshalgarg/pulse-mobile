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
          // Try to extract error message from response body
          try {
            final responseData = dioError.response!.data;
            if (responseData is Map<String, dynamic> && responseData.containsKey('message')) {
              message = responseData['message'];
            } else if (responseData is String) {
              message = responseData;
            } else {
              message = dioError.response!.statusMessage ?? 'Bad request';
            }
          } catch (e) {
            message = dioError.response!.statusMessage ?? 'Bad request';
          }
          break;
        }
        _handleError(dioError.response?.statusCode, dioError);
        break;
      case DioExceptionType.unknown:
        if (dioError.message.toString().contains("SocketException")) {
          message = 'No Internet connection. Please check your network and try again.';
          break;
        }
        // Check for other common network issues
        if (dioError.message.toString().contains("timeout")) {
          message = 'Request timed out. Please check your connection and try again.';
          break;
        }
        if (dioError.message.toString().contains("connection")) {
          message = 'Unable to connect to server. Please check your internet connection.';
          break;
        }
        // Log the actual error for debugging
        print("DioExceptionType.unknown - Actual error: ${dioError.message}");
        message = "Connection failed. Please try again.";
        break;
      default:
        message = "Something went wrong";
        break;
    }
  }

  _handleError(int? statusCode, dynamic error) {
    switch (statusCode) {
      case 401:
        // Try to extract error message from response body
        try {
          final responseData = error.response?.data;
          if (responseData is Map<String, dynamic> && responseData.containsKey('message')) {
            message = responseData['message'];
          } else if (responseData is String) {
            message = responseData;
          } else {
            message = 'Unauthorized access';
          }
        } catch (e) {
          message = 'Unauthorized access';
        }
        break;
      case 500:
        try {
          final responseData = error.response?.data;
          if (responseData is Map<String, dynamic> && responseData.containsKey('message')) {
            message = responseData['message'];
          } else if (responseData is String) {
            message = responseData;
          } else {
            message = 'Internal server error';
          }
        } catch (e) {
          message = 'Internal server error';
        }
        break;
      default:
        try {
          final responseData = error.response?.data;
          if (responseData is Map<String, dynamic> && responseData.containsKey('message')) {
            message = responseData['message'];
          } else if (responseData is String) {
            message = responseData;
          } else {
            message = 'Request failed with status code: $statusCode';
          }
        } catch (e) {
          message = 'Request failed with status code: $statusCode';
        }
        break;
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
