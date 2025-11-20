import 'package:soko_mtandao/features/booking/domain/entities/user_info.dart';

class UserModel extends UserInfo {
  UserModel({
    required String phone,
    required String name,
    required String email,
  }) : super(phone: phone, name: name, email: email);

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      phone: json['phone'],
      name: json['name'],
      email: json['email'],
    );
  }

  factory UserModel.fromEntity(UserInfo user) {
    return UserModel(
      phone: user.phone,
      name: user.name,
      email: user.email,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phone,
      'name': name,
      'email': email,
    };
  }
}