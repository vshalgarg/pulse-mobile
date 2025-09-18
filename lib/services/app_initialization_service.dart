import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';

class AppInitializationService {
  static bool _isInitialized = false;
  static String? _initializationError;

  /// Initialize the entire app
  static Future<bool> initializeApp(dynamic apiService) async {
    if (_isInitialized) {
      Logger.debugLog('✅ App already initialized');
      return true;
    }

    try {
      Logger.debugLog('🚀 Starting app initialization...');

      // Initialize all services
      await ServiceLocator().initializeServices(apiService);

      _isInitialized = true;
      _initializationError = null;
      
      Logger.debugLog('✅ App initialization completed successfully');
      return true;
    } catch (e) {
      _initializationError = e.toString();
      Logger.errorLog('❌ App initialization failed: $e');
      return false;
    }
  }

  /// Check if app is initialized
  static bool get isInitialized => _isInitialized;

  /// Get initialization error if any
  static String? get initializationError => _initializationError;

  /// Ensure app is initialized, throw error if not
  static void ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'App not initialized! Call AppInitializationService.initializeApp(apiService) first.\n'
        'Error: $_initializationError'
      );
    }
  }

  /// Reset initialization state (for testing)
  static void reset() {
    _isInitialized = false;
    _initializationError = null;
    ServiceLocator().reset();
    Logger.debugLog('🔄 App initialization reset');
  }
}
