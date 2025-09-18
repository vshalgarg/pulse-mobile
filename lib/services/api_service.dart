import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import 'api_provider.dart';
import 'dio_exception.dart';

class ApiService {
  final ApiProvider apiProvider;

  String get baseUrl => apiProvider.baseUrl;

  ApiService(this.apiProvider);

  Future<ResponseResult<T>> get<T>({
    required String path,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    bool refreshCache = false,
  }) async {
    try {
      final result = await apiProvider.getClient().get(
            path,
            queryParameters: queryParameters,
            options: Options(headers: headers),
          );

      // Check if status code is 200 for success
      if (result.statusCode == 200) {
        // If Dio didn't automatically decode the JSON, manually decode it.
        if (result.data is String) {
          return ResponseResult.success(jsonDecode(result.data), result.statusCode);
        }
        return ResponseResult.success(result.data, result.statusCode);
      } else {
        return ResponseResult.error(
          errorMessage: 'Request failed with status code: ${result.statusCode}',
          statusCode: result.statusCode,
        );
      }
    } on DioException catch (e) {
      // log("path: $path");
      _recordError(e);
      return ResponseResult.error(
        errorMessage: DioExceptions.fromDioError(dioError: e).errorMessage(),
        dioErrorType: e.type,
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ResponseResult<T>> post<T>({
    required String path,
    dynamic data, // Changed from Map<String, dynamic>? to dynamic
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    List<MultipartFile>? files,
    bool useFormDataFormat = false,
  }) async {
    try {

      dynamic dataPayload;
      
      if (useFormDataFormat) {
        // Handle FormData creation
        if (data is Map<String, dynamic>) {
          dataPayload = FormData.fromMap(data);
        } else {
          dataPayload = null;
        }
        
        if (dataPayload is FormData && files != null) {
          for (int i = 0; i < files.length; i++) {
            final file = files[i];
            dataPayload.files.add(MapEntry('Documents', file));
          }
        }
      } else {
        // Send data directly (could be Map, List, or any JSON-serializable type)
        dataPayload = data;
      }

      final result = await apiProvider.getClient().post(
            path,
            data: dataPayload,
            queryParameters: queryParameters,
            options: Options(headers: headers),
          );

      // Check if status code indicates success (200, 201, 202, etc.)
      if (result.statusCode! >= 200 && result.statusCode! < 300) {
        // If Dio didn't automatically decode the JSON, manually decode it.
        if (result.data is String) {
          return ResponseResult.success(jsonDecode(result.data), result.statusCode);
        }
        return ResponseResult.success(result.data, result.statusCode);
      } else {
        return ResponseResult.error(
          errorMessage: 'Request failed with status code: ${result.statusCode}',
          statusCode: result.statusCode,
        );
      }
    } on DioException catch (e) {
       // log("path: $path");
      _recordError(e);
      return ResponseResult.error(
        errorMessage: DioExceptions.fromDioError(dioError: e).errorMessage(),
        dioErrorType: e.type,
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      print("ApiService: General exception caught - $e");
      return ResponseResult.error(
        errorMessage: 'Request failed: $e',
      );
    }
  }

  Future<ResponseResult<T>> put<T>({
    required String path,
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    List<MultipartFile>? files,
    bool useFormDataFormat = true,
  }) async {
    try {
      final dataPayload = useFormDataFormat ? (data != null ? FormData.fromMap(data) : null) : data;

      if (dataPayload is FormData && files != null) {
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          dataPayload.files.add(MapEntry('image_$i', file));
        }
      }

      final result = await apiProvider.getClient().put(
            path,
            data: dataPayload,
            queryParameters: queryParameters,
            options: Options(headers: headers),
          );

      // Check if status code is 200 for success
      if (result.statusCode == 200) {
        return ResponseResult.success(result.data, result.statusCode);
      } else {
        return ResponseResult.error(
          errorMessage: 'Request failed with status code: ${result.statusCode}',
          statusCode: result.statusCode,
        );
      }
    } on DioException catch (e) {
      // log("path: $path");
      _recordError(e);
      return ResponseResult.error(
        errorMessage: DioExceptions.fromDioError(dioError: e).errorMessage(),
        dioErrorType: e.type,
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ResponseResult<T>> patch<T>({
    required String path,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  }) async {
    try {
      final result = await apiProvider.getClient().patch(
            path,
            data: data,
            options: Options(headers: headers),
          );

      // Check if status code is 200 for success
      if (result.statusCode == 200) {
        return ResponseResult.success(result.data, result.statusCode);
      } else {
        return ResponseResult.error(
          errorMessage: 'Request failed with status code: ${result.statusCode}',
          statusCode: result.statusCode,
        );
      }
    } on DioException catch (e) {
      // log("path: $path");
      _recordError(e);
      return ResponseResult.error(
        errorMessage: DioExceptions.fromDioError(dioError: e).errorMessage(),
        dioErrorType: e.type,
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<ResponseResult<T>> delete<T>({
    required String path,
    Map<String, String>? headers,
  }) async {
    try {
      final result = await apiProvider.getClient().delete(
            path,
            options: Options(headers: headers),
          );

      // Check if status code is 200 for success
      if (result.statusCode == 200) {
        return ResponseResult.success(result.data, result.statusCode);
      } else {
        return ResponseResult.error(
          errorMessage: 'Request failed with status code: ${result.statusCode}',
          statusCode: result.statusCode,
        );
      }
    } on DioException catch (e) {
      // log("path: $path");
      _recordError(e);
      return ResponseResult.error(
        errorMessage: DioExceptions.fromDioError(dioError: e).errorMessage(),
        dioErrorType: e.type,
        statusCode: e.response?.statusCode,
      );
    }
  }

  void _recordError(DioException error) {
    // FirebaseCrashlytics.instance.recordError(
    //   error.error,
    //   error.stackTrace,
    //   reason: '${error.message} (${error.requestOptions.uri})',
    //   printDetails: true,
    // );
    print("API Error: ${error.message}");
    print("API Error Type: ${error.type}");
    print("API Error Response: ${error.response?.data}");
  }


}

class ResponseResult<T> extends Equatable {
  final T? data;
  final String? errorMessage;
  final DioExceptionType? dioErrorType;
  final int? statusCode;

  const ResponseResult.success(this.data, this.statusCode)
      : errorMessage = null,
        dioErrorType = null;

  const ResponseResult.error({
    required this.errorMessage,
    this.dioErrorType,
    this.statusCode,
  }) : data = null;

  bool get isSuccess => errorMessage == null && statusCode == 200;

  @override
  List<Object?> get props => [data, errorMessage, statusCode];
}
