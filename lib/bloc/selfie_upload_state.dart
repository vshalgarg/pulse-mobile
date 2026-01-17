part of 'selfie_upload_cubit.dart';

abstract class SelfieUploadState extends Equatable {
  const SelfieUploadState();

  @override
  List<Object?> get props => [];
}

class SelfieUploadInitial extends SelfieUploadState {}

class SelfieUploadLoading extends SelfieUploadState {}

class SelfieUploadSuccess extends SelfieUploadState {
  final SelfieUploadResponse response;

  const SelfieUploadSuccess(this.response);

  @override
  List<Object?> get props => [response];
}

class SelfieUploadFailure extends SelfieUploadState {
  final String errorMessage;

  const SelfieUploadFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
