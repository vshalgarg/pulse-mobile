import 'package:app/services/service_locator.dart';
import 'package:app/services/app_initialization_service.dart';

/// Example of how to use services without initialization checks
class ServiceUsageExample {
  
  /// Example 1: Using Service Locator (Recommended)
  static Future<void> exampleUsingServiceLocator() async {
    // No need to check if initialized - ServiceLocator guarantees it
    final centralService = ServiceLocator().centralAssetAuditService;
    final imageService = ServiceLocator().imageUploadService;
    
    // Use services directly
    final data = await centralService.getAssetAuditData(
      siteType: 'Solar',
      auditSchId: '123',
      siteAuditSchId: '456',
    );
    
    final imageId = await imageService.uploadImage(
      imageData: 'base64data',
      activityType: ActivityTypeEnum.assetAudit,
      siteSchId: '456',
    );
  }

  /// Example 2: Using App Initialization Service
  static Future<void> exampleUsingAppInitialization() async {
    // Ensure app is initialized
    AppInitializationService.ensureInitialized();
    
    // Now use services safely
    final centralService = ServiceLocator().centralAssetAuditService;
    // ... use service
  }

  /// Example 3: In Widget Build Method
  static Widget buildExampleWidget() {
    return FutureBuilder(
      future: _loadData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        
        return Text('Data loaded successfully');
      },
    );
  }

  static Future<Map<String, dynamic>?> _loadData() async {
    // No initialization check needed!
    return await ServiceLocator().centralAssetAuditService.getAssetAuditData(
      siteType: 'Solar',
      auditSchId: '123',
      siteAuditSchId: '456',
    );
  }
}

/// Example 4: Error Handling
class ServiceErrorHandlingExample {
  static Future<void> handleServiceErrors() async {
    try {
      // This will throw StateError if services not initialized
      final service = ServiceLocator().centralAssetAuditService;
      await service.clearAllData();
    } on StateError catch (e) {
      print('Services not initialized: $e');
      // Handle initialization error
    } catch (e) {
      print('Other error: $e');
      // Handle other errors
    }
  }
}
