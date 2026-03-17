# Offline Location and Data Submission Service

This service provides offline functionality for location tracking and data submission in the Pulse Mobile app. It allows users to submit data even when they don't have internet connectivity, with automatic synchronization when connection is restored.

## Features

### 🌍 Offline Location Service
- **GPS Location**: Works without internet using device GPS
- **Location Caching**: Stores last known location for fallback
- **Location History**: Maintains location history for better accuracy
- **Retry Mechanism**: Multiple attempts to get location with different accuracy levels
- **Permission Handling**: Properly handles location permissions

### 📱 Offline Data Submission
- **Data Storage**: Stores form data locally when offline
- **Automatic Sync**: Syncs data when internet connection is restored
- **Retry Logic**: Retries failed submissions with exponential backoff
- **Data Management**: Limits stored data to prevent storage overflow
- **Status Tracking**: Tracks submission status (pending, submitted, failed)

## Files Created

1. **`offline_location_service.dart`** - Core offline location functionality
2. **`offline_data_service.dart`** - Data storage and management
3. **`offline_post_helper.dart`** - Integration with existing post helpers
4. **`offline_implementation_example.dart`** - Usage examples and implementation guide

## Dependencies Added

```yaml
dependencies:
  shared_preferences: ^2.3.2  # For local data storage
  connectivity_plus: ^6.0.5   # For connectivity checking
```

## How It Works

### Location Service
```dart
// Get current location (works offline)
final location = await OfflineLocationService.getCurrentLocationOffline();

```

### Data Submission
```dart
// Submit data with offline support
final success = await OfflinePostHelper.submitSingleItemOffline(
  dataType: 'ccu',  // or 'spv', 'dcba', etc.
  itemData: formData,
  screenName: 'CCU Screen',
  siteId: siteId,
  auditSchId: auditSchId,
  siteAuditSchId: siteAuditSchId,
);
```

## Integration with Existing Screens

### For CCU, SPV, and other Asset Audit screens:

1. **Import the offline helper:**
```dart
import '../utils/offline_post_helper.dart';
import '../services/offline_location_service.dart';
```

2. **Replace your submit method:**
```dart
// OLD: Direct API call
await submitToAPI(formData);

// NEW: Offline-enabled submission
final success = await OfflinePostHelper.submitSingleItemOffline(
  dataType: 'ccu', // Change based on screen
  itemData: formData,
  screenName: 'CCU Screen',
  siteId: siteId,
  auditSchId: auditSchId,
  siteAuditSchId: siteAuditSchId,
);
```

3. **Add offline status indicator to your app bar:**
```dart
AppBar(
  title: Text('Your Screen'),
  actions: [
    OfflineImplementationExample.buildOfflineStatusIndicator(),
  ],
)
```

## Location Accuracy Options

The service provides different accuracy levels for different use cases:

```dart
// High accuracy (slower, more battery usage)
final location = await OfflineLocationService.getLocationWithAccuracy(
  LocationAccuracy.high
);

// Medium accuracy (balanced)
final location = await OfflineLocationService.getLocationWithAccuracy(
  LocationAccuracy.medium
);

// Low accuracy (faster, less battery usage)
final location = await OfflineLocationService.getLocationWithAccuracy(
  LocationAccuracy.low
);
```

## Data Management

### Check Offline Data Status
```dart
final stats = await OfflinePostHelper.getOfflineStats();

```

### Process Pending Data
```dart
// Process all pending offline data
await OfflinePostHelper.processPendingOfflineData();
```

### Clear Data
```dart
// Clear all offline data
await OfflinePostHelper.clearAllOfflineData();
```

## Error Handling

The service includes comprehensive error handling:

- **Location Permission Denied**: Falls back to cached location
- **GPS Disabled**: Uses last known location
- **Network Errors**: Stores data for later submission
- **Storage Full**: Automatically removes oldest data
- **API Failures**: Retries with exponential backoff

## Performance Considerations

1. **Location Caching**: Reduces GPS usage and battery consumption
2. **Data Limits**: Prevents storage overflow (default: 100 items)
3. **Batch Processing**: Processes multiple items efficiently
4. **Background Sync**: Can be configured for periodic synchronization

## Testing

### Test Offline Location
```dart
// Test location service
final location = await OfflineLocationService.getCurrentLocationOffline();
assert(location['latitude'] != null);
```

### Test Offline Data Storage
```dart
// Test data storage
await OfflineDataService.storeOfflineData(
  dataType: 'test',
  data: {'test': 'value'},
  screenName: 'Test Screen',
);

final pendingData = await OfflineDataService.getPendingOfflineData();
assert(pendingData.isNotEmpty);
```

## Configuration

### Set Maximum Offline Items
```dart
await OfflineDataService.setMaxOfflineItems(50); // Default: 100
```

### Check Location Service Availability
```dart
final isAvailable = await OfflineLocationService.isLocationServiceAvailable();
if (!isAvailable) {
  // Handle case where location services are not available
}
```

## Troubleshooting

### Common Issues

1. **Location not available**: Check permissions and GPS settings
2. **Data not syncing**: Check internet connectivity
3. **Storage issues**: Clear old data or increase limits
4. **Performance issues**: Reduce location accuracy or data limits

### Debug Information

Enable debug logging to see detailed information:
```dart
// All services include comprehensive logging
// Check console output for detailed debug information
```

## Future Enhancements

1. **Background Sync**: Automatic sync in background
2. **Conflict Resolution**: Handle data conflicts during sync
3. **Compression**: Compress stored data to save space
4. **Encryption**: Encrypt sensitive offline data
5. **Analytics**: Track offline usage patterns

## Support

For issues or questions about the offline functionality, check the console logs for detailed error messages and debug information.
