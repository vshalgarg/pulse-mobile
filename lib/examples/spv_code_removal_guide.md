# SPV Screen Code Removal Guide

## Code to Remove from SPV Screen

When using the `ReusableAssetAuditComponent`, you can remove the following code from your SPV screen:

### 1. Remove the `_buildSpvSavedItemsList()` Method (Lines 1144-1338)

```dart
// REMOVE THIS ENTIRE METHOD (94 lines of code!)
Widget _buildSpvSavedItemsList() {
  if (savedSpvItems.isEmpty) {
    return Container(); // Return empty container if no items
  }

  return Column(
    children: [
      Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.green7,
          borderRadius: BorderRadius.circular(5),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 200,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: const Text(
                      "Serial No.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: fontFamilyMontserrat,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: const Text(
                      "Status",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: fontFamilyMontserrat,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: const Text(
                      "Scanned",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: fontFamilyMontserrat,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: const Text(
                      "Photo",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: fontFamilyMontserrat,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: const Text(
                      "Edit",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: fontFamilyMontserrat,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (savedSpvItems.isNotEmpty) ...[
                ...savedSpvItems.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 200,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            item["serialNumber"] ?? "",
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            item["status"] ?? "",
                            style: const TextStyle(
                              color: AppColors.color555555,
                              fontSize: 14,
                              fontFamily: fontFamilyMontserrat,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            item['isQRCodeScanned'] == true
                                ? Icons.qr_code_scanner
                                : Icons.close,
                            color: item['isQRCodeScanned'] == true
                                ? Colors.blue
                                : Colors.red,
                          ),
                        ),
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: IconButton(
                            icon: Icon(
                              Icons.camera_alt,
                              color: item['photo'] != null && item['photo'].isNotEmpty
                                  ? AppColors.color555555
                                  : Colors.grey,
                            ),
                            onPressed: item['photo'] != null && item['photo'].isNotEmpty
                                ? () {
                              _showPhotoViewer(context, item['photo'], widget.siteAuditSchId);
                            }
                                : null,
                          ),
                        ),
                        Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit_calendar_outlined,
                              color: AppColors.color555555,
                            ),
                            onPressed: () {
                              _editItem(item);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}
```

### 2. Remove the `_editItem()` Method (Lines 698-724)

```dart
// REMOVE THIS ENTIRE METHOD (26 lines of code!)
void _editItem(Map<String, dynamic> item) {
  Logger.debugLog('=== SPV: _editItem called with item: $item ===');
  Logger.debugLog('=== SPV: Item status: ${item['status']} ===');
  setState(() {
    spvSerialNumber = item['serialNumber'];
    photoImageId = item['photo'];
    spvPhoto = item['spvPhoto'];
    spvStatus = item['status'];
    
    // Set original status for comparison
    _originalSpvStatus = item['status'];
    
    // Set editing flags
    _isEditingExistingItem = true;
    _editingItemSerialNumber = item['serialNumber'];
    
    // Don't set hasUnsavedChanges = true here - let _onFormChanged handle it
    spvCardKey++;
  });
  Logger.debugLog('=== SPV: After _editItem setState - spvStatus: $spvStatus, _originalSpvStatus: $_originalSpvStatus ===');
  Logger.debugLog('=== SPV: Editing existing item: $_isEditingExistingItem, Serial: $_editingItemSerialNumber ===');
  _onFormChanged();

  // Load image asynchronously to avoid blocking UI
  if ((spvPhoto == null || spvPhoto!.isEmpty) && (photoImageId != null || photoImageId!.isNotEmpty)) {
    // ... rest of the method
  }
}
```

### 3. Remove the Call to `_buildSpvSavedItemsList()` (Line 1066)

```dart
// REMOVE THIS LINE
_buildSpvSavedItemsList(),
```

### 4. Simplify the `savedSpvItems` List Management

Since the `ReusableAssetAuditComponent` handles the saved items table, you can simplify how you manage `savedSpvItems`:

```dart
// OLD: Complex savedSpvItems management
List<Map<String, dynamic>> savedSpvItems = [];

// NEW: Simple list for the component
List<Map<String, dynamic>> savedSpvItems = [];

// The component will handle:
// - Displaying the table
// - Edit functionality
// - Delete functionality
// - Photo viewing
```

### 5. Remove Related Variables and Methods

You can also remove these related variables and methods:

```dart
// REMOVE these variables (if not used elsewhere)
bool _isEditingExistingItem = false;
String? _editingItemSerialNumber;
String? _originalSpvStatus;
int spvCardKey = 0;

// REMOVE these methods (if not used elsewhere)
String _truncateSerialNumber(String serialNumber) {
  // ... method implementation
}
```

## What the ReusableAssetAuditComponent Replaces

The `ReusableAssetAuditComponent` with `showTable: true` provides:

1. **Built-in Table Display**: Automatically shows saved items in a table format
2. **Edit Functionality**: Built-in edit buttons that call your `onItemSelected` callback
3. **Delete Functionality**: Built-in delete buttons that call your `onItemDeleted` callback
4. **Photo Viewing**: Built-in photo viewing functionality
5. **Consistent Styling**: Same table styling across all asset audit screens
6. **Responsive Design**: Automatically handles different screen sizes

## Code Reduction Summary

- **Remove**: `_buildSpvSavedItemsList()` method (94 lines)
- **Remove**: `_editItem()` method (26 lines)
- **Remove**: Call to `_buildSpvSavedItemsList()` (1 line)
- **Remove**: Related variables and methods (10+ lines)
- **Total Reduction**: ~130+ lines of code!

## Result

After removing this code, your SPV screen will be much cleaner and the `ReusableAssetAuditComponent` will handle all the saved items display and interaction functionality automatically.
