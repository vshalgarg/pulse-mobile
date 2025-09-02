import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/asset_audit_model.dart';
import '../models/asset_audit_post_model.dart';
import '../repositories/asset_audit_repository.dart';
import 'asset_audit_state.dart';

class AssetAuditCubit extends Cubit<AssetAuditState> {
  final AssetAuditRepository _repository;

  AssetAuditCubit({required AssetAuditRepository repository})
      : _repository = repository,
        super(AssetAuditInitial());

  Future<void> getAssetAuditData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    emit(AssetAuditLoading());

    try {
      final assetAuditData = await _repository.getAssetAuditData(
        siteType: siteType,
        auditSchId: auditSchId,
        siteAuditSchId: siteAuditSchId,
      );

      emit(AssetAuditLoaded(assetAuditData: assetAuditData));
    } catch (e) {
      // Clean up the error message for display
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }
      emit(AssetAuditError(message: errorMessage));
    }
  }

  void reset() {
    emit(AssetAuditInitial());
  }

  /// Update the page header with new selfie image ID
  /// This method updates the makerSelfieImageId in the page header
  void updatePageHeaderSelfieImageId(String imageId) {
    final currentState = state;
    if (currentState is AssetAuditLoaded && 
        currentState.assetAuditData.pageHeader.isNotEmpty) {
      
      // Create a new PageHeader with updated makerSelfieImageId
      final currentPageHeader = currentState.assetAuditData.pageHeader.first;
      final updatedPageHeader = PageHeader(
        siteAuditSchId: currentPageHeader.siteAuditSchId,
        circle: currentPageHeader.circle,
        cluster: currentPageHeader.cluster,
        district: currentPageHeader.district,
        clientName: currentPageHeader.clientName,
        siteCode: currentPageHeader.siteCode,
        siteName: currentPageHeader.siteName,
        siteTypeName: currentPageHeader.siteTypeName,
        indoorOutdoor: currentPageHeader.indoorOutdoor,
        ebNonEb: currentPageHeader.ebNonEb,
        op1Name: currentPageHeader.op1Name,
        op2Name: currentPageHeader.op2Name,
        siteId: currentPageHeader.siteId,
        makerSelfieImageId: int.tryParse(imageId), // Convert string to int
      );

      // Create new AssetAuditModel with updated page header
      final updatedAssetAuditData = AssetAuditModel(
        pageHeader: [updatedPageHeader],
        responseData: currentState.assetAuditData.responseData,
      );

      // Emit new state with updated data
      emit(AssetAuditLoaded(assetAuditData: updatedAssetAuditData));
    }
  }

  /// Get the current page header data for debugging
  PageHeader? getCurrentPageHeader() {
    final currentState = state;
    if (currentState is AssetAuditLoaded && 
        currentState.assetAuditData.pageHeader.isNotEmpty) {
      return currentState.assetAuditData.pageHeader.first;
    }
    return null;
  }

  /// Post asset audit data to API
  /// This method is called when navigating between screens to save the current screen's data
  Future<void> postAssetAuditData({
    required List<AssetAuditPostRequest> requests,
  }) async {
    emit(AssetAuditPosting());

    try {
      final responses = await _repository.postAssetAuditData(requests: requests);
      emit(AssetAuditPostSuccess(responses: responses));
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }
      emit(AssetAuditPostError(message: errorMessage));
    }
  }
}
