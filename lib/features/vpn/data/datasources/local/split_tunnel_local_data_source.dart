import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/split_tunnel_settings.dart';

abstract class SplitTunnelLocalDataSource {
  Future<SplitTunnelSettings> getSettings();
  Future<void> saveSettings(SplitTunnelSettings settings);
}

class InMemorySplitTunnelLocalDataSource implements SplitTunnelLocalDataSource {
  SplitTunnelSettings _settings = const SplitTunnelSettings();

  @override
  Future<SplitTunnelSettings> getSettings() async => _settings;

  @override
  Future<void> saveSettings(SplitTunnelSettings settings) async {
    _settings = settings;
  }
}

class SharedPrefsSplitTunnelLocalDataSource
    implements SplitTunnelLocalDataSource {
  SharedPrefsSplitTunnelLocalDataSource({
    Future<SharedPreferences>? sharedPreferences,
  }) : _sharedPreferences =
            sharedPreferences ?? SharedPreferences.getInstance();

  static const _settingsKey = 'vpn_split_tunnel_settings_v1';
  final Future<SharedPreferences> _sharedPreferences;

  @override
  Future<SplitTunnelSettings> getSettings() async {
    final prefs = await _sharedPreferences;
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return const SplitTunnelSettings();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const SplitTunnelSettings();
      }
      return _fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const SplitTunnelSettings();
    }
  }

  @override
  Future<void> saveSettings(SplitTunnelSettings settings) async {
    final prefs = await _sharedPreferences;
    await prefs.setString(_settingsKey, jsonEncode(_toJson(settings)));
  }

  Map<String, dynamic> _toJson(SplitTunnelSettings settings) {
    return {
      'enabled': settings.enabled,
      'mode': settings.mode.name,
      'rules': settings.rules
          .map(
            (rule) => {
              'id': rule.id,
              'type': rule.type.name,
              'value': rule.value,
              'enabled': rule.enabled,
            },
          )
          .toList(growable: false),
    };
  }

  SplitTunnelSettings _fromJson(Map<String, dynamic> json) {
    final rawRules = (json['rules'] as List?) ?? const [];
    final rules = rawRules
        .whereType<Map>()
        .map((map) => Map<String, dynamic>.from(map))
        .map(
          (ruleJson) => SplitTunnelRule(
            id: ruleJson['id'] as String? ?? '',
            type: _parseRuleType(ruleJson['type'] as String?),
            value: ruleJson['value'] as String? ?? '',
            enabled: ruleJson['enabled'] as bool? ?? true,
          ),
        )
        .where((rule) => rule.id.isNotEmpty && rule.value.isNotEmpty)
        .toList(growable: false);

    return SplitTunnelSettings(
      enabled: json['enabled'] as bool? ?? false,
      mode: _parseMode(json['mode'] as String?),
      rules: rules,
    );
  }

  SplitTunnelMode _parseMode(String? value) {
    return SplitTunnelMode.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SplitTunnelMode.excludeListedFromVpn,
    );
  }

  SplitTunnelRuleType _parseRuleType(String? value) {
    return SplitTunnelRuleType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SplitTunnelRuleType.domain,
    );
  }
}
