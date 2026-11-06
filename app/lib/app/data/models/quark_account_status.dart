class QuarkAccountStatus {
  const QuarkAccountStatus({
    required this.systemMode,
    required this.preferExclusive,
    required this.effectiveMode,
    required this.canPreferExclusive,
    required this.canManageCredentials,
    required this.loginRequired,
    required this.cookieConfigured,
    required this.suggestedCredentialTarget,
  });

  final String systemMode;
  final bool preferExclusive;
  final String effectiveMode;
  final bool canPreferExclusive;
  final bool canManageCredentials;
  final bool loginRequired;
  final bool cookieConfigured;

  /// 后端下发的凭证目标，前端不要再自行推断（shared / personal）。
  final String suggestedCredentialTarget;

  bool get isSystemShared => systemMode == 'shared';
  bool get isEffectiveExclusive => effectiveMode == 'exclusive';

  /// 建议使用的凭证目标：优先用后端下发值，缺失时按生效模式兜底。
  String get credentialTarget {
    final target = suggestedCredentialTarget.trim();
    if (target == 'shared' || target == 'personal') return target;
    return isEffectiveExclusive ? 'personal' : 'shared';
  }

  factory QuarkAccountStatus.fromJson(Map<String, dynamic> json) {
    return QuarkAccountStatus(
      systemMode: (json['systemMode'] ?? 'shared').toString().trim(),
      preferExclusive: json['preferExclusive'] == true,
      effectiveMode: (json['effectiveMode'] ?? 'shared').toString().trim(),
      canPreferExclusive: json['canPreferExclusive'] == true,
      canManageCredentials: json['canManageCredentials'] == true,
      loginRequired: json['loginRequired'] == true,
      cookieConfigured: json['cookieConfigured'] == true,
      suggestedCredentialTarget:
          (json['suggestedCredentialTarget'] ?? '').toString().trim(),
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
    suggestedCredentialTarget: 'shared',
  );
}
