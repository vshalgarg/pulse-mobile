# Central Asset Audit Service

A unified service architecture for all asset audit screens in the Flutter application. This central service provides consistent data management, API integration, and image handling across all asset audit workflows.

## 🏗️ Architecture

```
lib/services/asset_audit/
├── central_asset_audit_service.dart      # Main service coordinator
├── central_data_service.dart             # SQLite data operations
├── central_api_service.dart              # API calls and network operations
├── central_image_service.dart            # Image handling and caching
├── central_service_initializer.dart      # Service initialization
├── usage_example.dart                    # Usage examples and documentation
└── README.md                            # This documentation
```

## 🚀 Key Features

### ✅ **Unified Data Management**
- Single SQLite database for all asset audit data
- Consistent data structure across all screens
- Automatic data synchronization and caching
- Offline-first approach with API fallback

### ✅ **Centralized API Integration**
- Unified API calls for all asset audit operations
- Consistent error handling and logging
- Automatic retry mechanisms
- Screen-specific and bulk operations

### ✅ **Advanced Image Handling**
- Centralized image caching system
- Automatic image compression and optimization
- Support for multiple image formats
- Batch image operations

### ✅ **Form Data Persistence**
- Automatic form data saving and loading
- Screen-specific form data management
- Unsaved changes detection
- Data validation and error handling

## 📊 Database Schema

### Core Tables
- **page_headers**: Site and audit information
- **categories**: Asset categories (SPV, PCU, Inverter, etc.)
- **asset_items**: Individual asset details
- **form_data**: Screen-specific form data
- **cached_images**: Image cache storage

### Screen-Specific Tables
- **spv_items**: SPV-specific data
- **pcu_items**: PCU-specific data
- **inverter_items**: Inverter-specific data

## 🔧 Usage

### 1. Service Initialization

The service is automatically initialized in `main.dart`:

```dart
// In main.dart
CentralAssetAuditServiceInitializer.initialize(config.apiService);
```

### 2. Using in Screens

```dart
class MyAssetAuditScreen extends StatefulWidget {
  @override
  _MyAssetAuditScreenState createState() => _MyAssetAuditScreenState();
}

class _MyAssetAuditScreenState extends State<MyAssetAuditScreen> {
  late CentralAssetAuditService _service;

  @override
  void initState() {
    super.initState();
    _service = CentralAssetAuditServiceInitializer.getService();
  }

  // Use the service for all operations
  Future<void> loadData() async {
    final data = await _service.getAssetAuditData(
      siteType: "Solar",
      auditSchId: "123",
      siteAuditSchId: "456",
    );
  }
}
```

### 3. Common Operations

#### Load Asset Audit Data
```dart
final data = await _service.getAssetAuditData(
  siteType: "Solar",
  auditSchId: "123",
  siteAuditSchId: "456",
);
```

#### Load Screen-Specific Data
```dart
// SPV data
final spvData = await _service.getSPVData(
  siteType: "Solar",
  auditSchId: "123",
  siteAuditSchId: "456",
);

// PCU data (when implemented)
final pcuData = await _service.getPCUData(...);
```

#### Save Form Data
```dart
await _service.saveFormData(
  siteAuditSchId: "456",
  screenName: "spv_v2",
  formData: {
    'serial': 'SPV001',
    'remarks': 'Working fine',
  },
);
```

#### Handle Images
```dart
// Pick image
final imageFile = await _service.pickImage();

// Upload image
final photoId = await _service.uploadImage(
  siteType: "Solar",
  auditSchId: "123",
  siteAuditSchId: "456",
  imageFile: imageFile,
  serialNumber: "SPV001",
  screenType: "spv",
);

// Get cached image
final imageData = await _service.getImageAsDataUrl(123);
```

#### Post Data
```dart
final success = await _service.postSPVData(
  siteType: "Solar",
  auditSchId: "123",
  siteAuditSchId: "456",
  formData: formData,
);
```

## 🔄 Data Flow

### 1. Data Loading
```
Screen Request → Central Service → SQLite Cache → API (if needed) → Return Data
```

### 2. Data Saving
```
Screen Input → Central Service → SQLite Storage → API Post → Confirmation
```

### 3. Image Handling
```
Image Pick → Validation → Compression → Upload → Cache → Return Photo ID
```

## 🎯 Benefits

### ✅ **Consistency**
- All screens use the same data structure
- Unified error handling and logging
- Consistent user experience

### ✅ **Maintainability**
- Single source of truth for all operations
- Easy to update and modify
- Reduced code duplication

### ✅ **Performance**
- Centralized caching system
- Optimized database queries
- Efficient image handling

### ✅ **Reliability**
- Robust error handling
- Automatic retry mechanisms
- Offline-first approach

## 🔧 Migration Guide

### From Individual Services to Central Service

1. **Replace Service Initialization**
   ```dart
   // Old way
   _spvService = SPVV2ServiceInitializer.getService();
   
   // New way
   _service = CentralAssetAuditServiceInitializer.getService();
   ```

2. **Update Method Calls**
   ```dart
   // Old way
   final data = await _spvService.getSPVData(...);
   
   // New way
   final data = await _service.getSPVData(...);
   ```

3. **Unified Error Handling**
   ```dart
   // All services now use the same error handling pattern
   try {
     final data = await _service.getData(...);
   } catch (e) {
     Logger.errorLog('Error: $e');
   }
   ```

## 🚀 Future Enhancements

### Planned Features
- [ ] Real-time data synchronization
- [ ] Advanced offline capabilities
- [ ] Bulk data operations
- [ ] Data analytics and reporting
- [ ] Advanced image processing
- [ ] Multi-site data management

### Integration Points
- [ ] Cloud storage integration
- [ ] Advanced caching strategies
- [ ] Performance monitoring
- [ ] Error reporting and analytics

## 📝 Best Practices

### 1. Always Check Initialization
```dart
if (!_service.isInitialized) {
  Logger.errorLog('Service not initialized');
  return;
}
```

### 2. Handle Errors Gracefully
```dart
try {
  final data = await _service.getData(...);
  // Process data
} catch (e) {
  Logger.errorLog('Error: $e');
  // Show user-friendly error message
}
```

### 3. Use Appropriate Screen Names
```dart
// Use consistent screen names for form data
await _service.saveFormData(
  siteAuditSchId: siteAuditSchId,
  screenName: "spv_v2", // Consistent naming
  formData: formData,
);
```

### 4. Optimize Image Operations
```dart
// Check cache before uploading
if (await _service.isImageCached(imageId)) {
  final imageData = await _service.getImageAsDataUrl(imageId);
} else {
  // Upload new image
}
```

## 🐛 Troubleshooting

### Common Issues

1. **Service Not Initialized**
   - Ensure `CentralAssetAuditServiceInitializer.initialize()` is called in `main.dart`
   - Check that the service is properly imported

2. **Data Not Loading**
   - Check network connectivity
   - Verify API endpoints are correct
   - Check database permissions

3. **Image Upload Failures**
   - Validate image file format and size
   - Check network connectivity
   - Verify upload permissions

### Debug Logging

The service provides comprehensive logging. Enable debug mode to see detailed logs:

```dart
Logger.debugLog('Operation started');
// ... operation
Logger.debugLog('Operation completed successfully');
```

## 📞 Support

For issues or questions regarding the Central Asset Audit Service:

1. Check the logs for error messages
2. Review the usage examples in `usage_example.dart`
3. Verify service initialization in `main.dart`
4. Check database and API connectivity

---

**Version**: 1.0.0  
**Last Updated**: December 2024  
**Maintainer**: Development Team
