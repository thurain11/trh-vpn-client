import '../../../../core/result/result.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/services/vpn_profile_importer.dart';
import 'profile_parser_helpers.dart';

class VlessUriParser implements VpnProfileImporter {
  const VlessUriParser();

  @override
  bool canParse(String raw) =>
      raw.trimLeft().toLowerCase().startsWith('vless://');

  @override
  Result<VpnProfile> parse(String raw) {
    if (!canParse(raw)) {
      return const FailureResult('Unsupported VLESS URI.');
    }

    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.port == 0 ||
        uri.userInfo.isEmpty) {
      return const FailureResult(
          'Invalid VLESS URI. Host, port, and uuid are required.');
    }

    final remark =
        uri.fragment.isEmpty ? null : Uri.decodeComponent(uri.fragment);
    final security = uri.queryParameters['security'];
    final type = uri.queryParameters['type'];
    final idSeed = [
      uri.userInfo,
      uri.host,
      uri.port.toString(),
      uri.queryParameters['sid'] ?? '',
      uri.queryParameters['pbk'] ?? '',
      uri.queryParameters['flow'] ?? '',
    ].join('|');

    return Success(
      VpnProfile(
        id: ProfileParserHelpers.profileId('vless', idSeed),
        name: remark ?? '${uri.host}:${uri.port}',
        endpoint: VpnServerEndpoint(
          host: uri.host,
          port: uri.port,
          sni: uri.queryParameters['sni'],
          alpn: _splitCsv(uri.queryParameters['alpn']),
        ),
        protocol: VpnProtocol.vless,
        rawConfig: raw.trim(),
        source: VpnProfileSource(
          type: VpnProfileSourceType.uri,
          originalValue: raw.trim(),
        ),
        credentials: VpnCredentials(
          userId: uri.userInfo,
          flow: uri.queryParameters['flow'],
        ),
        transport: VpnTransportSettings(
          type: ProfileParserHelpers.parseTransport(type),
          host: uri.queryParameters['host'],
          path: uri.queryParameters['path'],
          security: security,
          serviceName: uri.queryParameters['serviceName'],
          fingerprint: uri.queryParameters['fp'],
          publicKey: uri.queryParameters['pbk'],
          shortId: uri.queryParameters['sid'],
          spiderX: uri.queryParameters['spx'],
        ),
        remarks: remark,
      ),
    );
  }
}

List<String> _splitCsv(String? value) {
  if (value == null || value.isEmpty) {
    return const [];
  }
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
