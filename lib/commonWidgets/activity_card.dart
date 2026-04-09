import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/pmis_project_activity_model.dart';
import 'package:flutter/material.dart';

class ActivityCard extends StatelessWidget {
  final PmisProjectActivity activity;
  final VoidCallback? onDirectionTap;
  final VoidCallback? onTap;

  const ActivityCard({
    super.key,
    required this.activity,
    this.onDirectionTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = activity.currentStatus.trim().toLowerCase() == 'completed';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7E6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Approvals Pending',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: poppins,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2F6BFF),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F43),
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Text(
                          isCompleted ? 'Approved' : 'Partially Approved',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: poppins,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

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
    // Same style reference as TicketCard download icon.
    return IconButton(
      icon: const Icon(
        Icons.file_download_outlined,
        color: AppColors.downloadIconColor,
      ),
      onPressed: () {},
    );
  }
}

