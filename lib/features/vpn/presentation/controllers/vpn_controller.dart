import 'dart:async' show StreamSubscription, unawaited;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../../core/error/user_friendly_error.dart';
import '../../../../core/result/result.dart';
import '../../../../shared/utils/qr_config_parser.dart';
import '../../../subscription/application/usecases/sync_subscription.dart';
import '../../application/services/runtime_health_checker.dart';
import '../../domain/entities/tunnel_runtime_config.dart';
import '../../domain/entities/vpn_log_entry.dart';
import '../../domain/entities/traffic_stats.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/entities/vpn_status.dart';

class VpnState {
  static const _sentinel = Object();

  const VpnState({
    this.status = VpnStatus.disconnected,
    this.profiles = const [],
    this.selectedProfile,
    this.trafficStats = const TrafficStats(downloadBytes: 0, uploadBytes: 0),
    this.isBusy = false,
    this.importInput = '',
    this.subscriptionInput = '',
    this.lastSubscriptionSyncAt,
    this.healthSummary,
    this.healthDetails,
    this.lastHealthCheckAt,
    this.isHealthChecking = false,
    this.logs = const [],
    this.logFilter = VpnLogFilter.all,
    this.logFilePath,
    this.runtimeConfigPreview,
    this.errorMessage,
  });

  final VpnStatus status;
  final List<VpnProfile> profiles;
  final VpnProfile? selectedProfile;
  final TrafficStats trafficStats;
  final bool isBusy;
  final String importInput;
  final String subscriptionInput;
  final DateTime? lastSubscriptionSyncAt;
  final String? healthSummary;
  final String? healthDetails;
  final DateTime? lastHealthCheckAt;
  final bool isHealthChecking;
  final List<VpnLogEntry> logs;
  final VpnLogFilter logFilter;
  final String? logFilePath;
  final String? runtimeConfigPreview;
  final String? errorMessage;

  List<VpnLogEntry> get visibleLogs {
    switch (logFilter) {
      case VpnLogFilter.all:
        return logs;
      case VpnLogFilter.info:
        return logs
            .where((log) => log.severity == VpnLogSeverity.info)
            .toList();
      case VpnLogFilter.warn:
        return logs
            .where((log) => log.severity == VpnLogSeverity.warn)
            .toList();
      case VpnLogFilter.error:
        return logs
            .where((log) => log.severity == VpnLogSeverity.error)
            .toList();
    }
  }

  VpnState copyWith({
    VpnStatus? status,
    List<VpnProfile>? profiles,
    Object? selectedProfile = _sentinel,
    TrafficStats? trafficStats,
    bool? isBusy,
    String? importInput,
    String? subscriptionInput,
    Object? lastSubscriptionSyncAt = _sentinel,
    Object? healthSummary = _sentinel,
    Object? healthDetails = _sentinel,
    Object? lastHealthCheckAt = _sentinel,
    bool? isHealthChecking,
    List<VpnLogEntry>? logs,
    VpnLogFilter? logFilter,
    Object? logFilePath = _sentinel,
    Object? runtimeConfigPreview = _sentinel,
    String? errorMessage,
    bool clearError = false,
  }) {
    final nextError = clearError ? null : (errorMessage ?? this.errorMessage);
    return VpnState(
      status: status ?? this.status,
      profiles: profiles ?? this.profiles,
      selectedProfile: selectedProfile == _sentinel
          ? this.selectedProfile
          : selectedProfile as VpnProfile?,
      trafficStats: trafficStats ?? this.trafficStats,
      isBusy: isBusy ?? this.isBusy,
      importInput: importInput ?? this.importInput,
      subscriptionInput: subscriptionInput ?? this.subscriptionInput,
      lastSubscriptionSyncAt: lastSubscriptionSyncAt == _sentinel
          ? this.lastSubscriptionSyncAt
          : lastSubscriptionSyncAt as DateTime?,
      healthSummary: healthSummary == _sentinel
          ? this.healthSummary
          : healthSummary as String?,
      healthDetails: healthDetails == _sentinel
          ? this.healthDetails
          : healthDetails as String?,
      lastHealthCheckAt: lastHealthCheckAt == _sentinel
          ? this.lastHealthCheckAt
          : lastHealthCheckAt as DateTime?,
      isHealthChecking: isHealthChecking ?? this.isHealthChecking,
      logs: logs ?? this.logs,
      logFilter: logFilter ?? this.logFilter,
      logFilePath:
          logFilePath == _sentinel ? this.logFilePath : logFilePath as String?,
      runtimeConfigPreview: runtimeConfigPreview == _sentinel
          ? this.runtimeConfigPreview
          : runtimeConfigPreview as String?,
      errorMessage: nextError == null
          ? null
          : UserFriendlyErrorMapper.toMessage(nextError),
    );
  }
}

