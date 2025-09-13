import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ApiLogger {
  static const String _logTag = 'API_LOGGER';
  static const String _logFileName = 'api_logs.txt';
  static const int _maxLogFileSize = 5 * 1024 * 1024; // 5MB
  static const int _maxLogFiles = 5;

  static Future<void> logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    String? requestId,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = _createLogEntry(
      type: 'REQUEST',
      method: method,
      url: url,
      headers: headers,
      queryParameters: queryParameters,
      data: data,
      requestId: requestId,
      timestamp: timestamp,
    );

    await _writeToLog(logEntry);
    
    if (kDebugMode) {
      developer.log(
        '🚀 API REQUEST [$method]',
        name: _logTag,
        time: DateTime.now(),
      );
      developer.log('URL: $url', name: _logTag);
      if (headers != null && headers.isNotEmpty) {
        developer.log('Headers: ${_formatJson(headers)}', name: _logTag);
      }
      if (queryParameters != null && queryParameters.isNotEmpty) {
        developer.log('Query Parameters: ${_formatJson(queryParameters)}', name: _logTag);
      }
      if (data != null) {
        developer.log('Request Data: ${_formatJson(data)}', name: _logTag);
      }
      developer.log('Timestamp: $timestamp', name: _logTag);
      developer.log('─' * 80, name: _logTag);
    }
  }

  static Future<void> logResponse({
    required String method,
    required String url,
    required int statusCode,
    String? statusMessage,
    Map<String, dynamic>? headers,
    dynamic data,
    String? requestId,
    int? responseTimeMs,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = _createLogEntry(
      type: 'RESPONSE',
      method: method,
      url: url,
      statusCode: statusCode,
      statusMessage: statusMessage,
      headers: headers,
      data: data,
      requestId: requestId,
      responseTimeMs: responseTimeMs,
      timestamp: timestamp,
    );

    await _writeToLog(logEntry);
    
    if (kDebugMode) {
      developer.log(
        '✅ API RESPONSE [$method]',
        name: _logTag,
        time: DateTime.now(),
      );
      developer.log('URL: $url', name: _logTag);
      developer.log('Status: $statusCode $statusMessage', name: _logTag);
      if (headers != null && headers.isNotEmpty) {
        developer.log('Response Headers: ${_formatJson(headers)}', name: _logTag);
      }
      if (data != null) {
        developer.log('Response Data: ${_formatJson(data)}', name: _logTag);
      }
      if (responseTimeMs != null) {
        developer.log('Response Time: ${responseTimeMs}ms', name: _logTag);
      }
      developer.log('Timestamp: $timestamp', name: _logTag);
      developer.log('─' * 80, name: _logTag);
    }
  }

  static Future<void> logError({
    required String method,
    required String url,
    required String errorType,
    required String errorMessage,
    int? statusCode,
    String? statusMessage,
    Map<String, dynamic>? headers,
    dynamic responseData,
    dynamic requestData,
    String? requestId,
  }) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = _createLogEntry(
      type: 'ERROR',
      method: method,
      url: url,
      errorType: errorType,
      errorMessage: errorMessage,
      statusCode: statusCode,
      statusMessage: statusMessage,
      headers: headers,
      data: responseData,
      requestData: requestData,
      requestId: requestId,
      timestamp: timestamp,
    );

    await _writeToLog(logEntry);
    
    if (kDebugMode) {
      developer.log(
        '❌ API ERROR [$method]',
        name: _logTag,
        time: DateTime.now(),
      );
      developer.log('URL: $url', name: _logTag);
      developer.log('Error Type: $errorType', name: _logTag);
      developer.log('Error Message: $errorMessage', name: _logTag);
      if (statusCode != null) {
        developer.log('Status: $statusCode $statusMessage', name: _logTag);
      }
      if (headers != null && headers.isNotEmpty) {
        developer.log('Response Headers: ${_formatJson(headers)}', name: _logTag);
      }
      if (responseData != null) {
        developer.log('Error Response Data: ${_formatJson(responseData)}', name: _logTag);
      }
      if (requestData != null) {
        developer.log('Request Data: ${_formatJson(requestData)}', name: _logTag);
      }
      developer.log('Timestamp: $timestamp', name: _logTag);
      developer.log('─' * 80, name: _logTag);
    }
  }

  static String _createLogEntry({
    required String type,
    required String method,
    required String url,
    int? statusCode,
    String? statusMessage,
    String? errorType,
    String? errorMessage,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    dynamic requestData,
    String? requestId,
    int? responseTimeMs,
    required String timestamp,
  }) {
    final logData = <String, dynamic>{
      'type': type,
      'method': method,
      'url': url,
      'timestamp': timestamp,
      'requestId': requestId,
    };

    if (statusCode != null) {
      logData['statusCode'] = statusCode;
    }
    if (statusMessage != null) {
      logData['statusMessage'] = statusMessage;
    }
    if (errorType != null) {
      logData['errorType'] = errorType;
    }
    if (errorMessage != null) {
      logData['errorMessage'] = errorMessage;
    }
    if (headers != null && headers.isNotEmpty) {
      logData['headers'] = headers;
    }
    if (queryParameters != null && queryParameters.isNotEmpty) {
      logData['queryParameters'] = queryParameters;
    }
    if (data != null) {
      logData['data'] = data;
    }
    if (requestData != null) {
      logData['requestData'] = requestData;
    }
    if (responseTimeMs != null) {
      logData['responseTimeMs'] = responseTimeMs;
    }

    return '${const JsonEncoder.withIndent('  ').convert(logData)}\n\n';
  }

  static Future<void> _writeToLog(String logEntry) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/$_logFileName');
      
      // Check if log file exists and its size
      if (await logFile.exists()) {
        final fileSize = await logFile.length();
        if (fileSize > _maxLogFileSize) {
          await _rotateLogFiles(directory);
        }
      }
      
      // Write log entry
      await logFile.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      if (kDebugMode) {
        developer.log('Failed to write to log file: $e', name: _logTag);
      }
    }
  }

  static Future<void> _rotateLogFiles(Directory directory) async {
    try {
      // Move existing log files
      for (int i = _maxLogFiles - 1; i > 0; i--) {
        final oldFile = File('${directory.path}/${_logFileName}.$i');
        final newFile = File('${directory.path}/${_logFileName}.${i + 1}');
        
        if (await oldFile.exists()) {
          if (i == _maxLogFiles - 1) {
            // Delete the oldest log file
            await oldFile.delete();
          } else {
            await oldFile.rename(newFile.path);
          }
        }
      }
      
      // Move current log file to .1
      final currentFile = File('${directory.path}/$_logFileName');
      if (await currentFile.exists()) {
        await currentFile.rename('${directory.path}/${_logFileName}.1');
      }
    } catch (e) {
      if (kDebugMode) {
        developer.log('Failed to rotate log files: $e', name: _logTag);
      }
    }
  }

  static Future<String> getLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/$_logFileName');
      
      if (await logFile.exists()) {
        return await logFile.readAsString();
      }
      return 'No logs found';
    } catch (e) {
      return 'Error reading logs: $e';
    }
  }

  static Future<void> clearLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logFile = File('${directory.path}/$_logFileName');
      
      if (await logFile.exists()) {
        await logFile.delete();
      }
      
      // Delete rotated log files
      for (int i = 1; i <= _maxLogFiles; i++) {
        final rotatedFile = File('${directory.path}/${_logFileName}.$i');
        if (await rotatedFile.exists()) {
          await rotatedFile.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        developer.log('Failed to clear logs: $e', name: _logTag);
      }
    }
  }

  static String _formatJson(dynamic data) {
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
}
