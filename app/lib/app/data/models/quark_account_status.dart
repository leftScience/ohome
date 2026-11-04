class QuarkAccountStatus {
  const QuarkAccountStatus({
    required this.systemMode,
    required this.preferExclusive,
    required this.effectiveMode,
    required this.canPreferExclusive,
    required this.canManageCredentials,
    required this.loginRequired,
    required this.cookieConfigured,
  });

  final String systemMode;
  final bool preferExclusive;
  final String effectiveMode;
  final bool canPreferExclusive;
  final bool canManageCredentials;
  final bool loginRequired;
  final bool cookieConfigured;

  bool get isSystemShared => systemMode == 'shared';
  bool get isEffectiveExclusive => effectiveMode == 'exclusive';

  factory QuarkAccountStatus.fromJson(Map<String, dynamic> json) {
    return QuarkAccountStatus(
      systemMode: (json['systemMode'] ?? 'shared').toString().trim(),
      preferExclusive: json['preferExclusive'] == true,
      effectiveMode: (json['effectiveMode'] ?? 'shared').toString().trim(),
      canPreferExclusive: json['canPreferExclusive'] == true,
      canManageCredentials: json['canManageCredentials'] == true,
      loginRequired: json['loginRequired'] == true,
      cookieConfigured: json['cookieConfigured'] == true,
    );
  }

  static const QuarkAccountStatus fallback = QuarkAccountStatus(
    systemMode: 'shared',
    preferExclusive: false,
    effectiveMode: 'shared',
    canPreferExclusive: true,
    canManageCredentials: false,
    loginRequired: false,
    cookieConfigured: false,
  );
}
