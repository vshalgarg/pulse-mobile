import '../models/notification_model.dart';
import 'api_service.dart';
import 'local_storage_db.dart';

class NotificationService {
  final ApiService _apiService;

  NotificationService(this._apiService);

  /// Get notifications for the current user
  Future<List<NotificationModel>> getNotifications({pageSize, pageNo}) async {
    try {
      // Get user ID from local storage
      final userId = LocalStorageDB.getUserId;
      if (userId == null) {
        return [];
      }

      // Get token for authorization
      final token = LocalStorageDB.getToken;
      if (token == null) {
        return [];
      }

      // Call the API
      final response = await _apiService.getNotifications(
        userId: userId,
        pageSize: pageSize,
        pageNo: pageNo,
        headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
      );

      if (response.isSuccess && response.data != null) {
        // Handle different response structures
        List<dynamic> notificationsData = [];

        if (response.data is List) {
          // Direct list response
          notificationsData = response.data as List<dynamic>;
        } else if (response.data is Map<String, dynamic>) {
          // Response wrapped in an object, check for common keys
          final Map<String, dynamic> dataMap =
              response.data as Map<String, dynamic>;
          if (dataMap.containsKey('data') && dataMap['data'] is List) {
            notificationsData = dataMap['data'] as List<dynamic>;
          } else if (dataMap.containsKey('notifications') &&
              dataMap['notifications'] is List) {
            notificationsData = dataMap['notifications'] as List<dynamic>;
          } else if (dataMap.containsKey('items') && dataMap['items'] is List) {
            notificationsData = dataMap['items'] as List<dynamic>;
          } else {
            // If it's a map but no list found, try to convert the map itself
            notificationsData = [dataMap];
          }
        }

        // Parse the response into NotificationModel objects
        final List<NotificationModel> notifications = [];
        for (int i = 0; i < notificationsData.length; i++) {
          try {
            final notification = NotificationModel.fromJson(
              notificationsData[i],
            );
            notifications.add(notification);
          } catch (e) {

            // Continue with other notifications
          }
        }

        return notifications;
      } else {

        return [];
      }
    } catch (e) {

      return [];
    }
  }

  /// Get count of unseen notifications for the current user
  Future<String> getNotificationsCount() async {
    try {
      // Get token for authorization
      final token = LocalStorageDB.getToken;
      if (token == null) {
        return "0";
      }

      // Call the API
      final response = await _apiService.getNotificationsCount(
        headers: {'Authorization': 'Bearer $token', 'accept': '*/*'},
      );

      if (response.isSuccess && response.data != null) {
        return response.data!;
      } else {

        return "0";
      }
    } catch (e) {

      return "0";
    }
  }
}
