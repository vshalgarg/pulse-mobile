import 'package:app/constants/constants_methods.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';

class FileUploadBox extends StatelessWidget {
  final VoidCallback onUploadTap;
  final File? selectedFile;
  final String? selectedFileName;
  final String? selectedFileSize;
  final VoidCallback? onDelete;
  final String label;
  final bool isRequired;

  const FileUploadBox({
    super.key,
    required this.onUploadTap,
    this.selectedFile,
    this.selectedFileName,
    this.selectedFileSize,
    this.onDelete,
    required this.label,
    required this.isRequired,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontFamily: fontFamilyMontserrat,
              ),
            ),
            if (isRequired)
              const Text(
                " *",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.errorColor,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
          ],
        ),
        getHeight(5),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show selected file if exists, otherwise show upload box
              if (selectedFile != null && selectedFileName != null) ...[
                // File info display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getFileIcon(selectedFileName!),
                        color: AppColors.primaryGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedFileName!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                                fontFamily: fontFamilyMontserrat,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (selectedFileSize != null)
                              Text(
                                selectedFileSize!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontFamily: fontFamilyMontserrat,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: onDelete,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Option to change file
                TextButton.icon(
                  onPressed: onUploadTap,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text(
                    'Change File',
                    style: TextStyle(fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                  ),
                ),
              ] else ...[
                // Upload Box with Dashed Border
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onUploadTap,
                    borderRadius: BorderRadius.circular(3),
                    child: DottedBorder(
                      color: Colors.grey,
                      strokeWidth: 1,
                      dashPattern: const [6, 3],
                      borderType: BorderType.RRect,
                      radius: const Radius.circular(3),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.file_upload_outlined, color: AppColors.color555555, size: 22),
                            SizedBox(width: 8),
                            Text(
                              "Upload File (Max Size: 2MB)",
                              style: TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.color555555,
                                fontFamily: fontFamilyMontserrat,),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Get appropriate icon based on file extension
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }
}
