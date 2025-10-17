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
        
        // Parse the response into NotificationModel objects
        final List<dynamic> notificationsData = response.data!;
        final List<NotificationModel> notifications = notificationsData
            .map((json) => NotificationModel.fromJson(json))
            .toList();
        
        print('NotificationService: Parsed ${notifications.length} notifications');
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
