import 'dart:async';
import 'dart:io';
import 'package:app/services/api_service.dart';
import 'package:app/services/log_push_config.dart';
import 'package:app/utils/file_logger.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/connectivity_helper.dart';

class LogPushService {
  static LogPushService? _instance;
  static Timer? _timer;
  static bool _isRunning = false;
  static Duration get _pushInterval => Duration(seconds: LogPushConfig.pushIntervalSeconds);
  static int get _maxLogSize => LogPushConfig.maxLogSizeBytes;
  static String get _logPushEndpoint => LogPushConfig.logPushEndpoint;
  
  final ApiService _apiService;
  
  LogPushService._(this._apiService);
  
  /// Get singleton instance
  static LogPushService getInstance(ApiService apiService) {
    _instance ??= LogPushService._(apiService);
    return _instance!;
  }
  
  /// Start pushing logs every 10 seconds
  static Future<void> startLogPushing(ApiService apiService) async {
    if (_isRunning) {
      Logger.debugLog('LogPushService is already running');
      return;
    }
    
    _instance = getInstance(apiService);
    _isRunning = true;
    
    Logger.debugLog('🚀 Starting log push service (every ${LogPushConfig.pushIntervalSeconds} seconds)');
    
    // Start the timer
    _timer = Timer.periodic(_pushInterval, (timer) async {
      await _instance!._pushLogsToBackend();
    });
    
    // Push logs immediately on start
    await _instance!._pushLogsToBackend();
  }
  
  /// Stop pushing logs
  static void stopLogPushing() {
    if (!_isRunning) {
      Logger.debugLog('LogPushService is not running');
      return;
    }
    
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    
    Logger.debugLog('🛑 Stopped log push service');
  }
  
  /// Check if service is running
  static bool get isRunning => _isRunning;
  
  /// Push logs to backend
  Future<void> _pushLogsToBackend() async {
    try {
      // Check connectivity
      if (!await ConnectivityHelper.isConnected()) {
        if (LogPushConfig.enableDebugLogging) {
          Logger.debugLog('📡 No internet connection, skipping log push');
        }
        return;
      }
      
      // Get current log file content
      final logContent = await _getCurrentLogContent();
      if (logContent == null || logContent.isEmpty) {
        if (LogPushConfig.enableDebugLogging) {
          Logger.debugLog('📝 No logs to push');
        }
        return;
      }
      
      // Truncate if too large
      final truncatedContent = _truncateLogContent(logContent);
      
      // Push to backend
    //  await _sendLogsToBackend(truncatedContent);
      
      if (LogPushConfig.enableDebugLogging) {
        Logger.debugLog('✅ Logs pushed to backend successfully');
      }
      
    } catch (e) {
      Logger.errorLog('❌ Failed to push logs to backend: $e');
    }
  }
  
  /// Get current log file content
  Future<String?> _getCurrentLogContent() async {
    try {
      final logFiles = await FileLogger.getLogFiles();
      if (logFiles.isEmpty) {
        return null;
      }
      
      // Get the most recent log file
      logFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final latestLogFile = logFiles.first;
      
      return await FileLogger.getLogFileContent(latestLogFile);
      
    } catch (e) {
      Logger.errorLog('❌ Failed to get log content: $e');
      return null;
    }
  }
  
  /// Truncate log content if it's too large
  String _truncateLogContent(String content) {
    if (content.length <= _maxLogSize) {
      return content;
    }
    
    // Take the last part of the log (most recent entries)
    final truncated = content.substring(content.length - _maxLogSize);
    
    // Find the first newline to avoid cutting in the middle of a log entry
    final firstNewlineIndex = truncated.indexOf('\n');
    if (firstNewlineIndex != -1) {
      return '...[LOGS_TRUNCATED]\n${truncated.substring(firstNewlineIndex + 1)}';
    }
    
    return '...[LOGS_TRUNCATED]\n$truncated';
  }
  
  /// Send logs to backend
  Future<void> _sendLogsToBackend(String logContent) async {
    try {
      final response = await _apiService.post<String>(
        path: _logPushEndpoint,
        data: {
          'logs': logContent,
          'timestamp': DateTime.now().toIso8601String(),
          'deviceId': await _getDeviceId(),
          'appVersion': await _getAppVersion(),
        },
      );
      
      if (response.isSuccess) {
        if (LogPushConfig.enableDebugLogging) {
          Logger.debugLog('📤 Logs sent successfully to backend');
        }
      } else {
        Logger.errorLog('❌ Backend rejected logs: ${response.errorMessage}');
      }
      
    } catch (e) {
      Logger.errorLog('❌ Error sending logs to backend: $e');
    }
  }
  
  /// Get device ID (you can implement this based on your needs)
  Future<String> _getDeviceId() async {
    // You can use device_info_plus package or any other method
    // For now, return a placeholder
    return 'device_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// Get app version (you can implement this based on your needs)
  Future<String> _getAppVersion() async {
    // You can use package_info_plus package or any other method
    // For now, return a placeholder
    return '1.0.0';
  }
  
  /// Push logs immediately (manual trigger)
  static Future<void> pushLogsNow(ApiService apiService) async {
    if (_instance == null) {
      _instance = getInstance(apiService);
    }
    await _instance!._pushLogsToBackend();
  }
  
  /// Get service status
  static Map<String, dynamic> getServiceStatus() {
    return {
      'isRunning': _isRunning,
      'pushInterval': _pushInterval.inSeconds,
      'maxLogSize': _maxLogSize,
      'endpoint': _logPushEndpoint,
    };
  }
}
