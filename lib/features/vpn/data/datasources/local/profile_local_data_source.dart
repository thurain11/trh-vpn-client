import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vpn_profile_model.dart';
import '../../../domain/entities/vpn_profile.dart';

abstract class ProfileLocalDataSource {
  Future<List<VpnProfileModel>> getProfiles();
  Future<void> saveProfile(VpnProfileModel profile);
  Future<void> deleteProfile(String id);
  Future<void> replaceProfiles(List<VpnProfileModel> profiles);
}

class InMemoryProfileLocalDataSource implements ProfileLocalDataSource {
  final List<VpnProfileModel> _profiles = [];

  @override
  Future<List<VpnProfileModel>> getProfiles() async {
    return List.unmodifiable(_profiles);
  }

  @override
  Future<void> saveProfile(VpnProfileModel profile) async {
    _profiles.removeWhere((element) => element.id == profile.id);
    _profiles.add(profile);
  }

  @override
  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((element) => element.id == id);
  }

  @override
  Future<void> replaceProfiles(List<VpnProfileModel> profiles) async {
    _profiles
      ..clear()
      ..addAll(profiles);
  }
}

class SharedPrefsProfileLocalDataSource implements ProfileLocalDataSource {
  SharedPrefsProfileLocalDataSource({
    Future<SharedPreferences>? sharedPreferences,
  }) : _sharedPreferences =
            sharedPreferences ?? SharedPreferences.getInstance();

  static const _profilesKey = 'vpn_profiles_v1';
  final Future<SharedPreferences> _sharedPreferences;

  @override
  Future<List<VpnProfileModel>> getProfiles() async {
    final prefs = await _sharedPreferences;
    final raw = prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      final profiles = decoded
          .whereType<Map>()
          .map((map) => _fromJson(Map<String, dynamic>.from(map)))
          .toList();
      profiles
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return profiles;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveProfile(VpnProfileModel profile) async {
    final prefs = await _sharedPreferences;
    final existing = List<VpnProfileModel>.from(await getProfiles());
    existing.removeWhere((item) => item.id == profile.id);
    existing.add(profile);
    await _persistProfiles(existing, prefs);
  }

  @override
  Future<void> deleteProfile(String id) async {
    final prefs = await _sharedPreferences;
    final existing = List<VpnProfileModel>.from(await getProfiles());
    existing.removeWhere((item) => item.id == id);
    await _persistProfiles(existing, prefs);
  }

  @override
  Future<void> replaceProfiles(List<VpnProfileModel> profiles) async {
    final prefs = await _sharedPreferences;
    await _persistProfiles(profiles, prefs);
  }

  Map<String, dynamic> _toJson(VpnProfileModel profile) {
    return {
      'id': profile.id,
      'name': profile.name,
      'endpoint': {
        'host': profile.endpoint.host,
        'port': profile.endpoint.port,
        'sni': profile.endpoint.sni,
        'alpn': profile.endpoint.alpn,
      },
      'protocol': profile.protocol.name,
      'rawConfig': profile.rawConfig,
      'source': {
        'type': profile.source.type.name,
        'originalValue': profile.source.originalValue,
      },
      'credentials': {
        'userId': profile.credentials.userId,
        'password': profile.credentials.password,
        'method': profile.credentials.method,
        'flow': profile.credentials.flow,
      },
      'transport': {
        'type': profile.transport.type.name,
        'path': profile.transport.path,
        'host': profile.transport.host,
        'security': profile.transport.security,
        'serviceName': profile.transport.serviceName,
        'fingerprint': profile.transport.fingerprint,
        'publicKey': profile.transport.publicKey,
        'shortId': profile.transport.shortId,
        'spiderX': profile.transport.spiderX,
      },
      'subscriptionId': profile.subscriptionId,
      'remarks': profile.remarks,
      'isSecureDnsEnabled': profile.isSecureDnsEnabled,
    };
  }

  VpnProfileModel _fromJson(Map<String, dynamic> json) {
    final endpoint =
        Map<String, dynamic>.from(json['endpoint'] as Map? ?? const {});
    final source =
        Map<String, dynamic>.from(json['source'] as Map? ?? const {});
    final credentials = Map<String, dynamic>.from(
      json['credentials'] as Map? ?? const {},
    );
    final transport = Map<String, dynamic>.from(
      json['transport'] as Map? ?? const {},
    );

    return VpnProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Profile',
      endpoint: VpnServerEndpoint(
        host: endpoint['host'] as String? ?? '',
        port: (endpoint['port'] as num?)?.toInt() ?? 0,
        sni: endpoint['sni'] as String?,
        alpn: (endpoint['alpn'] as List?)?.whereType<String>().toList() ??
            const [],
      ),
      protocol: _parseProtocol(json['protocol'] as String?),
      rawConfig: json['rawConfig'] as String? ?? '',
      source: VpnProfileSource(
        type: _parseSourceType(source['type'] as String?),
        originalValue: source['originalValue'] as String? ?? '',
      ),
      credentials: VpnCredentials(
        userId: credentials['userId'] as String?,
        password: credentials['password'] as String?,
        method: credentials['method'] as String?,
        flow: credentials['flow'] as String?,
      ),
      transport: VpnTransportSettings(
        type: _parseTransportType(transport['type'] as String?),
        path: transport['path'] as String?,
        host: transport['host'] as String?,
        security: transport['security'] as String?,
        serviceName: transport['serviceName'] as String?,
        fingerprint: transport['fingerprint'] as String?,
        publicKey: transport['publicKey'] as String?,
        shortId: transport['shortId'] as String?,
        spiderX: transport['spiderX'] as String?,
      ),
      subscriptionId: json['subscriptionId'] as String?,
      remarks: json['remarks'] as String?,
      isSecureDnsEnabled: json['isSecureDnsEnabled'] as bool? ?? true,
    );
  }

  Future<void> _persistProfiles(
    List<VpnProfileModel> profiles,
    SharedPreferences prefs,
  ) async {
    final jsonList = profiles.map(_toJson).toList();
    await prefs.setString(_profilesKey, jsonEncode(jsonList));
  }

  VpnProtocol _parseProtocol(String? value) {
    return VpnProtocol.values.firstWhere(
      (item) => item.name == value,
      orElse: () => VpnProtocol.custom,
    );
  }

  VpnProfileSourceType _parseSourceType(String? value) {
    return VpnProfileSourceType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => VpnProfileSourceType.manual,
    );
  }

  VpnTransportType _parseTransportType(String? value) {
    return VpnTransportType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => VpnTransportType.unknown,
    );
  }
}
