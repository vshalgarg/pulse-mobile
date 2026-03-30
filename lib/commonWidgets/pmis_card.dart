import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/pmis_project_model.dart';
import 'package:flutter/material.dart';

class PmisCard extends StatelessWidget {
  final PmisProject project;
  final VoidCallback? onTap;

  const PmisCard({
    super.key,
    required this.project,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = project.completionPercentage.clamp(0, 100);
    final filledColor =
        pct >= 100 ? AppColors.pmisProgressComplete : AppColors.pmisProgressIncomplete;
    final growthStyle = _growthStyle(project.growthColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      project.projectName,
                      style: const TextStyle(
                        fontFamily: poppins,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.locationColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: growthStyle.background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          growthStyle.icon,
                          size: 16,
                          color: growthStyle.foreground,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          project.growth,
                          style: TextStyle(
                            fontFamily: poppins,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: growthStyle.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                  backgroundColor: AppColors.pmisProgressTrack.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(filledColor),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                project.status,
                style: const TextStyle(
                  fontFamily: poppins,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.pmisStatusColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _GrowthStyle _growthStyle(String key) {
    final isGreen = key.toLowerCase().trim() == 'green';
    // User provided hex format is `RRGGBBAA` (alpha = last 2 chars),
    // but Flutter Color expects `AARRGGBB`.
    return _GrowthStyle(
      background: isGreen ? const Color(0x33D93025) : const Color(0x331B8A5A),
      foreground: isGreen ? const Color(0xFFD93025) : const Color(0xFF1B8A5A),
      icon: isGreen ? Icons.arrow_downward : Icons.arrow_upward,
    );
  }
}

class _GrowthStyle {
  final Color background;
  final Color foreground;
  final IconData icon;

  _GrowthStyle({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}
