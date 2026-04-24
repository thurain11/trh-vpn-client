import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/entities/tunnel_runtime_config.dart';
import '../domain/entities/traffic_stats.dart';
import '../domain/entities/vpn_profile.dart';

abstract class VpnBridge {
  Future<void> startTunnel(
      VpnProfile profile, TunnelRuntimeConfig runtimeConfig);
  Future<void> stopTunnel();
  Future<void> openLogFile(String path);
  Future<void> shareLogFile(String path);
  Future<String?> consumePendingImportUri();
  Stream<Map<String, dynamic>> watchStatusEvents();
  Stream<TrafficStats> watchTrafficStats();
}

class MethodChannelVpnBridge implements VpnBridge {
  MethodChannelVpnBridge() {
    _listenNativeEvents();
  }

  static const MethodChannel _methodChannel = MethodChannel(
    AppConstants.methodChannelName,
  );
  static const EventChannel _eventChannel = EventChannel(
    AppConstants.eventChannelName,
  );
  static final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>>? _sharedStatusEvents;
  static V2ray? _v2ray;
  static bool _initialized = false;
  static bool _nativeEventListening = false;

  @override
  Future<void> startTunnel(
      VpnProfile profile, TunnelRuntimeConfig runtimeConfig) async {
    await _ensureInitialized();
    _eventsController.add({
      'status': 'connecting',
      'profileName': profile.name,
      'severity': 'info',
      'message': 'Starting VPN runtime',
    });

    final granted = await _v2ray!.requestPermission();
    if (!granted) {
      _eventsController.add({
        'status': 'error',
        'profileName': profile.name,
        'severity': 'error',
        'message': 'VPN permission was denied.',
      });
      throw PlatformException(
        code: 'vpn_permission_denied',
        message: 'VPN permission was denied.',
      );
    }

    if (runtimeConfig.splitTunnelNote != null &&
        runtimeConfig.splitTunnelNote!.isNotEmpty) {
      _eventsController.add({
        'status': 'connecting',
        'profileName': profile.name,
        'severity': 'warn',
        'message': runtimeConfig.splitTunnelNote,
      });
    }

    final config = _resolveConfig(profile, runtimeConfig);
    final blockedApps = runtimeConfig.blockedApps
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final bypassSubnets = runtimeConfig.bypassSubnets
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    await _v2ray!.startV2Ray(
      remark: profile.name,
      config: config,
      blockedApps: blockedApps.isEmpty ? null : blockedApps,
      bypassSubnets: bypassSubnets.isEmpty ? null : bypassSubnets,
      proxyOnly: false,
    );
  }

  @override
  Future<void> stopTunnel() async {
    await _ensureInitialized();
    _eventsController.add({
      'status': 'disconnecting',
      'severity': 'warn',
      'message': 'Stopping VPN service',
    });
    await _v2ray!.stopV2Ray();
    _eventsController.add({
      'status': 'disconnected',
      'severity': 'info',
      'message': 'VPN service stopped',
    });
  }

  @override
  Future<void> openLogFile(String path) {
    return _methodChannel.invokeMethod<void>('openLogFile', {'path': path});
  }

  @override
  Future<void> shareLogFile(String path) {
    return _methodChannel.invokeMethod<void>('shareLogFile', {'path': path});
  }

  @override
  Future<String?> consumePendingImportUri() {
    return _methodChannel.invokeMethod<String>('consumePendingImportUri');
  }

  @override
  Stream<Map<String, dynamic>> watchStatusEvents() {
    _sharedStatusEvents ??= _eventsController.stream.asBroadcastStream();
    return _sharedStatusEvents!;
  }

