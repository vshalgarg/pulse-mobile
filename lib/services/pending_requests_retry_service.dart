import 'package:app/services/api_service.dart';
import 'package:app/services/pending_requests_service.dart';
import 'package:app/utils/connectivity_helper.dart';
import 'package:app/utils/logger.dart';

class PendingRequestsRetryService {
  final ApiService _apiService;
  final PendingRequestsService _pendingRequestsService;

  PendingRequestsRetryService({
    required ApiService apiService,
    required PendingRequestsService pendingRequestsService,
  }) : _apiService = apiService,
       _pendingRequestsService = pendingRequestsService;

  /// Retry all pending requests when connectivity is restored
  Future<void> retryAllPendingRequests() async {
    try {
      // Check if we have internet connectivity
      final isConnected = await ConnectivityHelper.isConnected();
      if (!isConnected) {
        Logger.debugLog('📵 PendingRequestsRetryService: No internet connection, skipping retry');
        return;
      }

      Logger.infoLog('🔄 PendingRequestsRetryService: Starting retry of pending requests');

      // Get all pending requests
      final pendingRequests = await _pendingRequestsService.getPendingRequests();
      
      if (pendingRequests.isEmpty) {
        Logger.debugLog('📋 PendingRequestsRetryService: No pending requests to retry');
        return;
      }

      Logger.debugLog('📋 PendingRequestsRetryService: Found ${pendingRequests.length} pending requests');

      // Retry each pending request
      for (final request in pendingRequests) {
        await _retrySingleRequest(request);
      }

      Logger.infoLog('✅ PendingRequestsRetryService: Completed retry of all pending requests');

    } catch (e) {
      Logger.errorLog('❌ PendingRequestsRetryService: Error during retry process: $e');
    }
  }

  /// Retry a single pending request
  Future<void> _retrySingleRequest(Map<String, dynamic> request) async {
    try {
      final requestId = request['request_id'] as String;
      final url = request['request_data'] as String;
      final requestDataJson = request['request_data'] as String;

      Logger.debugLog('🔄 PendingRequestsRetryService: Retrying request $requestId');

      // Parse the stored data
      final requestData = Uri.splitQueryString(requestDataJson);

      // Make the API call
      final response = await _apiService.post<List<dynamic>>(
        path: url,
        data: requestData,
      );

      if (response.isSuccess && response.data != null) {
        // Success - delete the pending request
        await _pendingRequestsService.deleteRequest(requestId);
        Logger.infoLog('✅ PendingRequestsRetryService: Successfully retried and deleted request $requestId');
      } else {
        // Failed - update retry count and status
        final errorMsg = response.errorMessage ?? 'Unknown error';
        await _pendingRequestsService.updateRequestStatus(
          requestId: requestId,
          status: 'failed',
          errorMessage: errorMsg,
        );
        Logger.errorLog('❌ PendingRequestsRetryService: Failed to retry request $requestId: $errorMsg');
      }

    } catch (e) {
      Logger.errorLog('❌ PendingRequestsRetryService: Error retrying request ${request['request_id']}: $e');
      
      // Update request status to failed
      await _pendingRequestsService.updateRequestStatus(
        requestId: request['request_id'] as String,
        status: 'failed',
        errorMessage: e.toString(),
      );
    }
  }

  /// Check and retry pending requests periodically
  Future<void> startPeriodicRetry() async {
    // This could be called from a background service or when the app comes to foreground
    await retryAllPendingRequests();
  }
}
