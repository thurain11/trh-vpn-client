import '../../domain/entities/vpn_status.dart';
import '../../domain/repositories/vpn_repository.dart';

class ObserveVpnStatus {
  const ObserveVpnStatus(this._repository);

  final VpnRepository _repository;

  Stream<VpnStatus> call() {
    return _repository.watchStatus();
  }
}
