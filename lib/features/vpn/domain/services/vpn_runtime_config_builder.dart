import '../../../../core/result/result.dart';
import '../entities/tunnel_runtime_config.dart';
import '../entities/vpn_profile.dart';

abstract class VpnRuntimeConfigBuilder {
  Result<TunnelRuntimeConfig> build(VpnProfile profile);
}
