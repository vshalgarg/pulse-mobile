import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_logger.dart';

class ApiLoggingInterceptor extends Interceptor {
  final bool logRequests;
  final bool logResponses;
  final bool logErrors;
  final bool logHeaders;

  ApiLoggingInterceptor({
    this.logRequests = true,
    this.logResponses = true,
    this.logErrors = true,
    this.logHeaders = true,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (logRequests) {
      _logRequest(options);
      // Also log to file
      ApiLogger.logRequest(
        method: options.method,
        url: '${options.baseUrl}${options.path}',
        headers: options.headers,
        queryParameters: options.queryParameters,
        data: options.data,
        requestId: options.extra['requestId']?.toString(),
      );
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (logResponses) {
      _logResponse(response);
      // Also log to file
      ApiLogger.logResponse(
        method: response.requestOptions.method,
        url: '${response.requestOptions.baseUrl}${response.requestOptions.path}',
        statusCode: response.statusCode ?? 0,
        statusMessage: response.statusMessage,
        headers: response.headers.map,
        data: response.data,
        requestId: response.requestOptions.extra['requestId']?.toString(),
      );
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (logErrors) {
      _logError(err);
      // Also log to file
      ApiLogger.logError(
        method: err.requestOptions.method,
        url: '${err.requestOptions.baseUrl}${err.requestOptions.path}',
        errorType: err.type.toString(),
        errorMessage: err.message ?? 'Unknown error',
        statusCode: err.response?.statusCode,
        statusMessage: err.response?.statusMessage,
        headers: err.response?.headers.map,
        responseData: err.response?.data,
        requestData: err.requestOptions.data,
        requestId: err.requestOptions.extra['requestId']?.toString(),
      );
    }
    super.onError(err, handler);
  }

  void _logRequest(RequestOptions options) {
    final timestamp = DateTime.now().toIso8601String();
    final method = options.method.toUpperCase();
    final url = '${options.baseUrl}${options.path}';
    
    developer.log(
      '🚀 API REQUEST [$method]',
      name: 'API_REQUEST',
      time: DateTime.now(),
    );
    
    developer.log(
      'URL: $url',
      name: 'API_REQUEST',
    );
    
    if (logHeaders && options.headers.isNotEmpty) {
      developer.log(
        'Headers: ${_formatJson(options.headers)}',
        name: 'API_REQUEST',
      );
    }
    
    if (options.queryParameters.isNotEmpty) {
      developer.log(
        'Query Parameters: ${_formatJson(options.queryParameters)}',
        name: 'API_REQUEST',
      );
    }
    
    if (options.data != null) {
      if (options.data is FormData) {
        developer.log(
          'Request Data: FormData with ${(options.data as FormData).fields.length} fields and ${(options.data as FormData).files.length} files',
          name: 'API_REQUEST',
        );
        
        // Log form fields
        final formData = options.data as FormData;
        if (formData.fields.isNotEmpty) {
          final fields = <String, dynamic>{};
          for (final field in formData.fields) {
            fields[field.key] = field.value;
          }
          developer.log(
            'Form Fields: ${_formatJson(fields)}',
            name: 'API_REQUEST',
          );
        }
      } else {
        developer.log(
          'Request Data: ${_formatJson(options.data)}',
          name: 'API_REQUEST',
        );
      }
    }
    
    developer.log(
      'Timestamp: $timestamp',
      name: 'API_REQUEST',
    );
    
    developer.log(
      '─' * 80,
      name: 'API_REQUEST',
    );
  }

  void _logResponse(Response response) {
    final timestamp = DateTime.now().toIso8601String();
    final method = response.requestOptions.method.toUpperCase();
    final url = '${response.requestOptions.baseUrl}${response.requestOptions.path}';
    final statusCode = response.statusCode;
    final statusMessage = response.statusMessage ?? 'Unknown';
    
    developer.log(
      '✅ API RESPONSE [$method]',
      name: 'API_RESPONSE',
      time: DateTime.now(),
    );
    
    developer.log(
      'URL: $url',
      name: 'API_RESPONSE',
    );
    
    developer.log(
      'Status: $statusCode $statusMessage',
      name: 'API_RESPONSE',
    );
    
    if (logHeaders && response.headers.map.isNotEmpty) {
      developer.log(
        'Response Headers: ${_formatJson(response.headers.map)}',
        name: 'API_RESPONSE',
      );
    }
    
    if (response.data != null) {
      developer.log(
        'Response Data: ${_formatJson(response.data)}',
        name: 'API_RESPONSE',
      );
    }
    
    developer.log(
      'Response Size: ${_getResponseSize(response)}',
      name: 'API_RESPONSE',
    );
    
    developer.log(
      'Timestamp: $timestamp',
      name: 'API_RESPONSE',
    );
    
    developer.log(
      '─' * 80,
      name: 'API_RESPONSE',
    );
  }

  void _logError(DioException error) {
    final timestamp = DateTime.now().toIso8601String();
    final method = error.requestOptions.method.toUpperCase();
    final url = '${error.requestOptions.baseUrl}${error.requestOptions.path}';
    final statusCode = error.response?.statusCode;
    final statusMessage = error.response?.statusMessage ?? 'Unknown';
    
    developer.log(
      '❌ API ERROR [$method]',
      name: 'API_ERROR',
      time: DateTime.now(),
    );
    
    developer.log(
      'URL: $url',
      name: 'API_ERROR',
    );
    
    developer.log(
      'Error Type: ${error.type}',
      name: 'API_ERROR',
    );
    
    developer.log(
      'Error Message: ${error.message}',
      name: 'API_ERROR',
    );
    
    if (statusCode != null) {
      developer.log(
        'Status: $statusCode $statusMessage',
        name: 'API_ERROR',
      );
    }
    
    if (logHeaders && error.response?.headers.map.isNotEmpty == true) {
      developer.log(
        'Response Headers: ${_formatJson(error.response!.headers.map)}',
        name: 'API_ERROR',
      );
    }
    
    if (error.response?.data != null) {
      developer.log(
        'Error Response Data: ${_formatJson(error.response!.data)}',
        name: 'API_ERROR',
      );
    }
    
    if (error.requestOptions.data != null) {
      developer.log(
        'Request Data: ${_formatJson(error.requestOptions.data)}',
        name: 'API_ERROR',
      );
    }
    
    developer.log(
      'Timestamp: $timestamp',
      name: 'API_ERROR',
    );
    
    developer.log(
      '─' * 80,
      name: 'API_ERROR',
    );
  }

  String _formatJson(dynamic data) {
    try {
      if (data == null) return 'null';
      if (data is String) return data;
      if (data is Map || data is List) {
        return const JsonEncoder.withIndent('  ').convert(data);
      }
      return data.toString();
    } catch (e) {
      return 'Error formatting JSON: $e';
    }
  }

  String _getResponseSize(Response response) {
    try {
      if (response.data == null) return '0 bytes';
      
      String dataString;
      if (response.data is String) {
        dataString = response.data as String;
      } else {
        dataString = jsonEncode(response.data);
      }
      
      final bytes = dataString.length;
      if (bytes < 1024) {
        return '$bytes bytes';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(2)} KB';
      } else {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
    } catch (e) {
      return 'Unknown size';
    }
  }
}
