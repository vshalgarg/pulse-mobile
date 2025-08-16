import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import 'api_provider.dart';
import 'dio_exception.dart';

class ApiService {
  ApiProvider apiProvider;

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

      // If Dio didn't automatically decode the JSON, manually decode it.
      if (result.data is String) {
        return ResponseResult.success(jsonDecode(result.data));
      }

      return ResponseResult.success(result.data);
    } on DioException catch (e) {
      // log("path: $path");
      _recordError(e);
      return ResponseResult.error(
        errorMessage: DioExceptions.fromDioError(dioError: e).errorMessage(),
        dioErrorType: e.type,
      );
    }
  }

  Future<ResponseResult<T>> post<T>({
    required String path,
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    List<MultipartFile>? files,
    bool useFormDataFormat = false,
  }) async {
    try {
      final dataPayload = useFormDataFormat ? (data != null ? FormData.fromMap(data) : null) : data;

      if (dataPayload is FormData && files != null) {
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          dataPayload.files.add(MapEntry('image_$i', file));
        }
      }

      final result = await apiProvider.getClient().post(
            path,
            data: dataPayload,
            queryParameters: queryParameters,
            options: Options(headers: headers),
          );

      // If Dio didn't automatically decode the JSON, manually decode it.
      if (result.data is String) {
        return ResponseResult.success(jsonDecode(result.data));
      }

      return ResponseResult.success(result.data);
    } on DioException catch (e) {
      // log("path: $path");
      _recordError(e);
      return ResponseResult.error(
        errorMessage: DioExceptions.fromDioError(dioError: e).errorMessage(),
        dioErrorType: e.type,
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

      return ResponseResult.success(result.data);
    } on DioException catch (e) {
      // log("path: $path");
      _recordError(e);
      return ResponseResult.error(
        errorMessage: DioExceptions.fromDioError(dioError: e).errorMessage(),
        dioErrorType: e.type,
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

      return ResponseResult.success(result.data);
    } on DioException catch (e) {
      // log("path: $path");
      _recordError(e);
      return ResponseResult.error(
        errorMessage: DioExceptions.fromDioError(dioError: e).errorMessage(),
        dioErrorType: e.type,
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

      return ResponseResult.success(result.data);
    } on DioException catch (e) {
      // log("path: $path");
      _recordError(e);
      return ResponseResult.error(
        errorMessage: DioExceptions.fromDioError(dioError: e).errorMessage(),
        dioErrorType: e.type,
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
  }
}

class ResponseResult<T> extends Equatable {
  final T? data;
  final String? errorMessage;
  final DioExceptionType? dioErrorType;

  const ResponseResult.success(this.data)
      : errorMessage = null,
        dioErrorType = null;

  const ResponseResult.error({
    required this.errorMessage,
    this.dioErrorType,
  }) : data = null;

  bool get isSuccess => errorMessage == null;

  @override
  List<Object?> get props => [data, errorMessage];
}
