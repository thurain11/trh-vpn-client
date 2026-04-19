import 'dart:convert';

class TunnelRuntimeConfig {
  const TunnelRuntimeConfig({
    required this.profileId,
    required this.platform,
    required this.engineType,
    required this.logLevel,
    required this.engineConfig,
    required this.summary,
  });

  final String profileId;
  final String platform;
  final String engineType;
  final String logLevel;
  final Map<String, dynamic> engineConfig;
  final TunnelRuntimeSummary summary;

  Map<String, dynamic> toJson() {
    return {
      'profileId': profileId,
      'platform': platform,
      'engineType': engineType,
      'logLevel': logLevel,
      'summary': summary.toJson(),
      'engineConfig': engineConfig,
    };
  }

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}

class TunnelRuntimeSummary {
  const TunnelRuntimeSummary({
    required this.protocol,
    required this.server,
    required this.port,
    required this.security,
    required this.transport,
  });

  final String protocol;
  final String server;
  final int port;
  final String security;
  final String transport;

  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol,
      'server': server,
      'port': port,
      'security': security,
      'transport': transport,
    };
  }
}