class VpnController extends StateNotifier<VpnState> {
  VpnController(this._ref) : super(const VpnState()) {
    _statusSubscription =
        _ref.read(observeVpnStatusProvider).call().listen(_handleStatus);
    _trafficSubscription = _ref
        .read(vpnRepositoryProvider)
        .watchTraffic()
        .listen((traffic) => state = state.copyWith(trafficStats: traffic));
    _eventSubscription = _ref
        .read(vpnBridgeProvider)
        .watchStatusEvents()
        .listen(_handleNativeEvent);
    unawaited(_consumePendingImportUri());
    unawaited(_loadSavedSubscription());
    loadProfiles();
  }

  final Ref _ref;
  StreamSubscription<VpnStatus>? _statusSubscription;
  StreamSubscription<TrafficStats>? _trafficSubscription;
  StreamSubscription<Map<String, dynamic>>? _eventSubscription;

  void _handleStatus(VpnStatus status) {
    final shouldResetStats =
        status == VpnStatus.connecting || status == VpnStatus.disconnected;
    state = state.copyWith(
      status: status,
      trafficStats:
          shouldResetStats ? TrafficStats.empty() : state.trafficStats,
    );
  }

  Future<void> loadProfiles() async {
    final result = await _ref.read(loadProfilesProvider).call();
    state = switch (result) {
      Success<List<VpnProfile>>(data: final profiles) => state.copyWith(
          profiles: profiles,
          selectedProfile: profiles.isEmpty ? null : profiles.first,
          runtimeConfigPreview: profiles.isEmpty
              ? null
              : _buildRuntimeConfigPreview(profiles.first),
        ),
      FailureResult<List<VpnProfile>>(message: final message) => state.copyWith(
          errorMessage: message,
        ),
    };
  }

  void selectProfile(VpnProfile? profile) {
    state = state.copyWith(
      selectedProfile: profile,
      runtimeConfigPreview:
          profile == null ? null : _buildRuntimeConfigPreview(profile),
    );
  }

  void setImportInput(String value) {
    state = state.copyWith(importInput: value);
  }

  void setSubscriptionInput(String value) {
    state = state.copyWith(subscriptionInput: value);
  }

  void clearErrorMessage() {
    if (state.errorMessage == null) {
      return;
    }
    state = state.copyWith(clearError: true);
  }

  Future<void> deleteProfile(VpnProfile profile) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _ref.read(deleteProfileProvider).call(profile.id);
      if (result is FailureResult<void>) {
        state = state.copyWith(errorMessage: result.message);
        return;
      }

      final remaining =
          state.profiles.where((item) => item.id != profile.id).toList();
      final nextSelected = state.selectedProfile?.id == profile.id
          ? (remaining.isEmpty ? null : remaining.first)
          : state.selectedProfile;
      state = state.copyWith(
        profiles: remaining,
        selectedProfile: nextSelected,
        runtimeConfigPreview: nextSelected == null
            ? null
            : _buildRuntimeConfigPreview(nextSelected),
      );
      _prependLog(
        title: 'PROFILE_DELETE',
        message: 'Deleted profile ${profile.name}.',
        severity: VpnLogSeverity.info,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: 'Delete failed: $error');
      _prependLog(
        title: 'PROFILE_DELETE',
        message: 'Delete failed: $error',
        severity: VpnLogSeverity.error,
      );
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  void clearLogs() {
    state = state.copyWith(logs: const []);
  }

  void setLogFilter(VpnLogFilter filter) {
    state = state.copyWith(logFilter: filter);
  }

  Future<void> openLogFile() async {
    final path = state.logFilePath;
    if (path == null || path.isEmpty) {
      state = state.copyWith(errorMessage: 'No log file available yet.');
      return;
    }

    try {
      await _ref.read(vpnBridgeProvider).openLogFile(path);
    } catch (error) {
      state = state.copyWith(errorMessage: 'Unable to open log file: $error');
    }
  }

