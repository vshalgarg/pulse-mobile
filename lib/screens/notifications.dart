import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/service_locator.dart';
import '../constants/app_colors.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _currentPage = 1;
  int _pageSize = 50;
  bool _hasMorePages = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
        _hasMorePages = true;
      });

      // Get notification service from service locator
      final notificationService = NotificationService(
        ServiceLocator().apiService,
      );

      final notifications = await notificationService.getNotifications(
        pageSize: _pageSize,
        pageNo: _currentPage,
      );

      setState(() {
        _notifications = notifications;
        _isLoading = false;
        _hasMorePages = notifications.length >= _pageSize;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load notifications: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMorePages) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      // Get notification service from service locator
      final notificationService = NotificationService(
        ServiceLocator().apiService,
      );

      final nextPage = _currentPage + 1;
      final newNotifications = await notificationService.getNotifications(
        pageSize: _pageSize,
        pageNo: nextPage,
      );

      setState(() {
        _notifications.addAll(newNotifications);
        _currentPage = nextPage;
        _hasMorePages = newNotifications.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF00373E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  String _formatNotificationDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Today, 3:00 PM';
    }

    try {
      // Parse the date string (assuming format like "16/10/2025 16:41")
      final dateTime = DateFormat('dd/MM/yyyy HH:mm').parse(dateString);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final notificationDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      // Format time in 12-hour format
      final timeFormat = DateFormat('h:mm a');
      final timeString = timeFormat.format(dateTime);

      if (notificationDate == today) {
        return 'Today, $timeString';
      } else if (notificationDate == yesterday) {
        return 'Yesterday, $timeString';
      } else {
        // Format other dates as "15 Oct 25, 3:00 PM"
        final dateFormat = DateFormat('d MMM yy');
        final dateString = dateFormat.format(dateTime);
        return '$dateString, $timeString';
      }
    } catch (e) {
      // If parsing fails, return the original string or fallback
      return 'Today, 3:00 PM';
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll see your notifications here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: AppColors.primaryGreen,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at the bottom when loading more
          if (index == _notifications.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                ),
              ),
            );
          }

          final notification = _notifications[index];
          return _buildNotificationCard(notification, index);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification, int index) {
    // Alternate colors based on index
    final bool isEven = index % 2 == 0;
    final Color cardColor = isEven ? const Color(0xFFFFF4DE) : const Color(0xFFDEF2FF);
    final Color textColor = isEven ? const Color(0xFF84570E) : const Color(0xFF2F2C4F);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message text
            Text(
              notification.message ?? 'No message',
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            // Clock icon with timestamp aligned to right
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: const Color(0xFF949494),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatNotificationDate(notification.notifyDt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF949494),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
