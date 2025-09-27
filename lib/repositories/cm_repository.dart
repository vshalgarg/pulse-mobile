import '../models/cm_site_model.dart';
import '../services/api_service.dart';

class CMRepository {
  final ApiService _apiService;

  CMRepository(this._apiService);

  Future<List<CMSite>> getCMSitesDropdown() async {
    try {
      print('🌐 [CMRepository] Starting CM Sites Dropdown API call...');
      print('🌐 [CMRepository] API Path: /api/v1/mobile/cm/CmSitesDropdown');
      print('🌐 [CMRepository] Base URL: ${_apiService.baseUrl}');
      
      final response = await _apiService.get<List<dynamic>>(
        path: '/api/v1/mobile/cm/CmSitesDropdown',
      );

      print('🔍 [CMRepository] Raw API Response:');
      print('   - Status Code: ${response.statusCode}');
      print('   - Is Success: ${response.isSuccess}');
      print('   - Error Message: ${response.errorMessage}');
      print('   - Data Type: ${response.data.runtimeType}');
      print('   - Data: ${response.data}');

      if (response.isSuccess && response.data != null) {
        print('✅ [CMRepository] API call successful, processing data...');
        
        // Check if data is a list
        if (response.data is List) {
          final List<dynamic> rawData = response.data!;
          print('📊 [CMRepository] Raw data count: ${rawData.length}');
          
          // Log first few items for debugging
          if (rawData.isNotEmpty) {
            print('📋 [CMRepository] First item structure:');
            print('   - Type: ${rawData.first.runtimeType}');
            print('   - Content: ${rawData.first}');
            
            // Check if it's a Map and has expected fields
            if (rawData.first is Map<String, dynamic>) {
              final Map<String, dynamic> firstItem = rawData.first;
              print('🔍 [CMRepository] First item fields:');
              firstItem.forEach((key, value) {
                print('   - $key: $value (${value.runtimeType})');
              });
            }
          }
          
          final sites = rawData.map((siteJson) {
            print('🔄 [CMRepository] Parsing site: $siteJson');
            try {
              final site = CMSite.fromJson(siteJson);
              print('✅ [CMRepository] Parsed site: ${site.siteName} (ID: ${site.siteId})');
              return site;
            } catch (e) {
              print('❌ [CMRepository] Error parsing site $siteJson: $e');
              rethrow;
            }
          }).toList();
          
          print('✅ [CMRepository] Successfully parsed ${sites.length} sites');
          print('📝 [CMRepository] Site names: ${sites.map((s) => s.siteName).toList()}');
          return sites;
        } else {
          print('❌ [CMRepository] Expected List but got ${response.data.runtimeType}');
          throw Exception('Invalid response format: expected List but got ${response.data.runtimeType}');
        }
      } else {
        print('❌ [CMRepository] API call failed:');
        print('   - Success: ${response.isSuccess}');
        print('   - Error: ${response.errorMessage}');
        print('   - Status Code: ${response.statusCode}');
        throw Exception('Failed to load sites: ${response.errorMessage}');
      }
    } catch (e) {
      print('❌ [CMRepository] Exception occurred: $e');
      print('❌ [CMRepository] Exception type: ${e.runtimeType}');
      print('❌ [CMRepository] Stack trace: ${StackTrace.current}');
      throw Exception('Failed to load sites: $e');
    }
  }
}