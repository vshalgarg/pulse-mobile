import 'package:app/constants/app_colors.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';

/// One row in the PMIS header tile (e.g. `Project : Acme`, `State : UP`).
class PmisHeaderDetailLine {
  final String label;
  final String value;

  const PmisHeaderDetailLine({
    required this.label,
    required this.value,
  });
}

/// Shared PMIS breadcrumb + context strip used under the app bar on state / site / module flows.
class PmisHeader extends StatelessWidget {
  /// e.g. `Project > State`, `Project > State > Site`, `Project > State > Site > Module`
  final String breadcrumbText;

  /// Shown in the dark band; order is preserved. Use labels like `Project`, `State`, `Site`, `Module`.
  final List<PmisHeaderDetailLine> detailLines;

  const PmisHeader({
    super.key,
    required this.breadcrumbText,
    required this.detailLines,
  });

  static const TextStyle _breadcrumbStyle = TextStyle(
    color: AppColors.white,
    fontSize: 14,
    fontFamily: poppins,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle _detailStyle = TextStyle(
    color: AppColors.white,
    fontSize: 14,
    fontFamily: poppins,
    fontWeight: FontWeight.w400,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
            child: Text(
              breadcrumbText,
              style: _breadcrumbStyle,
            ),
          ),
        ),
        ColoredBox(
          color: AppColors.black25,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < detailLines.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Text(
                      '${detailLines[i].label} : ${detailLines[i].value}',
                      maxLines: i == 0 ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: _detailStyle,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
