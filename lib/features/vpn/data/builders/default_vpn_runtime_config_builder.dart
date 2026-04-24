import '../../../../core/result/result.dart';
import '../../domain/entities/split_tunnel_settings.dart';
import '../../domain/entities/tunnel_runtime_config.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/services/vpn_runtime_config_builder.dart';

class DefaultVpnRuntimeConfigBuilder implements VpnRuntimeConfigBuilder {
  const DefaultVpnRuntimeConfigBuilder();

  @override
  Result<TunnelRuntimeConfig> build(
    VpnProfile profile, {
    SplitTunnelSettings splitTunnelSettings = const SplitTunnelSettings(),
  }) {
    if (profile.endpoint.host.isEmpty || profile.endpoint.port <= 0) {
      return const FailureResult(
          'Profile is missing a valid server address or port.');
    }

    final security = _resolveSecurity(profile);
    final transportType = profile.transport.type.name;
    final splitPlan = _buildSplitTunnelPlan(splitTunnelSettings);

    return Success(
      TunnelRuntimeConfig(
        profileId: profile.id,
        platform: 'android',
        engineType: 'xray',
        logLevel: 'info',
        summary: TunnelRuntimeSummary(
          protocol: profile.protocol.name,
          server: profile.endpoint.host,
          port: profile.endpoint.port,
          security: security,
          transport: transportType,
        ),
        engineConfig: {
          'log': {'loglevel': 'info'},
          'dns': {
            'servers': profile.isSecureDnsEnabled
                ? ['1.1.1.1', '8.8.8.8']
                : ['localhost'],
            'queryStrategy': profile.isSecureDnsEnabled ? 'UseIPv4' : 'UseIP',
          },
          'routing': {
            'domainStrategy': 'IPIfNonMatch',
            'rules': [
              {
                'type': 'field',
                'domain': ['localhost'],
                'outboundTag': 'direct',
              },
              ...splitPlan.routingRules,
            ],
          },
          'inbounds': [
            {
              'tag': 'socks-in',
              'port': 10808,
              'listen': '127.0.0.1',
              'protocol': 'socks',
              'settings': {'udp': true},
            },
          ],
          'outbounds': [
            {
              'tag': 'proxy',
              'protocol': _mapOutboundProtocol(profile.protocol),
              'settings': _buildOutboundSettings(profile),
              'streamSettings': _buildStreamSettings(profile, security),
            },
            {
              'tag': 'direct',
              'protocol': 'freedom',
              'settings': {},
            },
            {
              'tag': 'block',
              'protocol': 'blackhole',
              'settings': {},
            },
          ],
        },
        blockedApps: splitPlan.blockedApps,
        bypassSubnets: splitPlan.bypassSubnets,
        splitTunnelNote: splitPlan.note,
      ),
    );
  }

  String _mapOutboundProtocol(VpnProtocol protocol) {
    switch (protocol) {
      case VpnProtocol.shadowsocks:
        return 'shadowsocks';
      case VpnProtocol.trojan:
        return 'trojan';
      case VpnProtocol.vmess:
        return 'vmess';
      case VpnProtocol.vless:
        return 'vless';
      case VpnProtocol.wireGuard:
      case VpnProtocol.custom:
        return protocol.name;
    }
  }

  Map<String, dynamic> _buildOutboundSettings(VpnProfile profile) {
    switch (profile.protocol) {
      case VpnProtocol.vmess:
      case VpnProtocol.vless:
        return {
          'vnext': [
            {
              'address': profile.endpoint.host,
              'port': profile.endpoint.port,
              'users': [
                {
                  'id': profile.credentials.userId,
                  if (profile.protocol == VpnProtocol.vmess) 'alterId': 0,
                  if (profile.protocol == VpnProtocol.vmess) 'security': 'auto',
                  if (profile.protocol == VpnProtocol.vless)
                    'encryption': 'none',
                  if (profile.credentials.flow != null)
                    'flow': profile.credentials.flow,
                },
              ],
            },
          ],
        };
      case VpnProtocol.trojan:
        return {
          'servers': [
            {
              'address': profile.endpoint.host,
              'port': profile.endpoint.port,
              'password': profile.credentials.password,
            },
          ],
        };
      case VpnProtocol.shadowsocks:
        return {
          'servers': [
            {
              'address': profile.endpoint.host,
              'port': profile.endpoint.port,
              'method': profile.credentials.method,
              'password': profile.credentials.password,
            },
          ],
        };
      case VpnProtocol.wireGuard:
      case VpnProtocol.custom:
        return {
          'note': 'Protocol mapping not implemented yet.',
        };
    }
  }

