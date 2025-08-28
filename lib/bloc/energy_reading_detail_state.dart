part of 'energy_reading_detail_cubit.dart';

abstract class EnergyReadingDetailState extends Equatable {
  const EnergyReadingDetailState();

  @override
  List<Object?> get props => [];
}

class EnergyReadingDetailInitial extends EnergyReadingDetailState {}

class EnergyReadingDetailLoading extends EnergyReadingDetailState {}

class FileUploadSuccess extends EnergyReadingDetailState {
  final String fileId;

  const FileUploadSuccess(this.fileId);

  @override
  List<Object?> get props => [fileId];
}

class EnergyReadingDetailSaveSuccess extends EnergyReadingDetailState {
  final Map<String, dynamic>? responseData;

  const EnergyReadingDetailSaveSuccess(this.responseData);

  @override
  List<Object?> get props => [responseData];
}

class EnergyReadingDetailFailure extends EnergyReadingDetailState {
  final String errorMessage;

  const EnergyReadingDetailFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
