class RegisterStatus {
  const RegisterStatus({required this.enabled});

  final bool enabled;

  factory RegisterStatus.fromJson(Map<String, dynamic> json) {
    final raw = json['enabled'];
    final enabled = switch (raw) {
      bool value => value,
      int value => value != 0,
      String value =>
        value.trim().toLowerCase() == 'true' || value.trim() == '1',
      _ => false,
    };
    return RegisterStatus(enabled: enabled);
  }
}
