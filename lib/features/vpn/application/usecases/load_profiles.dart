import '../../../../core/result/result.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/repositories/vpn_repository.dart';

class LoadProfiles {
  const LoadProfiles(this._repository);

  final VpnRepository _repository;

  Future<Result<List<VpnProfile>>> call() {
    return _repository.getProfiles();
  }
}
