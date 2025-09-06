import 'package:app/bloc/pm_bloc/pm_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/PmGetDataModel.dart';
import '../../repositories/pm_repository.dart';
import '../../utils/pm_form_helper.dart';


class PmCubit extends Cubit<PmState> {
  final PmRepository _repository;

  PmCubit({required PmRepository repository})
      : _repository = repository,
        super(PmGetInitial());

  Future<void> getPmData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    print("🔍 DEBUG: PmCubit.getPmData called with:");
    print("🔍 siteType: $siteType");
    print("🔍 auditSchId: $auditSchId");
    print("🔍 siteAuditSchId: $siteAuditSchId");
    
    emit(PmGetLoading());

    try {
      final pmGetDataModel = await _repository.getAssetAuditData(
        siteType: siteType,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
      );

      print("🔍 DEBUG: API call successful, data received");
      emit(PmGetLoaded(pmGetDataModel: pmGetDataModel));
    } catch (e) {
      print("🔍 DEBUG: API call failed with error: $e");
      // Clean up the error message for display
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }
      emit(PmGetError(message: errorMessage));
    }
  }

  void reset() {
    emit(PmGetInitial());
  }

  Future<void> postPmData({
    required Map<String, dynamic> formData,
    required PmGetDataModel pmData,
    required String auditSchId,
    required String siteAuditSchId,
    required String siteId,
    required Map<String, int> photoIds,
    required Map<String, String> photoTimestamps,
    required Map<String, String> remarksData,
  }) async {
    emit(PmPosting());

    try {
      final requests = await PmFormHelper.buildPmPostRequests(
        formData: formData,
        pmData: pmData,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
        siteId: siteId,
        photoIds: photoIds,
        photoTimestamps: photoTimestamps,
        remarksData: remarksData,
      );

      if (requests.isNotEmpty) {
        final responses = await _repository.postPmData(requests: requests);
        emit(PmPostSuccess(responses: responses));
      } else {
        emit(PmPostError(message: 'No data to submit'));
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }
      emit(PmPostError(message: errorMessage));
    }
  }

  Future<void> postSinglePmItem({
    required String pmItemType,
    required int clOrder,
    required String resp,
    required String auditSchId,
    required String siteAuditSchId,
    required String siteId,
    String? remarks,
    int? photoId,
    String? photoTakenTs,
  }) async {
    emit(PmPosting());

    try {
      final request = await PmFormHelper.buildSinglePmRequest(
        pmItemType: pmItemType,
        clOrder: clOrder,
        resp: resp,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
        siteId: siteId,
        remarks: remarks,
        photoId: photoId,
        photoTakenTs: photoTakenTs,
      );

      final response = await _repository.postSinglePmItem(request: request);
      emit(PmPostSuccess(responses: [response]));
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }
      emit(PmPostError(message: errorMessage));
    }
  }

  // /// Update the page header with new selfie image ID
  // /// This method updates the makerSelfieImageId in the page header
  // void updatePageHeaderSelfieImageId(String imageId) {
  //   final currentState = state;
  //   if (currentState is AssetAuditLoaded &&
  //       currentState.assetAuditData.pageHeader.isNotEmpty) {
  //
  //     // Create a new PageHeader with updated makerSelfieImageId
  //     final currentPageHeader = currentState.assetAuditData.pageHeader.first;
  //     final updatedPageHeader = PageHeader(
  //       siteAuditSchId: currentPageHeader.siteAuditSchId,
  //       circle: currentPageHeader.circle,
  //       cluster: currentPageHeader.cluster,
  //       district: currentPageHeader.district,
  //       clientName: currentPageHeader.clientName,
  //       siteCode: currentPageHeader.siteCode,
  //       siteName: currentPageHeader.siteName,
  //       siteTypeName: currentPageHeader.siteTypeName,
  //       indoorOutdoor: currentPageHeader.indoorOutdoor,
  //       ebNonEb: currentPageHeader.ebNonEb,
  //       op1Name: currentPageHeader.op1Name,
  //       op2Name: currentPageHeader.op2Name,
  //       siteId: currentPageHeader.siteId,
  //       makerSelfieImageId: int.tryParse(imageId), // Convert string to int
  //     );
  //
  //     // Create new AssetAuditModel with updated page header
  //     final updatedAssetAuditData = AssetAuditModel(
  //       pageHeader: [updatedPageHeader],
  //       responseData: currentState.assetAuditData.responseData,
  //     );
  //
  //     // Emit new state with updated data
  //     emit(AssetAuditLoaded(assetAuditData: updatedAssetAuditData));
  //   }
  // }
  //
  // /// Get the current page header data for debugging
  // PageHeader? getCurrentPageHeader() {
  //   final currentState = state;
  //   if (currentState is AssetAuditLoaded &&
  //       currentState.assetAuditData.pageHeader.isNotEmpty) {
  //     return currentState.assetAuditData.pageHeader.first;
  //   }
  //   return null;
  // }

  // /// Post asset audit data to API
  // /// This method is called when navigating between screens to save the current screen's data
  // Future<void> postAssetAuditData({
  //   required List<AssetAuditPostRequest> requests,
  // }) async {
  //   emit(AssetAuditPosting());
  //
  //   try {
  //     final responses = await _repository.postAssetAuditData(requests: requests);
  //     emit(AssetAuditPostSuccess(responses: responses));
  //   } catch (e) {
  //     String errorMessage = e.toString();
  //     if (errorMessage.startsWith('Exception: ')) {
  //       errorMessage = errorMessage.substring('Exception: '.length);
  //     }
  //     emit(AssetAuditPostError(message: errorMessage));
  //   }
  // }
}
