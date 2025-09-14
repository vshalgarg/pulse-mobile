import 'package:flutter/material.dart';
import 'package:app/commonWidgets/reusable_asset_audit_component.dart';
import 'package:app/constants/app_colors.dart';

/// Simplified SPV Screen example showing how to use ReusableAssetAuditComponent
/// This replaces all the validation logic that was previously in SPV screen
class SPVScreenSimplifiedExample extends StatefulWidget {
  const SPVScreenSimplifiedExample({super.key});

  @override
  State<SPVScreenSimplifiedExample> createState() => _SPVScreenSimplifiedExampleState();
}

class _SPVScreenSimplifiedExampleState extends State<SPVScreenSimplifiedExample> {
  // Controllers for the reusable component
  final TextEditingController spvSerialController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();

  // List to store saved SPV items (replaces the complex validation logic)
  List<Map<String, dynamic>> spvSavedItems = [];

  // Simple state variables (much fewer than before)
  bool hasUnsavedChanges = false;

  @override
  void dispose() {
    spvSerialController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  // Simplified save method - validation is now handled by the component
  void _saveSpvItem() {
    setState(() {
      spvSavedItems.add({
        'serialNumber': spvSerialController.text,
        'status': true, // This would come from the component's status selection
        'photo': null, // This would come from the component's photo
        'remarks': remarksController.text,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      hasUnsavedChanges = true;
    });
    
    // Clear form after saving
    spvSerialController.clear();
    remarksController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SPV item saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Simple photo handler
  void _onSpvPhotoTap(String? photoPath) {
    print('SPV Photo selected: $photoPath');
    setState(() {
      hasUnsavedChanges = true;
    });
  }

  // Simple status handler
  void _onSpvStatusChanged(bool status) {
    print('SPV Status changed: $status');
    setState(() {
      hasUnsavedChanges = true;
    });
  }

  // Simple delete handler
  void _onSpvItemDeleted(Map<String, dynamic> item) {
    setState(() {
      spvSavedItems.remove(item);
      hasUnsavedChanges = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SPV item deleted!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Simple edit handler
  void _onSpvItemSelected(Map<String, dynamic> item) {
    // Populate form with selected item for editing
    spvSerialController.text = item['serialNumber'] ?? '';
    remarksController.text = item['remarks'] ?? '';
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SPV item selected for editing!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SPV Screen - Simplified'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // This single component replaces ALL the validation logic!
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
              
              // All validation is now handled by the component!
              serialHintText: "Enter SPV Serial Number *",
              remarksLabel: "SPV Remarks",
              remarksHintText: "Add any remarks here",
              remarksController: remarksController,
              showTable: true,
              tableTitle: "Saved SPV Items",
              tableColumns: const ["Serial Number", "Status", "Photo", "Remarks", "Actions"],
              onItemSelected: _onSpvItemSelected,
              enableQRScanner: true,
              enableImageCompression: true,
              imageHeight: 150,
              backgroundColor: AppColors.green7,
              
              // Validation configuration - this replaces ALL the old validation logic!
              serialValidation: ValidationConfig(
                rule: ValidationRule.custom,
                customValidator: (value) {
                  // Custom validation for SPV serial numbers
                  // This replaces the old _validateSerialNumber method
                  if (value.isEmpty) return false;
                  
                  // Add your specific SPV validation logic here
                  // For example: check against API data, specific format, etc.
                  return value.length >= 3; // Simple example
                },
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
              onValidationPassed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All validations passed!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Optional: Show unsaved changes indicator
            if (hasUnsavedChanges)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('You have unsaved changes'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
