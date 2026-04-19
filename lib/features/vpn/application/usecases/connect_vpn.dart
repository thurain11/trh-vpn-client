import '../../../../core/result/result.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/repositories/vpn_repository.dart';

class ConnectVpn {
  const ConnectVpn(this._repository);

  final VpnRepository _repository;

  Future<Result<void>> call(VpnProfile profile) {
    return _repository.connect(profile);
  }
}
