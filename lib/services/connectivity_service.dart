// import 'dart:async';
// import 'dart:io';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'fallback_connectivity_service.dart';
//
// class ConnectivityService {
//   static final ConnectivityService _instance = ConnectivityService._internal();
//   factory ConnectivityService() => _instance;
//   ConnectivityService._internal();
//
//   final Connectivity _connectivity = Connectivity();
//   final FallbackConnectivityService _fallbackService = FallbackConnectivityService();
//   StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
//
//   bool _isOnline = true;
//   bool _usingFallback = false;
//   StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
//
//   /// Stream to listen to connectivity changes
//   Stream<bool> get connectivityStream => _connectivityController.stream;
//
//   /// Current connectivity status
//   bool get isOnline => _isOnline;
//
//   /// Initialize the connectivity service
//   Future<void> initialize() async {
//     try {
//       // Check initial connectivity
//       await _checkConnectivity();
//
//       // Listen to connectivity changes with better error handling
//       _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
//         _onConnectivityChanged,
//         onError: (error) {
//           print('ConnectivityService: Error in connectivity stream: $error');
//           // Switch to fallback service
//           _switchToFallback();
//         },
//         cancelOnError: false, // Don't cancel the stream on error
//       );
//     } catch (e) {
//       print('ConnectivityService: Error initializing connectivity: $e');
//       // Check if it's a MissingPluginException
//       if (e.toString().contains('MissingPluginException')) {
//         print('ConnectivityService: Plugin not registered, switching to fallback service');
//         _switchToFallback();
//       } else {
//         // Fallback to offline mode if initialization fails
//         _updateConnectivityStatus(false);
//       }
//     }
//   }
//
//   /// Switch to fallback connectivity service
//   void _switchToFallback() {
//     if (!_usingFallback) {
//       _usingFallback = true;
//       print('ConnectivityService: Switching to fallback connectivity service');
//
//       // Initialize fallback service
//       _fallbackService.initialize();
//
//       // Listen to fallback service stream
//       _fallbackService.connectivityStream.listen((isOnline) {
//         _updateConnectivityStatus(isOnline);
//       });
//     }
//   }
//
//   /// Check current connectivity status
//   Future<void> _checkConnectivity() async {
//     try {
//       final connectivityResults = await _connectivity.checkConnectivity();
//       final isConnected = await _hasInternetConnection();
//
//       _updateConnectivityStatus(isConnected);
//     } catch (e) {
//       print('ConnectivityService: Error checking connectivity: $e');
//       // Check if it's a MissingPluginException
//       if (e.toString().contains('MissingPluginException')) {
//         print('ConnectivityService: Plugin not registered, assuming online');
//         _updateConnectivityStatus(true); // Assume online as fallback
//       } else {
//         _updateConnectivityStatus(false);
//       }
//     }
//   }
//
//   /// Handle connectivity changes
//   Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
//     final isConnected = await _hasInternetConnection();
//     _updateConnectivityStatus(isConnected);
//   }
//
//   /// Update connectivity status and notify listeners
//   void _updateConnectivityStatus(bool isOnline) {
//     if (_isOnline != isOnline) {
//       _isOnline = isOnline;
//       _connectivityController.add(_isOnline);
//       print('ConnectivityService: Connectivity changed to ${_isOnline ? "online" : "offline"}');
//     }
//   }
//
//   /// Check if device has actual internet connection
//   Future<bool> _hasInternetConnection() async {
//     try {
//       final connectivityResults = await _connectivity.checkConnectivity();
//
//       // If no connectivity at all, return false
//       if (connectivityResults.isEmpty ||
//           connectivityResults.every((result) => result == ConnectivityResult.none)) {
//         return false;
//       }
//
//       // Try to reach a reliable server to confirm internet access
//       final result = await InternetAddress.lookup('google.com')
//           .timeout(const Duration(seconds: 5));
//
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } catch (e) {
//       print('ConnectivityService: Internet connection check failed: $e');
//       // Check if it's a MissingPluginException
//       if (e.toString().contains('MissingPluginException')) {
//         print('ConnectivityService: Plugin not registered, assuming online');
//         return true; // Assume online as fallback
//       }
//       return false;
//     }
//   }
//
//   /// Force check connectivity status
//   Future<bool> checkConnectivity() async {
//     await _checkConnectivity();
//     return _isOnline;
//   }
//
//   /// Check if connectivity plugin is available
//   Future<bool> isPluginAvailable() async {
//     try {
//       await _connectivity.checkConnectivity();
//       return true;
//     } catch (e) {
//       if (e.toString().contains('MissingPluginException')) {
//         return false;
//       }
//       return true; // Other errors don't mean plugin is unavailable
//     }
//   }
//
//   /// Get connectivity status with fallback
//   Future<bool> getConnectivityStatus() async {
//     try {
//       return await _hasInternetConnection();
//     } catch (e) {
//       if (e.toString().contains('MissingPluginException')) {
//         print('ConnectivityService: Plugin not available, using fallback');
//         return true; // Assume online as fallback
//       }
//       return false;
//     }
//   }
//
//   /// Dispose resources
//   void dispose() {
//     _connectivitySubscription?.cancel();
//     _connectivityController.close();
//     if (_usingFallback) {
//       _fallbackService.dispose();
//     }
//   }
// }
