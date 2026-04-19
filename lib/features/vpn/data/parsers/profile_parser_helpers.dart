import 'dart:convert';

import '../../domain/entities/vpn_profile.dart';

class ProfileParserHelpers {
  static String profileId(String prefix, String seed) {
    final normalized = seed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return '$prefix-${normalized.isEmpty ? 'profile' : normalized}';
  }

  static String decodeBase64UrlSafe(String value) {
    final normalized = base64.normalize(value.replaceAll('-', '+').replaceAll('_', '/'));
    return utf8.decode(base64.decode(normalized));
  }

  static VpnTransportType parseTransport(String? type) {
    switch (type?.toLowerCase()) {
      case 'ws':
        return VpnTransportType.ws;
      case 'grpc':
        return VpnTransportType.grpc;
      case 'http':
      case 'h2':
        return VpnTransportType.http;
      case 'quic':
        return VpnTransportType.quic;
      case 'tcp':
      case null:
      case '':
        return VpnTransportType.tcp;
      default:
        return VpnTransportType.unknown;
    }
  }
}
