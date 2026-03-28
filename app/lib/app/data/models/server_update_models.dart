class ServerUpdateTask {
  const ServerUpdateTask({required this.raw});

  final Map<String, dynamic> raw;

  factory ServerUpdateTask.fromJson(Map<String, dynamic> json) {
    return ServerUpdateTask(raw: Map<String, dynamic>.from(json));
  }

  String get id => _readString(raw['id']);
  String get status => _readString(raw['status']);
  String get step => _readString(raw['step']);
  String get message => _readString(raw['message']);
  String get targetVersion => _readString(raw['targetVersion']);
  String get currentVersion => _readString(raw['currentVersion']);
  String get previousVersion => _readString(raw['previousVersion']);
  String get deployMode => _readString(raw['deployMode']);
  int get progress => _toInt(raw['progress']) ?? 0;
  bool get canRollback => raw['canRollback'] == true;
  DateTime? get startedAt => _parseDateTime(raw['startedAt']);
  DateTime? get finishedAt => _parseDateTime(raw['finishedAt']);

  bool get isTerminal =>
      status == 'success' || status == 'failed' || status == 'rolled_back';

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value.trim());
    if (value is double) return value.toInt();
    return null;
  }

  static String _readString(dynamic value) {
    if (value is String) return value.trim();
    return '';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }
}

class ServerUpdateInfo {
  const ServerUpdateInfo({required this.raw});

  final Map<String, dynamic> raw;

  factory ServerUpdateInfo.fromJson(Map<String, dynamic> json) {
    return ServerUpdateInfo(raw: Map<String, dynamic>.from(json));
  }

  String get deployMode => _readString(raw['deployMode']);
  String get currentVersion => _readString(raw['currentVersion']);
  bool get updaterReachable => raw['updaterReachable'] == true;

  ServerUpdateTask? get currentTask {
    final value = raw['currentTask'];
    if (value is Map<String, dynamic>) {
      return ServerUpdateTask.fromJson(value);
    }
    if (value is Map) {
      return ServerUpdateTask.fromJson(value.cast<String, dynamic>());
    }
    return null;
  }

  static String _readString(dynamic value) {
    if (value is String) return value.trim();
    return '';
  }
}

class ServerUpdateCheckResult {
  const ServerUpdateCheckResult({required this.raw});

  final Map<String, dynamic> raw;

  factory ServerUpdateCheckResult.fromJson(Map<String, dynamic> json) {
    return ServerUpdateCheckResult(raw: Map<String, dynamic>.from(json));
  }

  bool get available => raw['available'] == true;
  String get currentVersion => _readString(raw['currentVersion']);
  String get latestVersion => _readString(raw['latestVersion']);
  String get releaseNotes => _readString(raw['releaseNotes']);
  String get deployMode => _readString(raw['deployMode']);

  static String _readString(dynamic value) {
    if (value is String) return value.trim();
    return '';
  }
}

class ServerUpdateApplyResult {
  const ServerUpdateApplyResult({required this.raw});

  final Map<String, dynamic> raw;

  factory ServerUpdateApplyResult.fromJson(Map<String, dynamic> json) {
    return ServerUpdateApplyResult(raw: Map<String, dynamic>.from(json));
  }

  String get taskId {
    final value = raw['taskId'];
    return value is String ? value.trim() : '';
  }

  String get status {
    final value = raw['status'];
    return value is String ? value.trim() : '';
  }
}
