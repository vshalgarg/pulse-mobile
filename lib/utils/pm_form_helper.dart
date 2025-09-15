import 'package:app/models/PmGetDataModel.dart';
import 'package:app/models/PmPostRequestModel.dart';
import 'package:app/services/location_service.dart';
import 'package:intl/intl.dart';

class PmFormHelper {
  /// Safely parse and format date strings to dd/MM/yyyy HH:mm format (API expected format)
  static String? _parseAndFormatDate(String dateString) {
    try {
      // Try to parse as ISO format first
      final parsedDate = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
    } catch (e) {
      // Try to parse as dd/MM/yyyy HH:mm format (used by photo upload)
      try {
        final parsedDate = DateFormat('dd/MM/yyyy HH:mm').parse(dateString);
        return DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
      } catch (e2) {
        print('Warning: Could not parse date: $dateString');
        return null;
      }
    }
  }

  static Future<List<PmPostRequest>> buildPmPostRequests({
    required Map<String, dynamic> formData,
    required PmGetDataModel pmData,
    required String auditSchId,
    required String siteAuditSchId,
    required String siteId,
    required Map<String, int> photoIds,
    required Map<String, String> photoTimestamps,
    required Map<String, String> remarksData,
  }) async {
    List<PmPostRequest> requests = [];
    
    // Get current location with offline support
    final location = await LocationService.getCurrentLocationOffline();
    final latitude = location['latitude'] ?? '';
    final longitude = location['longitude'] ?? '';
    
    print('PmFormHelper: Location data received - Latitude: $latitude, Longitude: $longitude');
    print('PmFormHelper: Processing ${formData.length} form fields');
    print('PmFormHelper: photoTimestamps received: $photoTimestamps');
    print('PmFormHelper: photoIds received: $photoIds');
    
    // Get current timestamp in dd/MM/yyyy HH:mm format as expected by the API
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    print('PmFormHelper: now variable set to: $now');

    formData.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        final parts = key.split('_');
        if (parts.length >= 2) {
          final pmItemType = parts[0];
          final clOrder = int.tryParse(parts[1]) ?? 0;
          
          print('PmFormHelper: Processing field $key with pmItemType: $pmItemType, clOrder: $clOrder, value: $value');
          
          // Get photo ID and timestamp if this field has a photo
          final photoId = photoIds[key] ?? 0;
          final photoTakenTs = photoTimestamps[key] ?? '';
          
          print('PmFormHelper: Processing field $key - photoId: $photoId, photoTakenTs: $photoTakenTs');
          print('PmFormHelper: Available photoTimestamps keys: ${photoTimestamps.keys.toList()}');
          print('PmFormHelper: Looking for key "$key" in photoTimestamps: ${photoTimestamps.containsKey(key)}');
          
          // Get remarks for this field if available
          final remarks = remarksData[key] ?? '';

          // Find the matching item from pmData to get the pmCheckListSiteRespId
          int? pmCheckListSiteRespId;
          String? checklistDesc;
          if (pmData.responseData != null) {
            // Get the section data based on pmItemType
            List<dynamic>? sectionData;
            switch (pmItemType.toUpperCase()) {
              case 'CT':
                sectionData = pmData.responseData!.ct;
                break;
              case 'EARTHING':
                sectionData = pmData.responseData!.earthing;
                break;
              case 'SEB':
                sectionData = pmData.responseData!.seb;
                break;
              case 'SOLAR':
                sectionData = pmData.responseData!.solar;
                break;
              case 'CCU':
                sectionData = pmData.responseData!.ccu;
                break;
              case 'DG':
                sectionData = pmData.responseData!.dg;
                break;
              case 'FIRE EXTINGUISHER':
                sectionData = pmData.responseData!.fireExtinguisher;
                break;
              case 'BATTERY':
                sectionData = pmData.responseData!.battery;
                break;
              case 'TOWER':
                sectionData = pmData.responseData!.tower;
                break;
              case 'ELECTRICAL':
                sectionData = pmData.responseData!.electrical;
                break;
              case 'HYGIENE':
                sectionData = pmData.responseData!.hygiene;
                break;
              case 'CIVIL & STRUCTURES':
                sectionData = pmData.responseData!.civilStructures;
                break;
              case 'BOS (BALANCE OF SYSTEM)':
                sectionData = pmData.responseData!.bos;
                break;
              case 'TRANSFORMER':
                sectionData = pmData.responseData!.transformer;
                break;
              case 'SAFETY SYSTEMS':
                sectionData = pmData.responseData!.safetySystems;
                break;
              case 'SPV':
                sectionData = pmData.responseData!.spv;
                break;
              case 'INVERTERS':
                sectionData = pmData.responseData!.inverters;
                break;
              case 'PERFORMANCE MONITORING':
                sectionData = pmData.responseData!.performanceMonitoring;
                break;
              case 'CABLES':
                sectionData = pmData.responseData!.cables;
                break;
              // case 'BOUNDARY':
              //   sectionData = pmData.responseData!.;
              //   break;
              default:
                print('Warning: Unknown pmItemType: $pmItemType');
                sectionData = null;
            }
            
            // Find the item with matching clOrder
            if (sectionData != null) {
              for (var item in sectionData) {
                int itemClOrder;
                if (item is Map<String, dynamic>) {
                  // Handle dynamic data (Civil & Structures, BOS, etc.)
                  itemClOrder = item['cl_order'] ?? 0;
                  if (itemClOrder == clOrder) {
                    pmCheckListSiteRespId = item['pm_check_list_site_resp_id'];
                    checklistDesc = item['checklist_desc'] ?? '';
                    break;
                  }
                } else {
                  // Handle typed objects (Earthing, Solar, etc.)
                  itemClOrder = item.clOrder ?? 0;
                  if (itemClOrder == clOrder) {
                    pmCheckListSiteRespId = item.pmCheckListSiteRespId;
                    checklistDesc = item.checklistDesc ?? '';
                    break;
                  }
                }
              }
            }
            
            // Radio button fields are now included in the API submission
            // No need to skip them anymore
          }

          // Use the value directly as-is for API submission
          String apiValue = value.toString();

          // Log when pmCheckListSiteRespId is null for debugging
          if (pmCheckListSiteRespId == null) {
            print('Warning: pmCheckListSiteRespId is null for field $key - this may be a new record');
          }

          PmPostRequest request = PmPostRequest(
            pmCheckListSiteRespId: pmCheckListSiteRespId,
            pmCheckListMstId: 0,
            auditSchId: int.tryParse(auditSchId) ?? 0,
            siteAuditSchId: int.tryParse(siteAuditSchId) ?? 0,
            siteId: int.tryParse(siteId) ?? 0,
            pmItemType: pmItemType,
            checklistDesc: checklistDesc ?? '',
            resp: apiValue,
            clOrder: clOrder,
            photoId: photoId > 0 ? photoId : null,
            photoTakenTs: photoId > 0 ? (photoTakenTs.isNotEmpty ? _parseAndFormatDate(photoTakenTs) : now) : null,
            longitude: longitude.isNotEmpty ? longitude : null,
            latitude: latitude.isNotEmpty ? latitude : null,
            localCreatedDt: now,
            localModifiedDt: now,
            remarks: remarks,
            isActive: true,
          );

          // Debug logging for photo data
          if (photoId > 0) {
            print('PmFormHelper: Photo data - photoId: $photoId, photoTakenTs: ${request.photoTakenTs}, originalTimestamp: $photoTakenTs');
            print('PmFormHelper: Final request photoTakenTs: ${request.photoTakenTs}');
            print('PmFormHelper: now variable: $now');
            print('PmFormHelper: photoTakenTs.isNotEmpty: ${photoTakenTs.isNotEmpty}');
            print('PmFormHelper: _parseAndFormatDate result: ${photoTakenTs.isNotEmpty ? _parseAndFormatDate(photoTakenTs) : 'using now fallback'}');
          }
          
          // Debug logging for EARTHING data specifically
          if (pmItemType.toUpperCase() == 'EARTHING') {
            print('PmFormHelper: EARTHING request created - Longitude: ${request.longitude}, Latitude: ${request.latitude}');
            print('PmFormHelper: EARTHING request details - pmItemType: ${request.pmItemType}, resp: ${request.resp}, clOrder: ${request.clOrder}');
          }

          requests.add(request);
        }
      }
    });

    return requests;
  }

  static Future<PmPostRequest> buildSinglePmRequest({
    required String pmItemType,
    required int clOrder,
    required String resp,
    required String auditSchId,
    required String siteAuditSchId,
    required String siteId,
    String? remarks,
    int? photoId,
    String? photoTakenTs,
    int? pmCheckListSiteRespId,
  }) async {
    // Get current location with offline support
    final location = await LocationService.getCurrentLocationOffline();
    final latitude = location['latitude'] ?? '';
    final longitude = location['longitude'] ?? '';
    
    // Get current timestamp in dd/MM/yyyy HH:mm format as expected by the API
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    return PmPostRequest(
      pmCheckListSiteRespId: pmCheckListSiteRespId,
      pmCheckListMstId: 0,
      auditSchId: int.tryParse(auditSchId) ?? 0,
      siteAuditSchId: int.tryParse(siteAuditSchId) ?? 0,
      siteId: int.tryParse(siteId) ?? 0,
      pmItemType: pmItemType,
      checklistDesc: '',
      resp: resp,
      clOrder: clOrder,
      photoId: photoId,
      photoTakenTs: photoId != null && photoId > 0 ? (photoTakenTs != null ? _parseAndFormatDate(photoTakenTs) : now) : null,
      longitude: longitude.isNotEmpty ? longitude : null,
      latitude: latitude.isNotEmpty ? latitude : null,
      localCreatedDt: now,
      localModifiedDt: now,
      remarks: remarks,
      isActive: true,
    );
  }
}
