import 'dart:io';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/app_colors.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/constants_strings.dart';
import '../services/service_locator.dart';
import '../utils/logger.dart';
import '../utils/toastbar.dart';
import 'package:open_file/open_file.dart';

class CMRemarksShowWidget extends StatelessWidget {
  final List<dynamic> remarksList;

  const CMRemarksShowWidget({
    super.key,
    required this.remarksList,
  });

  String _formatTimestamp(int timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('dd-MMM-yyyy').format(date);
    } catch (e) {
      Logger.errorLog('Error formatting timestamp: $e');
      return '';
    }
  }

  Future<void> _downloadAndOpenAttachment(
    BuildContext context,
    int attachmentId,
    String attachmentName,
  ) async {
    try {
      LoaderWidget.showLoader(context);
      // Download file
      final byteData = await ServiceLocator()
          .imageUploadService
          .downloadFromServer(attachmentId.toString());

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (byteData == null || byteData.isEmpty) {
        if (context.mounted) {
          Toastbar.showErrorToastbar('Failed to download attachment', context);
        }
        return;
      }

      // Parse base64 data if needed
      String base64Data = byteData;
      if (byteData.contains(',')) {
        base64Data = byteData.split(',')[1];
      }

      // Convert to bytes
      final bytes = base64Data.codeUnits;

      // Get temporary directory and save file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'attachment_$attachmentName.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Open file
      final result = await OpenFile.open(file.path);
      
      if (result.type != ResultType.done && context.mounted) {
        Toastbar.showErrorToastbar('Could not open file: ${result.message}', context);
      }
    } catch (e) {
      Logger.errorLog('Error downloading attachment: $e');
      
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context).pop();
        Toastbar.showErrorToastbar('Error downloading attachment', context);
      }
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (remarksList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: remarksList.map((remarkItem) {
        // Convert dynamic to Map<String, dynamic>
        final remark = remarkItem is Map<String, dynamic> 
            ? remarkItem 
            : Map<String, dynamic>.from(remarkItem as Map);
        
        final createdByName = remark['created_by_name']?.toString() ?? 'Unknown';
        final cmStatus = remark['cm_status']?.toString() ?? '';
        final cmRemark = remark['cm_remark']?.toString() ?? '';
        final timestamp = remark['createddt'] as int? ?? 0;
        final attachmentId = remark['cm_attachment_id'] as int?;
        final attachmentName = remark['cm_attachment_name']?.toString() ?? 'file';
        final formattedDate = _formatTimestamp(timestamp);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F5EF).withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              if (formattedDate.isNotEmpty) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontFamily: fontFamilyMontserrat,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const DottedLine(
                          dashLength: 4,       // length of each dash
                          dashGapLength: 3,    // space between dashes
                          lineThickness: 2,    // thickness of the line
                          dashColor: AppColors.whiteColor, // dotted line color
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Content row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side - Name, Status, and Remark
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name and Status
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '[$createdByName]',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: fontFamilyMontserrat,
                                ),
                              ),
                              if (cmStatus.isNotEmpty) ...[
                                const TextSpan(
                                  text: ' : ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                                TextSpan(
                                  text: cmRemark,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontFamily: fontFamilyMontserrat,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right side - Attachment icon
                  if (attachmentId != null && attachmentId > 0) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _downloadAndOpenAttachment(
                        context,
                        attachmentId,
                        attachmentName,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.attach_file,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

