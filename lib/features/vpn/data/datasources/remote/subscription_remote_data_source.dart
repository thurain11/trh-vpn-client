import 'dart:async';

import 'package:http/http.dart' as http;

abstract class SubscriptionRemoteDataSource {
  Future<String> fetchSubscription(String url);
}

class HttpSubscriptionRemoteDataSource implements SubscriptionRemoteDataSource {
  HttpSubscriptionRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> fetchSubscription(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw ArgumentError('Invalid subscription URL.');
    }

    Future<http.Response> fetchWithTimeout(Duration timeout) {
      return _client.get(
        uri,
        headers: const {
          'User-Agent': 'Lunex/0.1',
          'Accept': 'text/plain,application/json,*/*',
        },
      ).timeout(
        timeout,
        onTimeout: () =>
            throw TimeoutException('Subscription request timed out.'),
      );
    }

    http.Response response;
    try {
      response = await fetchWithTimeout(const Duration(seconds: 12));
    } on TimeoutException {
      response = await fetchWithTimeout(const Duration(seconds: 25));
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Failed to fetch subscription (HTTP ${response.statusCode}).',
      );
    }
    return response.body;
  }
}
