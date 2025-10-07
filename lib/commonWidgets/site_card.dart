import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/cm_site_model.dart';
import 'package:app/utils.dart';
import 'package:flutter/material.dart';

class SiteCard extends StatelessWidget {
  final CMSite site;
  final String? distance;
  final VoidCallback? onDirectionTap;
  final VoidCallback? onTap;
  final VoidCallback? onDownloadTap;
  final bool isDownloaded;

  const SiteCard({
    super.key,
    required this.site,
    this.distance,
    this.onDirectionTap,
    this.onTap,
    this.onDownloadTap,
    this.isDownloaded = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Telecom label
              Text(
                "Telecom",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                  fontFamily: fontFamilyMontserrat,
                ),
              ),
              const SizedBox(height: 4),
              
              // Site ID and Site Code
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                     "${site.siteCode} (Site ID : ${site.siteId})",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
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
              const SizedBox(height: 4),
              
              // Site Name (main title) with distance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      site.clusterDistrictName,
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: fontFamilyMontserrat,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  if (distance != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      distance!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),

              // Client/Company row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      site.clientName ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 14, 
                        color: AppColors.black,
                        fontWeight: FontWeight.w500,
                        fontFamily: fontFamilyMontserrat,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Download icon - shows different states
                  isDownloaded
                      ? IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                          onPressed: null,
                          tooltip: 'Site Downloaded',
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.file_download_outlined,
                            color: Colors.blue,
                            size: 24,
                          ),
                          onPressed: onDownloadTap,
                          tooltip: 'Download Site Info',
                        ),
                ],
              ),

              const SizedBox(height: 4),
              const Divider(height: 0.5, color: AppColors.color555555),
              const SizedBox(height: 4),

              // Footer with dates (using site creation info or current dates)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      "Raised On : ${Utils.formatDataForTicketCard(DateTime.now().toString())}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: fontFamilyMontserrat,
                        color: AppColors.color555555,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Text(
                      "Due : ${Utils.formatDataForTicketCard(DateTime.now().add(const Duration(days: 2)).toString())}",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: fontFamilyMontserrat,
                        color: AppColors.color555555,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
