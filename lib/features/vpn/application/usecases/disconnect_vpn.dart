import '../../../../core/result/result.dart';
import '../../domain/repositories/vpn_repository.dart';

class DisconnectVpn {
  const DisconnectVpn(this._repository);

  final VpnRepository _repository;

  Future<Result<void>> call() {
    return _repository.disconnect();
  }
}
