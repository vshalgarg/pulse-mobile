class UserDetailsModel {
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? userId;
  final String? profileImage;
  final String? role;
  final String? department;
  final String? designation;
  final String? mobile;
  final String? username;
  final String? userImageName;
  final bool? isActive;
  final int? mgrId;
  final String? remarks;
  final int? departmentId;
  final int? designationId;
  final String? address;
  final int? tenantId;
  final bool? isFirstTimeLogin;

  UserDetailsModel({
    this.fullName,
    this.firstName,
    this.lastName,
    this.email,
    this.userId,
    this.profileImage,
    this.role,
    this.department,
    this.designation,
    this.mobile,
    this.username,
    this.userImageName,
    this.isActive,
    this.mgrId,
    this.remarks,
    this.departmentId,
    this.designationId,
    this.address,
    this.tenantId,
    this.isFirstTimeLogin,
  });

  factory UserDetailsModel.fromJson(Map<String, dynamic> json) {
    return UserDetailsModel(
      fullName: json['fullName'] ?? 
                json['full_name'] ?? 
                json['name'] ?? 
                json['displayName'] ?? 
                json['display_name'] ?? 
                json['userName'] ?? 
                json['user_name'] ??
                json['username'],
      firstName: json['firstName'] ?? json['first_name'],
      lastName: json['lastName'] ?? json['last_name'],
      email: json['email'],
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? json['id']?.toString(),
      profileImage: json['profileImage'] ?? json['profile_image'] ?? json['userImageName'],
      role: json['role'],
      department: json['department'],
      designation: json['designation'],
      mobile: json['mobile'],
      username: json['username'],
      userImageName: json['userImageName'],
      isActive: json['isActive'],
      mgrId: json['mgrId'],
      remarks: json['remarks'],
      departmentId: json['departmentId'],
      designationId: json['designationId'],
      address: json['address'],
      tenantId: json['tenantId'],
      isFirstTimeLogin: json['isFirstTimeLogin'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'userId': userId,
      'profileImage': profileImage,
      'role': role,
      'department': department,
      'designation': designation,
      'mobile': mobile,
      'username': username,
      'userImageName': userImageName,
      'isActive': isActive,
      'mgrId': mgrId,
      'remarks': remarks,
      'departmentId': departmentId,
      'designationId': designationId,
      'address': address,
      'tenantId': tenantId,
      'isFirstTimeLogin': isFirstTimeLogin,
    };
  }

  @override
  String toString() {
    return 'UserDetailsModel(fullName: $fullName, firstName: $firstName, lastName: $lastName, email: $email, userId: $userId, mobile: $mobile, username: $username, isActive: $isActive)';
  }
}
