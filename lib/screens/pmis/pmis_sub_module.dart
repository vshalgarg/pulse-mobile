import 'package:app/app_config.dart';
import 'package:app/commonWidgets/pmis_card.dart';
import 'package:app/commonWidgets/pmis_header.dart';
import 'package:app/commonWidgets/safe_svg_picture.dart';
import 'package:app/constants/app_colors.dart';
import 'package:app/constants/app_images.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/models/pmis_project_model.dart';
import 'package:app/models/pmis_project_module_model.dart';
import 'package:app/models/pmis_project_site_model.dart';
import 'package:app/models/pmis_project_submodule_model.dart';
import 'package:app/screens/pmis/activities.dart';
import 'package:flutter/material.dart';

class PmisSubModuleScreen extends StatefulWidget {
  final PmisProject project;
  final int projectId;
  final String stateName;
  final PmisProjectSite site;
  final PmisProjectModule module;

  const PmisSubModuleScreen({
    super.key,
    required this.project,
    required this.projectId,
    required this.stateName,
    required this.site,
    required this.module,
  });

  @override
  State<PmisSubModuleScreen> createState() => _PmisSubModuleScreenState();
}

class _PmisSubModuleScreenState extends State<PmisSubModuleScreen> {
  bool _loading = true;
  String? _errorMessage;
  List<PmisProjectSubModule> _subModules = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubModules());
  }

  Future<void> _loadSubModules() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final config = AppConfig.of(context);
      final result =
          await config.pmisSubModuleRepository.getProjectSubModuleList(
        projectId: widget.projectId,
        siteId: widget.site.siteId,
        moduleId: widget.module.ppmId,
      );

      if (!mounted) return;

      if (result.isSuccess && result.data != null) {
        setState(() {
          _loading = false;
          _subModules = result.data!;
        });
      } else {
        setState(() {
          _loading = false;
          _errorMessage = result.errorMessage ?? 'Failed to load sub-modules';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Same mapping pattern as [PmisModuleScreen] / project list → [PmisCard].
  PmisProject _mapSubModuleToCardModel(PmisProjectSubModule item) {
    return PmisProject(
      pmId: item.ppsmId,
      projectName: item.subModuleName,
      totalActivities: 0,
      completedActivities: 0,
      completionPercentage: item.completionPct,
      status: item.scheduleStatus,
      growth: item.progressDeltaValue,
      growthColor: item.progressDeltaColor,
    );
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
                    widget.module.moduleName,
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
                PmisHeader(
                  breadcrumbText:
                      'Project > State > Site > Module > Sub module',
                  detailLines: [
                    PmisHeaderDetailLine(
                      label: 'Project Name',
                      value: widget.project.projectName,
                    ),
                    PmisHeaderDetailLine(
                      label: 'State',
                      value: widget.stateName,
                    ),
                    PmisHeaderDetailLine(
                      label: 'Site',
                      value: widget.site.siteName,
                    ),
                    PmisHeaderDetailLine(
                      label: 'Module',
                      value: widget.module.moduleName,
                    ),
                   
                  ],
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadSubModules,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: AppColors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_subModules.isEmpty) {
      return const Center(
        child: Text(
          'No sub-modules found',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Same list + card pattern as [ProjectListScreen].
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _subModules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _subModules[index];
        return PmisCard(
          project: _mapSubModuleToCardModel(item),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => ProjectActivitiesScreen(
                  projectId: widget.projectId,
                  appBarTitle: item.subModuleName,
                  breadcrumbText:
                      'Project > State > Site > Module > Sub module > Activity',
                  headerDetailLines: [
                    PmisHeaderDetailLine(
                      label: 'Project Name',
                      value: widget.project.projectName,
                    ),
                    PmisHeaderDetailLine(
                      label: 'State',
                      value: widget.stateName,
                    ),
                    PmisHeaderDetailLine(
                      label: 'Site',
                      value: widget.site.siteName,
                    ),
                    PmisHeaderDetailLine(
                      label: 'Module',
                      value: widget.module.moduleName,
                    ),
                    PmisHeaderDetailLine(
                      label: 'Sub module',
                      value: item.subModuleName,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
