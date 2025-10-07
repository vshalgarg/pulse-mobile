import 'package:app/commonWidgets/loader_widget.dart';
import 'package:app/constants/constants_methods.dart';
import 'package:app/constants/constants_strings.dart';
import 'package:app/enum/activity_type_enum.dart';
import 'package:app/enum/corrective_maintenance_screen_mode_enum.dart';
import 'package:app/models/cm_site_model.dart';
import 'package:app/repositories/cm_repository.dart';
import 'package:app/services/service_locator.dart';
import 'package:app/utils/toastbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../commonWidgets/site_card.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_images.dart';
import '../../services/location_service.dart';
import 'corrective_maintenance_screen.dart';

class CMAllSitesScreen extends StatefulWidget {
  const CMAllSitesScreen({super.key});

  @override
  State<CMAllSitesScreen> createState() => _CMAllSitesScreenState();
}

class _CMAllSitesScreenState extends State<CMAllSitesScreen> {
  
  List<CMSite> _allSites = [];
  List<CMSite> _filteredSites = [];
  List<CMSite> _nearbySites = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _downloadedSiteIds = <int>{};
  bool _isInitializingDownloadedSites = false;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final repository = ServiceLocator().cmRepository;
      
      // Add timeout to prevent indefinite loading
      final sites = await repository.getCMSitesDropdown().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - please check your internet connection');
        },
      );

      if (mounted) {
        setState(() {
          _allSites = sites;
          _filteredSites = sites;
          _selectedFilter = 'All Sites';
          _isLoading = false;
        });
        
        // Initialize downloaded sites state after sites are loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (sites.isNotEmpty) {
              _initializeDownloadedSites(sites);
            }
          });
        });
      }
    } catch (e) {
      print('Error loading sites: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _filterSites(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'All Sites') {
        _filteredSites = _allSites;
      } else if (filter == 'Near By Sites') {
        // For now, show all sites as nearby sites
        // In a real implementation, you would filter based on user location
        _filteredSites = _allSites;
      }
    });
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (query.isEmpty) {
        _filteredSites = _selectedFilter == 'All Sites' ? _allSites : _nearbySites;
      } else {
        final baseList = _selectedFilter == 'All Sites' ? _allSites : _nearbySites;
        _filteredSites = baseList.where((site) {
          return site.siteName.toLowerCase().contains(_searchQuery) ||
                 site.siteCode.toLowerCase().contains(_searchQuery) ||
                 site.clusterDistrictName.toLowerCase().contains(_searchQuery) ||
                 site.circleStateName.toLowerCase().contains(_searchQuery);
        }).toList();
      }
    });
  }

  int _getSiteCountForFilter(String filter) {
    if (filter == 'All Sites') {
      return _allSites.length;
    } else if (filter == 'Near By Sites') {
      return _allSites.length; // For now, same as all sites
    }
    return 0;
  }

  void _navigateToSite(CMSite site) {
    // Navigate to corrective maintenance screen with the selected site data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CorrectiveMaintenanceScreen(
          mode: CMScreenModeEnum.create,
          preloadedSites: [site], // Pass the selected site
          preloadedSiteData: {
            'siteId': site.siteId,
            'siteName': site.siteName,
            'siteCode': site.siteCode,
            'clusterDistrictName': site.clusterDistrictName,
            'circleStateName': site.circleStateName,
            'clientName': site.clientName,
            'oem': site.oem,
          },
        ),
      ),
    );
  }

  void _initializeDownloadedSites(List<CMSite> sites) async {
    // Prevent multiple initializations
    if (_isInitializingDownloadedSites) return;
    _isInitializingDownloadedSites = true;

    try {
      bool hasChanges = false;
      // Check which sites are already downloaded and populate local state
      for (final site in sites) {
        final isDownloaded = await _isSiteDownloaded(site);
        if (isDownloaded && !_downloadedSiteIds.contains(site.siteId)) {
          _downloadedSiteIds.add(site.siteId);
          hasChanges = true;
        }
      }
      // Only trigger UI update if there were actual changes
      if (hasChanges && mounted) {
        setState(() {});
      }
    } finally {
      _isInitializingDownloadedSites = false;
    }
  }

  Future<bool> _isSiteDownloaded(CMSite site) async {
    // Check local state first (for recently downloaded sites)
    if (_downloadedSiteIds.contains(site.siteId)) {
      return true;
    }

    // Check database for existing downloads using CM site data service
    try {
      final isDownloaded = await ServiceLocator().centralAssetAuditDataService
          .isCMSiteDownloaded(site.siteId);
      return isDownloaded;
    } catch (e) {
      return false;
    }
  }

  Future<void> _downloadSiteData(CMSite site) async {
    try {
      LoaderWidget.showLoader(context);
      
      // Use the new CM-specific download method
      final service = ServiceLocator().centralAssetAuditService;
      final isDownloaded = await service.downloadCMSiteData(site: site);

      if (isDownloaded) {
        // Add to local state and trigger UI update
        setState(() {
          _downloadedSiteIds.add(site.siteId);
        });
        
        // Re-initialize downloaded sites state to ensure consistency
        _initializeDownloadedSites(_allSites);
        
        Toastbar.showSuccessToastbar(
          'Site data downloaded successfully',
          context,
        );
      } else {
        Toastbar.showErrorToastbar(
          'Failed to download site data',
          context,
        );
      }
    } catch (e) {
      print('Download error: $e');
      Toastbar.showErrorToastbar(
        'Error downloading site data: $e',
        context,
      );
    } finally {
      LoaderWidget.hideLoader();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildCustomAppBar(),
      body: Stack(
        children: [
          // Background image that fully covers the screen
          Positioned.fill(
            child: SvgPicture.asset(
              AppImages.home,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Content overlay
          SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height,
              child: Column(
                children: [
                  _buildFilterBar(),
                  _buildSearchBar(),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildCustomAppBar() {
    return AppBar(
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
                  "Corrective Maintenance",
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
    );
  }


  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: _searchController,
        onChanged: _performSearch,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: const TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
          prefixIcon: null, // Remove search icon from left
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : const Icon(
                  Icons.search,
                  color: Colors.black,
                  size: 20,
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = ['All Sites', 'Near By Sites'];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final count = _getSiteCountForFilter(filter);
          final isSelected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8, left: 8),
            child: _buildFilterButton(
              filter: filter,
              count: count,
              isSelected: isSelected,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterButton({
    required String filter,
    required int count,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _filterSites(filter),
      child: Container(
        height: 32, // Fixed height for consistency
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.myTicketsSelected : AppColors.myTickets,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: Text(
            '$filter ($count)',
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.dashboardTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    } else if (_errorMessage != null) {
      return _buildErrorWidget(_errorMessage!);
    } else if (_filteredSites.isEmpty) {
      return Center(
        child: Text(
          _allSites.isEmpty
              ? 'No sites found'
              : 'No sites found for ${_selectedFilter ?? 'selected filter'}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      return SingleChildScrollView(
        child: Column(
          children: [getHeight(5), _buildSiteList(), getHeight(10)],
        ),
      );
    }
  }

  Widget _buildSiteList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredSites.length,
      itemBuilder: (context, index) {
        final site = _filteredSites[index];

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == _filteredSites.length - 1 ? 0 : 5,
          ),
          child: FutureBuilder<bool>(
            future: _isSiteDownloaded(site),
            builder: (context, snapshot) {
              final isDownloaded = snapshot.data ?? false;
              return SiteCard(
                site: site,
                distance: "2 KM", // You can calculate actual distance here
                isDownloaded: isDownloaded,
                onDirectionTap: () {
                  // Show location info or open maps
                  Toastbar.showInfoToastbar(
                    'Location: ${site.clusterDistrictName}, ${site.circleStateName}',
                    context,
                  );
                },
                onTap: () => _navigateToSite(site),
                onDownloadTap: isDownloaded 
                  ? null // Disable download if already downloaded
                  : () => _downloadSiteData(site),
              );
            },
          ),
        );
      },
    );
  }


  Widget _buildErrorWidget(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.errorColor,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading sites',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontFamily: fontFamilyMontserrat,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSites,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
