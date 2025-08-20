import 'package:app/commonWidgets/qr_screen_form_field.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/form_fields_model.dart';
import 'custom_file_upload.dart';
import 'custom_form_dropdown.dart';
import 'custom_form_field.dart';
import 'custom_radio_options.dart';

class DynamicFormCard extends StatelessWidget {
  final int index;
  final List<FieldConfig> fields;
  final Function(String fieldLabel, dynamic value)? onValueChanged;

  const DynamicFormCard({
    super.key,
    required this.index,
    required this.fields,
    this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green7,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...fields.asMap().entries.map((entry) {
            final index = entry.key;
            final field = entry.value;
            
            Widget fieldWidget;
            switch (field.type) {
              case FieldType.textField:
                fieldWidget = CustomFormField(
                  label: field.label,
                  initialValue: field.initialValue ?? "",
                  isRequired: field.isRequired,
                  isEditable: field.isEditable,
                );
                break;

              case FieldType.dropdown:
                fieldWidget = CustomDropdown(
                  items: field.items ?? [],
                  onChanged: (val) => onValueChanged?.call(field.label, val),
                );
                break;

              case FieldType.serial:
                fieldWidget = SerialNumberField(
                  label: field.label,
                  controller: field.controller ?? TextEditingController(),
                );
                break;

              case FieldType.upload:
                fieldWidget = FileUploadBox(
                  label: field.label,
                  isRequired: field.isRequired,
                  onUploadTap: () async {
                    print("FileUploadBox tapped for field: ${field.label}");
                    try {
                      // Open file picker
                      final file = await Utils.pickSingleFile(
                        fileType: FileType.custom,
                        extensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
                      );
                      if (file != null) {
                        print("File selected: ${file.path}");
                        onValueChanged?.call(field.label, file.path);
                      } else {
                        print("No file selected");
                      }
                    } catch (e) {
                      print("Error picking file: $e");
                      // Show error message if file picker fails
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error picking file: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  fileName: field.initialValue,
                  onDelete: () => onValueChanged?.call(field.label, null),
                );
                break;

              case FieldType.optionSelector:
                fieldWidget = CustomOptionSelector(
                  label: field.label,
                  isRequired: field.isRequired,
                  options: field.options ?? [],
                  onChanged: (val) => onValueChanged?.call(field.label, val),
                );
                break;

              default:
                fieldWidget = const SizedBox.shrink();
            }

            // Add margin between fields (except for the first field)
            if (index == 0) {
              return fieldWidget;
            } else {
              return Column(
                children: [
                  const SizedBox(height: 10),
                  fieldWidget,
                ],
              );
            }
          }).toList(),
        ],
      ),
    );
  }
}

// class DynamicFormCard extends StatefulWidget {
//   const DynamicFormCard({super.key});
//
//   @override
//   State<DynamicFormCard> createState() => _DynamicFormCardState();
// }
//
// class _DynamicFormCardState extends State<DynamicFormCard> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//       decoration: BoxDecoration(
//         color: AppColors.green7,
//       ),
//         child: Column(
//          children: [
//            CustomFormField(
//              label: "Circle",
//              initialValue: "Haryana",
//              isRequired: true,
//              isEditable: false,
//            ),
//            CustomDropdown(items: items, onChanged: onChanged)
//            getHeight(15),
//            SerialNumberField(
//              label: "ACDB - Serial Number",
//              controller: serialController,
//            ),
//            getHeight(15),
//            FileUploadBox(
//              label: "Customer Photo",
//              isRequired: true,
//              onUploadTap: () async {
//                setState(() {
//                  selectedFile = "Customer_Photo.pdf";
//                  hasUnsavedChanges = true;
//                });
//              },
//              fileName: selectedFile,
//              onDelete: () {
//                setState(() {
//                  selectedFile = null;
//                  hasUnsavedChanges = true;
//                });
//              },
//            ),
//            getHeight(15),
//            CustomOptionSelector(
//              label: "Battery ODC Lock status",
//              isRequired: true,
//              options: [
//                OptionItem(
//                  value: "yes",
//                  label: "Yes",
//                  selectedIcon: Icons.check_circle,
//                  unselectedIcon: Icons.circle_outlined,
//                ),
//                OptionItem(
//                  value: "no",
//                  label: "No",
//                  selectedIcon: Icons.cancel,
//                  unselectedIcon: Icons.circle_outlined,
//                ),
//              ],
//              onChanged: (value) {
//                print("Selected: $value");
//                setState(() {
//                  selectedBatteryStatus = value;
//                  hasUnsavedChanges = true;
//                });
//              },
//            ),
//          ],
//
//         ),
//       ),
//     );
//   }
// }
