import 'package:app/app_config.dart';
import 'package:app/commonWidgets/activity_card.dart';
import 'package:app/commonWidgets/pmis_header.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/pmis_project_activity_model.dart';
import 'package:app/services/api_service.dart';
import 'package:app/services/location_service.dart';
import 'package:flutter/material.dart';

class ProjectActivitiesScreen extends StatefulWidget {
  /// Passed to PMIS `project-activity-list` as `projectId`.
  final int projectId;

  final String appBarTitle;

  /// Breadcrumb line under the app bar (e.g. `Project > … > Activities`).
  final String breadcrumbText;

  /// Context rows in the dark band; if null, shows `Project ID : [projectId]`.
  final List<PmisHeaderDetailLine>? headerDetailLines;

  const ProjectActivitiesScreen({
    super.key,
    required this.projectId,
    this.appBarTitle = 'Project Activities',
    this.breadcrumbText = 'Project > Activities',
    this.headerDetailLines,
  });

  @override
  State<ProjectActivitiesScreen> createState() =>
      _ProjectActivitiesScreenState();
}

class _ProjectActivitiesScreenState extends State<ProjectActivitiesScreen> {
  late Future<ResponseResult<List<PmisProjectActivity>>> _future;

  Future<ResponseResult<List<PmisProjectActivity>>> _loadActivities() async {
    try {
      final config = AppConfig.of(context);
      final location = await LocationService.getCurrentLocation();

      return await config.pmisActivitiesRepository.getProjectActivityList(
        id: widget.projectId,
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } catch (e) {
      return ResponseResult.error(
        errorMessage: e.toString(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _loadActivities();
  }

  List<PmisHeaderDetailLine> get _headerDetailLines {
    return widget.headerDetailLines ??
        [
          PmisHeaderDetailLine(
            label: 'Project ID',
            value: widget.projectId.toString(),
          ),
        ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 10, top: 12, right: 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_sharp,
                    color: AppColors.backgroundColorapp,
                    size: 25,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  alignment: Alignment.centerLeft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.appBarTitle,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      fontFamily: poppins,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeSvgPicture.asset(AppImages.home, fit: BoxFit.cover),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PmisHeader(
                  breadcrumbText: widget.breadcrumbText,
                  detailLines: _headerDetailLines,
                ),
                Expanded(
                  child: FutureBuilder<
                      ResponseResult<List<PmisProjectActivity>>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      final result = snapshot.data;
                      if (result == null ||
                          !result.isSuccess ||
                          result.data == null) {
                        return Center(
                          child: Text(
                            result?.errorMessage ?? 'Failed to load activities',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      final activities = result.data!;
                      if (activities.isEmpty) {
                        return const Center(
                          child: Text(
                            'No activities found',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: activities.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return ActivityCard(activity: activities[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
