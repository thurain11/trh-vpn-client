import 'dart:io';

enum RuntimeHealthState { healthy, degraded, broken }

class RuntimeHealthReport {
  const RuntimeHealthReport({
    required this.state,
    required this.checkedAt,
    required this.dnsOk,
    required this.connectOk,
    required this.latencyMs,
    required this.summary,
    required this.details,
  });

  final RuntimeHealthState state;
  final DateTime checkedAt;
  final bool dnsOk;
  final bool connectOk;
  final int? latencyMs;
  final String summary;
  final String details;
}

class RuntimeHealthChecker {
  const RuntimeHealthChecker();

  Future<RuntimeHealthReport> check({
    required String latencyHost,
    required int latencyPort,
    String dnsHost = 'www.google.com',
    Uri? connectUrl,
  }) async {
    final checkedAt = DateTime.now();
    final effectiveConnectUrl = connectUrl ??
        Uri(
          scheme: 'https',
          host: 'www.gstatic.com',
          path: '/generate_204',
        );

    final dnsResult = await _checkDns(dnsHost);
    final connectResult = await _checkConnect(effectiveConnectUrl);
    final latency = await _measureLatency(
      host: latencyHost,
      port: latencyPort,
    );

    final successes = <bool>[
      dnsResult.ok,
      connectResult.ok,
      latency != null,
    ].where((ok) => ok).length;

    final state = switch (successes) {
      3 => RuntimeHealthState.healthy,
      2 => RuntimeHealthState.degraded,
      _ => RuntimeHealthState.broken,
    };

    final summary = switch (state) {
      RuntimeHealthState.healthy => 'Healthy',
      RuntimeHealthState.degraded => 'Degraded',
      RuntimeHealthState.broken => 'Broken',
    };

    final details = [
      'dns=${dnsResult.ok ? 'ok' : 'fail'}${dnsResult.message == null ? '' : ' (${dnsResult.message})'}',
      'connect=${connectResult.ok ? 'ok' : 'fail'}${connectResult.message == null ? '' : ' (${connectResult.message})'}',
      'latency=${latency == null ? 'n/a' : '${latency}ms'}',
    ].join(' • ');

    return RuntimeHealthReport(
      state: state,
      checkedAt: checkedAt,
      dnsOk: dnsResult.ok,
      connectOk: connectResult.ok,
      latencyMs: latency,
      summary: summary,
      details: details,
    );
  }

  Future<_CheckResult> _checkDns(String host) async {
    try {
      final result = await InternetAddress.lookup(host).timeout(
        const Duration(seconds: 5),
      );
      if (result.isEmpty) {
        return const _CheckResult(ok: false, message: 'empty result');
      }
      return const _CheckResult(ok: true);
    } catch (error) {
      return _CheckResult(ok: false, message: '$error');
    }
  }

  Future<_CheckResult> _checkConnect(Uri url) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(url).timeout(
        const Duration(seconds: 8),
      );
      request.followRedirects = true;
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final ok = response.statusCode >= 200 && response.statusCode < 400;
      return _CheckResult(
        ok: ok,
        message: ok ? null : 'HTTP ${response.statusCode}',
      );
    } catch (error) {
      return _CheckResult(ok: false, message: '$error');
    } finally {
      client?.close(force: true);
    }
  }

  Future<int?> _measureLatency({
    required String host,
    required int port,
  }) async {
    if (host.isEmpty || port <= 0) {
      return null;
    }
    final stopwatch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return null;
    } finally {
      stopwatch.stop();
      socket?.destroy();
    }
  }
}

class _CheckResult {
  const _CheckResult({required this.ok, this.message});

  final bool ok;
  final String? message;
}
