part of 'asset_audit_photo_upload_cubit.dart';

abstract class AssetAuditPhotoUploadState extends Equatable {
  const AssetAuditPhotoUploadState();

  @override
  List<Object?> get props => [];
}

class AssetAuditPhotoUploadInitial extends AssetAuditPhotoUploadState {}

class AssetAuditPhotoUploadLoading extends AssetAuditPhotoUploadState {}

class AssetAuditPhotoUploadSuccess extends AssetAuditPhotoUploadState {
  final AssetAuditPhotoUploadResponse response;

  const AssetAuditPhotoUploadSuccess(this.response);

  @override
  List<Object?> get props => [response];
}

class AssetAuditPhotoUploadFailure extends AssetAuditPhotoUploadState {
  final String errorMessage;

  const AssetAuditPhotoUploadFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
