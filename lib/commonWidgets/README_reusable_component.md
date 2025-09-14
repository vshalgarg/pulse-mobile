# Reusable Asset Audit Component

A highly flexible and reusable Flutter component for asset audit functionality that includes text field with QR scanner, image picker, status selection, optional remarks field, save functionality, and table display of saved items.

## Features

- **Text Field with QR Scanner**: Input field with integrated QR code scanner
- **Image Picker with Compression**: Camera integration with automatic image compression
- **Status Selection**: Radio buttons for OK/Not OK status
- **Optional Remarks Field**: Configurable remarks/notes field
- **Save Functionality**: Save button with callback support
- **Table Display**: Display saved items in a scrollable table
- **Item Management**: Edit and delete items from the table
- **Built-in Validation**: Comprehensive validation system with configurable rules
- **Error Display**: Real-time error messages with visual feedback
- **Highly Configurable**: Extensive customization options
- **Read-only Mode**: Support for read-only display
- **Multiple Image Formats**: Support for file paths, base64, and photo IDs

## Usage

### Basic Usage

```dart
import 'package:app/commonWidgets/reusable_asset_audit_component.dart';

ReusableAssetAuditComponent(
  componentId: 'unique_id',
  serialLabel: "Serial Number",
  photoLabel: "Add Photo",
  statusLabel: "Status",
  serialController: TextEditingController(),
  savedItems: [],
  onItemDeleted: (item) {},
  onSave: () {},
  onPhotoTap: (photoPath) {},
  onStatusChanged: (status) {},
)
```

### Advanced Usage

```dart
ReusableAssetAuditComponent(
  componentId: 'spv_component',
  serialLabel: "SPV - Serial Number",
  photoLabel: "Add a Photo",
  statusLabel: "Status",
  serialController: spvSerialController,
  savedItems: spvSavedItems,
  onItemDeleted: _onItemDeleted,
  onSave: _saveItem,
  onPhotoTap: _onPhotoTap,
  onStatusChanged: _onStatusChanged,
  
  // Optional properties
  serialHintText: "Enter SPV Serial Number *",
  remarksLabel: "Remarks",
  remarksHintText: "Add any remarks here",
  remarksController: remarksController,
  showTable: true,
  tableTitle: "Saved SPV Items",
  tableColumns: const ["Serial Number", "Status", "Photo", "Remarks", "Actions"],
  onItemSelected: _onItemSelected,
  enableQRScanner: true,
  enableImageCompression: true,
  imageHeight: 150,
  backgroundColor: AppColors.green7,
  borderColor: Colors.grey,
  padding: const EdgeInsets.all(16),
  margin: const EdgeInsets.symmetric(vertical: 10),
)
```

## Properties

### Required Properties

| Property | Type | Description |
|----------|------|-------------|
| `componentId` | String | Unique identifier for this component instance |
| `serialLabel` | String | Label for the serial number field |
| `photoLabel` | String | Label for the photo field |
| `statusLabel` | String | Label for the status field |
| `serialController` | TextEditingController | Controller for the serial number field |
| `savedItems` | List<Map<String, dynamic>> | List of saved items to display in table |
| `onItemDeleted` | Function(Map<String, dynamic>) | Callback when item is deleted from table |
| `onSave` | VoidCallback? | Callback when save button is pressed |
| `onPhotoTap` | Function(String?) | Callback when photo is selected |
| `onStatusChanged` | ValueChanged<bool> | Callback when status is changed |

### Optional Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `buttonLabel` | String | "Save" | Text for the save button |
| `onSerialChanged` | ValueChanged<String>? | null | Callback when serial number changes |
| `initialStatus` | bool? | null | Initial status value |
| `initialPhotoPath` | String? | null | Initial photo path |
| `isEditable` | bool | true | Whether the component is editable |
| `isStatusEditable` | bool | true | Whether status selection is editable |
| `backendStatus` | bool? | null | Backend status value |
| `serialHintText` | String? | null | Hint text for serial field |
| `remarksLabel` | String? | null | Label for remarks field |
| `remarksHintText` | String? | null | Hint text for remarks field |
| `remarksController` | TextEditingController? | null | Controller for remarks field |
| `onRemarksChanged` | ValueChanged<String>? | null | Callback when remarks change |
| `showSaveButton` | bool | true | Whether to show save button |
| `isRemarksEditable` | bool | false | Whether remarks field is editable |
| `showTable` | bool | true | Whether to show saved items table |
| `tableTitle` | String | "Saved Items" | Title for the table |
| `tableColumns` | List<String> | ["Serial Number", "Status", "Photo", "Remarks", "Actions"] | Column headers |
| `onItemSelected` | Function(Map<String, dynamic>)? | null | Callback when item is selected from table |
| `enableQRScanner` | bool | true | Whether QR scanner is enabled |
| `enableImageCompression` | bool | true | Whether to compress images |
| `imageHeight` | double | 150.0 | Height of image picker area |
| `backgroundColor` | Color | AppColors.green7 | Background color of component |
| `borderColor` | Color | Colors.grey | Border color of component |
| `padding` | EdgeInsets | EdgeInsets.all(16) | Padding inside component |
| `margin` | EdgeInsets | EdgeInsets.symmetric(vertical: 10) | Margin around component |

