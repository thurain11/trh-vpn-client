enum VpnProtocol { vmess, vless, trojan, shadowsocks, wireGuard, custom }

enum VpnProfileSourceType { manual, uri, qr, subscription }

enum VpnTransportType { tcp, ws, grpc, http, quic, unknown }

class VpnProfile {
  const VpnProfile({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.protocol,
    required this.rawConfig,
    required this.source,
    this.credentials = const VpnCredentials(),
    this.transport = const VpnTransportSettings(),
    this.subscriptionId,
    this.remarks,
    this.isSecureDnsEnabled = true,
  });

  final String id;
  final String name;
  final VpnServerEndpoint endpoint;
  final VpnProtocol protocol;
  final String rawConfig;
  final VpnProfileSource source;
  final VpnCredentials credentials;
  final VpnTransportSettings transport;
  final String? subscriptionId;
  final String? remarks;
  final bool isSecureDnsEnabled;

  String get serverAddress => endpoint.host;
  int get serverPort => endpoint.port;

  VpnProfile copyWith({
    String? id,
    String? name,
    VpnServerEndpoint? endpoint,
    VpnProtocol? protocol,
    String? rawConfig,
    VpnProfileSource? source,
    VpnCredentials? credentials,
    VpnTransportSettings? transport,
    Object? subscriptionId = _sentinel,
    Object? remarks = _sentinel,
    bool? isSecureDnsEnabled,
  }) {
    return VpnProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      endpoint: endpoint ?? this.endpoint,
      protocol: protocol ?? this.protocol,
      rawConfig: rawConfig ?? this.rawConfig,
      source: source ?? this.source,
      credentials: credentials ?? this.credentials,
      transport: transport ?? this.transport,
      subscriptionId: identical(subscriptionId, _sentinel)
          ? this.subscriptionId
          : subscriptionId as String?,
      remarks: identical(remarks, _sentinel) ? this.remarks : remarks as String?,
      isSecureDnsEnabled: isSecureDnsEnabled ?? this.isSecureDnsEnabled,
    );
  }
}

class VpnServerEndpoint {
  const VpnServerEndpoint({
    required this.host,
    required this.port,
    this.sni,
    this.alpn = const [],
  });

  final String host;
  final int port;
  final String? sni;
  final List<String> alpn;
}

class VpnCredentials {
  const VpnCredentials({
    this.userId,
    this.password,
    this.method,
    this.flow,
  });

  final String? userId;
  final String? password;
  final String? method;
  final String? flow;
}

class VpnTransportSettings {
  const VpnTransportSettings({
    this.type = VpnTransportType.tcp,
    this.path,
    this.host,
    this.security,
    this.serviceName,
    this.fingerprint,
    this.publicKey,
    this.shortId,
    this.spiderX,
  });

  final VpnTransportType type;
  final String? path;
  final String? host;
  final String? security;
  final String? serviceName;
  final String? fingerprint;
  final String? publicKey;
  final String? shortId;
  final String? spiderX;
}

class VpnProfileSource {
  const VpnProfileSource({
    required this.type,
    required this.originalValue,
  });

  final VpnProfileSourceType type;
  final String originalValue;
}

const _sentinel = Object();
