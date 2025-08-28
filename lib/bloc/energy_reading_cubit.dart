import 'package:app/models/energy_reading_model.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:io';

import '../constants/constants_strings.dart';
import '../repositories/energy_reading_repository.dart';

part 'energy_reading_state.dart';

class EnergyReadingCubit extends Cubit<EnergyReadingState> {
  final EnergyReadingRepository energyReadingRepository;

  EnergyReadingCubit(this.energyReadingRepository) : super(EnergyReadingInitial());

  // Get energy reading data
  Future<void> getEnergyReadingData({
    required String siteType,
    required String auditSchId,
    required String siteAuditSchId,
  }) async {
    if (state is EnergyReadingLoading) return;
    emit(EnergyReadingLoading());
    
    final result = await energyReadingRepository.getEnergyReadingData(
      siteType: siteType,
      auditSchId: auditSchId,
      siteAuditSchId: siteAuditSchId,
    );
    
    if (result.isSuccess) {
      emit(EnergyReadingSuccess(result.data!));
    } else {
      emit(EnergyReadingFailure(result.errorMessage ?? somethingWentWrong));
    }
  }

  // Upload file
  Future<void> uploadFile({
    required File file,
    required String id,
  }) async {
    if (state is EnergyReadingLoading) return;
    emit(EnergyReadingLoading());
    
    final result = await energyReadingRepository.uploadFile(
      file: file,
      id: id,
    );
    
    if (result.isSuccess) {
      emit(FileUploadSuccess(result.data ?? ''));
    } else {
      emit(EnergyReadingFailure(result.errorMessage ?? somethingWentWrong));
    }
  }

  // Save energy reading data
  Future<void> saveEnergyReadingData({
    required EnergyReadingRequest energyReadingData,
  }) async {
    if (state is EnergyReadingLoading) return;
    emit(EnergyReadingLoading());
    
    final result = await energyReadingRepository.saveEnergyReadingData(
      energyReadingData: [energyReadingData.toJson()],
    );
    
    if (result.isSuccess) {
      emit(EnergyReadingSaveSuccess(result.data));
    } else {
      emit(EnergyReadingFailure(result.errorMessage ?? somethingWentWrong));
    }
  }

  // Reset state
  void reset() {
    emit(EnergyReadingInitial());
  }
}
