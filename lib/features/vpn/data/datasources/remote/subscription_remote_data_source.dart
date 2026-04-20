import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

abstract class SubscriptionRemoteDataSource {
  Future<String> fetchSubscription(String url);
}

class HttpSubscriptionRemoteDataSource implements SubscriptionRemoteDataSource {
  HttpSubscriptionRemoteDataSource({http.Client? client})
      : _client = client ?? _createDefaultClient();

  final http.Client _client;

  /// Creates an HTTP client tuned for VPN subscription fetching:
  /// - 10 s connection timeout (avoids long OS-level TCP waits)
  /// - Accepts self-signed / IP-based certificates common on VPN panels
  static http.Client _createDefaultClient() {
    final inner = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (_, __, ___) => true;
    return IOClient(inner);
  }

  @override
  Future<String> fetchSubscription(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw ArgumentError('Invalid subscription URL.');
    }

    http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const {
          // Many V2Ray subscription servers reject unknown user-agents.
          'User-Agent': 'v2rayNG/1.8.19',
          'Accept': 'text/plain,application/json,*/*',
          'Accept-Encoding': 'gzip, deflate',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'Subscription request timed out after 15s for $url',
        ),
      );
    } on SocketException catch (e) {
      // Surface a user-friendly message instead of the raw OS error.
      throw StateError(
        'Cannot reach subscription server.\n'
        'Check your internet connection or try importing a direct profile URI instead.\n'
        'Detail: ${e.message}',
      );
    }

    // Follow one redirect if the HTTP client didn't handle it.
    if (response.statusCode >= 300 && response.statusCode < 400) {
      final location = response.headers['location'];
      if (location != null && location.isNotEmpty) {
        final redirectUri = Uri.tryParse(location);
        if (redirectUri != null) {
          response = await _client.get(
            redirectUri,
            headers: const {
              'User-Agent': 'v2rayNG/1.8.19',
              'Accept': 'text/plain,application/json,*/*',
            },
          ).timeout(const Duration(seconds: 15));
        }
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Failed to fetch subscription (HTTP ${response.statusCode}).',
      );
    }
    return response.body;
  }
}
