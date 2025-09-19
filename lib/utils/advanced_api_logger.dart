import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AdvancedApiLogger {
  static bool _isEnabled = true;
  static bool _logRequests = true;
  static bool _logResponses = true;
  static bool _logErrors = true;
  static bool _logHeaders = true;
  static bool _logBody = true;
  static int _maxBodyLength = 1000; // Max characters to log for body
  
  // Configure the logger
  static void configure({
    bool enabled = true,
    bool logRequests = true,
    bool logResponses = true,
    bool logErrors = true,
    bool logHeaders = true,
    bool logBody = true,
    int maxBodyLength = 1000,
  }) {
    _isEnabled = enabled;
    _logRequests = logRequests;
    _logResponses = logResponses;
    _logErrors = logErrors;
    _logHeaders = logHeaders;
    _logBody = logBody;
    _maxBodyLength = maxBodyLength;
  }
  
  static void logRequest(RequestOptions options) {
    if (!_isEnabled || !_logRequests) return;
    
    final buffer = StringBuffer();
    buffer.writeln('\n${'🌐' * 20} REQUEST ${'🌐' * 20}');
    buffer.writeln('${options.method} ${options.uri}');
    buffer.writeln('${'─' * 60}');
    
    if (_logHeaders && options.headers.isNotEmpty) {
      buffer.writeln('📋 Headers:');
      options.headers.forEach((key, value) {
        buffer.writeln('   $key: $value');
      });
      buffer.writeln('');
    }
    
    if (options.queryParameters.isNotEmpty) {
      buffer.writeln('🔍 Query Parameters:');
      options.queryParameters.forEach((key, value) {
        buffer.writeln('   $key: $value');
      });
      buffer.writeln('');
    }
    
    if (_logBody && options.data != null) {
      buffer.writeln('📦 Request Body:');
      final bodyString = _formatData(options.data);
      buffer.writeln(bodyString);
    }
    
    buffer.writeln('${'🌐' * 50}');
    debugPrint(buffer.toString());
  }
  
  static void logResponse(Response response) {
    if (!_isEnabled || !_logResponses) return;
    
    final buffer = StringBuffer();
    final statusEmoji = _getStatusEmoji(response.statusCode);
    buffer.writeln('\n${statusEmoji * 20} RESPONSE ${statusEmoji * 20}');
    buffer.writeln('${response.requestOptions.method} ${response.requestOptions.uri}');
    buffer.writeln('Status: ${response.statusCode} ${response.statusMessage}');
    buffer.writeln('${'─' * 60}');
    
    if (_logHeaders && response.headers.map.isNotEmpty) {
      buffer.writeln('📋 Response Headers:');
      response.headers.map.forEach((key, value) {
        buffer.writeln('   $key: ${value.join(', ')}');
      });
      buffer.writeln('');
    }
    
    if (_logBody && response.data != null) {
      buffer.writeln('📦 Response Body:');
      final bodyString = _formatData(response.data);
      buffer.writeln(bodyString);
    }
    
    buffer.writeln('${statusEmoji * 50}');
    debugPrint(buffer.toString());
  }
  
  static void logError(DioException error) {
    if (!_isEnabled || !_logErrors) return;
    
    final buffer = StringBuffer();
    buffer.writeln('\n${'❌' * 20} ERROR ${'❌' * 20}');
    buffer.writeln('${error.requestOptions.method} ${error.requestOptions.uri}');
    buffer.writeln('${'─' * 60}');
    buffer.writeln('❌ Type: ${error.type}');
    buffer.writeln('❌ Message: ${error.message}');
    
    if (error.response != null) {
      buffer.writeln('📥 Status: ${error.response?.statusCode}');
      if (_logBody && error.response?.data != null) {
        buffer.writeln('📥 Data:');
        final bodyString = _formatData(error.response?.data);
        buffer.writeln(bodyString);
      }
    }
    
    buffer.writeln('${'❌' * 50}');
    debugPrint(buffer.toString());
  }
  
  static String _formatData(dynamic data) {
    try {
      String jsonString;
      if (data is String) {
        jsonString = data;
      } else {
        jsonString = const JsonEncoder.withIndent('  ').convert(data);
      }
      
      // Filter out image data to prevent log spam
      jsonString = _filterImageData(jsonString);
      
      // Check if we should truncate
      bool isTruncated = false;
      if (jsonString.length > _maxBodyLength) {
        jsonString = '${jsonString.substring(0, _maxBodyLength)}...\n[TRUNCATED - ${jsonString.length} characters total]';
        isTruncated = true;
      }
      
      final buffer = StringBuffer();
      
      // Add copyable JSON format (only if not truncated)
      if (!isTruncated) {
        buffer.writeln('📋 Copyable JSON:');
        buffer.writeln('```json');
        buffer.writeln(jsonString);
        buffer.writeln('```');
        buffer.writeln('');
      }
      
      // Add formatted JSON for readability
      buffer.writeln('📦 Formatted JSON:');
      final lines = jsonString.split('\n');
      for (final line in lines) {
        buffer.writeln('   $line');
      }
      
      return buffer.toString();
    } catch (e) {
      return '   $data';
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
  
  static String _getStatusEmoji(int? statusCode) {
    if (statusCode == null) return '❓';
    if (statusCode >= 200 && statusCode < 300) return '✅';
    if (statusCode >= 300 && statusCode < 400) return '🔄';
    if (statusCode >= 400 && statusCode < 500) return '⚠️';
    if (statusCode >= 500) return '💥';
    return '❓';
  }
  
  // Utility methods for manual logging
  static void logInfo(String message) {
    if (!_isEnabled) return;
    debugPrint('ℹ️ API: $message');
  }
  
  static void logSuccess(String message) {
    if (!_isEnabled) return;
    debugPrint('✅ API: $message');
  }
  
  static void logWarning(String message) {
    if (!_isEnabled) return;
    debugPrint('⚠️ API: $message');
  }
}
