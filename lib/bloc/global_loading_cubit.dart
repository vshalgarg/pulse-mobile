import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

part 'global_loading_state.dart';

class GlobalLoadingCubit extends Cubit<GlobalLoadingState> {
  GlobalLoadingCubit() : super(GlobalLoadingInitial());

  void showLoading({String? message}) {
    emit(GlobalLoadingShow(message: message ?? 'Loading...'));
  }

  void hideLoading() {
    emit(GlobalLoadingHide());
  }

  void updateMessage(String message) {
    if (state is GlobalLoadingShow) {
      emit(GlobalLoadingShow(message: message));
    }
  }
}
