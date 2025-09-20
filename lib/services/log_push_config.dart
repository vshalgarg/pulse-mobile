class LogPushConfig {
  /// API endpoint for pushing logs
  static const String logPushEndpoint = 'api/v1/mobile/pushLogs';
  
  /// How often to push logs (in seconds)
  static const int pushIntervalSeconds = 10;
  
  /// Maximum log size to send in each push (in bytes)
  static const int maxLogSizeBytes = 50 * 1024; // 50KB
  
  /// Whether to start pushing logs automatically on app startup
  static const bool autoStartOnAppLaunch = true;
  
  /// Whether to push logs only when connected to WiFi
  static const bool wifiOnly = false;
  
  /// Whether to include device information in log pushes
  static const bool includeDeviceInfo = true;
  
  /// Whether to include app version in log pushes
  static const bool includeAppVersion = true;
  
  /// Custom headers to include with log push requests
  static const Map<String, String> customHeaders = {
    'Content-Type': 'application/json',
    'X-Log-Source': 'mobile-app',
  };
  
  /// Whether to enable debug logging for the log push service
  static const bool enableDebugLogging = true;
}
