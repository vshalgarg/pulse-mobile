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
