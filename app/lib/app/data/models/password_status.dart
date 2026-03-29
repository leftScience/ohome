class PasswordStatus {
  const PasswordStatus({required this.usingDefaultPassword});

  final bool usingDefaultPassword;

  factory PasswordStatus.fromJson(Map<String, dynamic> json) {
    return PasswordStatus(
      usingDefaultPassword: json['usingDefaultPassword'] == true,
    );
  }
}
