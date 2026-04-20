import 'dart:convert';

class QrConfigParser {
  const QrConfigParser();

  String normalize(String raw) {
    final candidates = _candidateInputs(raw);
    if (candidates.isEmpty) {
      return '';
    }

    final resolved = <String>[];
    for (final candidate in candidates) {
      final value = _resolveCandidate(candidate);
      if (value.isNotEmpty) {
        resolved.add(value);
      }
    }

    // Prefer direct VPN profile URI over subscription URL.
    for (final value in resolved) {
      if (_isDirectProfileScheme(value)) {
        return value;
      }
    }

    for (final value in resolved) {
      if (_isHttpLikeScheme(value)) {
        return value;
      }
    }

    final fallback =
        _stripWrapperQuotes(raw.replaceAll(RegExp(r'\s+'), ' ').trim());
    return fallback;
  }

  String? extractDirectProfileUri(String raw) {
    final candidates = _candidateInputs(raw);
    for (final candidate in candidates) {
      final value = _resolveCandidate(candidate);
      if (_isDirectProfileScheme(value)) {
        return value;
      }
    }
    return null;
  }

  List<String> _candidateInputs(String raw) {
    var value = raw.replaceAll('\u0000', '').trim();
    if (value.isEmpty) {
      return const [];
    }

    value = _stripWrapperQuotes(value);
    final candidates = <String>{};

    void addCandidate(String input) {
      final trimmed = _stripWrapperQuotes(input.trim());
      if (trimmed.isEmpty) {
        return;
      }
      candidates.add(trimmed);
      final decoded = _decodeUriBestEffort(trimmed);
      if (decoded != null && decoded.isNotEmpty && decoded != trimmed) {
        candidates.add(_stripWrapperQuotes(decoded.trim()));
      }

      final embedded = _extractShareLinkFromText(trimmed);
      if (embedded != null && embedded.isNotEmpty) {
        candidates.add(embedded);
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

    return candidates.toList(growable: false);
  }

  String _resolveCandidate(String input) {
    var value = _stripWrapperQuotes(input.trim());
    if (value.isEmpty) {
      return '';
    }

    final embeddedFirst = _extractShareLinkFromText(value);
    if (embeddedFirst != null) {
      value = embeddedFirst;
    }

    // Early return: valid VPN profile URIs must not go through further
    // transformations (JSON extraction, base64 decoding, etc.) that can
    // corrupt URI payloads – especially vmess:// with base64 encoded data.
    if (_isDirectProfileScheme(value)) {
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

    var refreshedLower = value.toLowerCase();
    if (refreshedLower.startsWith('http://') ||
        refreshedLower.startsWith('https://')) {
      final extractedFromUrl = _extractEmbeddedUriFromHttpUrl(value);
      if (extractedFromUrl != null && extractedFromUrl.isNotEmpty) {
        value = extractedFromUrl;
      }
    }

    refreshedLower = value.toLowerCase();
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
        value = decodedJsonExtract ?? decodedTrimmed;
      }
    }

    final embeddedLast = _extractShareLinkFromText(value);
    if (embeddedLast != null) {
      value = embeddedLast;
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

  bool _isDirectProfileScheme(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('vless://') ||
        lower.startsWith('vmess://') ||
        lower.startsWith('trojan://') ||
        lower.startsWith('ss://');
  }

  bool _isHttpLikeScheme(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  String? _extractShareLinkFromText(String text) {
    final match = RegExp(
      r'(vless|vmess|trojan|ss)://\S+',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return null;
    }
    final rawMatch = match.group(0);
    if (rawMatch == null || rawMatch.trim().isEmpty) {
      return null;
    }
    var result = rawMatch.trim();
    result = result.replaceFirst(RegExp(r'[),;]+$'), '');
    while (result.endsWith('"') || result.endsWith('\'')) {
      result = result.substring(0, result.length - 1).trimRight();
    }
    return result.isEmpty ? null : result;
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
      if (_isDirectProfileScheme(decoded)) {
        return decoded;
      }

      final embedded = _extractShareLinkFromText(decoded);
      if (embedded != null && embedded.isNotEmpty) {
        return embedded;
      }

      final decodedBase64 = _decodeBase64ToString(decoded);
      if (decodedBase64 != null) {
        final decodedTrimmed = decodedBase64.trim();
        if (_isDirectProfileScheme(decodedTrimmed)) {
          return decodedTrimmed;
        }
        final embeddedFromBase64 = _extractShareLinkFromText(decodedTrimmed);
        if (embeddedFromBase64 != null && embeddedFromBase64.isNotEmpty) {
          return embeddedFromBase64;
        }
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

  String? _decodeUriBestEffort(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return null;
    }
  }
}
