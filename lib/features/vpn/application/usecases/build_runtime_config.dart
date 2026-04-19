import '../../../../core/result/result.dart';
import '../../domain/entities/tunnel_runtime_config.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/services/vpn_runtime_config_builder.dart';

class BuildRuntimeConfig {
  const BuildRuntimeConfig(this._builder);

  final VpnRuntimeConfigBuilder _builder;

  Result<TunnelRuntimeConfig> call(VpnProfile profile) {
    return _builder.build(profile);
  }
}
