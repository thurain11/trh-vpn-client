import '../../../../core/result/result.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/services/vpn_profile_importer.dart';
import 'profile_parser_helpers.dart';

class TrojanUriParser implements VpnProfileImporter {
  const TrojanUriParser();

  @override
  bool canParse(String raw) =>
      raw.trimLeft().toLowerCase().startsWith('trojan://');

  @override
  Result<VpnProfile> parse(String raw) {
    if (!canParse(raw)) {
      return const FailureResult('Unsupported Trojan URI.');
    }

    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.port == 0 ||
        uri.userInfo.isEmpty) {
      return const FailureResult(
        'Invalid Trojan URI. Host, port, and password are required.',
      );
    }

    final remark =
        uri.fragment.isEmpty ? null : Uri.decodeComponent(uri.fragment);
    return Success(
      VpnProfile(
        id: ProfileParserHelpers.profileId('trojan', '${uri.host}-${uri.port}'),
        name: remark ?? '${uri.host}:${uri.port}',
        endpoint: VpnServerEndpoint(
          host: uri.host,
          port: uri.port,
          sni: uri.queryParameters['sni'],
          alpn: _splitCsv(uri.queryParameters['alpn']),
        ),
        protocol: VpnProtocol.trojan,
        rawConfig: raw.trim(),
        source: VpnProfileSource(
          type: VpnProfileSourceType.uri,
          originalValue: raw.trim(),
        ),
        credentials: VpnCredentials(password: uri.userInfo),
        transport: VpnTransportSettings(
          type:
              ProfileParserHelpers.parseTransport(uri.queryParameters['type']),
          host: uri.queryParameters['host'],
          path: uri.queryParameters['path'],
          security: uri.queryParameters['security'] ?? 'tls',
          serviceName: uri.queryParameters['serviceName'],
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
