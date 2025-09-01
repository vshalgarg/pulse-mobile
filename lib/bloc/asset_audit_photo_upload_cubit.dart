import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/asset_audit_photo_upload_model.dart';
import '../repositories/asset_audit_photo_upload_repository.dart';
import '../constants/constants_strings.dart';

part 'asset_audit_photo_upload_state.dart';

class AssetAuditPhotoUploadCubit extends Cubit<AssetAuditPhotoUploadState> {
  final AssetAuditPhotoUploadRepository assetAuditPhotoUploadRepository;

  AssetAuditPhotoUploadCubit(this.assetAuditPhotoUploadRepository) 
      : super(AssetAuditPhotoUploadInitial());

  // Upload photo for asset audit
  Future<void> uploadPhoto({
    required File file,
    String? imgId,
    String? schId,
  }) async {
    if (state is AssetAuditPhotoUploadLoading) return;
    emit(AssetAuditPhotoUploadLoading());
    
    final result = await assetAuditPhotoUploadRepository.uploadPhoto(
      file: file,
      imgId: imgId,
      schId: schId,
    );
    
    if (result.isSuccess) {
      emit(AssetAuditPhotoUploadSuccess(result.data!));
    } else {
      emit(AssetAuditPhotoUploadFailure(result.errorMessage ?? somethingWentWrong));
    }
  }

  // Reset state
  void reset() {
    emit(AssetAuditPhotoUploadInitial());
  }
}
