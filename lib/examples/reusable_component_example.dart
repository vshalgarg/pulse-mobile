import 'package:flutter/material.dart';
import 'package:app/commonWidgets/reusable_asset_audit_component.dart';
import 'package:app/constants/app_colors.dart';

/// Example usage of the ReusableAssetAuditComponent
/// This demonstrates how to use the component in different scenarios
class ReusableComponentExample extends StatefulWidget {
  const ReusableComponentExample({super.key});

  @override
  State<ReusableComponentExample> createState() => _ReusableComponentExampleState();
}

class _ReusableComponentExampleState extends State<ReusableComponentExample> {
  // Controllers for different components
  final TextEditingController spvSerialController = TextEditingController();
  final TextEditingController mmsSerialController = TextEditingController();
  final TextEditingController inverterSerialController = TextEditingController();
  final TextEditingController spvRemarksController = TextEditingController();
  final TextEditingController mmsRemarksController = TextEditingController();

  // Lists to store saved items for each component
  List<Map<String, dynamic>> spvSavedItems = [];
  List<Map<String, dynamic>> mmsSavedItems = [];
  List<Map<String, dynamic>> inverterSavedItems = [];

  @override
  void dispose() {
    spvSerialController.dispose();
    mmsSerialController.dispose();
    inverterSerialController.dispose();
    spvRemarksController.dispose();
    mmsRemarksController.dispose();
    super.dispose();
  }

  // SPV Component Handlers
  void _saveSpvItem() {
    if (spvSerialController.text.isNotEmpty) {
      setState(() {
        spvSavedItems.add({
          'serialNumber': spvSerialController.text,
          'status': true, // You can get this from the component
          'photo': null, // You can get this from the component
          'remarks': spvRemarksController.text,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
      
      // Clear form
      spvSerialController.clear();
      spvRemarksController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SPV item saved successfully!')),
      );
    }
  }

  void _onSpvPhotoTap(String? photoPath) {
    print('SPV Photo selected: $photoPath');
  }

  void _onSpvStatusChanged(bool status) {
    print('SPV Status changed: $status');
  }

  void _onSpvItemDeleted(Map<String, dynamic> item) {
    setState(() {
      spvSavedItems.remove(item);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SPV item deleted!')),
    );
  }

  void _onSpvItemSelected(Map<String, dynamic> item) {
    // Populate form with selected item for editing
    spvSerialController.text = item['serialNumber'] ?? '';
    spvRemarksController.text = item['remarks'] ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SPV item selected for editing!')),
    );
  }

  // MMS Component Handlers
  void _saveMmsItem() {
    if (mmsSerialController.text.isNotEmpty) {
      setState(() {
        mmsSavedItems.add({
          'serialNumber': mmsSerialController.text,
          'status': false,
          'photo': null,
          'remarks': mmsRemarksController.text,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
      
      mmsSerialController.clear();
      mmsRemarksController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MMS item saved successfully!')),
      );
    }
  }

  void _onMmsPhotoTap(String? photoPath) {
    print('MMS Photo selected: $photoPath');
  }

  void _onMmsStatusChanged(bool status) {
    print('MMS Status changed: $status');
  }

  void _onMmsItemDeleted(Map<String, dynamic> item) {
    setState(() {
      mmsSavedItems.remove(item);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('MMS item deleted!')),
    );
  }

  // Inverter Component Handlers (Read-only example)
  void _onInverterPhotoTap(String? photoPath) {
    print('Inverter Photo selected: $photoPath');
  }

  void _onInverterStatusChanged(bool status) {
    print('Inverter Status changed: $status');
  }

  void _onInverterItemDeleted(Map<String, dynamic> item) {
    setState(() {
      inverterSavedItems.remove(item);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inverter item deleted!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reusable Component Examples'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Example 1: SPV Component with full functionality and validation
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
              serialHintText: "Enter SPV Serial Number *",
              remarksLabel: "Remarks",
              remarksHintText: "Add any remarks here",
              remarksController: spvRemarksController,
              showTable: true,
              tableTitle: "Saved SPV Items",
              tableColumns: const ["Serial Number", "Status", "Photo", "Remarks", "Actions"],
              onItemSelected: _onSpvItemSelected,
              enableQRScanner: true,
              enableImageCompression: true,
              imageHeight: 150,
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

            // Example 2: MMS Component with different configuration and validation
            ReusableAssetAuditComponent(
              componentId: 'mms_component',
              serialLabel: "MMS - Serial Number",
              photoLabel: "Add MMS Photo",
              statusLabel: "MMS Status",
              serialController: mmsSerialController,
              savedItems: mmsSavedItems,
              onItemDeleted: _onMmsItemDeleted,
              onSave: _saveMmsItem,
              onPhotoTap: _onMmsPhotoTap,
              onStatusChanged: _onMmsStatusChanged,
              serialHintText: "Enter MMS Serial Number *",
              remarksLabel: "MMS Remarks",
              remarksController: mmsRemarksController,
              showTable: true,
              tableTitle: "Saved MMS Items",
              tableColumns: const ["Serial", "Status", "Photo", "Remarks", "Delete"],
              enableQRScanner: true,
              enableImageCompression: false, // No compression for MMS
              imageHeight: 120,
              backgroundColor: Colors.blue.shade700,
              borderColor: Colors.blue.shade300,
              
              // Different validation configuration
              serialValidation: const ValidationConfig(
                rule: ValidationRule.alphanumeric,
                minLength: 5,
                customErrorMessage: 'MMS serial must be at least 5 alphanumeric characters',
              ),
              requirePhoto: false, // Photo not required for MMS
              requireStatus: true,
              validateOnChange: false, // Only validate on save
              validateOnSave: true,
            ),

            const SizedBox(height: 20),

            // Example 3: Read-only Inverter Component
            ReusableAssetAuditComponent(
              componentId: 'inverter_component',
              serialLabel: "Inverter - Serial Number",
              photoLabel: "Inverter Photo",
              statusLabel: "Inverter Status",
              serialController: inverterSerialController,
              savedItems: inverterSavedItems,
              onItemDeleted: _onInverterItemDeleted,
              onSave: null, // No save button
              onPhotoTap: _onInverterPhotoTap,
              onStatusChanged: _onInverterStatusChanged,
              serialHintText: "Inverter Serial Number (Read Only)",
              isEditable: false, // Read-only mode
              isStatusEditable: false, // Read-only status
              showSaveButton: false, // No save button
              showTable: true,
              tableTitle: "Inverter Items (Read Only)",
              tableColumns: const ["Serial", "Status", "Photo", "Delete"],
              enableQRScanner: false, // No QR scanner in read-only mode
              backgroundColor: Colors.grey.shade600,
              borderColor: Colors.grey.shade400,
            ),

            const SizedBox(height: 20),

            // Example 4: Minimal Component (No table, no remarks)
            ReusableAssetAuditComponent(
              componentId: 'minimal_component',
              serialLabel: "Serial Number",
              photoLabel: "Photo",
              statusLabel: "Status",
              serialController: TextEditingController(),
              savedItems: [],
              onItemDeleted: (item) {},
              onSave: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Minimal component saved!')),
                );
              },
              onPhotoTap: (path) {},
              onStatusChanged: (status) {},
              showTable: false, // No table
              showSaveButton: true,
              enableQRScanner: false, // No QR scanner
              backgroundColor: Colors.purple.shade700,
              imageHeight: 100,
            ),
          ],
        ),
      ),
    );
  }
}
