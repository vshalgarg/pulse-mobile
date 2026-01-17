import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'file_logger.dart';

class ApiLogger {
  static const String _requestPrefix = '🌐 REQUEST';
  static const String _responsePrefix = '📥 RESPONSE';
  static const String _errorPrefix = '❌ ERROR';
  
  static void logRequest(RequestOptions options) {
    debugPrint('\n${'=' * 80}');
    debugPrint('$_requestPrefix ${options.method} ${options.uri}');
    debugPrint('${'=' * 80}');
    
    // Headers
    if (options.headers.isNotEmpty) {
      debugPrint('📋 Headers:');
      options.headers.forEach((key, value) {
        debugPrint('   $key: $value');
      });
    }
    
    // Query Parameters
    if (options.queryParameters.isNotEmpty) {
      debugPrint('🔍 Query Parameters:');
      options.queryParameters.forEach((key, value) {
        debugPrint('   $key: $value');
      });
    }
    
    // Request Body
    if (options.data != null) {
      debugPrint('📦 Request Body:');
      _printJsonData(options.data);
    }
    
    // Generate and print curl command
    final curlCommand = _generateCurlCommand(options);
    debugPrint('🌐 CURL Command:');
    debugPrint('```bash');
    debugPrint(curlCommand);
    debugPrint('```');
    
    debugPrint('${'=' * 80}\n');
    
    // Also log to file
    _logRequestToFile(options);
  }
  
  static void logResponse(Response response) {
    debugPrint('\n${'=' * 80}');
    debugPrint('$_responsePrefix ${response.requestOptions.method} ${response.requestOptions.uri}');
    debugPrint('Status: ${response.statusCode} | Time: ${response.statusMessage}');
    debugPrint('${'=' * 80}');
    
    // Response Headers
    if (response.headers.map.isNotEmpty) {
      debugPrint('📋 Response Headers:');
      response.headers.map.forEach((key, value) {
        debugPrint('   $key: ${value.join(', ')}');
      });
    }
    
    // Response Body
    if (response.data != null) {
      debugPrint('📦 Response Body:');
      _printJsonData(response.data);
    }
    
    debugPrint('${'=' * 80}\n');
    
    // Also log to file
    _logResponseToFile(response);
  }
  
  static void logError(DioException error) {
    debugPrint('\n${'=' * 80}');
    debugPrint('$_errorPrefix ${error.requestOptions.method} ${error.requestOptions.uri}');
    debugPrint('${'=' * 80}');
    
    debugPrint('❌ Error Type: ${error.type}');
    debugPrint('❌ Error Message: ${error.message}');
    
    if (error.response != null) {
      debugPrint('📥 Error Response Status: ${error.response?.statusCode}');
      debugPrint('📥 Error Response Data:');
      _printJsonData(error.response?.data);
    }
    
    debugPrint('${'=' * 80}\n');
    
    // Also log to file
    _logErrorToFile(error);
  }
  
  static void _printJsonData(dynamic data) {
    try {
      String jsonString;
      if (data is String) {
        jsonString = data;
      } else {
        jsonString = const JsonEncoder.withIndent('  ').convert(data);
      }
      
      // Filter out image data to prevent log spam
      jsonString = _filterImageData(jsonString);
      
      // Print copyable JSON format
      debugPrint('📋 Copyable JSON:');
      debugPrint('```json');
      debugPrint(jsonString);
      debugPrint('```');
    } catch (e) {
      debugPrint('   $data');
    }
  }
  
  static String _filterImageData(String jsonString) {
    // Filter out base64 image data
    String filtered = jsonString;
    
    // Remove base64 image data patterns
    filtered = filtered.replaceAllMapped(
      RegExp(r'"imageData":\s*"[^"]*"'),
      (match) => '"imageData": "[BASE64_IMAGE_DATA_REMOVED_FROM_LOGS]"',
    );
    
    // Remove data:image/ patterns
    filtered = filtered.replaceAllMapped(
      RegExp(r'data:image/[^;]+;base64,[A-Za-z0-9+/=]+'),
      (match) => 'data:image/jpeg;base64,[BASE64_IMAGE_DATA_REMOVED_FROM_LOGS]',
    );
    
    // Remove large base64 strings (likely images)
    filtered = filtered.replaceAllMapped(
      RegExp(r'"[A-Za-z0-9+/]{100,}={0,2}"'),
      (match) {
        final matchStr = match.group(0) ?? '';
        if (matchStr.length > 200) {
          return '"[LARGE_BASE64_DATA_REMOVED_FROM_LOGS]"';
        }
        return matchStr;
      },
    );
    
    // Remove image bytes patterns
    filtered = filtered.replaceAllMapped(
      RegExp(r'"imageBytes":\s*"[^"]*"'),
      (match) => '"imageBytes": "[IMAGE_BYTES_REMOVED_FROM_LOGS]"',
    );
    
    // Remove photo data patterns
    filtered = filtered.replaceAllMapped(
      RegExp(r'"photoData":\s*"[^"]*"'),
      (match) => '"photoData": "[PHOTO_DATA_REMOVED_FROM_LOGS]"',
    );
    
    // Remove any field containing large base64 data
    filtered = filtered.replaceAllMapped(
      RegExp(r'"[^"]*":\s*"[A-Za-z0-9+/]{500,}={0,2}"'),
      (match) => match.group(0)!.replaceAllMapped(
        RegExp(r'"[A-Za-z0-9+/]{500,}={0,2}"'),
        (innerMatch) => '"[LARGE_BASE64_DATA_REMOVED_FROM_LOGS]"',
      ),
    );
    
    return filtered;
  }
  
