import 'package:flutter_test/flutter_test.dart';

import 'package:lunex/core/result/result.dart';
import 'package:lunex/features/vpn/data/builders/default_vpn_runtime_config_builder.dart';
import 'package:lunex/features/vpn/data/parsers/vless_uri_parser.dart';
import 'package:lunex/features/vpn/domain/entities/tunnel_runtime_config.dart';
import 'package:lunex/features/vpn/domain/entities/vpn_profile.dart';

void main() {
  const uri =
      'vless://3609523d-2702-42cb-870c-45e1713c2933@168.144.109.201:443'
      '?type=tcp&encryption=none&security=reality'
      '&pbk=Fr4lA1ei1hNoWSaWyxoxH62DOgG_KnRUL_Z3DROJqys'
      '&fp=chrome&sni=www.oracle.com&sid=2551ec0a49&spx=%2F'
      '&flow=xtls-rprx-vision#trh-v2box-s2dskllg';

  test('VLESS Reality parser keeps Reality-specific fields', () {
    const parser = VlessUriParser();

    final result = parser.parse(uri);

    expect(result, isA<Success<VpnProfile>>());
    final profile = (result as Success<VpnProfile>).data;
    expect(profile.transport.security, 'reality');
    expect(profile.transport.publicKey, 'Fr4lA1ei1hNoWSaWyxoxH62DOgG_KnRUL_Z3DROJqys');
    expect(profile.transport.fingerprint, 'chrome');
    expect(profile.transport.shortId, '2551ec0a49');
    expect(profile.transport.spiderX, '/');
    expect(profile.credentials.flow, 'xtls-rprx-vision');
    expect(profile.endpoint.sni, 'www.oracle.com');
  });

  test('Runtime config builder emits Xray realitySettings', () {
    const parser = VlessUriParser();
    const builder = DefaultVpnRuntimeConfigBuilder();

    final parseResult = parser.parse(uri) as Success<VpnProfile>;
    final buildResult = builder.build(parseResult.data);

    expect(buildResult, isA<Success<TunnelRuntimeConfig>>());
    final runtimeConfig = (buildResult as Success<TunnelRuntimeConfig>).data;
    final outbound = (runtimeConfig.engineConfig['outbounds'] as List<dynamic>).first
        as Map<String, dynamic>;
    final streamSettings = outbound['streamSettings'] as Map<String, dynamic>;
    final realitySettings = streamSettings['realitySettings'] as Map<String, dynamic>;

    expect(runtimeConfig.summary.security, 'reality');
    expect(streamSettings['security'], 'reality');
    expect(realitySettings['serverName'], 'www.oracle.com');
    expect(realitySettings['fingerprint'], 'chrome');
    expect(realitySettings['publicKey'], 'Fr4lA1ei1hNoWSaWyxoxH62DOgG_KnRUL_Z3DROJqys');
    expect(realitySettings['shortId'], '2551ec0a49');
    expect(realitySettings['spiderX'], '/');
  });
}