  @override
  Stream<TrafficStats> watchTrafficStats() async* {
    var sessionActive = false;
    var baselineDownload = 0;
    var baselineUpload = 0;

    await for (final event in watchStatusEvents()) {
      final status = event['status'] as String?;

      if (status == 'disconnecting' ||
          status == 'disconnected' ||
          status == 'error') {
        sessionActive = false;
        baselineDownload = 0;
        baselineUpload = 0;
        yield TrafficStats.empty();
        continue;
      }

      final totalDownload = _toInt(event['downloadBytes']);
      final totalUpload = _toInt(event['uploadBytes']);
      if (totalDownload == null || totalUpload == null) {
        continue;
      }

      if (!sessionActive && (status == 'connecting' || status == 'connected')) {
        sessionActive = true;
        baselineDownload = totalDownload;
        baselineUpload = totalUpload;
      }

      if (!sessionActive) {
        continue;
      }

      // Runtime counters can restart; keep session deltas monotonic.
      if (totalDownload < baselineDownload || totalUpload < baselineUpload) {
        baselineDownload = totalDownload;
        baselineUpload = totalUpload;
      }

      yield TrafficStats(
        downloadBytes: totalDownload - baselineDownload,
        uploadBytes: totalUpload - baselineUpload,
        downloadSpeedBytesPerSecond:
            _toInt(event['downloadSpeedBytesPerSecond']) ?? 0,
        uploadSpeedBytesPerSecond:
            _toInt(event['uploadSpeedBytesPerSecond']) ?? 0,
        totalDownloadBytes: totalDownload,
        totalUploadBytes: totalUpload,
        sessionDuration: _parseDuration(event['duration']),
      );
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _v2ray = V2ray(onStatusChanged: (status) {
      final mappedStatus = _mapState(status.state);
      _eventsController.add({
        'status': mappedStatus,
        'downloadBytes': status.download,
        'uploadBytes': status.upload,
        'downloadSpeedBytesPerSecond': status.downloadSpeed,
        'uploadSpeedBytesPerSecond': status.uploadSpeed,
        'duration': status.duration,
        'severity': mappedStatus == 'error' ? 'error' : 'info',
        'message':
            'state=${status.state} • up=${status.uploadSpeed}B/s • down=${status.downloadSpeed}B/s • duration=${status.duration}',
      });
    });
    await _v2ray!.initialize();
    _initialized = true;
  }

  void _listenNativeEvents() {
    if (_nativeEventListening) {
      return;
    }
    _nativeEventListening = true;
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is! Map) {
        return;
      }
      final payload = Map<String, dynamic>.from(event);
      if (payload['action'] == 'import_uri') {
        _eventsController.add(payload);
      }
    });
  }

  String _resolveConfig(VpnProfile profile, TunnelRuntimeConfig runtimeConfig) {
    final raw = profile.rawConfig.trim();
    final hasSplitRouting = _hasSplitRouting(runtimeConfig.engineConfig);

    if (raw.contains('://') && !hasSplitRouting) {
      return V2ray.parseFromURL(raw).getFullConfiguration();
    }

    if (_looksLikeJson(raw) && !hasSplitRouting) {
      return raw;
    }

    if (runtimeConfig.engineConfig.isNotEmpty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(runtimeConfig.engineConfig);
    }

    if (raw.contains('://')) {
      return V2ray.parseFromURL(raw).getFullConfiguration();
    }
    if (_looksLikeJson(raw)) {
      return raw;
    }
    return runtimeConfig.toPrettyJson();
  }

  bool _hasSplitRouting(Map<String, dynamic> engineConfig) {
    final routing = engineConfig['routing'];
    if (routing is! Map) {
      return false;
    }
    final rules = routing['rules'];
    if (rules is! List) {
      return false;
    }
    return rules.length > 1;
  }

  bool _looksLikeJson(String value) {
    final normalized = value.trim();
    return normalized.startsWith('{') && normalized.endsWith('}');
  }

  String _mapState(String state) {
    final value = state.toUpperCase();
    if (value.contains('DISCONNECT')) {
      return 'disconnected';
    }
    if (value.contains('CONNECTING')) {
      return 'connecting';
    }
    if (value.contains('CONNECTED')) {
      return 'connected';
    }
    if (value.contains('ERROR')) {
      return 'error';
    }
    return 'disconnected';
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  Duration _parseDuration(dynamic value) {
    if (value is Duration) {
      return value;
    }
    if (value is String) {
      final parts = value.split(':');
      if (parts.length == 3) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final second = int.tryParse(parts[2]) ?? 0;
        return Duration(hours: hour, minutes: minute, seconds: second);
      }
    }
    return Duration.zero;
  }
}
