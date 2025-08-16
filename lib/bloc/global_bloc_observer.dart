import 'package:bloc/bloc.dart';

import '../constants/constants_methods.dart';


class GlobalBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    kDebugPrint(change.currentState);
    kDebugPrint(change.nextState);
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    kDebugPrint(transition);
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    kDebugPrint(error);
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase bloc) {
    kDebugPrint("Cubit Closed ${bloc.state}");
    super.onClose(bloc);
  }
}
