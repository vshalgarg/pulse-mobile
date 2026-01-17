import '../models/user_details_model.dart';

class TestUserApiResponse {
  /// Test method to verify the API response parsing
  static void testApiResponse() {
    // Sample API response based on your provided data
    final Map<String, dynamic> apiResponse = {
      "userId": 352,
      "fullName": "Abhimanyu Sahu",
      "email": "abhimanyusahu84@gmail.com",
      "mobile": "9006082503",
      "username": "9006082503",
      "userImageName": null,
      "startDate": null,
      "endDate": null,
      "isActive": true,
      "mgrId": 13,
      "remarks": null,
      "departmentId": 3,
      "designationId": 179,
      "userroles": null,
      "mirrorUserAccess": null,
      "address": null,
      "stateMstId": null,
      "cityMstId": null,
      "tenantId": 1,
      "isFirstTimeLogin": false
    };

    // Parse the response using our model
    final userDetails = UserDetailsModel.fromJson(apiResponse);

    // Test the fullName extraction
    if (userDetails.fullName == "Abhimanyu Sahu") {

    } else {

    }

  }
}
