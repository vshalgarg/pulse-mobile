import 'dart:io';
import 'package:app/models/energy_reading_detail_model.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../constants/constants_strings.dart';
import '../repositories/energy_reading_detail_repository.dart';

part 'energy_reading_detail_state.dart';

class EnergyReadingDetailCubit extends Cubit<EnergyReadingDetailState> {
  final EnergyReadingDetailRepository energyReadingDetailRepository;

  EnergyReadingDetailCubit(this.energyReadingDetailRepository) : super(EnergyReadingDetailInitial());

  // Upload file
  Future<void> uploadFile({
    required File file,
    required String id,
  }) async {
    if (state is EnergyReadingDetailLoading) return;
    emit(EnergyReadingDetailLoading());
    
    final result = await energyReadingDetailRepository.uploadFile(
      file: file,
      id: id,
    );
    
    if (result.isSuccess) {
      emit(FileUploadSuccess(result.data ?? ''));
    } else {
      emit(EnergyReadingDetailFailure(result.errorMessage ?? somethingWentWrong));
    }
  }

  // Save energy reading detail data
  Future<void> saveEnergyReadingData({
    required EnergyReadingDetailRequest energyReadingData,
  }) async {
    if (state is EnergyReadingDetailLoading) return;
    emit(EnergyReadingDetailLoading());
    
    final result = await energyReadingDetailRepository.saveEnergyReadingDetailData(
      energyReadingData: [energyReadingData.toJson()],
    );
    
    if (result.isSuccess) {
      emit(EnergyReadingDetailSaveSuccess(result.data));
    } else {
      emit(EnergyReadingDetailFailure(result.errorMessage ?? somethingWentWrong));
    }
  }

  // Reset state
  void reset() {
    emit(EnergyReadingDetailInitial());
  }
}
