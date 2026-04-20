import 'dart:convert';

import '../../../../core/result/result.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/services/vpn_profile_importer.dart';
import 'profile_parser_helpers.dart';

class ShadowsocksUriParser implements VpnProfileImporter {
  const ShadowsocksUriParser();

  @override
  bool canParse(String raw) => raw.trimLeft().toLowerCase().startsWith('ss://');

  @override
  Result<VpnProfile> parse(String raw) {
    final trimmed = raw.trim();
    if (!canParse(trimmed)) {
      return const FailureResult('Unsupported Shadowsocks URI.');
    }

    final body = trimmed.substring('ss://'.length);
    final parts = body.split('#');
    final content = parts.first;
    final remark = parts.length > 1 ? Uri.decodeComponent(parts[1]) : null;

    final contentWithoutQuery = content.split('?').first;
    final decoded = _decodeUserInfo(contentWithoutQuery);
    if (decoded == null) {
      return const FailureResult(
        'Invalid Shadowsocks URI. Expected method, password, host, and port.',
      );
    }

    final methodPassword = decoded.$1.split(':');
    if (methodPassword.length < 2 || decoded.$2.isEmpty || decoded.$3 == 0) {
      return const FailureResult(
        'Invalid Shadowsocks URI. Expected method, password, host, and port.',
      );
    }
    final idSeed = [
      methodPassword.first,
      methodPassword.sublist(1).join(':'),
      decoded.$2,
      decoded.$3.toString(),
    ].join('|');

    return Success(
      VpnProfile(
        id: ProfileParserHelpers.profileId('ss', idSeed),
        name: remark ?? '${decoded.$2}:${decoded.$3}',
        endpoint: VpnServerEndpoint(host: decoded.$2, port: decoded.$3),
        protocol: VpnProtocol.shadowsocks,
        rawConfig: trimmed,
        source: VpnProfileSource(
          type: VpnProfileSourceType.uri,
          originalValue: trimmed,
        ),
        credentials: VpnCredentials(
          method: methodPassword.first,
          password: methodPassword.sublist(1).join(':'),
        ),
        remarks: remark,
      ),
    );
  }

  (String, String, int)? _decodeUserInfo(String content) {
    if (content.contains('@')) {
      final parsed = Uri.tryParse('ss://$content');
      if (parsed == null ||
          parsed.userInfo.isEmpty ||
          parsed.host.isEmpty ||
          parsed.port == 0) {
        return null;
      }
      final credentials =
          utf8.decode(base64.decode(base64.normalize(parsed.userInfo)));
      return (credentials, parsed.host, parsed.port);
    }

    final decoded = ProfileParserHelpers.decodeBase64UrlSafe(content);
    final parsed = Uri.tryParse('ss://$decoded');
    if (parsed == null ||
        parsed.userInfo.isEmpty ||
        parsed.host.isEmpty ||
        parsed.port == 0) {
      return null;
    }
    return (parsed.userInfo, parsed.host, parsed.port);
  }
}
