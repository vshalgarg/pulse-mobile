import 'package:equatable/equatable.dart';
import '../models/asset_audit_model.dart';
import '../models/asset_audit_post_model.dart';

abstract class AssetAuditState extends Equatable {
  const AssetAuditState();

  @override
  List<Object?> get props => [];
}

class AssetAuditInitial extends AssetAuditState {}

class AssetAuditLoading extends AssetAuditState {}

class AssetAuditLoaded extends AssetAuditState {
  final AssetAuditModel assetAuditData;

  const AssetAuditLoaded({required this.assetAuditData});

  @override
  List<Object?> get props => [assetAuditData];
}

class AssetAuditError extends AssetAuditState {
  final String message;

  const AssetAuditError({required this.message});

  @override
  List<Object?> get props => [message];
}

// States for POST operations
class AssetAuditPosting extends AssetAuditState {}

class AssetAuditPostSuccess extends AssetAuditState {
  final List<AssetAuditPostResponse> responses;

  const AssetAuditPostSuccess({required this.responses});

  @override
  List<Object?> get props => [responses];
}

class AssetAuditPostError extends AssetAuditState {
  final String message;

  const AssetAuditPostError({required this.message});

  @override
  List<Object?> get props => [message];
}
