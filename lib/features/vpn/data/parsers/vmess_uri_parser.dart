import 'dart:convert';

import '../../../../core/result/result.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/services/vpn_profile_importer.dart';
import 'profile_parser_helpers.dart';

class VmessUriParser implements VpnProfileImporter {
  const VmessUriParser();

  @override
  bool canParse(String raw) =>
      raw.trimLeft().toLowerCase().startsWith('vmess://');

  @override
  Result<VpnProfile> parse(String raw) {
    final trimmed = raw.trim();
    if (!canParse(trimmed)) {
      return const FailureResult('Unsupported VMess URI.');
    }

    final encoded = trimmed.substring('vmess://'.length).trim();
    try {
      final decodedJson = encoded.startsWith('{')
          ? encoded
          : ProfileParserHelpers.decodeBase64UrlSafe(encoded);
      final payload = jsonDecode(decodedJson) as Map<String, dynamic>;
      final host = payload['add'] as String?;
      final port = int.tryParse(payload['port']?.toString() ?? '');
      final userId = payload['id'] as String?;
      if (host == null ||
          host.isEmpty ||
          port == null ||
          userId == null ||
          userId.isEmpty) {
        return const FailureResult(
            'Invalid VMess URI. Host, port, and id are required.');
      }

      final remark = payload['ps'] as String?;
      final idSeed = [
        userId,
        host,
        port.toString(),
        payload['net']?.toString() ?? '',
        payload['path']?.toString() ?? '',
        payload['host']?.toString() ?? '',
      ].join('|');
      return Success(
        VpnProfile(
          id: ProfileParserHelpers.profileId('vmess', idSeed),
          name: remark ?? '$host:$port',
          endpoint: VpnServerEndpoint(
            host: host,
            port: port,
            sni: payload['sni'] as String?,
            alpn: _splitCsv(payload['alpn'] as String?),
          ),
          protocol: VpnProtocol.vmess,
          rawConfig: trimmed,
          source: VpnProfileSource(
            type: VpnProfileSourceType.uri,
            originalValue: trimmed,
          ),
          credentials: VpnCredentials(userId: userId),
          transport: VpnTransportSettings(
            type:
                ProfileParserHelpers.parseTransport(payload['net'] as String?),
            host: payload['host'] as String?,
            path: payload['path'] as String?,
            security: payload['tls'] as String?,
            serviceName: payload['serviceName'] as String?,
          ),
          remarks: remark,
        ),
      );
    } catch (_) {
      return const FailureResult(
          'Invalid VMess URI. Could not decode the payload.');
    }
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
