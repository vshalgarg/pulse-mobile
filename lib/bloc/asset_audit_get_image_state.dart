part of 'asset_audit_get_image_cubit.dart';

abstract class AssetAuditGetImageState extends Equatable {
  const AssetAuditGetImageState();

  @override
  List<Object?> get props => [];
}

class AssetAuditGetImageInitial extends AssetAuditGetImageState {}

class AssetAuditGetImageLoading extends AssetAuditGetImageState {}

class AssetAuditGetImageSuccess extends AssetAuditGetImageState {
  final String imageData; // Store the actual image data (base64 string)

  const AssetAuditGetImageSuccess(this.imageData);

  @override
  List<Object?> get props => [imageData];
}

class AssetAuditGetImageFailure extends AssetAuditGetImageState {
  final String errorMessage;

  const AssetAuditGetImageFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