### Validation Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `serialValidation` | ValidationConfig? | null | Validation rules for serial number field |
| `remarksValidation` | ValidationConfig? | null | Validation rules for remarks field |
| `requirePhoto` | bool | false | Whether photo is required |
| `requireStatus` | bool | false | Whether status selection is required |
| `validateOnChange` | bool | false | Whether to validate fields on change |
| `validateOnSave` | bool | true | Whether to validate all fields before saving |
| `onValidationFailed` | VoidCallback? | null | Callback when validation fails |
| `onValidationPassed` | VoidCallback? | null | Callback when validation passes |

## Callbacks

### onSave
Called when the save button is pressed. Use this to save the current form data to your list of saved items.

```dart
void _saveItem() {
  if (serialController.text.isNotEmpty) {
    setState(() {
      savedItems.add({
        'serialNumber': serialController.text,
        'status': currentStatus,
        'photo': currentPhotoPath,
        'remarks': remarksController.text,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    
    // Clear form
    serialController.clear();
    remarksController?.clear();
  }
}
```

### onPhotoTap
Called when a photo is selected or deleted. The parameter is the file path or null if deleted.

```dart
void _onPhotoTap(String? photoPath) {
  setState(() {
    currentPhotoPath = photoPath;
  });
}
```

### onStatusChanged
Called when the status radio button selection changes.

```dart
void _onStatusChanged(bool status) {
  setState(() {
    currentStatus = status;
  });
}
```

### onItemDeleted
Called when an item is deleted from the table.

```dart
void _onItemDeleted(Map<String, dynamic> item) {
  setState(() {
    savedItems.remove(item);
  });
}
```

### onItemSelected
Called when an item is selected from the table (for editing).

```dart
void _onItemSelected(Map<String, dynamic> item) {
  // Populate form with selected item data
  serialController.text = item['serialNumber'] ?? '';
  remarksController?.text = item['remarks'] ?? '';
  // Set other fields as needed
}
```

## Saved Items Data Structure

The `savedItems` list should contain maps with the following structure:

```dart
List<Map<String, dynamic>> savedItems = [
  {
    'serialNumber': 'SPV-001',
    'status': true, // true for OK, false for Not OK
    'photo': '/path/to/image.jpg', // or base64 string or photo ID
    'remarks': 'Working condition',
    'timestamp': '2024-01-15T10:30:00Z', // Optional
  },
  // ... more items
];
```

## Validation System

The component includes a comprehensive validation system with multiple validation rules and real-time error display.

### Validation Rules

| Rule | Description | Parameters |
|------|-------------|------------|
| `ValidationRule.required` | Field is required | `customErrorMessage` |
| `ValidationRule.minLength` | Minimum character length | `minLength`, `customErrorMessage` |
| `ValidationRule.maxLength` | Maximum character length | `maxLength`, `customErrorMessage` |
| `ValidationRule.email` | Valid email format | `customErrorMessage` |
| `ValidationRule.numeric` | Numbers only | `customErrorMessage` |
| `ValidationRule.alphanumeric` | Letters and numbers only | `customErrorMessage` |
| `ValidationRule.serialNumber` | Valid serial number format (alphanumeric with hyphens/underscores) | `customErrorMessage` |
| `ValidationRule.custom` | Custom validation function | `customValidator`, `customErrorMessage` |

### Validation Examples

