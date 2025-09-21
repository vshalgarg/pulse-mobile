import 'package:app/enum/activity_type_enum.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/connectivity_helper.dart';
import 'package:app/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../../constants/app_images.dart';
import '../../constants/constants_strings.dart';
import '../../constants/constants_methods.dart';
import '../../constants/pm_constants.dart';
import 'pm_page_widget.dart';
import 'pm_page_header_solar.dart';
import 'pm_page_header_telecom.dart';
import '../../commonWidgets/custom_form_appbar.dart';
import '../../commonWidgets/custom_dialogs/unsaved_changes_dialog.dart';
import '../../utils/pm_navigation_helper.dart';
import '../../utils/asset_audit_navigation_helper.dart';

class PMPageRender extends StatefulWidget {
  final Map<String, dynamic> pmData;
  final Function(Map<String, dynamic>)? onDataChanged;
  final bool isLoading;
  final String? errorMessage;

  const PMPageRender({
    super.key,
    required this.pmData,
    this.onDataChanged,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<PMPageRender> createState() => _PMPageRenderState();
}

class _PMPageRenderState extends State<PMPageRender> {
  int _currentPageIndex = 0;
  late List<String> _availablePages;
  late Map<String, dynamic> _pmData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pmData = Map<String, dynamic>.from(widget.pmData);
    _initializeAvailablePages();
  }


  void _initializeAvailablePages() {
    // Use navigation helper to get available screens
    _availablePages = PMNavigationHelper.getAvailableScreens(_pmData);

  }

  String get _currentPageName => _availablePages[_currentPageIndex];
  String get _currentDataKey => _currentPageName == 'Site Info' ? 'Header' : PMConstants.getDataKeyForPage(_currentPageName);
  
  /// Determine if this is a solar PM based on data structure
  bool get _isSolarPM {
    final responseData = _pmData['responseData'] as Map<String, dynamic>? ?? {};
    
    // Check for solar-specific page keys
    final solarKeys = ['SPV', 'Cables', 'Inverters', 'Transformer', 'BOS', 'Civil & Structures', 'Safety Systems', 'Performance', 'Earthing', 'Hygiene'];
    final hasSolarKeys = solarKeys.any((key) => responseData.containsKey(key));
    
    // Check for telecom-specific page keys
    final telecomKeys = ['Tower', 'Battery', 'CCU', 'Solar', 'Electrical', 'SEB', 'DG', 'Fire Extinguisher', 'CT'];
    final hasTelecomKeys = telecomKeys.any((key) => responseData.containsKey(key));
    
    // If we have solar keys but no telecom keys, it's solar
    if (hasSolarKeys && !hasTelecomKeys) return true;
    
    // If we have telecom keys but no solar keys, it's telecom
    if (hasTelecomKeys && !hasSolarKeys) return false;
    
    // If we have both or neither, check the site type from pageHeader
    final pageHeader = _pmData['pageHeader'] as List?;
    if (pageHeader != null && pageHeader.isNotEmpty) {
      final firstHeader = pageHeader.first as Map<String, dynamic>?;
      final siteTypeName = firstHeader?['site_type_name']?.toString().toLowerCase();
      
      if (siteTypeName != null) {
        if (siteTypeName.contains('solar') || siteTypeName.contains('spv') || siteTypeName.contains('pv')) {
          return true;
        }
      }
    }
    
    // Default to telecom for backward compatibility
    return false;
  }
  
  /// Build the appropriate site info page based on PM type
  Widget _buildSiteInfoPage() {
    print('Building Site Info Page - Is Solar PM: $_isSolarPM');
    
    if (_isSolarPM) {
      return PMPageHeaderSolar(
        pageHeader: _pageHeader,
        pmData: _pmData,
        onNext: _onNextPage,
        onClose: () => Navigator.pop(context),
        isLoading: _isLoading,
        errorMessage: widget.errorMessage,
      );
    } else {
      return PMPageHeaderTelecom(
        pageHeader: _pageHeader,
        pmData: _pmData,
        onNext: _onNextPage,
        onClose: () => Navigator.pop(context),
        isLoading: _isLoading,
        errorMessage: widget.errorMessage,
      );
    }
  }
  List<Map<String, dynamic>> get _currentPageData {
    if (_currentPageName == 'Site Info') {
      return []; // Site Info page doesn't have PM items
    }
    final responseData = _pmData['responseData'] as Map<String, dynamic>? ?? {};
    final data = responseData[_currentDataKey] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }
  
  Map<String, dynamic>? get _pageHeader {
    final pageHeader = _pmData['pageHeader'] as List?;
    if (pageHeader?.isNotEmpty == true) {
      return pageHeader!.first as Map<String, dynamic>;
    }
    return null;
  }

  bool get _isFirstPage => _currentPageIndex == 0;
  bool get _isLastPage => _currentPageIndex == _availablePages.length - 1;

  void _onPageDataChanged(List<Map<String, dynamic>> updatedData) {
    setState(() {
      _pmData['responseData'][_currentDataKey] = updatedData;
    });
    // Call the optional callback if provided
    widget.onDataChanged?.call(_pmData);
  }

  void _onPreviousPage() {
    if (!_isFirstPage) {
      setState(() {
        _currentPageIndex--;
      });
      // Clear any cached widget state
      _clearWidgetState();
    }
  }

  Future<void> _onNextPage() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Update data in SQLite before navigating to next page (except for Site Info page)
      if (!_isFirstPage) {
        await _updateDataInSqliteAndCallApi();
      }
      
      // Navigate to next page if not on last page
      if (!_isLastPage) {
        setState(() {
          _currentPageIndex++;
          Logger.debugLog('Page index updated to: $_currentPageIndex');
        });
        _clearWidgetState();
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateDataInSqliteAndCallApi() async {
    try {

      // Get siteAuditSchId from PM data
      final siteAuditSchId = _pmData['pageHeader']?[0]?['site_audit_sch_id']?.toString();
      
      if (siteAuditSchId != null) {
        print('🔄 Updating PM data in SQLite for site: $siteAuditSchId');
        final dataToPost = _pmData['responseData'][_currentPageName];
        // Update data in SQLite
        final success = await ServiceLocator().centralAssetAuditService.updateDataInSqlite(
          siteAuditSchId: siteAuditSchId,
          updatedData: _pmData,
        );
        
        if (success) {
          await _postPmDataToApi(dataToPost);
        } else {
          print('❌ Failed to update PM data in SQLite');
        }
      } else {
        print('❌ siteAuditSchId not found in PM data');
      }
    } catch (e) {
      print('❌ Error updating PM data in SQLite: $e');
    }
  }

  Future<void> _postPmDataToApi(final dataToPost) async {
    try {
      if(await ConnectivityHelper.isConnected()) {
        // Post data with photo ID replacement
        await ServiceLocator().assetAuditPostService
            .postAssetAuditDataWithPhotoReplacement(
            requests: dataToPost,
            activityType: ActivityTypeEnum.preventiveMaintenance,
            isLastPage: _isLastPage
        );
        Logger.infoLog('PM data posted successfully to API');
      }
    } catch (e) {
      Logger.errorLog('Error posting PM data to API: $e');
    }
  }

  void _clearWidgetState() {
    // Force widget recreation by updating a state variable
    // This ensures all form fields and widgets are cleared
    print('🧹 Clearing widget state for page: $_currentPageName');
  }

  // Helper methods for getting page names
  String _getNextPageName() {
    return PMNavigationHelper.getNextScreenName(_pmData, _currentPageName);
  }

  String _getPreviousPageName() {
    return PMNavigationHelper.getPreviousScreenName(_pmData, _currentPageName);
  }

  void _onSave() {
    // Handle save action internally
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PM Data Saved'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _onSubmit() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Update data in SQLite and post to API
      await _updateDataInSqliteAndCallApi();
      
      // Show success message and navigate to home screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PM Data Submitted'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to home screen
        AssetAuditNavigationHelper.navigateToHomeScreen(context);
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UnsavedChangesDialog(
        message: 'You have unsaved changes. Do you want to save before leaving?',
        onSaveAndExit: () async {
          // Save data and then navigate back
          widget.onDataChanged?.call(_pmData);
          Navigator.pop(context);
        },
        onDiscard: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        siteAuditSchId: null, // You can pass siteAuditSchId if available
        section: 'Preventive Maintenance',
        parentContext: context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_availablePages.isEmpty) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
        appBar: CustomFormAppbar(
          title: 'Preventive Maintenance',
          onClose: () => _showUnsavedChangesDialog(),
        ),
        body: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: SvgPicture.asset(
                AppImages.home,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.white,
                    ),
                    getHeight(16),
                    const Text(
                      'No PM Data Available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                    getHeight(8),
                    const Text(
                      'There are no PM items to display',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: fontFamilyMontserrat,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show site info page if current page is Site Info
    if (_currentPageName == 'Site Info') {
      return Container(
        key: ValueKey('pm_header_${_currentPageName}_$_currentPageIndex'),
        child: _buildSiteInfoPage(),
      );
    }

    // Show PM section page
    return Container(
      key: ValueKey('pm_page_${_currentPageName}_$_currentPageIndex'),
      child: PMPageWidget.forSection(
        pmItems: _currentPageData,
        sectionName: _currentPageName,
        pageTitle: 'Preventive Maintenance',
        leftButtonText: _isFirstPage ? 'Save' : _getPreviousPageName(),
        rightButtonText: _isLastPage ? 'Submit' : _getNextPageName(),
        onLeftButtonPressed: _isFirstPage ? _onSave : _onPreviousPage,
        onRightButtonPressed: _isLastPage ? _onSubmit : _onNextPage,
        onDataChanged: _onPageDataChanged,
        isLoading: _isLoading,
        errorMessage: widget.errorMessage,
      ),
    );
  }
}

/// Helper class for PM data structure
class PMDataHelper {
  static Map<String, dynamic> createEmptyPMData() {
    return {
      'pageHeader': [],
      'responseData': {},
    };
  }

  static Map<String, dynamic>? getPageHeader(Map<String, dynamic> pmData) {
    final pageHeader = pmData['pageHeader'] as List?;
    if (pageHeader?.isNotEmpty == true) {
      return pageHeader!.first as Map<String, dynamic>;
    }
    return null;
  }

  static Map<String, dynamic> getResponseData(Map<String, dynamic> pmData) {
    return pmData['responseData'] as Map<String, dynamic>? ?? {};
  }

  static List<String> getAvailablePages(Map<String, dynamic> pmData) {
    final responseData = getResponseData(pmData);
    final pageOrder = PMConstants.getPageOrder();
    
    return pageOrder.where((page) {
      final dataKey = PMConstants.getDataKeyForPage(page);
      return responseData.containsKey(dataKey) && 
             responseData[dataKey] is List && 
             (responseData[dataKey] as List).isNotEmpty;
    }).toList();
  }

  static List<Map<String, dynamic>> getPageData(
    Map<String, dynamic> pmData, 
    String pageName
  ) {
    final responseData = getResponseData(pmData);
    final dataKey = PMConstants.getDataKeyForPage(pageName);
    final data = responseData[dataKey] as List? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  static Map<String, dynamic> updatePageData(
    Map<String, dynamic> pmData,
    String pageName,
    List<Map<String, dynamic>> updatedData,
  ) {
    final updatedPMData = Map<String, dynamic>.from(pmData);
    final dataKey = PMConstants.getDataKeyForPage(pageName);
    updatedPMData['responseData'][dataKey] = updatedData;
    return updatedPMData;
  }
}