  Map<String, dynamic> _buildStreamSettings(
      VpnProfile profile, String security) {
    final streamSettings = <String, dynamic>{
      'network': _mapTransport(profile.transport.type),
      'security': _mapStreamSecurity(security),
    };

    if (security == 'reality') {
      streamSettings['realitySettings'] = {
        if (profile.endpoint.sni != null) 'serverName': profile.endpoint.sni,
        if (profile.transport.fingerprint != null)
          'fingerprint': profile.transport.fingerprint,
        if (profile.transport.publicKey != null)
          'publicKey': profile.transport.publicKey,
        if (profile.transport.shortId != null)
          'shortId': profile.transport.shortId,
        if (profile.transport.spiderX != null)
          'spiderX': profile.transport.spiderX,
      };
    } else if (security != 'none') {
      streamSettings['tlsSettings'] = {
        if (profile.endpoint.sni != null) 'serverName': profile.endpoint.sni,
        if (profile.endpoint.alpn.isNotEmpty) 'alpn': profile.endpoint.alpn,
      };
    }

    if (profile.transport.type == VpnTransportType.ws) {
      streamSettings['wsSettings'] = {
        if (profile.transport.path != null) 'path': profile.transport.path,
        if (profile.transport.host != null)
          'headers': {'Host': profile.transport.host},
      };
    }

    if (profile.transport.type == VpnTransportType.grpc) {
      streamSettings['grpcSettings'] = {
        if (profile.transport.serviceName != null)
          'serviceName': profile.transport.serviceName,
      };
    }

    if (profile.transport.type == VpnTransportType.http) {
      streamSettings['httpSettings'] = {
        if (profile.transport.host != null) 'host': [profile.transport.host],
        if (profile.transport.path != null) 'path': profile.transport.path,
      };
    }

    return streamSettings;
  }

  String _mapStreamSecurity(String security) {
    switch (security) {
      case 'reality':
        return 'reality';
      case 'none':
        return 'none';
      default:
        return 'tls';
    }
  }

  String _resolveSecurity(VpnProfile profile) {
    final security = profile.transport.security;
    if (security != null && security.isNotEmpty) {
      return security;
    }
    switch (profile.protocol) {
      case VpnProtocol.trojan:
        return 'tls';
      case VpnProtocol.vless:
      case VpnProtocol.vmess:
      case VpnProtocol.shadowsocks:
      case VpnProtocol.wireGuard:
      case VpnProtocol.custom:
        return 'none';
    }
  }

  String _mapTransport(VpnTransportType type) {
    switch (type) {
      case VpnTransportType.http:
        return 'http';
      case VpnTransportType.grpc:
        return 'grpc';
      case VpnTransportType.ws:
        return 'ws';
      case VpnTransportType.quic:
        return 'quic';
      case VpnTransportType.tcp:
      case VpnTransportType.unknown:
        return 'tcp';
    }
  }

  _SplitTunnelPlan _buildSplitTunnelPlan(SplitTunnelSettings settings) {
    if (!settings.enabled) {
      return const _SplitTunnelPlan.empty();
    }

    final activeRules =
        settings.rules.where((rule) => rule.enabled).toList(growable: false);
    if (activeRules.isEmpty) {
      return const _SplitTunnelPlan.empty();
    }

    final domains = <String>[];
    final ips = <String>[];
    final appPackages = <String>[];

    for (final rule in activeRules) {
      switch (rule.type) {
        case SplitTunnelRuleType.domain:
          final normalized = _normalizeDomainRuleValue(rule.value);
          if (normalized.isNotEmpty && !domains.contains(normalized)) {
            domains.add(normalized);
          }
        case SplitTunnelRuleType.ipCidr:
          final normalized = rule.value.trim();
          if (normalized.isNotEmpty && !ips.contains(normalized)) {
            ips.add(normalized);
          }
        case SplitTunnelRuleType.appPackage:
          final normalized = rule.value.trim();
          if (normalized.isNotEmpty && !appPackages.contains(normalized)) {
            appPackages.add(normalized);
          }
      }
    }

    final routingRules = <Map<String, dynamic>>[];
    final blockedApps = <String>[];
    String? note;

    if (settings.mode == SplitTunnelMode.excludeListedFromVpn) {
      if (domains.isNotEmpty) {
        routingRules.add({
          'type': 'field',
          'domain': domains,
          'outboundTag': 'direct',
        });
      }
      if (ips.isNotEmpty) {
        routingRules.add({
          'type': 'field',
          'ip': ips,
          'outboundTag': 'direct',
        });
      }
      blockedApps.addAll(appPackages);
    } else {
      if (domains.isNotEmpty) {
        routingRules.add({
          'type': 'field',
          'domain': domains,
          'outboundTag': 'proxy',
        });
      }
      if (ips.isNotEmpty) {
        routingRules.add({
          'type': 'field',
          'ip': ips,
          'outboundTag': 'proxy',
        });
      }
      if (domains.isNotEmpty || ips.isNotEmpty) {
        routingRules.add({
          'type': 'field',
          'network': 'tcp,udp',
          'outboundTag': 'direct',
        });
      }
      if (appPackages.isNotEmpty) {
        note =
            'Split tunneling include-mode for apps is not supported in the current Android runtime.';
      }
    }

    return _SplitTunnelPlan(
      routingRules: routingRules,
      blockedApps: blockedApps,
      bypassSubnets: const ['0.0.0.0/0', '::/0'],
      note: note,
    );
  }

  String _normalizeDomainRuleValue(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('domain:') ||
        trimmed.startsWith('full:') ||
        trimmed.startsWith('regexp:') ||
        trimmed.startsWith('keyword:')) {
      return trimmed;
    }
    return 'domain:$trimmed';
  }
}

class _SplitTunnelPlan {
  const _SplitTunnelPlan({
    required this.routingRules,
    required this.blockedApps,
    required this.bypassSubnets,
    this.note,
  });

  const _SplitTunnelPlan.empty()
      : routingRules = const [],
        blockedApps = const [],
        bypassSubnets = const ['0.0.0.0/0', '::/0'],
        note = null;

  final List<Map<String, dynamic>> routingRules;
  final List<String> blockedApps;
  final List<String> bypassSubnets;
  final String? note;
}
