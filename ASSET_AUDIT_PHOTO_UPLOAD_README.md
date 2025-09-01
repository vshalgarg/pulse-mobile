# Asset Audit Photo Upload System

This document describes the new Asset Audit Photo Upload system that has been implemented for the telecom asset audit flow.

## Overview

The new system provides a dedicated photo upload mechanism for asset audit screens, using the `/api/v1/mobile/uploads` endpoint instead of the previous selfie upload endpoint.

## Components

### 1. Model (`lib/models/asset_audit_photo_upload_model.dart`)
- `AssetAuditPhotoUploadResponse` class that matches the API response structure
- Contains: `fileName`, `message`, `imgId`, `status`

### 2. Repository (`lib/repositories/asset_audit_photo_upload_repository.dart`)
- `AssetAuditPhotoUploadRepository` class
- Handles the actual API calls to `/api/v1/mobile/uploads`
- Supports optional `imgId` and `schId` parameters
- Uses multipart form data for file uploads

### 3. Cubit (`lib/bloc/asset_audit_photo_upload_cubit.dart`)
- `AssetAuditPhotoUploadCubit` class
- Manages the state of photo uploads
- States: Initial, Loading, Success, Failure

### 4. Helper (`lib/utils/asset_audit_photo_upload_helper.dart`)
- `AssetAuditPhotoUploadHelper` class
- Provides a clean interface for uploading photos
- Methods:
  - `uploadPhotoAndGetId()` - Main upload method
  - `isUploading()` - Check upload status
  - `getLastErrorMessage()` - Get error messages
  - `resetState()` - Reset cubit state

## API Endpoint

- **URL**: `/api/v1/mobile/uploads`
- **Method**: POST
- **Content-Type**: multipart/form-data
- **Parameters**:
  - `imgFile` (required): The image file
  - `activityType` (required): Must be "AA" for Asset Audit
  - `imgId` (optional): Image ID for updates
  - `schId` (optional): Schedule ID

## Response Format

```json
{
  "fileName": "1720254293_12.jpg",
  "message": "Files uploaded successfully",
  "imgId": "55",
  "status": "SUCCESS"
}
```

## Usage in Screens

### Basic Usage

```dart
import '../utils/asset_audit_photo_upload_helper.dart';

// Upload photo and get photoId
final photoId = await AssetAuditPhotoUploadHelper.uploadPhotoAndGetId(
  photoFile: photoFile,
  schId: schId,
  imgId: imgId, // optional
  context: context,
);

if (photoId != null) {
  // Photo uploaded successfully
  setState(() {
    // Store the photoId
  });
}
```

### State Management

```dart
// Check if upload is in progress
if (AssetAuditPhotoUploadHelper.isUploading(context)) {
  // Show loading indicator
}

// Get error messages
final errorMessage = AssetAuditPhotoUploadHelper.getLastErrorMessage(context);

// Reset state if needed
AssetAuditPhotoUploadHelper.resetState(context);
```

## Integration

The system has been integrated into:

1. **App Configuration** (`lib/app_config.dart`)
   - Repository and cubit instances created
   - Dependencies injected

2. **App Root** (`lib/app_root.dart`)
   - Cubit provider registered
   - Available throughout the app

3. **CCU Screen** (`lib/screens/asset_audit/asset_audit_telecom/ccu_screen.dart`)
   - All photo uploads now use the new system
   - Cabinet, Rectifier, and MPPT photo uploads updated

## Benefits

1. **Separation of Concerns**: Dedicated system for asset audit photo uploads
2. **Correct Endpoint**: Uses the proper `/api/v1/mobile/uploads` endpoint
3. **Consistent API**: Matches the expected response format
4. **Reusable**: Can be used across all asset audit screens
5. **Maintainable**: Clean architecture with proper separation

## Next Steps

To complete the implementation:

1. Update other asset audit telecom screens to use the new system:
   - Battery Screen
   - Surveillance Screen
   - SMPS Screen
   - DG Screen
   - Extinguisher Screen
   - Fencing Screen
   - Solar Plates Screen

2. Replace all instances of `AssetAuditPostHelper.uploadPhotoAndGetId` with `AssetAuditPhotoUploadHelper.uploadPhotoAndGetId`

3. Test the photo upload functionality across all screens

## Testing

A test file has been created at `lib/test_asset_audit_photo_upload.dart` to demonstrate the system functionality. You can remove this file after testing is complete.

## Notes

- The system maintains backward compatibility with existing code
- All photo uploads in the CCU screen have been updated
- The new system follows the same patterns as the existing selfie upload system
- Error handling and state management are consistent with other parts of the app
