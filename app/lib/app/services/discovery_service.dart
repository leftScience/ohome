import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:ohome/app/data/models/discovered_server.dart';
import 'package:ohome/app/data/models/discovery_info.dart';
import 'package:ohome/app/data/storage/discovery_storage.dart';
import 'package:ohome/app/utils/app_env.dart';

class DiscoveryService {
  DiscoveryService({required DiscoveryStorage storage}) : _storage = storage;

  static const _networkChannel = MethodChannel('ohome/network_info');
  static const _defaultPort = 18090;
  static const _mdnsServiceName = '_ohome._tcp.local';
  static const _probePath = '/api/v1/public/discovery';

  final DiscoveryStorage _storage;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(milliseconds: 800),
      receiveTimeout: const Duration(milliseconds: 800),
      sendTimeout: const Duration(milliseconds: 800),
      headers: const <String, dynamic>{'Content-Type': 'application/json'},
    ),
  );

  Future<List<DiscoveredServer>> discoverServers() async {
    final remembered = await _storage.readLastSuccessfulServer();
    final merged = <String, DiscoveredServer>{};
    final probedOrigins = <String>{};

    if (remembered != null) {
      final previous = await _probeOrigin(remembered.origin);
      if (previous != null) {
        final server = previous.instanceId == remembered.instanceId
            ? previous.merge(
                DiscoveredServer(
                  info: previous.info,
                  origin: previous.origin,
                  sources: const <DiscoverySource>{
                    DiscoverySource.previousSuccess,
                  },
                ),
              )
            : previous;
        _upsert(merged, server);
        probedOrigins.add(previous.origin);
      }
    }

    final mdnsServers = await _discoverViaMdns();
    for (final server in mdnsServers) {
      _upsert(merged, server);
      probedOrigins.add(server.origin);
    }

    final ports = <int>{_defaultPort};
    if (remembered != null && remembered.port > 0) {
      ports.add(remembered.port);
    }

    final scannedServers = await _discoverViaSubnetScan(
      ports: ports,
      skipOrigins: probedOrigins,
    );
    for (final server in scannedServers) {
      _upsert(merged, server);
    }

    final values = merged.values.toList(growable: false)
      ..sort((left, right) {
        final rankCompare = right.rank.compareTo(left.rank);
        if (rankCompare != 0) return rankCompare;
        return left.serviceName.compareTo(right.serviceName);
      });
    return values;
  }

  Future<void> rememberSuccessfulServer({
    required String apiBaseUrlInput,
    DiscoveredServer? selectedServer,
  }) async {
    final remembered = selectedServer ?? await _probeInput(apiBaseUrlInput);
    if (remembered == null) return;
    await _storage.writeLastSuccessfulServer(
      RememberedServer(
        origin: remembered.origin,
        instanceId: remembered.instanceId,
        port: remembered.port,
      ),
    );
  }

  Future<DiscoveredServer?> _probeInput(String rawInput) async {
    final normalized = AppEnv.normalizeApiBaseUrlInput(rawInput);
    final origin = _originFromApiBaseUrl(normalized);
    return _probeOrigin(origin);
  }

  Future<List<DiscoveredServer>> _discoverViaMdns() async {
    if (!Platform.isAndroid) return const <DiscoveredServer>[];

    final client = MDnsClient();
    final discovered = <String, DiscoveredServer>{};

    try {
      await _setMulticastLock(enabled: true);
      await client.start();

      final pointers = await client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(_mdnsServiceName),
          )
          .toList()
          .timeout(
            const Duration(milliseconds: 1200),
            onTimeout: () => const <PtrResourceRecord>[],
          );

      for (final pointer in pointers) {
        final services = await client
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(pointer.domainName),
            )
            .toList()
            .timeout(
              const Duration(milliseconds: 1200),
              onTimeout: () => const <SrvResourceRecord>[],
            );

        for (final service in services) {
          final addresses = await client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(service.target),
              )
              .toList()
              .timeout(
                const Duration(milliseconds: 1200),
                onTimeout: () => const <IPAddressResourceRecord>[],
              );

          for (final address in addresses) {
            final origin = 'http://${address.address.address}:${service.port}';
            final server = await _probeOrigin(
              origin,
              sources: const <DiscoverySource>{DiscoverySource.mdns},
            );
            if (server == null) continue;
            _upsert(discovered, server);
          }
        }
      }
    } catch (_) {
      return const <DiscoveredServer>[];
    } finally {
      client.stop();
      await _setMulticastLock(enabled: false);
    }

    return discovered.values.toList(growable: false);
  }

  Future<List<DiscoveredServer>> _discoverViaSubnetScan({
    required Set<int> ports,
    required Set<String> skipOrigins,
  }) async {
    final cidr = await _getActiveIpv4Cidr();
    if (cidr == null) return const <DiscoveredServer>[];

    final hosts = _enumerateHosts(cidr);
    if (hosts.isEmpty) return const <DiscoveredServer>[];

    final candidates = <String>[];
    for (final host in hosts) {
      for (final port in ports) {
        final origin = 'http://$host:$port';
        if (skipOrigins.contains(origin)) continue;
        candidates.add(origin);
      }
    }

    final discovered = <String, DiscoveredServer>{};
    const batchSize = 24;
    for (var i = 0; i < candidates.length; i += batchSize) {
      final end = (i + batchSize > candidates.length)
          ? candidates.length
          : i + batchSize;
      final batch = candidates.sublist(i, end);
      final results = await Future.wait(
        batch.map(
          (origin) => _probeOrigin(
            origin,
            sources: const <DiscoverySource>{DiscoverySource.subnetScan},
          ),
        ),
      );
      for (final server in results.whereType<DiscoveredServer>()) {
        _upsert(discovered, server);
      }
    }

    return discovered.values.toList(growable: false);
  }

  Future<DiscoveredServer?> _probeOrigin(
    String origin, {
    Set<DiscoverySource> sources = const <DiscoverySource>{},
  }) async {
    final normalizedOrigin = _normalizeOrigin(origin);
    try {
      final response = await _dio.get<dynamic>('$normalizedOrigin$_probePath');
      final info = _decodeDiscoveryInfo(response.data);
      if (info == null || info.instanceId.isEmpty || info.apiBaseUrl.isEmpty) {
        return null;
      }

      return DiscoveredServer(
        info: info,
        origin: _originFromApiBaseUrl(info.apiBaseUrl),
        sources: sources,
      );
    } catch (_) {
      return null;
    }
  }

  DiscoveryInfo? _decodeDiscoveryInfo(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;
    final code = payload['code'];
    if (code is int && code != 200) return null;
    if (code is String && code != '200') return null;
    final data = payload['data'];
    if (data is! Map<String, dynamic>) return null;
    return DiscoveryInfo.fromJson(data);
  }

  Future<_ActiveIpv4Cidr?> _getActiveIpv4Cidr() async {
    if (!Platform.isAndroid) return null;

    try {
      final payload = await _networkChannel.invokeMapMethod<String, dynamic>(
        'getActiveIpv4Cidr',
      );
      if (payload == null) return null;
      final address = (payload['address'] as String? ?? '').trim();
      final prefixLength = payload['prefixLength'];
      final prefix = prefixLength is int
          ? prefixLength
          : int.tryParse(prefixLength?.toString() ?? '');
      if (address.isEmpty || prefix == null || prefix < 0 || prefix > 32) {
        return null;
      }
      return _ActiveIpv4Cidr(address: address, prefixLength: prefix);
    } on PlatformException {
      return null;
    }
  }

  Future<void> _setMulticastLock({required bool enabled}) async {
    if (!Platform.isAndroid) return;

    try {
      await _networkChannel.invokeMethod<void>(
        enabled ? 'acquireMulticastLock' : 'releaseMulticastLock',
      );
    } on PlatformException {
      return;
    }
  }

  List<String> _enumerateHosts(_ActiveIpv4Cidr cidr) {
    final prefix = cidr.prefixLength;
    if (prefix >= 31) return const <String>[];

    final address = _ipv4ToInt(cidr.address);
    if (address == null) return const <String>[];

    final hostBits = 32 - prefix;
    final hostCount = (1 << hostBits) - 2;
    if (hostCount <= 0 || hostCount > 1022) {
      return const <String>[];
    }

    final mask = prefix == 0 ? 0 : ((0xFFFFFFFF << hostBits) & 0xFFFFFFFF);
    final network = address & mask;
    final first = network + 1;
    final last = network + hostCount;
    final current = address;

    final hosts = <String>[];
    for (var value = first; value <= last; value++) {
      if (value == current) continue;
      hosts.add(_intToIpv4(value));
    }
    return hosts;
  }

  int? _ipv4ToInt(String value) {
    final parts = value.split('.');
    if (parts.length != 4) return null;
    var result = 0;
    for (final part in parts) {
      final segment = int.tryParse(part);
      if (segment == null || segment < 0 || segment > 255) return null;
      result = (result << 8) | segment;
    }
    return result;
  }

  String _intToIpv4(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ].join('.');
  }

  String _normalizeOrigin(String origin) {
    final trimmed = origin.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _originFromApiBaseUrl(String apiBaseUrl) {
    final uri = Uri.parse(apiBaseUrl);
    final portText = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portText';
  }

  void _upsert(Map<String, DiscoveredServer> target, DiscoveredServer server) {
    final key = server.instanceId.trim().isNotEmpty
        ? 'id:${server.instanceId}'
        : 'origin:${server.origin}';
    final current = target[key];
    if (current == null) {
      target[key] = server;
      return;
    }
    target[key] = current.merge(server);
  }
}

class _ActiveIpv4Cidr {
  const _ActiveIpv4Cidr({required this.address, required this.prefixLength});

  final String address;
  final int prefixLength;
}
