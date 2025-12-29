# PM Custom Form Component Integration Guide

## How It Works

### Current Flow

1. **PM Page Render** (`pm_page_render.dart`)
   - Receives PM data with sections (Battery, Earthing, CCU, etc.)
   - Renders each section one by one using `PMPageWidget`

2. **PM Page Widget** (`pm_page_widget.dart`)
   - Receives a list of PM items for a specific section
   - Iterates through each item and renders either:
     - **PMCustomFormComponent** (for grouped items with `resp_dtl_checklist`)
     - **PMCustomWidget** (for regular items)

3. **Decision Logic** (in `pm_page_widget.dart` line ~407-420)
   ```dart
   // Check if this is a grouped item with resp_dtl_checklist
   final isGroup = pmItem['is_group'] == true;
   final hasRespDtlChecklist = pmItem['resp_dtl_checklist'] != null;

   // Use PMCustomFormComponent for grouped items
   if (isGroup && hasRespDtlChecklist) {
     return PMCustomFormComponent(...);
   }

   // Use regular PMCustomWidget for non-grouped items
   return PMCustomWidget(...);
   ```

---

## Example: Battery Section

### JSON Structure
```json
{
  "is_group": true,
  "resp_type": "NUMERIC",
  "checklist_desc": "Number of Battery Modules",
  "resp": "8",
  "resp_dtl_checklist": [
    {
      "resp_type": "NUMERIC",
      "checklist_desc": "Battery SOH",
      "pm_check_list_mst_id": 29
    }
  ],
  "response_details": [
    {
      "mfg_serial_no": "NG-BATT-762326",
      "resp": null,
      "checklist_desc": "Battery SOH"
    },
    {
      "mfg_serial_no": "NG-BATT-762327",
      "resp": null,
      "checklist_desc": "Battery SOH"
    }
    // ... 6 more batteries
  ]
}
```

### What Happens

1. **Detection**: 
   - `is_group === true` ✅
   - `resp_dtl_checklist` exists ✅
   - `resp_dtl_checklist[0].resp_type === "NUMERIC"` ✅
   - `response_details` exists with `mfg_serial_no` ✅

2. **Rendering**:
   - Uses `PMCustomFormComponent` (CASE 1: Battery)
   - Shows:
     - Label: "Battery SOH" (from `resp_dtl_checklist[0].checklist_desc`)
     - Dropdown: All `mfg_serial_no` values from `response_details`
     - Numeric Input: For entering SOH value
     - Save Button: Updates `response_details[i].resp` for selected serial number

3. **User Interaction**:
   - User selects serial number from dropdown (e.g., "NG-BATT-762326")
   - User enters numeric value (e.g., "85")
   - User clicks "Save"
   - Updates `response_details[0].resp = "85"` (matching by `mfg_serial_no`)
   - Table shows saved entries

---

## Example: Earthing Section

### JSON Structure
```json
{
  "is_group": true,
  "resp_type": "NUMERIC",
  "checklist_desc": "Number of Earth Pits",
  "resp": "3",
  "resp_dtl_checklist": [
    {
      "resp_type": "RADIO",
      "checklist_desc": "Earth pits Above Ground",
      "resp_type_value_map": {
        "OK": "OK",
        "Not Ok": "Not Ok"
      }
    }
  ],
  "response_details": null  // Initially empty
}
```

### What Happens

1. **Detection**:
   - `is_group === true` ✅
   - `resp_dtl_checklist` exists ✅
   - `resp_dtl_checklist[0].resp_type === "RADIO"` ✅
   - `response_details` is null or empty ✅

2. **Rendering**:
   - Uses `PMCustomFormComponent` (CASE 2: Earthing)
   - Shows:
     - Label: "Earth pits Above Ground" (from `resp_dtl_checklist[0].checklist_desc`)
     - Radio Buttons: "OK" and "Not Ok" (from `resp_type_value_map`)
     - Max entries: 3 (from parent `resp` value)

3. **User Interaction**:
   - User selects "OK" radio button
   - Component creates `response_details` array
   - Adds entry: `{...resp_dtl_checklist[0], "resp": "OK"}`
   - User can add up to 3 entries (parent `resp` = 3)
   - After 3 entries, radio buttons are disabled
   - Table shows all saved entries

---

## Data Flow

```
PM Data (JSON)
    ↓
pm_page_render.dart
    ↓
pm_page_widget.dart (for each section)
    ↓
For each PM Item:
    ├─ is_group === true && resp_dtl_checklist exists?
    │   ├─ YES → PMCustomFormComponent
    │   │         ├─ CASE 1: Battery (NUMERIC + response_details)
    │   │         └─ CASE 2: Earthing (RADIO + no response_details)
    │   │
    │   └─ NO → PMCustomWidget (regular field)
    │
    └─ onChange callback → _onItemChanged → Updates _pmItems → Notifies parent
```

---

## Key Points

1. **Automatic Detection**: The system automatically detects which component to use based on:
   - `is_group === true`
   - `resp_dtl_checklist` exists
   - `resp_dtl_checklist[0].resp_type` (NUMERIC or RADIO)
   - Presence of `response_details` with `mfg_serial_no`

2. **No Manual Configuration**: You don't need to specify which items use the custom form component. It's determined automatically.

3. **Data Updates**: When user interacts with `PMCustomFormComponent`:
   - Changes are immediately reflected in `response_details`
   - `onChange` callback updates the parent `_pmItems` list
   - Changes propagate up to `pm_page_render.dart`

4. **Table Display**: The saved items table automatically shows:
   - **Case**: PM Item Type (e.g., "Battery", "Earthing")
   - **Checklist Name**: From `resp_dtl_checklist[0].checklist_desc`
   - **Values**: Serial numbers (CASE 1) or radio selections (CASE 2)

---

## Testing

To test the integration:

1. **Battery Section**:
   - Navigate to Battery section
   - Find "Number of Battery Modules" item
   - Should see dropdown with serial numbers
   - Enter numeric value and save
   - Check table shows saved entries

2. **Earthing Section**:
   - Navigate to Earthing section
   - Find "Number of Earth Pits" item
   - Should see radio buttons
   - Select options (up to the count limit)
   - Check table shows saved entries

---

## Files Modified

1. **pm_page_widget.dart**:
   - Added import for `PMCustomFormComponent`
   - Added conditional logic to detect grouped items
   - Renders appropriate component based on item type

2. **pm_custom_form_component.dart** (New):
   - Handles CASE 1: Battery (NUMERIC + response_details)
   - Handles CASE 2: Earthing (RADIO + no response_details)
   - Displays saved items table

---

## Summary

The integration is **automatic and transparent**. When rendering PM sections:

- **Grouped items** (`is_group === true` + `resp_dtl_checklist`) → Use `PMCustomFormComponent`
- **Regular items** → Use `PMCustomWidget`

No additional configuration needed! The component handles both Battery and Earthing cases automatically based on the JSON structure.

