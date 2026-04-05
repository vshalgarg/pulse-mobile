import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/pmis_project_site_model.dart';
import 'package:flutter/material.dart';

class PmisSiteCard extends StatelessWidget {
  final PmisProjectSite site;
  final VoidCallback? onTap;
  /// Same contract as [TicketCard.onDirectionTap] (maps / directions).
  final VoidCallback? onDirectionTap;

  const PmisSiteCard({
    super.key,
    required this.site,
    this.onTap,
    this.onDirectionTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = site.completionPct.clamp(0, 100);
    final filledColor = pct >= 100
        ? AppColors.pmisProgressComplete
        : AppColors.pmisProgressIncomplete;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        shadowColor: Colors.black26,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Site ID : ${site.siteCode}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w400,
                        fontFamily: fontFamilyMontserrat,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.directions,
                      color: Colors.amber,
                      size: 24,
                    ),
                    onPressed: onDirectionTap,
                  ),
                ],
              ),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      site.siteName,
                      style: const TextStyle(
                        fontFamily: poppins,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.locationColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.36,
                    ),
                    child: Text(
                      site.distanceKm,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: poppins,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        color: AppColors.color555555,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Completion : $pct%',
                style: TextStyle(
                  fontFamily: poppins,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 8,
                  backgroundColor:
                      AppColors.pmisProgressTrack.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(filledColor),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                site.scheduleStatus,
                style: TextStyle(
                  fontFamily: poppins,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.color555555,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
