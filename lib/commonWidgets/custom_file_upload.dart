import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_colors.dart';
import '../constants/constants_strings.dart';

class FileUploadBox extends StatelessWidget {
  final VoidCallback onUploadTap;
  final String? fileName;
  final VoidCallback? onDelete;
  final String label;
  final bool isRequired;

  const FileUploadBox({
    super.key,
    required this.onUploadTap,
    this.fileName,
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

              const SizedBox(height: 12),

              // File name + Delete Icon (only show if file exists)
              if (fileName != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        fileName!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SvgPicture.asset(AppImages.trash),
                    // IconButton(
                    //   icon: const Icon(Icons.restore_from_trash_outlined, color: Colors.red),
                    //   onPressed: onDelete,
                    // ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
