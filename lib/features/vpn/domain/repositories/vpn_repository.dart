import '../../../../core/result/result.dart';
import '../entities/tunnel_runtime_config.dart';
import '../entities/traffic_stats.dart';
import '../entities/vpn_profile.dart';
import '../entities/vpn_status.dart';

abstract class VpnRepository {
  Future<Result<List<VpnProfile>>> getProfiles();
  Future<Result<void>> saveProfile(VpnProfile profile);
  Future<Result<void>> deleteProfile(String id);
  Result<TunnelRuntimeConfig> buildRuntimeConfig(VpnProfile profile);
  Future<Result<void>> connect(VpnProfile profile);
  Future<Result<void>> disconnect();
  Stream<VpnStatus> watchStatus();
  Stream<TrafficStats> watchTraffic();
}
