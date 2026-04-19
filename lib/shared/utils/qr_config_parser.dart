import 'dart:convert';

class QrConfigParser {
  const QrConfigParser();

  String normalize(String raw) {
    var value = raw.replaceAll('\u0000', '').trim();
    if (value.isEmpty) {
      return '';
    }

    value = _stripWrapperQuotes(value);
    final candidates = <String>{};

    void addCandidate(String input) {
      final trimmed = _stripWrapperQuotes(input.trim());
      if (trimmed.isEmpty) {
        return;
      }
      candidates.add(trimmed);
      final decoded = Uri.decodeFull(trimmed);
      if (decoded != trimmed && decoded.isNotEmpty) {
        candidates.add(_stripWrapperQuotes(decoded.trim()));
      }
    }

    addCandidate(value);

    final lines = value
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    for (final line in lines) {
      addCandidate(line);
    }

    final tokens = value
        .split(RegExp(r'[\s,;]+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty);
    for (final token in tokens) {
      addCandidate(token);
    }

    for (final candidate in candidates) {
      final resolved = _resolveCandidate(candidate);
      if (_isSupportedOrSubscriptionScheme(resolved)) {
        return resolved;
      }
    }

    // Last chance: keep best-effort normalized text for error/debug visibility.
    final fallback = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return fallback;
  }

  String _resolveCandidate(String input) {
    var value = input.trim();
    if (value.isEmpty) {
      return value;
    }

    final extractedFromJson = _extractFromJsonPayload(value);
    if (extractedFromJson != null && extractedFromJson.isNotEmpty) {
      value = extractedFromJson;
    }

    final lower = value.toLowerCase();
    if (lower.startsWith('clash://install-config')) {
      final uri = Uri.tryParse(value);
      final url = uri?.queryParameters['url'];
      if (url != null && url.trim().isNotEmpty) {
        value = Uri.decodeComponent(url.trim());
      }
    }

    if (lower.startsWith('hiddify://import/')) {
      final payload = value.substring('hiddify://import/'.length);
      final decoded = Uri.decodeComponent(payload);
      if (decoded.trim().isNotEmpty) {
        value = decoded.trim();
      }
    }

    final refreshedLower = value.toLowerCase();
    if (refreshedLower.startsWith('https://') ||
        refreshedLower.startsWith('http://')) {
      final extractedFromUrl = _extractEmbeddedUriFromHttpUrl(value);
      if (extractedFromUrl != null && extractedFromUrl.isNotEmpty) {
        value = extractedFromUrl;
      }
    }

    if (refreshedLower.startsWith('v2ray://') ||
        refreshedLower.startsWith('v2rayn://')) {
      final payload = value.substring(value.indexOf('://') + 3);
      final decoded = _decodeBase64ToString(payload);
      if (decoded != null && decoded.trim().isNotEmpty) {
        value = decoded.trim();
      }
    }

    if (!value.contains('://')) {
      final decoded = _decodeBase64ToString(value);
      if (decoded != null && decoded.trim().isNotEmpty) {
        final decodedTrimmed = decoded.trim();
        final decodedJsonExtract = _extractFromJsonPayload(decodedTrimmed);
        if (decodedJsonExtract != null && decodedJsonExtract.isNotEmpty) {
          value = decodedJsonExtract;
        } else {
          value = decodedTrimmed;
        }
      }
    }

    return _stripWrapperQuotes(value.trim());
  }

  String _stripWrapperQuotes(String input) {
    if (input.length >= 2 &&
        ((input.startsWith('"') && input.endsWith('"')) ||
            (input.startsWith("'") && input.endsWith("'")))) {
      return input.substring(1, input.length - 1).trim();
    }
    return input;
  }

  bool _isSupportedOrSubscriptionScheme(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('vless://') ||
        lower.startsWith('vmess://') ||
        lower.startsWith('trojan://') ||
        lower.startsWith('ss://') ||
        lower.startsWith('https://') ||
        lower.startsWith('http://');
  }

  String? _extractEmbeddedUriFromHttpUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return null;
    }

    for (final entry in uri.queryParameters.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) {
        continue;
      }
      final decoded = Uri.decodeComponent(value).trim();
      final lower = decoded.toLowerCase();
      if (lower.startsWith('vless://') ||
          lower.startsWith('vmess://') ||
          lower.startsWith('trojan://') ||
          lower.startsWith('ss://')) {
        return decoded;
      }
    }
    return null;
  }

  String? _extractFromJsonPayload(String source) {
    try {
      final json = jsonDecode(source);
      if (json is Map<String, dynamic>) {
        for (final key in const ['uri', 'url', 'link']) {
          final value = json[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }

        if (json['add'] != null && json['port'] != null && json['id'] != null) {
          return 'vmess://${jsonEncode(json)}';
        }

        final vmess = json['vmess'];
        if (vmess is String && vmess.trim().isNotEmpty) {
          return vmess.trim();
        }

        final links = json['links'];
        if (links is List) {
          for (final item in links) {
            if (item is String && item.trim().isNotEmpty) {
              return item.trim();
            }
          }
        }
      }
    } catch (_) {
      // Not JSON payload.
    }
    return null;
  }

  String? _decodeBase64ToString(String value) {
    try {
      final normalized = base64.normalize(value);
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      try {
        final normalized = base64.normalize(value);
        return utf8.decode(base64Url.decode(normalized));
      } catch (_) {
        return null;
      }
    }
  }
}
