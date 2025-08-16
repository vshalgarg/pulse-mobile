import 'package:app/constants/constants_methods.dart';
import 'package:app/models/ask_model.dart';

import '../services/api_service.dart';

class DemoRepository {
  ApiService apiService;

  DemoRepository(this.apiService);

  //login api
  Future<ResponseResult<AskModel?>> callAskApi({required Map<String, dynamic> body}) async {
    try {
      final result = await apiService.post<Map<String, dynamic>>(
        path: "ask",
        data: body,
      );
      if (result.isSuccess) {
        kDebugPrint("data is here $result.data");
        return ResponseResult.success(AskModel.fromJson(result.data));
      } else {
        return ResponseResult.error(errorMessage: result.errorMessage);
      }
    } catch (e) {
      return const ResponseResult.error(
        errorMessage: 'We could not process your request',
      );
    }
  }
}
