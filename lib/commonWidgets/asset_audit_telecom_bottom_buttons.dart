import 'package:app/commonWidgets/custom_buttons/arrow_botton.dart';
import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/utils/asset_audit_navigation_helper.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../constants/app_colors.dart';
import '../../bloc/global_loading_cubit.dart';

class AssetAuditTelecomBottomButtons extends StatelessWidget {
  final Future<void> Function() onNextButtonClick;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? assetAuditData;
  final String screenName;
  final String siteAuditSchId;
  final String siteType;
  final String auditSchId;
  final BuildContext parentContext;

  const AssetAuditTelecomBottomButtons({
    super.key,
    required this.onNextButtonClick,
    this.isLoading = false,
    this.errorMessage,
    required this.assetAuditData,
    required this.screenName,
    required this.siteAuditSchId,
    required this.siteType,
    required this.auditSchId,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show buttons if loading or has error
    if (isLoading || errorMessage != null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        children: [
          Expanded(
            child: ArrowButton(
              text: AssetAuditNavigationHelper.getTelecomPreviousScreenName(
                assetAuditData,
                screenName,
              ),
              isLeftArrow: true,
              backgroundColor: AppColors.buttonColorBackBg,
              textColor: AppColors.buttonColorTextBg,
              onPressed: () {
                AssetAuditNavigationHelper.navigateToPreviousTelecomScreen(
                  context,
                  assetAuditData,
                  screenName,
                  siteAuditSchId,
                  siteType,
                  auditSchId,
                  parentContext,
                );
              },
            ),
          ),
          getWidth(14),
          Expanded(
            child: ArrowButton(
              text: AssetAuditNavigationHelper.getTelecomNextScreenName(
                assetAuditData,
                screenName,
              ),
              isLeftArrow: false,
              backgroundColor: AppColors.buttonColorBg,
              textColor: AppColors.buttonColorSite,

              onPressed: () async {
                LoaderWidget.showLoader(context);
                try {
                  await onNextButtonClick();

                  // Only navigate if no error occurred
                  AssetAuditNavigationHelper.navigateToNextTelecomScreen(
                    context,
                    assetAuditData,
                    screenName,
                    siteAuditSchId,
                    siteType,
                    auditSchId,
                    parentContext,
                  );
                } catch (e) {
                  // Error already handled in postCurrentScreenData, don't navigate
                  // Loader will be hidden in finally block
                } finally {
                  LoaderWidget.hideLoader();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
