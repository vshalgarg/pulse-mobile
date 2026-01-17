import 'dart:io';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/selfie_upload_model.dart';
import '../repositories/selfie_upload_repository.dart';
import '../constants/constants_strings.dart';

part 'selfie_upload_state.dart';

class SelfieUploadCubit extends Cubit<SelfieUploadState> {
  final SelfieUploadRepository selfieUploadRepository;

  SelfieUploadCubit(this.selfieUploadRepository) : super(SelfieUploadInitial());

  // Upload selfie
  Future<void> uploadSelfie({
    required File file,
    required String imgId,
    required String schId,
  }) async {
    if (state is SelfieUploadLoading) return;
    emit(SelfieUploadLoading());
    
    final result = await selfieUploadRepository.uploadSelfie(
      file: file,
      imgId: imgId,
      schId: schId,
    );
    
    if (result.isSuccess) {
      emit(SelfieUploadSuccess(result.data!));
    } else {
      emit(SelfieUploadFailure(result.errorMessage ?? somethingWentWrong));
    }
  }

  // Reset state
  void reset() {
    emit(SelfieUploadInitial());
  }
}
