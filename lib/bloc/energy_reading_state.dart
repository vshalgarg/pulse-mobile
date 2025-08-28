part of 'energy_reading_cubit.dart';

abstract class EnergyReadingState extends Equatable {
  const EnergyReadingState();

  @override
  List<Object?> get props => [];
}

class EnergyReadingInitial extends EnergyReadingState {}

class EnergyReadingLoading extends EnergyReadingState {}

class EnergyReadingDataLoaded extends EnergyReadingState {
  final EnergyReadingResponse energyReadingResponse;

  const EnergyReadingDataLoaded(this.energyReadingResponse);

  @override
  List<Object?> get props => [energyReadingResponse];
}

class EnergyReadingSuccess extends EnergyReadingState {
  final EnergyReadingResponse energyReadingResponse;

  const EnergyReadingSuccess(this.energyReadingResponse);

  @override
  List<Object?> get props => [energyReadingResponse];
}

class FileUploadSuccess extends EnergyReadingState {
  final String fileId;

  const FileUploadSuccess(this.fileId);

  @override
  List<Object?> get props => [fileId];
}

class EnergyReadingSaveSuccess extends EnergyReadingState {
  final Map<String, dynamic>? responseData;

  const EnergyReadingSaveSuccess(this.responseData);

  @override
  List<Object?> get props => [responseData];
}

class EnergyReadingFailure extends EnergyReadingState {
  final String errorMessage;

  const EnergyReadingFailure(this.errorMessage);

  @override
  List<Object?> get props => [errorMessage];
}
