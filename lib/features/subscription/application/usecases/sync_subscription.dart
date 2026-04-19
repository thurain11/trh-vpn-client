import 'dart:convert';

import '../../../../core/result/result.dart';
import '../../../vpn/data/datasources/local/profile_local_data_source.dart';
import '../../../vpn/data/datasources/remote/subscription_remote_data_source.dart';
import '../../../vpn/data/models/vpn_profile_model.dart';
import '../../../vpn/domain/entities/vpn_profile.dart';
import '../../../vpn/domain/services/vpn_profile_importer.dart';
import '../../data/datasources/local/subscription_local_data_source.dart';
import '../../data/models/subscription_record_model.dart';
import '../../domain/entities/subscription_record.dart';

class SyncSubscription {
  const SyncSubscription({
    required SubscriptionRemoteDataSource remoteDataSource,
    required SubscriptionLocalDataSource subscriptionLocalDataSource,
    required ProfileLocalDataSource profileLocalDataSource,
    required VpnProfileImporter importer,
  }) : _remoteDataSource = remoteDataSource,
       _subscriptionLocalDataSource = subscriptionLocalDataSource,
       _profileLocalDataSource = profileLocalDataSource,
       _importer = importer;

  final SubscriptionRemoteDataSource _remoteDataSource;
  final SubscriptionLocalDataSource _subscriptionLocalDataSource;
  final ProfileLocalDataSource _profileLocalDataSource;
  final VpnProfileImporter _importer;

  Future<Result<SubscriptionSyncResult>> call({
    required String url,
    String? name,
  }) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      return const FailureResult('Subscription URL is required.');
    }

    final subscriptionId = _subscriptionId(normalizedUrl);
    try {
      final payload = await _remoteDataSource.fetchSubscription(normalizedUrl);
      final uris = _extractUris(payload);
      if (uris.isEmpty) {
        await _saveRecord(
          id: subscriptionId,
          url: normalizedUrl,
          name: name,
          lastError: 'No valid VPN URIs found in subscription payload.',
        );
        return const FailureResult('No valid VPN URIs found in subscription.');
      }

      final existing = await _profileLocalDataSource.getProfiles();
      final nonSubscriptionProfiles = existing
          .where((profile) => profile.subscriptionId != subscriptionId)
          .toList();
      final oldSubscriptionProfiles = existing
          .where((profile) => profile.subscriptionId == subscriptionId)
          .toList();
      final oldById = {for (final profile in oldSubscriptionProfiles) profile.id: profile};

      final parsedProfiles = <VpnProfileModel>[];
      var skippedInvalid = 0;

      for (final uri in uris) {
        final parsed = _importer.parse(uri);
        switch (parsed) {
          case Success<VpnProfile>(data: final profile):
            final prepared = _applySubscriptionMetadata(
              profile: profile,
              subscriptionId: subscriptionId,
            );
            parsedProfiles.add(prepared);
          case FailureResult<VpnProfile>():
            skippedInvalid++;
        }
      }

      if (parsedProfiles.isEmpty) {
        await _saveRecord(
          id: subscriptionId,
          url: normalizedUrl,
          name: name,
          lastError: 'Subscription returned no parseable profiles.',
        );
        return const FailureResult('Subscription returned no parseable profiles.');
      }

      final dedupedById = <String, VpnProfileModel>{};
      for (final profile in parsedProfiles) {
        dedupedById[profile.id] = profile;
      }
      final dedupedProfiles = dedupedById.values.toList();

      final mergedProfiles = dedupedProfiles.map((profile) {
        final previous = oldById[profile.id];
        if (previous == null) {
          return profile;
        }
        return VpnProfileModel.fromEntity(
          profile.toEntity().copyWith(
                name: previous.name,
                remarks: previous.remarks,
                isSecureDnsEnabled: previous.isSecureDnsEnabled,
              ),
        );
      }).toList();

      final finalProfiles = [...nonSubscriptionProfiles, ...mergedProfiles];
      await _profileLocalDataSource.replaceProfiles(finalProfiles);

      final syncedAt = DateTime.now();
      await _subscriptionLocalDataSource.savePrimary(
        SubscriptionRecordModel(
          id: subscriptionId,
          url: normalizedUrl,
          name: name,
          lastSyncedAt: syncedAt,
          lastError: null,
        ),
      );

      return Success(
        SubscriptionSyncResult(
          syncedAt: syncedAt,
          fetchedUriCount: uris.length,
          parsedProfileCount: parsedProfiles.length,
          addedOrUpdatedCount: mergedProfiles.length,
          dedupedCount: parsedProfiles.length - dedupedProfiles.length,
          removedCount: oldSubscriptionProfiles.length - mergedProfiles.length,
          skippedCount: skippedInvalid,
        ),
      );
    } catch (error) {
      await _saveRecord(
        id: subscriptionId,
        url: normalizedUrl,
        name: name,
        lastError: error.toString(),
      );
      return FailureResult('Subscription sync failed: $error');
    }
  }

  Future<Result<SubscriptionRecord?>> loadPrimary() async {
    try {
      final primary = await _subscriptionLocalDataSource.getPrimary();
      return Success(primary?.toEntity());
    } catch (error) {
      return FailureResult('Failed to load subscription: $error');
    }
  }

  List<String> _extractUris(String rawPayload) {
    var payload = rawPayload.trim();
    if (!payload.contains('://')) {
      final decoded = _tryDecodeBase64(payload);
      if (decoded != null && decoded.contains('://')) {
        payload = decoded;
      }
    }
    return payload
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.contains('://'))
        .toList();
  }

  String? _tryDecodeBase64(String raw) {
    try {
      var normalized = raw.replaceAll(RegExp(r'\s+'), '');
      normalized = normalized.replaceAll('-', '+').replaceAll('_', '/');
      final padding = normalized.length % 4;
      if (padding != 0) {
        normalized = normalized.padRight(normalized.length + (4 - padding), '=');
      }
      final bytes = base64Decode(normalized);
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  VpnProfileModel _applySubscriptionMetadata({
    required VpnProfile profile,
    required String subscriptionId,
  }) {
    final patched = profile.copyWith(
      source: VpnProfileSource(
        type: VpnProfileSourceType.subscription,
        originalValue: profile.rawConfig,
      ),
      subscriptionId: subscriptionId,
    );
    return VpnProfileModel.fromEntity(patched);
  }

  String _subscriptionId(String url) {
    final encoded = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
    return 'sub-$encoded';
  }

  Future<void> _saveRecord({
    required String id,
    required String url,
    String? name,
    String? lastError,
  }) async {
    await _subscriptionLocalDataSource.savePrimary(
      SubscriptionRecordModel(
        id: id,
        url: url,
        name: name,
        lastSyncedAt: DateTime.now(),
        lastError: lastError,
      ),
    );
  }
}

class SubscriptionSyncResult {
  const SubscriptionSyncResult({
    required this.syncedAt,
    required this.fetchedUriCount,
    required this.parsedProfileCount,
    required this.addedOrUpdatedCount,
    required this.dedupedCount,
    required this.removedCount,
    required this.skippedCount,
  });

  final DateTime syncedAt;
  final int fetchedUriCount;
  final int parsedProfileCount;
  final int addedOrUpdatedCount;
  final int dedupedCount;
  final int removedCount;
  final int skippedCount;
}
