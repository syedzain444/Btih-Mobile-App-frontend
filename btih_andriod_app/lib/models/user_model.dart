class User {
  final String? email;
  final String? phoneNumber;
  final String mrNo;

  User({this.email, this.phoneNumber, required this.mrNo});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      mrNo: json['mrNo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'phoneNumber': phoneNumber,
      'mrNo': mrNo,
    };
  }
}