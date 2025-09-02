# 🖼️ Asset Audit Image Integration Guide

## 🎯 **Overview**
This guide explains how to implement image display for all asset audit screens using the **Screen-by-Screen Integration** approach (Approach 2).

## 🚀 **Why Approach 2 is Better**

### **Approach 1: Get All Images on First Page**
- ❌ **Complex state management** - Need to pass large image data between screens
- ❌ **Memory issues** - Loading all images at once can cause performance problems
- ❌ **Slower initial load** - User waits for all images before proceeding
- ❌ **Harder to maintain** - Changes affect multiple screens

### **Approach 2: Screen-by-Screen Integration (Recommended)**
- ✅ **Better performance** - Images load only when needed
- ✅ **Cleaner architecture** - Each screen manages its own images
- ✅ **Easier maintenance** - Changes are isolated to specific screens
- ✅ **Better user experience** - Progressive loading, faster navigation

## 🏗️ **Implementation Pattern**

### **1. Required Components**
```dart
// Add to MultiBlocListener in each screen
BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
  listener: (context, state) {
    if (state is AssetAuditGetImageSuccess) {
      // Handle successful image fetch
      _handleImageFetchSuccess(state.imageData, state.imgId);
    } else if (state is AssetAuditGetImageFailure) {
      // Handle image fetch failure
      print('Image fetch failed: ${state.errorMessage}');
    }
  },
),
```

### **2. Image Fetching Method**
```dart
/// Fetch images for existing items that have photoId
void _fetchImagesForExistingItems() {
  if (savedItems.isEmpty) return;
  
  print('=== Fetching images for existing items ===');
  for (int i = 0; i < savedItems.length; i++) {
    final item = savedItems[i];
    final photoId = item['photoId'];
    
    if (photoId != null && photoId.toString().isNotEmpty && photoId.toString() != "0") {
      print('Fetching image for item $i: photoId=$photoId');
      
      // Get the siteAuditSchId from the asset audit data
      if (widget.assetAuditData?.pageHeader.isNotEmpty == true) {
        final schId = widget.assetAuditData!.pageHeader.first.siteAuditSchId.toString();
        
        // Trigger image fetch using the AssetAuditGetImageCubit
        context.read<AssetAuditGetImageCubit>().getImage(
          imgId: photoId.toString(),
          schId: schId,
        );
      }
    }
  }
}
```

### **3. Image Success Handler**
```dart
/// Handle successful image fetch
void _handleImageFetchSuccess(String imageData, String imgId) {
  print('=== Image fetch success ===');
  print('Image data length: ${imageData.length}');
  
  // Find the item that corresponds to this image and update it
  for (int i = 0; i < savedItems.length; i++) {
    if (savedItems[i]['photoId']?.toString() == imgId) {
      setState(() {
        savedItems[i]['photo'] = 'data:image/jpeg;base64,$imageData';
        print('Updated item $i with image data');
      });
      break;
    }
  }
}
```

### **4. Call Image Fetching**
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  
  // ... existing code ...
  
  // Fetch images for existing items
  _fetchImagesForExistingItems();
}
```

## 📱 **Screen-by-Screen Implementation**

### **1. Telecom Page 1 (Selfie) ✅ COMPLETED**
- **Items**: Selfie image
- **Photo ID Source**: `pageHeader.makerSelfieImageId`
- **Implementation**: Uses `AssetAuditGetImageCubit` to fetch and display selfie

### **2. Fencing Screen ✅ COMPLETED**
- **Items**: Boundary items
- **Photo ID Source**: `item.photoId` from API response
- **Implementation**: Fetches images for all Boundary items with photo IDs

### **3. SMPS Screen (Need to Implement)**
- **Items**: Rectifier, MPPT, ACDB, LSPU items
- **Photo ID Source**: `item.photoId` from API response
- **Implementation**: Add image fetching for all item types

### **4. DG Screen (Need to Implement)**
- **Items**: CCTV items
- **Photo ID Source**: `item.photoId` from API response
- **Implementation**: Add image fetching for CCTV items

### **5. Battery Screen (Need to Implement)**
- **Items**: Rectifier, MPPT items
- **Photo ID Source**: `item.photoId` from API response
- **Implementation**: Add image fetching for battery items

### **6. Solar Plates Screen (Need to Implement)**
- **Items**: Rectifier, MPPT items
- **Photo ID Source**: `item.photoId` from API response
- **Implementation**: Add image fetching for solar items

## 🔧 **Implementation Steps for Each Screen**

### **Step 1: Add BlocListener**
```dart
// Add to MultiBlocListener
BlocListener<AssetAuditGetImageCubit, AssetAuditGetImageState>(
  listener: (context, state) {
    if (state is AssetAuditGetImageSuccess) {
      _handleImageFetchSuccess(state.imageData, state.imgId);
    }
  },
),
```

### **Step 2: Add Image Fetching Method**
```dart
void _fetchImagesForExistingItems() {
  // Implementation specific to each screen
}
```

### **Step 3: Add Image Success Handler**
```dart
void _handleImageFetchSuccess(String imageData, String imgId) {
  // Implementation specific to each screen
}
```

### **Step 4: Call in didChangeDependencies**
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  _fetchImagesForExistingItems();
}
```

## 📊 **Data Flow**

```
Screen Loads
     ↓
Load Items from API
     ↓
Check for Photo IDs
     ↓
Trigger Image Fetch for Each Item
     ↓
Image Fetch Success
     ↓
Update Item with Image Data
     ↓
Display Image in UI
```

## 🎨 **UI Display**

### **For Each Item Type**
```dart
// Example: Display image in CustomInfoCard
CustomInfoCard(
  // ... other parameters ...
  initialPhotoPath: item['photo'] ?? null, // Use fetched image data
  onPhotoTap: () {
    // Handle photo tap
  },
)
```

## 🚨 **Important Notes**

1. **Photo ID Mapping**: Ensure `photoId` field is correctly mapped from API response
2. **Image Data Format**: Images are returned as base64 strings, prefix with `data:image/jpeg;base64,`
3. **State Management**: Use `setState` to update item data when images are fetched
4. **Error Handling**: Handle image fetch failures gracefully
5. **Performance**: Only fetch images for items that have photo IDs

## 🔍 **Debugging**

### **Add Debug Prints**
```dart
print('=== Fetching images for existing items ===');
print('Total items: ${savedItems.length}');
print('Items with photo IDs: ${savedItems.where((item) => item['photoId'] != null).length}');
```

### **Check Image Data**
```dart
print('Image data length: ${imageData.length}');
print('Image data starts with: ${imageData.substring(0, Math.min(50, imageData.length))}');
```

## ✅ **Benefits of This Approach**

1. **Scalable**: Easy to add new screens and item types
2. **Maintainable**: Each screen manages its own images
3. **Performance**: Images load progressively, no memory issues
4. **User Experience**: Faster navigation, immediate image display
5. **Debugging**: Easy to track image loading per screen

## 🎯 **Next Steps**

1. ✅ **Telecom Page 1** - Selfie image (COMPLETED)
2. ✅ **Fencing Screen** - Boundary items (COMPLETED)
3. 🔄 **SMPS Screen** - Rectifier, MPPT, ACDB, LSPU items
4. 🔄 **DG Screen** - CCTV items
5. 🔄 **Battery Screen** - Rectifier, MPPT items
6. 🔄 **Solar Plates Screen** - Rectifier, MPPT items

This approach ensures that all asset audit screens can display images for their respective items efficiently and maintainably! 🚀
