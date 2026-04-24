enum SplitTunnelMode {
  excludeListedFromVpn,
  includeOnlyListedInVpn,
}

enum SplitTunnelRuleType {
  appPackage,
  domain,
  ipCidr,
}

class SplitTunnelRule {
  const SplitTunnelRule({
    required this.id,
    required this.type,
    required this.value,
    this.enabled = true,
  });

  final String id;
  final SplitTunnelRuleType type;
  final String value;
  final bool enabled;

  SplitTunnelRule copyWith({
    String? id,
    SplitTunnelRuleType? type,
    String? value,
    bool? enabled,
  }) {
    return SplitTunnelRule(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      enabled: enabled ?? this.enabled,
    );
  }
}

class SplitTunnelSettings {
  const SplitTunnelSettings({
    this.enabled = false,
    this.mode = SplitTunnelMode.excludeListedFromVpn,
    this.rules = const [],
  });

  final bool enabled;
  final SplitTunnelMode mode;
  final List<SplitTunnelRule> rules;

  SplitTunnelSettings copyWith({
    bool? enabled,
    SplitTunnelMode? mode,
    List<SplitTunnelRule>? rules,
  }) {
    return SplitTunnelSettings(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      rules: rules ?? this.rules,
    );
  }
}
