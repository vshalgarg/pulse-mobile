import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';

class CustomFileUploadNew extends StatelessWidget {
  final String? label;
  final String? placeholder;
  final File? selectedFile;
  final Function(File?) onFileSelected;
  final bool isRequired;
  final String? acceptedFileTypes;
  final String? maxSizeText;
  final List<File> uploadedFiles;
  final Function(File) onFileDeleted;
  final bool isDisabled; // Add isDisabled parameter

  const CustomFileUploadNew({
    super.key,
    this.label,
    this.placeholder,
    this.selectedFile,
    required this.onFileSelected,
    this.isRequired = false,
    this.acceptedFileTypes,
    this.maxSizeText,
    this.uploadedFiles = const [],
    required this.onFileDeleted,
    this.isDisabled = false, // Default value is false
  });

  Future<void> _pickFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      onFileSelected(File(result.files.single.path!));
    }
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with required asterisk
        if (label != null) ...[
          Row(
            children: [
              Text(
                label!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.whiteColor,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              if (isRequired)
                const Text(
                  " *",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                    fontFamily: fontFamilyMontserrat,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // Upload box
        GestureDetector(
          onTap: isDisabled ? null : () => _pickFile(context),
          child: Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: isDisabled ? Colors.grey.shade200 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
            child: selectedFile != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 18,
                          color: AppColors.color555555,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getFileName(selectedFile!.path),
                            style: const TextStyle(
                              fontWeight: FontWeight.w400,
                              color: AppColors.color555555,
                              fontFamily: fontFamilyMontserrat,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isDisabled)
                          GestureDetector(
                            onTap: () => onFileSelected(null),
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red.shade400,
                            ),
                          ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.upload_file,
                          size: 20,
                          color: AppColors.color555555,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          placeholder ?? "Upload File",
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.color555555,
                            fontFamily: fontFamilyMontserrat,
                            fontSize: 14,
                          ),
                        ),
                        if (maxSizeText != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            maxSizeText!,
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: AppColors.color555555.withOpacity(0.7),
                              fontFamily: fontFamilyMontserrat,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (acceptedFileTypes != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            acceptedFileTypes!,
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: AppColors.color555555.withOpacity(0.7),
                              fontFamily: fontFamilyMontserrat,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
        
        // Uploaded Files List
        if (uploadedFiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...uploadedFiles.map((file) => _buildUploadedFileItem(file)).toList(),
        ],
        
      ],
    );
  }

  Widget _buildUploadedFileItem(File file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(file.path),
            size: 20,
            color: AppColors.color555555,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getFileName(file.path),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.color555555,
                fontFamily: fontFamilyMontserrat,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (!isDisabled)
            GestureDetector(
              onTap: () => onFileDeleted(file),
              child: Icon(
                Icons.delete_outline,
                size: 20,
                color: Colors.red.shade400,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }
}
