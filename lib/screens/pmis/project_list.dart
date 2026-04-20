import 'package:app/bloc/pmis_project_cubit.dart';
import 'package:app/bloc/pmis_project_state.dart';
import 'package:app/commonWidgets/pmis_card.dart';
import 'package:app/commonWidgets/pmis_header.dart';
import 'package:app/screens/pmis/activities.dart';
import 'package:app/screens/pmis/pmis_state.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProjectListScreen extends StatefulWidget {
  final String title;

  /// From [PulseDashboard] `taskName` (e.g. `Project`, `Activity`): query
  /// `project-list` and decides card navigation (`PmisStateScreen` vs
  /// [ProjectActivitiesScreen]).
  final String activityType;

  const ProjectListScreen({
    super.key,
    required this.activityType,
    this.title = 'Projects',
  });

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  bool get _dashboardIsActivity =>
      widget.activityType.trim().toUpperCase() == 'ACTIVITY';

  void _reloadProjects() {
    context.read<PmisProjectCubit>().loadProjects(
          activityType: widget.activityType,
        );
  }

  @override
  void initState() {
    super.initState();
    _reloadProjects();
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
                    'Projects',
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
            child: BlocBuilder<PmisProjectCubit, PmisProjectState>(
              builder: (context, state) {
                if (state is PmisProjectLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  );
                }
                if (state is PmisProjectFailure) {
                  return Center(
                    child: Text(
                      state.errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                if (state is PmisProjectSuccess) {
                  if (state.projects.isEmpty) {
                    return const Center(
                      child: Text(
                        'No projects found',
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
                    itemCount: state.projects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final project = state.projects[index];
                      return PmisCard(
                        project: project,
                        onTap: () async {
                          if (_dashboardIsActivity) {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) =>
                                    ProjectActivitiesScreen(
                                  projectId: project.pmId,
                                  activityType: 'activity',
                                  appBarTitle: project.projectName,
                                  breadcrumbText: 'Project > Activities',
                                  headerDetailLines: [
                                    PmisHeaderDetailLine(
                                      label: 'Project',
                                      value: project.projectName,
                                    ),
                                  ],
                                  enableDashboardActivitySearch: true,
                                ),
                              ),
                            );
                          } else {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => PmisStateScreen(
                                  project: project,
                                  projectId: project.pmId,
                                ),
                              ),
                            );
                          }
                          if (!mounted) return;
                          _reloadProjects();
                        },
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}
