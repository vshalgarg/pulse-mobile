import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/image_repository.dart';
import '../constants/constants_strings.dart';

part 'asset_audit_get_image_state.dart';

class AssetAuditGetImageCubit extends Cubit<AssetAuditGetImageState> {
  final ImageRepository imageRepository;

  AssetAuditGetImageCubit(this.imageRepository)
      : super(AssetAuditGetImageInitial());

  // Get image for asset audit
  Future<void> getImage({
    required String imgId,
    String? schId,
  }) async {
    if (state is AssetAuditGetImageLoading) return;
    emit(AssetAuditGetImageLoading());
    
    final result = await imageRepository.getImage(
      imgId: imgId,
      schId: schId,
    );
    
    if (result.isSuccess && result.data != null) {
      emit(AssetAuditGetImageSuccess(result.data!));
    } else {
      emit(AssetAuditGetImageFailure(result.errorMessage ?? somethingWentWrong));
    }
  }

  // Reset state
  void reset() {
    emit(AssetAuditGetImageInitial());
  }
}
