import 'config_model.dart';

class ConfigUpsertPayload {
  const ConfigUpsertPayload({
    this.id,
    required this.name,
    required this.key,
    required this.value,
    required this.isLock,
    required this.remark,
    this.credentialTarget,
  });

  final int? id;
  final String name;
  final String key;
  final String value;
  final String isLock;
  final String remark;
  final String? credentialTarget;

  factory ConfigUpsertPayload.fromConfig(
    ConfigModel config, {
    String? value,
    String? credentialTarget,
  }) {
    return ConfigUpsertPayload(
      id: config.id,
      name: config.name,
      key: config.key,
      value: value ?? config.value,
      isLock: config.isLock,
      remark: config.remark,
      credentialTarget: credentialTarget,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'name': name.trim(),
      'key': key.trim(),
      'value': value,
      'isLock': isLock.trim(),
      'remark': remark.trim(),
      if (credentialTarget != null && credentialTarget!.trim().isNotEmpty)
        'credentialTarget': credentialTarget!.trim(),
    };
  }
}
