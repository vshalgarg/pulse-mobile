import 'package:app/app_config.dart';
import 'package:app/commonWidgets/pmis_card.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/pmis_project_model.dart';
import 'package:app/models/pmis_project_state_model.dart';
import 'package:app/services/api_service.dart';
import 'package:flutter/material.dart';

class PmisStateScreen extends StatefulWidget {
  final PmisProject project;
  final int projectId;

  const PmisStateScreen({
    super.key,
    required this.project,
    required this.projectId,
  });

  @override
  State<PmisStateScreen> createState() => _PmisStateScreenState();
}

class _PmisStateScreenState extends State<PmisStateScreen> {
  late Future<ResponseResult<List<PmisProjectState>>> _future;

  Future<ResponseResult<List<PmisProjectState>>> _loadStates() async {
    try {
      final config = AppConfig.of(context);
      return await config.pmisStateRepository.getProjectStateList(
        projectId: widget.projectId,
      );
    } catch (e) {
      return ResponseResult.error(
        errorMessage: e.toString(),
      );
    }
  }

  PmisProject _mapStateToCardModel(PmisProjectState state) {
    return PmisProject(
      pmId: state.stateId,
      projectName: state.state,
      totalActivities: 0,
      completedActivities: 0,
      completionPercentage: state.completionPct,
      status: state.scheduleStatus,
      growth: state.progressDeltaValue,
      growthColor: state.progressDeltaColor,
    );
  }

  @override
  void initState() {
    super.initState();
    _future = _loadStates();
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
                    widget.project.projectName,
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
              children: [
                _buildProjectStateHeader(),
                Expanded(
                  child: FutureBuilder<ResponseResult<List<PmisProjectState>>>(
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
                            result?.errorMessage ?? 'Failed to load states',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      final states = result.data!;
                      if (states.isEmpty) {
                        return const Center(
                          child: Text(
                            'No states found',
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
                        itemCount: states.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final state = states[index];
                          final stateCardModel = _mapStateToCardModel(state);
                          return PmisCard(project: stateCardModel);
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

  Widget _buildProjectStateHeader() {
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
            
            child: const Text(
              'Project > State',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontFamily: poppins,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            color:  AppColors.black25,
            child: Text(
              'Project : ${widget.project.projectName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontFamily: poppins,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
