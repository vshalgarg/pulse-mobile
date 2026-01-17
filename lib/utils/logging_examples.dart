import 'file_logger.dart';

/// Examples of how to use FileLogger in your application
class LoggingExamples {
  
  /// Example: Logging API calls
  static Future<void> logApiExample() async {
    // Log API request
    await FileLogger.logApiRequest(
      'POST', 
      'https://api.example.com/users',
      headers: {'Authorization': 'Bearer token123'},
      body: {'name': 'John Doe', 'email': 'john@example.com'},
    );
    
    // Log API response
    await FileLogger.logApiResponse(
      'POST', 
      'https://api.example.com/users', 
      201,
      body: {'id': 123, 'name': 'John Doe', 'email': 'john@example.com'},
    );
  }
  
  /// Example: Logging errors with stack trace
  static Future<void> logErrorExample() async {
    try {
      // Some operation that might fail
      throw Exception('Something went wrong');
    } catch (e, stackTrace) {
      await FileLogger.error(
        'Failed to process user data',
        data: {'userId': 123, 'operation': 'updateProfile'},
        stackTrace: stackTrace,
      );
    }
  }
  
  /// Example: Logging user actions
  static Future<void> logUserAction(String action, Map<String, dynamic> data) async {
    await FileLogger.info(
      'User action: $action',
      data: data,
    );
  }
  
  /// Example: Logging debug information
  static Future<void> logDebugInfo(String message, Map<String, dynamic> data) async {
    await FileLogger.debug(
      message,
      data: data,
    );
  }
  
  /// Example: Logging warnings
  static Future<void> logWarning(String message, Map<String, dynamic> data) async {
    await FileLogger.warning(
      message,
      data: data,
    );
  }
  
  /// Example: Logging with filtered image data
  static Future<void> logWithImageData() async {
    final data = {
      'userId': 123,
      'imageData': 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD...', // This will be filtered
      'profileImage': 'base64encodedimagedata...', // This will be filtered
      'name': 'John Doe',
      'email': 'john@example.com',
    };
    
    await FileLogger.info(
      'User profile updated',
      data: data, // Image data will be automatically filtered
    );
  }
}
