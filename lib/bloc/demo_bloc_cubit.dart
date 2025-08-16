import 'package:app/models/ask_model.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../constants/constants_strings.dart';
import '../repositories/demo_repository.dart';

part 'demo_bloc_state.dart';

class DemoBlocCubit extends Cubit<DemoBlocState> {
  DemoRepository askRepository;

  DemoBlocCubit(this.askRepository) : super(DemoBlocInitial());

  // call api
  Future<void> callApi(String question) async {
    if (state is DemoBlocLoading) return;
    emit(DemoBlocLoading());
    final result = await askRepository.callAskApi(
      body: {
        "question": question,
        "chat_id": null,
      },
    );
    if (result.isSuccess) {
      emit(DemoBlocSuccess(result.data!));
    } else {
      emit(DemoBlocFailure(result.errorMessage ?? somethingWentWrong));
    }
  }
}
