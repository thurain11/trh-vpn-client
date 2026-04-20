import '../../../../core/result/result.dart';
import '../../domain/repositories/vpn_repository.dart';

class DeleteProfile {
  const DeleteProfile(this._repository);

  final VpnRepository _repository;

  Future<Result<void>> call(String id) {
    return _repository.deleteProfile(id);
  }
}
