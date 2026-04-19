import '../../../../core/result/result.dart';
import '../../domain/entities/tunnel_runtime_config.dart';
import '../../domain/entities/traffic_stats.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/entities/vpn_status.dart';
import '../../domain/repositories/vpn_repository.dart';
import '../../domain/services/vpn_runtime_config_builder.dart';
import '../datasources/local/profile_local_data_source.dart';
import '../models/vpn_profile_model.dart';
import '../../platform/vpn_bridge.dart';
import '../../platform/vpn_status_stream.dart';

class VpnRepositoryImpl implements VpnRepository {
  VpnRepositoryImpl({
    required VpnBridge bridge,
    required VpnStatusStream statusStream,
    required ProfileLocalDataSource profileLocalDataSource,
    required VpnRuntimeConfigBuilder runtimeConfigBuilder,
  }) : _bridge = bridge,
       _statusStream = statusStream,
       _profileLocalDataSource = profileLocalDataSource,
       _runtimeConfigBuilder = runtimeConfigBuilder;

  final VpnBridge _bridge;
  final VpnStatusStream _statusStream;
  final ProfileLocalDataSource _profileLocalDataSource;
  final VpnRuntimeConfigBuilder _runtimeConfigBuilder;

  @override
  Result<TunnelRuntimeConfig> buildRuntimeConfig(VpnProfile profile) {
    return _runtimeConfigBuilder.build(profile);
  }

  @override
  Future<Result<void>> connect(VpnProfile profile) async {
    try {
      final runtimeConfigResult = _runtimeConfigBuilder.build(profile);
      switch (runtimeConfigResult) {
        case FailureResult<TunnelRuntimeConfig>(message: final message):
          return FailureResult(message);
        case Success<TunnelRuntimeConfig>(data: final runtimeConfig):
          await _bridge.startTunnel(profile, runtimeConfig);
      }
      return const Success(null);
    } catch (error) {
      return FailureResult(error.toString());
    }
  }

  @override
  Future<Result<void>> disconnect() async {
    try {
      await _bridge.stopTunnel();
      return const Success(null);
    } catch (error) {
      return FailureResult(error.toString());
    }
  }

  @override
  Future<Result<List<VpnProfile>>> getProfiles() async {
    try {
      final profiles = await _profileLocalDataSource.getProfiles();
      return Success(profiles.map((profile) => profile.toEntity()).toList());
    } catch (error) {
      return FailureResult(error.toString());
    }
  }

  @override
  Future<Result<void>> saveProfile(VpnProfile profile) async {
    try {
      await _profileLocalDataSource.saveProfile(
        VpnProfileModel.fromEntity(profile),
      );
      return const Success(null);
    } catch (error) {
      return FailureResult(error.toString());
    }
  }

  @override
  Stream<VpnStatus> watchStatus() => _statusStream.watch();

  @override
  Stream<TrafficStats> watchTraffic() => _bridge.watchTrafficStats();
}