  Future<void> shareLogFile() async {
    final path = state.logFilePath;
    if (path == null || path.isEmpty) {
      state = state.copyWith(errorMessage: 'No log file available yet.');
      return;
    }

    try {
      await _ref.read(vpnBridgeProvider).shareLogFile(path);
    } catch (error) {
      state = state.copyWith(errorMessage: 'Unable to share log file: $error');
    }
  }

  Future<void> importRawUri() async {
    if (state.importInput.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Paste a VPN URI first.');
      return;
    }

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _ref.read(importProfileFromUriProvider).call(
            state.importInput,
          );
      state = switch (result) {
        Success<VpnProfile>(data: final profile) => state.copyWith(
            profiles: [
              ...state.profiles.where((item) => item.id != profile.id),
              profile
            ],
            selectedProfile: profile,
            importInput: '',
            runtimeConfigPreview: _buildRuntimeConfigPreview(profile),
          ),
        FailureResult<VpnProfile>(message: final message) => state.copyWith(
            errorMessage: message,
          ),
      };
    } catch (error) {
      state = state.copyWith(errorMessage: 'Import failed: $error');
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<void> importFromQrPayload(String rawPayload) async {
    const parser = QrConfigParser();

    final rawPreview = rawPayload.length > 200
        ? '${rawPayload.substring(0, 200)}…'
        : rawPayload;
    _prependLog(
      title: 'IMPORT_QR',
      message: 'Raw payload (${rawPayload.length} chars): $rawPreview',
      severity: VpnLogSeverity.info,
    );

    final normalized = parser.normalize(rawPayload);

    if (normalized.isEmpty) {
      state =
          state.copyWith(errorMessage: 'QR content is empty or unsupported.');
      _prependLog(
        title: 'IMPORT_QR',
        message: 'Normalization returned empty. Raw: $rawPreview',
        severity: VpnLogSeverity.error,
      );
      return;
    }

    final normalizedPreview = normalized.length > 200
        ? '${normalized.substring(0, 200)}…'
        : normalized;
    _prependLog(
      title: 'IMPORT_QR',
      message: 'Normalized (${normalized.length} chars): $normalizedPreview',
      severity: VpnLogSeverity.info,
    );

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      // Prefer the normalized result – it is the fully processed candidate.
      // Fall back to extractDirectProfileUri only when normalize() returned
      // something other than a profile URI (e.g. an HTTP subscription URL).
      String? candidateUri;
      if (_isProfileUri(normalized)) {
        candidateUri = normalized;
      } else {
        candidateUri = parser.extractDirectProfileUri(rawPayload);
      }

      if (candidateUri != null) {
        _prependLog(
          title: 'IMPORT_QR',
          message:
              'Importing profile URI: ${candidateUri.length > 160 ? '${candidateUri.substring(0, 160)}…' : candidateUri}',
          severity: VpnLogSeverity.info,
        );
        await _importQrProfileUri(candidateUri);
        return;
      }

      if (_isHttpLikeUrl(normalized)) {
        // Use direct sync – QR codes contain the exact subscription URL,
        // so URL-variant fallback (/json/ ↔ /sub/) is unnecessary and
        // would double the total timeout wait on slow connections.
        final syncResult =
            await _ref.read(syncSubscriptionProvider).call(url: normalized);
        switch (syncResult) {
          case Success<SubscriptionSyncResult>(data: final data):
            await loadProfiles();
            state = state.copyWith(
              subscriptionInput: normalized,
              lastSubscriptionSyncAt: data.syncedAt,
              errorMessage: null,
            );
            _prependLog(
              title: 'IMPORT_QR',
              message:
                  'Subscription QR synced ${data.addedOrUpdatedCount} profiles (${data.dedupedCount} deduped).',
              severity: VpnLogSeverity.info,
            );
          case FailureResult<SubscriptionSyncResult>(message: final message):
            state = state.copyWith(errorMessage: '$message\nURL: $normalized');
            _prependLog(
              title: 'IMPORT_QR',
              message: '$message (url: $normalized)',
              severity: VpnLogSeverity.error,
            );
        }
        return;
      }

      final preview = normalized.length > 160
          ? '${normalized.substring(0, 160)}...'
          : normalized;
      state = state.copyWith(
        errorMessage: 'Unsupported profile format.\nScanned: $preview',
      );
      _prependLog(
        title: 'IMPORT_QR',
        message: 'Unsupported profile format (raw QR: $preview)',
        severity: VpnLogSeverity.error,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: 'QR import failed: $error');
      _prependLog(
        title: 'IMPORT_QR',
        message: 'QR import failed: $error',
        severity: VpnLogSeverity.error,
      );
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  bool _isHttpLikeUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  bool _isProfileUri(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('vless://') ||
        lower.startsWith('vmess://') ||
        lower.startsWith('trojan://') ||
        lower.startsWith('ss://');
  }

  Future<Result<SubscriptionSyncResult>> _syncSubscriptionWithFallback(
    String originalUrl,
  ) async {
    final candidates = _candidateSubscriptionUrls(originalUrl);
    FailureResult<SubscriptionSyncResult>? lastFailure;

    for (final candidate in candidates) {
      final result =
          await _ref.read(syncSubscriptionProvider).call(url: candidate);
      if (result is Success<SubscriptionSyncResult>) {
        return result;
      }
      lastFailure = result as FailureResult<SubscriptionSyncResult>;
    }

    return lastFailure ??
        const FailureResult<SubscriptionSyncResult>(
          'Subscription sync failed.',
        );
  }

  List<String> _candidateSubscriptionUrls(String url) {
    final normalized = url.trim();
    final candidates = <String>[normalized];
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return candidates;
    }

    final path = uri.path;
    if (path.contains('/json/')) {
      candidates.add(
          uri.replace(path: path.replaceFirst('/json/', '/sub/')).toString());
    } else if (path.contains('/sub/')) {
      candidates.add(
          uri.replace(path: path.replaceFirst('/sub/', '/json/')).toString());
    }

    return candidates.toSet().toList(growable: false);
  }

  Future<void> _importQrProfileUri(String uri) async {
    final parsed = _ref.read(vpnProfileImporterProvider).parse(uri);
    switch (parsed) {
      case Success<VpnProfile>(data: final profile):
        final qrProfile = profile.copyWith(
          source: VpnProfileSource(
            type: VpnProfileSourceType.qr,
            originalValue: uri,
          ),
        );
        final saveResult = await _ref.read(vpnRepositoryProvider).saveProfile(
              qrProfile,
            );
        if (saveResult is FailureResult<void>) {
          state = state.copyWith(errorMessage: saveResult.message);
          _prependLog(
            title: 'IMPORT_QR',
            message: saveResult.message,
            severity: VpnLogSeverity.error,
          );
          return;
        }

        state = state.copyWith(
          profiles: [
            ...state.profiles.where((item) => item.id != qrProfile.id),
            qrProfile
          ],
          selectedProfile: qrProfile,
          runtimeConfigPreview: _buildRuntimeConfigPreview(qrProfile),
          errorMessage: null,
        );
        _prependLog(
          title: 'IMPORT_QR',
          message: 'Imported ${qrProfile.name} from QR scan.',
          severity: VpnLogSeverity.info,
        );
      case FailureResult<VpnProfile>(message: final message):
        final preview = uri.length > 160 ? '${uri.substring(0, 160)}...' : uri;
        state = state.copyWith(errorMessage: '$message\nScanned: $preview');
        _prependLog(
          title: 'IMPORT_QR',
          message: '$message (raw QR: $preview)',
          severity: VpnLogSeverity.error,
        );
    }
  }

  Future<void> syncSubscription() async {
    final url = state.subscriptionInput.trim();
    if (url.isEmpty) {
      state = state.copyWith(errorMessage: 'Paste a subscription URL first.');
      return;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final result = await _syncSubscriptionWithFallback(url);
      switch (result) {
        case Success<SubscriptionSyncResult>(data: final data):
          await loadProfiles();
          state = state.copyWith(
            lastSubscriptionSyncAt: data.syncedAt,
          );
          _prependLog(
            title: 'SUBSCRIPTION_SYNC',
            severity: VpnLogSeverity.info,
            message:
                'Synced ${data.addedOrUpdatedCount} profiles (${data.dedupedCount} deduped, ${data.removedCount} removed, ${data.skippedCount} skipped).',
          );
        case FailureResult<SubscriptionSyncResult>(message: final message):
          state = state.copyWith(errorMessage: message);
          _prependLog(
            title: 'SUBSCRIPTION_SYNC',
            severity: VpnLogSeverity.error,
            message: message,
          );
      }
    } catch (error) {
      state = state.copyWith(errorMessage: 'Subscription sync failed: $error');
      _prependLog(
        title: 'SUBSCRIPTION_SYNC',
        severity: VpnLogSeverity.error,
        message: 'Subscription sync failed: $error',
      );
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  Future<void> runHealthCheck() async {
    final profile = state.selectedProfile;
    if (profile == null) {
      state = state.copyWith(errorMessage: 'Select a profile first.');
      return;
    }

    state = state.copyWith(isHealthChecking: true, clearError: true);
    try {
      final report = await _ref.read(runtimeHealthCheckerProvider).check(
            latencyHost: profile.endpoint.host,
            latencyPort: profile.endpoint.port,
          );
      state = state.copyWith(
        isHealthChecking: false,
        healthSummary: report.summary,
        healthDetails: report.details,
        lastHealthCheckAt: report.checkedAt,
      );
      _prependLog(
        title: 'HEALTH_CHECK',
        severity: report.state == RuntimeHealthState.broken
            ? VpnLogSeverity.error
            : (report.state == RuntimeHealthState.degraded
                ? VpnLogSeverity.warn
                : VpnLogSeverity.info),
        message: '${report.summary} • ${report.details}',
      );
    } catch (error) {
      state = state.copyWith(
        isHealthChecking: false,
        errorMessage: 'Health check failed: $error',
      );
      _prependLog(
        title: 'HEALTH_CHECK',
        severity: VpnLogSeverity.error,
        message: 'Health check failed: $error',
      );
    }
  }

  Future<void> connect() async {
    final profile = state.selectedProfile;
    if (profile == null) {
      state = state.copyWith(errorMessage: 'Select a profile first.');
      return;
    }

    state = state.copyWith(
      isBusy: true,
      clearError: true,
      status: VpnStatus.connecting,
      trafficStats: TrafficStats.empty(),
    );
    final result = await _ref.read(connectVpnProvider).call(profile);
    if (result is FailureResult<void>) {
      state = state.copyWith(
        isBusy: false,
        status: VpnStatus.error,
        errorMessage: result.message,
      );
      return;
    }
    state = state.copyWith(isBusy: false, errorMessage: null);
  }

  Future<void> disconnect() async {
    state = state.copyWith(
      isBusy: true,
      clearError: true,
      status: VpnStatus.disconnecting,
    );
    final result = await _ref.read(disconnectVpnProvider).call();
    if (result is FailureResult<void>) {
      state = state.copyWith(
        isBusy: false,
        status: VpnStatus.error,
        errorMessage: result.message,
      );
      return;
    }
    state = state.copyWith(
      isBusy: false,
      status: VpnStatus.disconnected,
      trafficStats: TrafficStats.empty(),
      errorMessage: null,
    );
  }

  void _handleNativeEvent(Map<String, dynamic> event) {
    final action = event['action'] as String?;
    if (action == 'import_uri') {
      final uri = event['uri'] as String?;
      if (uri != null && uri.isNotEmpty) {
        unawaited(_importExternalUri(uri));
      }
      return;
    }

    final entries = <VpnLogEntry>[];
    final profileName = event['profileName'] as String?;
    final message = event['message'] as String?;
    final commandPreview = event['commandPreview'] as String?;
    final configPath = event['configPath'] as String?;
    final logFilePath = event['logFilePath'] as String?;
    final status = event['status'] as String? ?? 'event';
    final severity = _resolveSeverity(event);
    final titleBase = profileName == null
        ? status.toUpperCase()
        : '${status.toUpperCase()} • $profileName';

    if (message != null &&
        message.isNotEmpty &&
        message != 'Traffic stats updated') {
      entries.add(
        VpnLogEntry(
          timestamp: DateTime.now(),
          title: titleBase,
          message: message,
          severity: severity,
        ),
      );
    }

    if (commandPreview != null && commandPreview.isNotEmpty) {
      entries.add(
        VpnLogEntry(
          timestamp: DateTime.now(),
          title: '$titleBase • command',
          message: commandPreview,
          severity: VpnLogSeverity.info,
        ),
      );
    }

    if (configPath != null && configPath.isNotEmpty) {
      entries.add(
        VpnLogEntry(
          timestamp: DateTime.now(),
          title: '$titleBase • config',
          message: configPath,
          severity: VpnLogSeverity.info,
        ),
      );
    }

    if (entries.isEmpty) {
      if (logFilePath != null && logFilePath.isNotEmpty) {
        state = state.copyWith(logFilePath: logFilePath);
      }
      return;
    }

    state = state.copyWith(
      logFilePath: logFilePath ?? state.logFilePath,
      logs: [...entries, ...state.logs].take(50).toList(growable: false),
    );
  }

  String _buildRuntimeConfigPreview(VpnProfile profile) {
    final result = _ref.read(buildRuntimeConfigProvider).call(profile);
    return switch (result) {
      Success<TunnelRuntimeConfig>(data: final config) => config.toPrettyJson(),
      FailureResult<TunnelRuntimeConfig>(message: final message) =>
        'Unable to build runtime config: $message',
    };
  }

  VpnLogSeverity _resolveSeverity(Map<String, dynamic> event) {
    switch (event['severity']) {
      case 'error':
        return VpnLogSeverity.error;
      case 'warn':
        return VpnLogSeverity.warn;
      case 'info':
        return VpnLogSeverity.info;
    }

    final status = event['status'] as String? ?? '';
    final message = (event['message'] as String? ?? '').toLowerCase();
    if (status == 'error' ||
        message.contains('failed') ||
        message.contains('denied') ||
        message.contains('exited with code')) {
      return VpnLogSeverity.error;
    }
    if (status == 'disconnecting' ||
        message.contains('missing') ||
        message.contains('warning')) {
      return VpnLogSeverity.warn;
    }
    return VpnLogSeverity.info;
  }

  Future<void> _importExternalUri(String uri) async {
    state = state.copyWith(
      isBusy: true,
      importInput: uri,
      clearError: true,
    );

    final result = await _ref.read(importProfileFromUriProvider).call(uri);
    state = switch (result) {
      Success<VpnProfile>(data: final profile) => state.copyWith(
          isBusy: false,
          profiles: [
            ...state.profiles.where((item) => item.id != profile.id),
            profile
          ],
          selectedProfile: profile,
          importInput: '',
          runtimeConfigPreview: _buildRuntimeConfigPreview(profile),
          logs: [
            VpnLogEntry(
              timestamp: DateTime.now(),
              title: 'IMPORT_URI',
              message: 'Imported ${profile.name} from device intent.',
              severity: VpnLogSeverity.info,
            ),
            ...state.logs,
          ].take(50).toList(growable: false),
        ),
      FailureResult<VpnProfile>(message: final message) => state.copyWith(
          isBusy: false,
          errorMessage: message,
          logs: [
            VpnLogEntry(
              timestamp: DateTime.now(),
              title: 'IMPORT_URI',
              message: message,
              severity: VpnLogSeverity.error,
            ),
            ...state.logs,
          ].take(50).toList(growable: false),
        ),
    };
  }

  Future<void> _consumePendingImportUri() async {
    final uri = await _ref.read(vpnBridgeProvider).consumePendingImportUri();
    if (uri == null || uri.isEmpty) {
      return;
    }
    await _importExternalUri(uri);
  }

  Future<void> _loadSavedSubscription() async {
    final result = await _ref.read(syncSubscriptionProvider).loadPrimary();
    switch (result) {
      case Success(data: final subscription):
        if (subscription == null) {
          return;
        }
        state = state.copyWith(
          subscriptionInput: subscription.url,
          lastSubscriptionSyncAt: subscription.lastSyncedAt,
        );
      case FailureResult():
      // Ignore load failures to keep startup resilient.
    }
  }

  void _prependLog({
    required String title,
    required String message,
    required VpnLogSeverity severity,
  }) {
    state = state.copyWith(
      logs: [
        VpnLogEntry(
          timestamp: DateTime.now(),
          title: title,
          message: message,
          severity: severity,
        ),
        ...state.logs,
      ].take(50).toList(growable: false),
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _trafficSubscription?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }
}

final vpnControllerProvider = StateNotifierProvider<VpnController, VpnState>(
  (ref) => VpnController(ref),
);
