import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/asset_audit_model.dart';
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
      emit(AssetAuditError(message: e.toString()));
    }
  }

  void reset() {
    emit(AssetAuditInitial());
  }
}
