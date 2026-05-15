import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class FileLogger {
  static File? _logFile;
  static String? _logDirectory;
  static bool _isInitialized = false;
  static const int _maxLogFileSize = 5 * 1024 * 1024; // 5MB
  static const int _maxLogFiles = 10; // Keep last 10 log files
  
  /// Initialize the file logger
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logDirectory = '${directory.path}/pulseapplogs';
      
      // Create logs directory if it doesn't exist
      final logDir = Directory(_logDirectory!);
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      // Create or get the current log file
      final timestamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _logFile = File('$_logDirectory/pulse_app_log_$timestamp.txt');
      
      _isInitialized = true;
      
      // Log initialization
      await _writeToFile('INFO', 'FileLogger initialized successfully');
      await _writeToFile('INFO', 'Log directory: $_logDirectory');
      
    } catch (e) {
      debugPrint('Failed to initialize FileLogger: $e');
    }
  }
  
  /// Write a log message to file
  static Future<void> log(String level, String message, {Map<String, dynamic>? data}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_logFile == null) return;
    
    try {
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
      final threadId = DateTime.now().millisecondsSinceEpoch % 10000;
      
      String logEntry = '[$timestamp] [$level] [Thread-$threadId] $message';
      
      if (data != null && data.isNotEmpty) {
        // Filter out image data before logging
        final filteredData = _filterImageData(data);
        logEntry += '\nData: ${JsonEncoder.withIndent('  ').convert(filteredData)}';
      }
      
      logEntry += '\n${'─' * 80}\n';
      
      await _writeToFile(level, logEntry);
      
      // Also print to console for development
      debugPrint('[$level] $message');
      
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }
  
  /// Log info message
  static Future<void> info(String message, {Map<String, dynamic>? data}) async {
    await log('INFO', message, data: data);
  }
  
  /// Log warning message
  static Future<void> warning(String message, {Map<String, dynamic>? data}) async {
    await log('WARN', message, data: data);
  }
  
  /// Log error message
  static Future<void> error(String message, {Map<String, dynamic>? data, StackTrace? stackTrace}) async {
    String fullMessage = message;
    if (stackTrace != null) {
      fullMessage += '\nStack Trace:\n$stackTrace';
    }
    await log('ERROR', fullMessage, data: data);
  }
  
  /// Log debug message
  static Future<void> debug(String message, {Map<String, dynamic>? data}) async {
    await log('DEBUG', message, data: data);
  }
  
  /// Log API request
  static Future<void> logApiRequest(String method, String url, {Map<String, dynamic>? headers, dynamic body}) async {
    final data = {
      'method': method,
      'url': url,
      'headers': headers,
      'body': body,
    };
    await log('API_REQUEST', '$method $url', data: data);
  }
  
  /// Log API response
  static Future<void> logApiResponse(String method, String url, int statusCode, {dynamic body, Map<String, dynamic>? headers}) async {
    final data = {
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'headers': headers,
      'body': body,
    };
    await log('API_RESPONSE', '$method $url - $statusCode', data: data);
  }
  
  /// Log API error
  static Future<void> logApiError(String method, String url, String error, {int? statusCode, dynamic body}) async {
    final data = {
      'method': method,
      'url': url,
      'error': error,
      'statusCode': statusCode,
      'body': body,
    };
    await log('API_ERROR', '$method $url - Error: $error', data: data);
  }
  
  /// Write to file with rotation
  static Future<void> _writeToFile(String level, String content) async {
    if (_logFile == null) return;
    
    try {
      // Check file size and rotate if necessary
      if (await _logFile!.exists()) {
        final fileSize = await _logFile!.length();
        if (fileSize > _maxLogFileSize) {
          await _rotateLogFile();
        }
      }
      
      // Write to file
      await _logFile!.writeAsString(content, mode: FileMode.append);
      
    } catch (e) {
      debugPrint('Failed to write to log file: $e');
    }
  }
  
  /// Rotate log file when it gets too large
  static Future<void> _rotateLogFile() async {
    if (_logDirectory == null) return;
    
    try {
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final rotatedFile = File('$_logDirectory/app_log_$timestamp.txt');
      
      // Move current file to rotated name
      if (await _logFile!.exists()) {
        await _logFile!.copy(rotatedFile.path);
        await _logFile!.delete();
      }
      
      // Create new log file
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _logFile = File('$_logDirectory/app_log_$today.txt');
      
      // Clean up old log files
      await _cleanupOldLogs();
      
    } catch (e) {
      debugPrint('Failed to rotate log file: $e');
    }
  }
  
  /// Clean up old log files
  static Future<void> _cleanupOldLogs() async {
    if (_logDirectory == null) return;
    
    try {
      final logDir = Directory(_logDirectory!);
      final files = await logDir.list().toList();
      
      // Sort files by modification time (newest first)
      files.sort((a, b) {
        if (a is File && b is File) {
          return b.lastModifiedSync().compareTo(a.lastModifiedSync());
        }
        return 0;
      });
      
      // Keep only the most recent files
      for (int i = _maxLogFiles; i < files.length; i++) {
        if (files[i] is File) {
          await files[i].delete();
        }
      }
      
    } catch (e) {
      debugPrint('Failed to cleanup old logs: $e');
    }
  }
  
  /// Filter out image data from logs
  static Map<String, dynamic> _filterImageData(Map<String, dynamic> data) {
    final filtered = Map<String, dynamic>.from(data);
    
    filtered.forEach((key, value) {
      if (value is String && _isImageData(value)) {
        filtered[key] = '[IMAGE_DATA_REMOVED_FROM_LOGS]';
      } else if (value is Map<String, dynamic>) {
        filtered[key] = _filterImageData(value);
      } else if (value is List) {
        filtered[key] = value.map((item) {
          if (item is String && _isImageData(item)) {
            return '[IMAGE_DATA_REMOVED_FROM_LOGS]';
          } else if (item is Map<String, dynamic>) {
            return _filterImageData(item);
          }
          return item;
        }).toList();
      }
    });
    
    return filtered;
  }
  
  /// Check if a string contains image data
  static bool _isImageData(String value) {
    // Check for base64 image patterns
    if (value.contains('data:image/') && value.contains('base64,')) {
      return true;
    }
    
    // Check for large base64 strings (likely images)
    if (value.length > 200 && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(value)) {
      return true;
    }
    
    // Check for common image field names
    final imageFields = ['imageData', 'imageBytes', 'photoData', 'photoBytes', 'image', 'photo'];
    return imageFields.any((field) => value.toLowerCase().contains(field.toLowerCase()));
  }
  
  /// Get all log files
  static Future<List<File>> getLogFiles() async {
    if (_logDirectory == null) {
      await initialize();
    }
    
    if (_logDirectory == null) return [];
    
    try {
      final logDir = Directory(_logDirectory!);
      final files = await logDir.list().toList();
      return files.whereType<File>().toList();
    } catch (e) {
      debugPrint('Failed to get log files: $e');
      return [];
    }
  }
  
  /// Get log file content
  static Future<String> getLogFileContent(File file) async {
    try {
      final bytes = await file.readAsBytes();
      // Some log lines can contain malformed bytes from third-party/native output.
      // Decode defensively so log viewing never crashes the workflow.
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      debugPrint('Failed to read log file: $e');
      return 'Error reading log file: $e';
    }
  }
  
  /// Clear all log files
  static Future<void> clearLogs() async {
    if (_logDirectory == null) {
      await initialize();
    }
    
    if (_logDirectory == null) return;
    
    try {
      final logDir = Directory(_logDirectory!);
      if (await logDir.exists()) {
        await logDir.delete(recursive: true);
        await logDir.create(recursive: true);
      }
      
      // Reinitialize
      _isInitialized = false;
      await initialize();
      
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }
  
  /// Get log directory path
  static String? getLogDirectory() => _logDirectory;
}
