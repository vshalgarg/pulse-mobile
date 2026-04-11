import 'dart:io';

import 'package:dio/dio.dart';

import '../services/local_storage_db.dart';

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
        final err = dioError.error;
        final msg = dioError.message ?? '';
        final blob = '$msg ${err ?? ''}'.toLowerCase();

        if (err is SocketException) {
          message =
              'No internet connection (${err.message}). Please check Wi-Fi or mobile data.';
          break;
        }
        if (err is HandshakeException) {
          message =
              'Secure connection failed (TLS handshake). Check device date/time, VPN, or try another network.';
          break;
        }
        if (blob.contains('socketexception')) {
          message =
              'No Internet connection. Please check your network and try again.';
          break;
        }
        if (blob.contains('handshake') ||
            blob.contains('certificate') ||
            blob.contains('ssl')) {
          message =
              'Secure connection failed. Check device date/time and network settings.';
          break;
        }
        if (blob.contains('timeout')) {
          message =
              'Request timed out. Please check your connection and try again.';
          break;
        }
        if (blob.contains('connection')) {
          message =
              'Unable to connect to server. Please check your internet connection.';
          break;
        }
        if (blob.contains('failed host lookup') ||
            blob.contains('network is unreachable')) {
          message =
              'Could not reach the server. Check DNS, firewall, or try again later.';
          break;
        }
        // Preserve root cause for support (truncated); statusCode is null — no HTTP response.
        final detail = [msg, err?.toString()]
            .map((e) => e?.trim() ?? '')
            .where((e) => e.isNotEmpty)
            .join(' — ');
        message = detail.isEmpty
            ? 'Connection failed before a response was received. Please try again.'
            : (detail.length > 180
                ? '${detail.substring(0, 180)}…'
                : detail);
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
    await LocalStorageDB.clearAllData();
    // message = errorResponseModel.message ?? "";
    // return pushNamedAndRemoveUntil(navigatorKey.currentContext!, loginScreen);
  }

  String errorMessage() => message;

  int errorStatusCode() => statusCode;
}