  static String _generateCurlCommand(RequestOptions options) {
    final buffer = StringBuffer();
    
    // Add curl command
    buffer.write('curl -X ${options.method.toUpperCase()}');
    
    // Add URL
    buffer.write(' "${options.uri}"');
    
    // Add headers
    options.headers.forEach((key, value) {
      buffer.write(' \\\n  -H "$key: $value"');
    });
    
    // Add query parameters
    if (options.queryParameters.isNotEmpty) {
      final queryString = options.queryParameters.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      buffer.write(' \\\n  -G --data-urlencode "$queryString"');
    }
    
    // Add request body
    if (options.data != null) {
      if (options.data is FormData) {
        // Handle FormData specially
        final formData = options.data as FormData;
        
        // Add form fields
        formData.fields.forEach((field) {
          buffer.write(' \\\n  --form-data "${field.key}=${field.value}"');
        });
        
        // Add files
        formData.files.forEach((file) {
          buffer.write(' \\\n  --form-data "${file.key}=@${file.value.filename}"');
        });
      } else {
        String bodyData;
        if (options.data is String) {
          bodyData = options.data as String;
        } else {
          try {
            bodyData = const JsonEncoder.withIndent('').convert(options.data);
          } catch (e) {
            bodyData = options.data.toString();
          }
        }
        
        // Filter out large base64 data for curl command
        bodyData = _filterImageData(bodyData);
        
        buffer.write(' \\\n  -d \'$bodyData\'');
      }
    }
    
    return buffer.toString();
  }
  
  static void logSimple(String message) {
    debugPrint('🔍 API: $message');
  }
  
  static void logSuccess(String message) {
    debugPrint('✅ API: $message');
  }
  
  static void logWarning(String message) {
    debugPrint('⚠️ API: $message');
  }
  
  // File logging methods
  static void _logRequestToFile(RequestOptions options) {
    // Handle FormData specially for file logging
    dynamic bodyData = options.data;
    if (options.data is FormData) {
      final formData = options.data as FormData;
      bodyData = {
        'type': 'FormData',
        'fields': formData.fields.map((e) => {'key': e.key, 'value': e.value}).toList(),
        'files': formData.files.map((e) => {'key': e.key, 'filename': e.value.filename}).toList(),
      };
    }
    
    final data = {
      'method': options.method,
      'url': options.uri.toString(),
      'headers': options.headers,
      'queryParameters': options.queryParameters,
      'body': bodyData,
    };
    FileLogger.logApiRequest(options.method, options.uri.toString(), 
        headers: options.headers, body: bodyData);
  }
  
  static void _logResponseToFile(Response response) {
    final data = {
      'method': response.requestOptions.method,
      'url': response.requestOptions.uri.toString(),
      'statusCode': response.statusCode,
      'headers': response.headers.map,
      'body': response.data,
    };
    FileLogger.logApiResponse(
      response.requestOptions.method, 
      response.requestOptions.uri.toString(), 
      response.statusCode ?? 0,
      body: response.data,
      headers: response.headers.map,
    );
  }
  
  static void _logErrorToFile(DioException error) {
    final data = {
      'method': error.requestOptions.method,
      'url': error.requestOptions.uri.toString(),
      'errorType': error.type.toString(),
      'errorMessage': error.message,
      'statusCode': error.response?.statusCode,
      'responseData': error.response?.data,
    };
    FileLogger.logApiError(
      error.requestOptions.method,
      error.requestOptions.uri.toString(),
      error.message ?? 'Unknown error',
      statusCode: error.response?.statusCode,
      body: error.response?.data,
    );
  }
}
