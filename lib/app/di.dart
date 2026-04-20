import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger/app_logger.dart';
import '../features/subscription/application/usecases/sync_subscription.dart';
import '../features/subscription/data/datasources/local/subscription_local_data_source.dart';
import '../features/vpn/application/services/runtime_health_checker.dart';
import '../features/vpn/application/usecases/build_runtime_config.dart';
import '../features/vpn/application/usecases/connect_vpn.dart';
import '../features/vpn/application/usecases/delete_profile.dart';
import '../features/vpn/application/usecases/disconnect_vpn.dart';
import '../features/vpn/application/usecases/import_profile.dart';
import '../features/vpn/application/usecases/import_profile_from_uri.dart';
import '../features/vpn/application/usecases/load_profiles.dart';
import '../features/vpn/application/usecases/observe_vpn_status.dart';
import '../features/vpn/data/builders/default_vpn_runtime_config_builder.dart';
import '../features/vpn/data/datasources/local/profile_local_data_source.dart';
import '../features/vpn/data/datasources/remote/subscription_remote_data_source.dart';
import '../features/vpn/data/parsers/composite_profile_importer.dart';
import '../features/vpn/data/parsers/shadowsocks_uri_parser.dart';
import '../features/vpn/data/parsers/trojan_uri_parser.dart';
import '../features/vpn/data/parsers/vless_uri_parser.dart';
import '../features/vpn/data/parsers/vmess_uri_parser.dart';
import '../features/vpn/data/repositories_impl/vpn_repository_impl.dart';
import '../features/vpn/domain/services/vpn_profile_importer.dart';
import '../features/vpn/domain/repositories/vpn_repository.dart';
import '../features/vpn/domain/services/vpn_runtime_config_builder.dart';
import '../features/vpn/platform/vpn_bridge.dart';
import '../features/vpn/platform/vpn_status_stream.dart';

final appLoggerProvider = Provider<AppLogger>((ref) => const AppLogger());

final vpnBridgeProvider = Provider<VpnBridge>(
  (ref) => MethodChannelVpnBridge(),
);

final runtimeHealthCheckerProvider = Provider<RuntimeHealthChecker>(
  (ref) => const RuntimeHealthChecker(),
);

final vpnStatusStreamProvider = Provider<VpnStatusStream>(
  (ref) => VpnStatusStream(ref.watch(vpnBridgeProvider)),
);

final profileLocalDataSourceProvider = Provider<ProfileLocalDataSource>(
  (ref) => SharedPrefsProfileLocalDataSource(),
);

final vpnRuntimeConfigBuilderProvider = Provider<VpnRuntimeConfigBuilder>(
  (ref) => const DefaultVpnRuntimeConfigBuilder(),
);

final vpnProfileImporterProvider = Provider<VpnProfileImporter>(
  (ref) => const CompositeProfileImporter([
    VlessUriParser(),
    VmessUriParser(),
    TrojanUriParser(),
    ShadowsocksUriParser(),
  ]),
);

final subscriptionLocalDataSourceProvider =
    Provider<SubscriptionLocalDataSource>(
  (ref) => SharedPrefsSubscriptionLocalDataSource(),
);

final subscriptionRemoteDataSourceProvider =
    Provider<SubscriptionRemoteDataSource>(
  (ref) => HttpSubscriptionRemoteDataSource(),
);

final syncSubscriptionProvider = Provider<SyncSubscription>(
  (ref) => SyncSubscription(
    remoteDataSource: ref.watch(subscriptionRemoteDataSourceProvider),
    subscriptionLocalDataSource: ref.watch(subscriptionLocalDataSourceProvider),
    profileLocalDataSource: ref.watch(profileLocalDataSourceProvider),
    importer: ref.watch(vpnProfileImporterProvider),
  ),
);

final vpnRepositoryProvider = Provider<VpnRepository>(
  (ref) => VpnRepositoryImpl(
    bridge: ref.watch(vpnBridgeProvider),
    statusStream: ref.watch(vpnStatusStreamProvider),
    profileLocalDataSource: ref.watch(profileLocalDataSourceProvider),
    runtimeConfigBuilder: ref.watch(vpnRuntimeConfigBuilderProvider),
  ),
);

final connectVpnProvider = Provider<ConnectVpn>(
  (ref) => ConnectVpn(ref.watch(vpnRepositoryProvider)),
);

final disconnectVpnProvider = Provider<DisconnectVpn>(
  (ref) => DisconnectVpn(ref.watch(vpnRepositoryProvider)),
);

final deleteProfileProvider = Provider<DeleteProfile>(
  (ref) => DeleteProfile(ref.watch(vpnRepositoryProvider)),
);

final observeVpnStatusProvider = Provider<ObserveVpnStatus>(
  (ref) => ObserveVpnStatus(ref.watch(vpnRepositoryProvider)),
);

final importProfileProvider = Provider<ImportProfile>(
  (ref) => ImportProfile(ref.watch(vpnRepositoryProvider)),
);

final importProfileFromUriProvider = Provider<ImportProfileFromUri>(
  (ref) => ImportProfileFromUri(
    ref.watch(vpnProfileImporterProvider),
    ref.watch(vpnRepositoryProvider),
  ),
);

final loadProfilesProvider = Provider<LoadProfiles>(
  (ref) => LoadProfiles(ref.watch(vpnRepositoryProvider)),
);

final buildRuntimeConfigProvider = Provider<BuildRuntimeConfig>(
  (ref) => BuildRuntimeConfig(ref.watch(vpnRuntimeConfigBuilderProvider)),
);
