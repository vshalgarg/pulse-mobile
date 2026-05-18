import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/raise_it_ticket_request_model.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/logger.dart';
import 'package:app/utils/toastbar.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

class RaiseItTicketCommentsWidget extends StatelessWidget {
  final List<RaiseItTicketCommentRequest> comments;

  const RaiseItTicketCommentsWidget({
    super.key,
    required this.comments,
  });

  static List<RaiseItTicketCommentRequest> visibleComments(
    List<RaiseItTicketCommentRequest> source,
  ) {
    return source.where((c) {
      if (c.isActive == false) return false;
      final hasText = c.comments != null && c.comments!.trim().isNotEmpty;
      final hasAttachment =
          c.itAssetAttachmentId != null && c.itAssetAttachmentId! > 0;
      return hasText || hasAttachment;
    }).toList();
  }

  String _formatCommentDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final trimmed = raw.trim();
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return DateFormat('dd-MMM-yyyy').format(parsed);
      }
      final epoch = int.tryParse(trimmed);
      if (epoch != null) {
        final ms = epoch > 9999999999 ? epoch : epoch * 1000;
        return DateFormat('dd-MMM-yyyy')
            .format(DateTime.fromMillisecondsSinceEpoch(ms));
      }
    } catch (e) {
      Logger.errorLog('[RaiseItTicketComments] Date format error: $e');
    }
    return '';
  }

  Future<void> _openAttachment(
    BuildContext context,
    int attachmentId,
    String attachmentName,
  ) async {
    try {
      LoaderWidget.showLoader(context);
      final fileName = attachmentName.trim().isNotEmpty
          ? attachmentName.trim()
          : 'attachment_$attachmentId';
      final filePath = await ServiceLocator().cmRepository.downloadDocument(
        attachmentId,
        fileName,
      );
      final openResult = await OpenFile.open(filePath);
      if (openResult.type != ResultType.done && context.mounted) {
        Toastbar.showErrorToastbar(
          openResult.message.isNotEmpty
              ? openResult.message
              : 'Unable to open attachment',
          context,
        );
      }
    } catch (e) {
      Logger.errorLog('[RaiseItTicketComments] Open attachment failed: $e');
      if (context.mounted) {
        Toastbar.showErrorToastbar('Unable to open attachment: $e', context);
      }
    } finally {
      if (LoaderWidget.isShowing) {
        LoaderWidget.hideLoader();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleComments(comments);
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: visible.map((comment) {
        final name = comment.commentedByName?.trim().isNotEmpty == true
            ? comment.commentedByName!.trim()
            : 'Unknown';
        final text = comment.comments?.trim() ?? '';
        final attachmentId = comment.itAssetAttachmentId;
        final attachmentName = comment.attachmentName?.trim().isNotEmpty == true
            ? comment.attachmentName!.trim()
            : 'attachment';
        final formattedDate = _formatCommentDate(comment.commentedDt);

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
              if (formattedDate.isNotEmpty) ...[
                Center(
                  child: Column(
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
                        dashLength: 4,
                        dashGapLength: 3,
                        lineThickness: 2,
                        dashColor: AppColors.whiteColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '[$name]',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: fontFamilyMontserrat,
                            ),
                          ),
                          if (text.isNotEmpty)
                            TextSpan(
                              text: ' : $text',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontFamily: fontFamilyMontserrat,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (attachmentId != null && attachmentId > 0) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _openAttachment(
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
