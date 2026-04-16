import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/pmis_project_activity_model.dart';
import 'package:flutter/material.dart';

class ActivityCard extends StatelessWidget {
  final PmisProjectActivity activity;
  final VoidCallback? onDirectionTap;
  final VoidCallback? onTap;
  final VoidCallback? onDownloadTap;

  /// Green check when ticket is in `raw_api_data` like SV download (see TicketCard).
  final bool isOfflineDownloaded;
  final bool showProjectHierarchy;

  const ActivityCard({
    super.key,
    required this.activity,
    this.onDirectionTap,
    this.onTap,
    this.onDownloadTap,
    this.isOfflineDownloaded = false,
    this.showProjectHierarchy = false,
  });

  @override
  Widget build(BuildContext context) {
    final approvalChipText = activity.approvalStatus?.trim() ?? '';
    final activityChipText = activity.activityStatus?.trim() ?? '';
    final showApprovalChip = approvalChipText.isNotEmpty;
    final showActivityChip = activityChipText.isNotEmpty;
    final showStatusSection = showApprovalChip || showActivityChip;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showStatusSection) ...[
                  Row(
                    children: [
                      if (showApprovalChip)
                        Expanded(
                          child: _statusChip(
                            text: approvalChipText,
                            backgroundColor: const Color(0xFFD7E6FF),
                            textColor: const Color(0xFF2F6BFF),
                          ),
                        ),
                      if (showApprovalChip && showActivityChip)
                        const SizedBox(width: 12),
                      if (showActivityChip)
                        Expanded(
                          child: _statusChip(
                            text: activityChipText,
                            backgroundColor: const Color(0xFFFF9F43),
                            textColor: AppColors.white,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                Text(
                  activity.activityName,
                  style: const TextStyle(
                    fontFamily: fontFamilyMontserrat,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.locationColor,
                  ),
                ),

                const SizedBox(height: 14),


                _infoRow(
                  label: 'State :',
                  value: activity.state,
                ),
                _infoRow(
                  label: 'Site :',
                  value: activity.siteName,
                  trailing: _uploadIcon(),
                ),
                _infoRow(
                  label: 'Modules :',
                  value: activity.moduleName,
                ),
                _infoRow(
                  label: 'Sub Modules :',
                  value: activity.subModuleName,
                  trailing: _downloadIcon(),
                ),

                const SizedBox(height: 10),
                Divider(
                  color: Colors.black.withOpacity(0.15),
                  thickness: 1,
                  height: 1,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Plan Start : ${_displayValue(activity.plannedStartDt)}',
                        style: const TextStyle(
                          fontFamily: poppins,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.color555555,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Plan End : ${_displayValue(activity.plannedEndDt)}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontFamily: poppins,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.color555555,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Actual  Start : ${_displayValue(activity.actualStartDt)}',
                        style: const TextStyle(
                          fontFamily: poppins,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.color555555,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Actual End : ${_displayValue(activity.actualEndDt)}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontFamily: poppins,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.color555555,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayValue(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    final trimmed = value.trim();
    final match =
        RegExp(r'^(\d{2})/([A-Za-z]{3})/(\d{4})$').firstMatch(trimmed);
    if (match == null) return trimmed;

    final day = match.group(1)!;
    final rawMonth = match.group(2)!;
    final year = match.group(3)!;
    final month =
        '${rawMonth[0].toUpperCase()}${rawMonth.substring(1).toLowerCase()}';
    return '$day-$month-$year';
  }

  Widget _infoRow({
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: fontFamilyMontserrat,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.color555555,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: poppins,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.color555555,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _statusChip({
    required String text,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: poppins,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _uploadIcon() {
    // Same style reference as TicketCard direction icon.
    return IconButton(
      icon: const Icon(
        Icons.directions,
        color: Colors.amber,
        size: 24,
      ),
      onPressed: onDirectionTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      alignment: Alignment.center,
    );
  }

  Widget _downloadIcon() {
    if (isOfflineDownloaded) {
      return IconButton(
        icon: const Icon(
          Icons.check_circle,
          color: AppColors.primaryGreen,
          size: 24,
        ),
        onPressed: null,
        tooltip: 'Saved for offline',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        alignment: Alignment.center,
      );
    }
    return IconButton(
      icon: const Icon(
        Icons.file_download_outlined,
        color: AppColors.downloadIconColor,
      ),
      onPressed: onDownloadTap,
      tooltip: 'Download for offline',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      alignment: Alignment.center,
    );
  }
}

