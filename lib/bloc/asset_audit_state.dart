import 'package:equatable/equatable.dart';
import '../models/asset_audit_model.dart';

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
