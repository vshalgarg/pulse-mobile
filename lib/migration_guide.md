# Migration Guide: CentralAssetAuditServiceInitializer → ServiceLocator

## Overview
This guide shows how to migrate from the old `CentralAssetAuditServiceInitializer` pattern to the new `ServiceLocator` pattern.

## Files to Update
The following files need to be updated (found via grep):

### Solar V2 Screens:
- `lib/screens/asset_audit/asset_audit_solar_v2/acdb_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/dcdb_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/vcb_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/transformer_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/mms_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/fire_extinguisher_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/scada_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/wms_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/pcu_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/ltdb_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/inverter_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/boundary_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_solar_v2/surveillance_v2_screen.dart`

### Telecom V2 Screens:
- `lib/screens/asset_audit/asset_audit_telecom_v2/dg_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_telecom_v2/fire_extinguisher_telecom_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_telecom_v2/cctv_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_telecom_v2/smps_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_telecom_v2/boundary_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_telecom_v2/solar_plate_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_telecom_v2/battery_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_telecom_v2/ccu_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_telecom_v2/boundary_telecom_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_telecom_v2/site_info_v2_screen.dart`
- `lib/screens/asset_audit/asset_audit_telecom_v2/asset_audit_telecom_v2_screen.dart`

### Other Files:
- `lib/screens/asset_audit/asset_audit_solar_v2/asset_audit_solar_v2_screen.dart`
- `lib/commonWidgets/pm_page_render.dart`

## Migration Steps

### 1. Update Imports
**Remove:**
```dart
import '../../../services/asset_audit/central_service_initializer.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';
```

**Add:**
```dart
import '../../../services/service_locator.dart';
```

### 2. Remove Service Instance Variable
**Remove:**
```dart
late CentralAssetAuditService _service;
```

### 3. Remove Initialization Method
**Remove the entire `_initializeServices()` method:**
```dart
void _initializeServices() {
  Logger.debugLog('🔧 Initializing Central Asset Audit service for...');
  _service = CentralAssetAuditServiceInitializer.getService();
  
  // Check if service is initialized
  if (!CentralAssetAuditServiceInitializer.isInitialized) {
    Logger.errorLog('❌ Central service not initialized!');
    setState(() {
      _errorMessage = 'Central service not initialized. Please restart the app.';
      _isLoadingData = false;
    });
    return;
  }
  
  Logger.debugLog('✅ Central Asset Audit service initialized successfully');
}
```

### 4. Update initState()
**Remove the call to `_initializeServices()`:**
```dart
@override
void initState() {
  super.initState();
  // Remove this line: _initializeServices();
  _loadData();
}
```

### 5. Replace Service Usage
**Replace all instances of `_service.` with `ServiceLocator().centralAssetAuditService.`:**

**Before:**
```dart
final data = await _service.getAssetAuditData(...);
_service.updateDataInSqlite(...);
```

**After:**
```dart
final data = await ServiceLocator().centralAssetAuditService.getAssetAuditData(...);
ServiceLocator().centralAssetAuditService.updateDataInSqlite(...);
```

## Example Migration (spv_v2_screen.dart)

### Before:
```dart
import '../../../services/asset_audit/central_service_initializer.dart';
import '../../../services/asset_audit/central_asset_audit_service.dart';

class _SPVV2ScreenState extends State<SPVV2Screen> {
  late CentralAssetAuditService _service;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
  }

  void _initializeServices() {
    _service = CentralAssetAuditServiceInitializer.getService();
    if (!CentralAssetAuditServiceInitializer.isInitialized) {
      // error handling
    }
  }

  Future<void> _loadData() async {
    final data = await _service.getAssetAuditData(...);
    // ...
  }
}
```

### After:
```dart
import '../../../services/service_locator.dart';

class _SPVV2ScreenState extends State<SPVV2Screen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await ServiceLocator().centralAssetAuditService.getAssetAuditData(...);
    // ...
  }
}
```

## Benefits After Migration

✅ **No more initialization checks** - ServiceLocator guarantees services are ready  
✅ **Cleaner code** - Removed repetitive initialization logic  
✅ **Better error handling** - Clear errors if services not initialized  
✅ **Consistent pattern** - Same approach across entire app  
✅ **Fail-fast behavior** - App won't start if services fail to initialize  

## Testing After Migration

1. **Run the app** - Should start without initialization errors
2. **Test asset audit screens** - Should work without service initialization issues
3. **Test PM screens** - Should work with the new service locator
4. **Check logs** - Should see "All services initialized successfully" message

## Notes

- The old `CentralAssetAuditServiceInitializer` can be deleted after all files are migrated
- All service calls are now guaranteed to work (no null checks needed)
- The app will fail fast if services aren't properly initialized at startup
