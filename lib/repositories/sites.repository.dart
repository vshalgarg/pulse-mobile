import 'package:app/models/all_site_model.dart';
import 'package:app/utils/logger.dart';
import '../services/api_service.dart';

class SitesRepository {
  final ApiService _apiService;

  SitesRepository(this._apiService);

  Future<List<AllSiteModel>> getAllSitesData(
    double latitude,
    double longitude,
    String searchInput,
    String type,
  ) async {
    try {
      Logger.debugLog('[SitesRepository] Starting to fetch all sites data');
      Logger.debugLog(
        '[SitesRepository] Latitude: $latitude, Longitude: $longitude',
      );

      final response = await _apiService.get<List<dynamic>>(
        path: '/api/v1/common/allSiteData',
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'type': type,
          'searchText': searchInput,
        },
      );

      Logger.debugLog(
        '[SitesRepository] API response received - Success: ${response.isSuccess}',
      );

      if (response.isSuccess && response.data != null) {
        // Check if data is a list
        if (response.data is List) {
          final List<dynamic> rawData = response.data!;
          Logger.debugLog(
            '[SitesRepository] Processing ${rawData.length} sites',
          );

          final List<AllSiteModel> sites = [];
          for (int i = 0; i < rawData.length; i++) {
            try {
              final siteJson = rawData[i];
              final site = AllSiteModel.fromJson(siteJson);
              sites.add(site);
            } catch (e) {
              Logger.errorLog(
                '[SitesRepository] Error parsing site at index $i: $e',
              );
              Logger.errorLog(
                '[SitesRepository] Problematic site data: ${rawData[i]}',
              );
              // Continue with other sites instead of crashing
              continue;
            }
          }

          Logger.infoLog(
            '[SitesRepository] Successfully parsed ${sites.length} out of ${rawData.length} sites',
          );
          return sites;
        } else {
          Logger.errorLog(
            '[SitesRepository] Expected List but got ${response.data.runtimeType}',
          );
          throw Exception(
            'Invalid response format: expected List but got ${response.data.runtimeType}',
          );
        }
      } else {
        Logger.errorLog(
          '[SitesRepository] API call failed: - Success: ${response.isSuccess} - Error: ${response.errorMessage} - Status Code: ${response.statusCode}',
        );
        throw Exception('Failed to load sites: ${response.errorMessage}');
      }
    } catch (e) {
      Logger.errorLog('[SitesRepository] Exception in getAllSitesData: $e');
      Logger.errorLog('[SitesRepository] Stack trace: ${StackTrace.current}');
      throw Exception('Failed to load sites: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getOrganisationList() async {
    try {
      Logger.debugLog('[SitesRepository] Starting to fetch organisation list');

      final response = await _apiService.get<List<dynamic>>(
        path: '/api/v1/common/organisationList',
      );

      Logger.debugLog(
        '[SitesRepository] Organisation list API response received - Success: ${response.isSuccess}',
      );

      if (response.isSuccess && response.data != null) {
        // Check if data is a list
        if (response.data is List) {
          final List<dynamic> rawData = response.data!;
          Logger.debugLog(
            '[SitesRepository] Processing ${rawData.length} organisations',
          );

          final List<Map<String, dynamic>> organisations = [];
          for (int i = 0; i < rawData.length; i++) {
            try {
              final orgJson = rawData[i] as Map<String, dynamic>;
              organisations.add({
                'org_id': orgJson['org_id'],
                'org_name': orgJson['org_name'],
              });
            } catch (e) {
              Logger.errorLog(
                '[SitesRepository] Error parsing organisation at index $i: $e',
              );
              Logger.errorLog(
                '[SitesRepository] Problematic organisation data: ${rawData[i]}',
              );
              // Continue with other organisations instead of crashing
              continue;
            }
          }

          Logger.infoLog(
            '[SitesRepository] Successfully parsed ${organisations.length} out of ${rawData.length} organisations',
          );
          return organisations;
        } else {
          Logger.errorLog(
            '[SitesRepository] Expected List but got ${response.data.runtimeType}',
          );
          throw Exception(
            'Invalid response format: expected List but got ${response.data.runtimeType}',
          );
        }
      } else {
        Logger.errorLog(
          '[SitesRepository] Organisation list API call failed: - Success: ${response.isSuccess} - Error: ${response.errorMessage} - Status Code: ${response.statusCode}',
        );
        throw Exception('Failed to load organisations: ${response.errorMessage}');
      }
    } catch (e) {
      Logger.errorLog('[SitesRepository] Exception in getOrganisationList: $e');
      Logger.errorLog('[SitesRepository] Stack trace: ${StackTrace.current}');
      throw Exception('Failed to load organisations: $e');
    }
  }
}
