import '../models/notification_model.dart';
import 'api_service.dart';
import 'local_storage_db.dart';

class NotificationService {
  final ApiService _apiService;

  NotificationService(this._apiService);

  /// Get notifications for the current user
  Future<List<NotificationModel>> getNotifications({
    int pageSize = 50,
    int pageNo = 1,
  }) async {
    try {
      // Get user ID from local storage
      final userId = LocalStorageDB.getUserId;
      if (userId == null) {
        print('NotificationService: No user ID found');
        return [];
      }

      // Get token for authorization
      final token = LocalStorageDB.getToken;
      if (token == null) {
        print('NotificationService: No token found');
        return [];
      }

      print('NotificationService: Fetching notifications for userId: $userId');

      // Call the API
      final response = await _apiService.getNotifications(
        userId: userId,
        pageSize: pageSize,
        pageNo: pageNo,
        headers: {
          'Authorization': 'Bearer $token',
          'accept': '*/*',
        },
      );

      if (response.isSuccess && response.data != null) {
        print('NotificationService: Notifications fetched successfully');
        print('NotificationService: Response data type: ${response.data.runtimeType}');
        print('NotificationService: Response data: ${response.data}');
        
        // Handle different response structures
        List<dynamic> notificationsData = [];
        
        if (response.data is List) {
          // Direct list response
          notificationsData = response.data as List<dynamic>;
        } else if (response.data is Map<String, dynamic>) {
          // Response wrapped in an object, check for common keys
          final Map<String, dynamic> dataMap = response.data as Map<String, dynamic>;
          if (dataMap.containsKey('data') && dataMap['data'] is List) {
            notificationsData = dataMap['data'] as List<dynamic>;
          } else if (dataMap.containsKey('notifications') && dataMap['notifications'] is List) {
            notificationsData = dataMap['notifications'] as List<dynamic>;
          } else if (dataMap.containsKey('items') && dataMap['items'] is List) {
            notificationsData = dataMap['items'] as List<dynamic>;
          } else {
            // If it's a map but no list found, try to convert the map itself
            notificationsData = [dataMap];
          }
        }
        
        print('NotificationService: Extracted ${notificationsData.length} notification items');
        
        // Parse the response into NotificationModel objects
        final List<NotificationModel> notifications = [];
        for (int i = 0; i < notificationsData.length; i++) {
          try {
            final notification = NotificationModel.fromJson(notificationsData[i]);
            notifications.add(notification);
          } catch (e) {
            print('NotificationService: Error parsing notification at index $i: $e');
            print('NotificationService: Problematic data: ${notificationsData[i]}');
            // Continue with other notifications
          }
        }
        
        print('NotificationService: Successfully parsed ${notifications.length} notifications');
        return notifications;
      } else {
        print('NotificationService: Failed to fetch notifications: ${response.errorMessage}');
        return [];
      }
    } catch (e) {
      print('NotificationService: Error fetching notifications: $e');
      return [];
    }
  }
}
