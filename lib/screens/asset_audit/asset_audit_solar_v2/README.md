# Asset Audit Solar V2

This package provides a new implementation of the Asset Audit Solar functionality with the following improvements:

## Features

1. **Synchronous API Calls**: No more complex state management with Cubits/Blocs
2. **SQLite First**: Data is fetched from local SQLite database first, then from API if not found
3. **Smart Image Caching**: Images are cached locally and fetched from cache when available
4. **Simple Data Flow**: Straightforward data loading and posting without complex state management

## Architecture

### Services

- **`AssetAuditSolarV2Service`**: Main service that coordinates all operations
- **`AssetAuditSolarV2DataService`**: Handles SQLite database operations
- **`AssetAuditSolarV2ApiService`**: Handles API calls
- **`AssetAuditSolarV2ImageService`**: Handles image operations (local + API)

### Data Flow

1. **Initial Load**: When a ticket is clicked, API is called to fetch data and store in SQLite
2. **Screen Display**: All screens fetch data from SQLite database
3. **Image Handling**: Images are first checked in local cache, then fetched from API if needed
4. **Data Posting**: Form data is posted to API and local storage is updated

## Usage

### 1. Initialize Service

In your `main.dart`:

```dart
import 'screens/asset_audit/asset_audit_solar_v2/service_initializer.dart';

void main() async {
  // ... other initialization code
  
  // Initialize AssetAuditSolarV2Service
  AssetAuditSolarV2ServiceInitializer.initialize(apiService);
}
```
```

### 3. Use in Screens

```dart
import 'screens/asset_audit/asset_audit_solar_v2/asset_audit_solar_v2_screen.dart';

// Navigate to the screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AssetAuditSolarV2Screen(
      siteType: siteType,
      auditSchId: auditSchId,
      siteAuditSchId: siteAuditSchId,
    ),
  ),
);
```

## API Endpoints

- **GET** `/api/v1/mobile/assetAudit/PageData/{siteType}/{auditSchId}/{siteAuditSchId}` - Fetch asset audit data
- **POST** `/api/v1/mobile/assetAudit/PostData/{siteType}/{auditSchId}/{siteAuditSchId}` - Post form data
- **GET** `/api/v1/mobile/allImageList?imgIds={imageId}` - Fetch image data
- **POST** `/api/v1/mobile/assetAudit/UploadSelfie/{siteType}/{auditSchId}/{siteAuditSchId}` - Upload selfie
- **POST** `/api/v1/mobile/assetAudit/UploadAssetImage/{siteType}/{auditSchId}/{siteAuditSchId}` - Upload asset image

## Database Schema

### Tables

1. **`page_headers`**: Site information and page header data
2. **`categories`**: Category and subcategory data
3. **`asset_items`**: Individual asset items
4. **`cached_images`**: Cached image data
5. **`form_data`**: Screen-specific form data

### Key Features

- **Atomic Transactions**: All data operations use database transactions
- **Conflict Resolution**: Uses `ConflictAlgorithm.replace` for upsert operations
- **Indexing**: Proper indexing on frequently queried columns
- **Data Integrity**: Foreign key relationships and constraints

## Image Handling

### Caching Strategy

1. **Check Local Cache**: First check if image exists in SQLite
2. **Fetch from API**: If not cached, fetch from API
3. **Cache Result**: Store fetched image in SQLite for future use
4. **Return Data**: Return image data as base64 string

### Supported Formats

- Base64 encoded images
- Data URLs (`data:image/jpeg;base64,...`)
- Local file paths

## Error Handling

- **Network Errors**: Graceful fallback to cached data
- **Database Errors**: Proper error logging and user feedback
- **Image Errors**: Fallback to placeholder images
- **API Errors**: Clear error messages and retry options

## Performance Optimizations

- **Lazy Loading**: Images are loaded only when needed
- **Batch Operations**: Multiple database operations in single transaction
- **Memory Management**: Proper disposal of resources
- **Caching**: Aggressive caching of images and data

## Migration from V1

To migrate from the old Asset Audit Solar implementation:

1. **Replace Navigation**: Update tickets screen to use new navigation
2. **Remove Cubits**: Remove old state management code
3. **Update Imports**: Change imports to use v2 services
4. **Test Thoroughly**: Ensure all functionality works as expected

## Debugging

### Logs

All operations are logged with appropriate log levels:
- **Debug**: Detailed operation information
- **Info**: General operation status
- **Error**: Error conditions and exceptions

### Database Inspection

Use the debug tools to inspect SQLite data:
- Check cached data
- Verify form data persistence
- Inspect image cache

## Future Enhancements

- **Offline Mode**: Full offline functionality
- **Sync Optimization**: Background sync of data
- **Image Compression**: Automatic image compression
- **Batch Upload**: Batch upload of multiple images
- **Data Validation**: Enhanced data validation
- **Performance Metrics**: Detailed performance monitoring