```dart
// Required field with custom error message
serialValidation: const ValidationConfig(
  rule: ValidationRule.required,
  customErrorMessage: 'Serial number is required',
),

// Minimum length validation
serialValidation: const ValidationConfig(
  rule: ValidationRule.minLength,
  minLength: 5,
  customErrorMessage: 'Serial number must be at least 5 characters',
),

// Serial number format validation
serialValidation: const ValidationConfig(
  rule: ValidationRule.serialNumber,
  customErrorMessage: 'Please enter a valid serial number',
),

// Custom validation
serialValidation: ValidationConfig(
  rule: ValidationRule.custom,
  customValidator: (value) => value.startsWith('SPV-'),
  customErrorMessage: 'Serial number must start with "SPV-"',
),

// Combined validation with multiple rules
serialValidation: const ValidationConfig(
  rule: ValidationRule.serialNumber,
),
remarksValidation: const ValidationConfig(
  rule: ValidationRule.maxLength,
  maxLength: 200,
  customErrorMessage: 'Remarks must be less than 200 characters',
),
```

### Validation Behavior

- **Real-time Validation**: Set `validateOnChange: true` to validate fields as user types
- **Save-time Validation**: Set `validateOnSave: true` to validate all fields before saving
- **Required Fields**: Set `requirePhoto: true` or `requireStatus: true` to make fields mandatory
- **Error Display**: Errors are displayed below each field with visual indicators
- **Callbacks**: Use `onValidationFailed` and `onValidationPassed` for custom handling

## Examples

### SPV Component with Validation
```dart
ReusableAssetAuditComponent(
  componentId: 'spv_component',
  serialLabel: "SPV - Serial Number",
  photoLabel: "Add a Photo",
  statusLabel: "Status",
  serialController: spvSerialController,
  savedItems: spvSavedItems,
  onItemDeleted: _onSpvItemDeleted,
  onSave: _saveSpvItem,
  onPhotoTap: _onSpvPhotoTap,
  onStatusChanged: _onSpvStatusChanged,
  remarksLabel: "Remarks",
  remarksController: spvRemarksController,
  backgroundColor: AppColors.green7,
  
  // Validation configuration
  serialValidation: const ValidationConfig(
    rule: ValidationRule.serialNumber,
    customErrorMessage: 'Please enter a valid SPV serial number',
  ),
  remarksValidation: const ValidationConfig(
    rule: ValidationRule.maxLength,
    maxLength: 200,
    customErrorMessage: 'Remarks must be less than 200 characters',
  ),
  requirePhoto: true,
  requireStatus: true,
  validateOnChange: true,
  validateOnSave: true,
  onValidationFailed: () {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fix validation errors before saving'),
        backgroundColor: Colors.red,
      ),
    );
  },
)
```

### Read-only Component
```dart
ReusableAssetAuditComponent(
  componentId: 'readonly_component',
  serialLabel: "Serial Number",
  photoLabel: "Photo",
  statusLabel: "Status",
  serialController: controller,
  savedItems: items,
  onItemDeleted: _onItemDeleted,
  onSave: null,
  onPhotoTap: _onPhotoTap,
  onStatusChanged: _onStatusChanged,
  isEditable: false,
  isStatusEditable: false,
  showSaveButton: false,
  enableQRScanner: false,
  backgroundColor: Colors.grey.shade600,
)
```

### Minimal Component
```dart
ReusableAssetAuditComponent(
  componentId: 'minimal_component',
  serialLabel: "Serial",
  photoLabel: "Photo",
  statusLabel: "Status",
  serialController: controller,
  savedItems: [],
  onItemDeleted: (item) {},
  onSave: _saveItem,
  onPhotoTap: (path) {},
  onStatusChanged: (status) {},
  showTable: false,
  enableQRScanner: false,
  imageHeight: 100,
)
```

## Integration with Existing Screens

To replace existing `CustomInfoCard` usage with `ReusableAssetAuditComponent`:

1. Import the new component:
```dart
import 'package:app/commonWidgets/reusable_asset_audit_component.dart';
```

2. Replace `CustomInfoCard` with `ReusableAssetAuditComponent`:
```dart
// Old
CustomInfoCard(
  serialLabel: "SPV - Serial Number",
  // ... other properties
)

// New
ReusableAssetAuditComponent(
  componentId: 'spv_component',
  serialLabel: "SPV - Serial Number",
  // ... other properties
)
```

3. Update your state management to handle the new callbacks and data structure.

## Benefits

- **Reusable**: Use across multiple screens with different configurations
- **Flexible**: Extensive customization options
- **Consistent**: Uniform UI across different asset types
- **Maintainable**: Single component to maintain instead of multiple variants
- **Feature-rich**: Built-in table display, image handling, QR scanning, validation
- **Type-safe**: Proper typing for all callbacks and data structures
- **Validated**: Comprehensive validation system with real-time error feedback
- **User-friendly**: Clear error messages and visual indicators
