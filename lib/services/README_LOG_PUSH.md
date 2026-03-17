# Log Push Service

This service automatically pushes application logs to your backend API every 10 seconds (configurable).

## Features

- **Automatic Log Pushing**: Sends logs to backend every 10 seconds
- **Configurable**: Easy to customize push interval, endpoint, and other settings
- **Smart Truncation**: Automatically truncates large logs to prevent API overload
- **Connectivity Aware**: Only pushes when internet connection is available
- **Manual Push**: Option to manually trigger log pushes
- **Service Status**: View service status and configuration

## Configuration

Edit `lib/services/log_push_config.dart` to customize:

```dart
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
```

## Backend API Requirements

Your backend should accept POST requests to the configured endpoint with the following JSON structure:

```json
{
  "logs": "string containing log content",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "deviceId": "device_1234567890",
  "appVersion": "1.0.0"
}
```

## Usage

### Automatic Usage
The service starts automatically when the app launches (if `autoStartOnAppLaunch` is true).

### Manual Usage
```dart
// Start the service
await LogPushService.startLogPushing(apiService);

// Stop the service
LogPushService.stopLogPushing();

// Push logs immediately
await LogPushService.pushLogsNow(apiService);

// Check service status
final status = LogPushService.getServiceStatus();

```

### Log Viewer Integration
The LogViewerScreen includes buttons to:
- Push logs manually (cloud upload icon)
- View service status (info icon)

## Service Status

The service provides status information including:
- Running status
- Push interval
- Maximum log size
- API endpoint

## Error Handling

- Logs are only pushed when internet connectivity is available
- Failed pushes are logged as errors but don't crash the app
- Large logs are automatically truncated to prevent API overload
- Service continues running even if individual pushes fail

## Log Content

The service sends the most recent log file content, which includes:
- Application logs
- API request/response logs
- Error logs
- Debug information

Image data is automatically filtered out to prevent log spam.
