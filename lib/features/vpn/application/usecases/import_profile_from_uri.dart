import '../../../../core/result/result.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/repositories/vpn_repository.dart';
import '../../domain/services/vpn_profile_importer.dart';

class ImportProfileFromUri {
  const ImportProfileFromUri(this._importer, this._repository);

  final VpnProfileImporter _importer;
  final VpnRepository _repository;

  Future<Result<VpnProfile>> call(String raw) async {
    final parsedResult = _importer.parse(raw);
    switch (parsedResult) {
      case Success<VpnProfile>(data: final profile):
        final saveResult = await _repository.saveProfile(profile);
        if (saveResult is FailureResult<void>) {
          return FailureResult(saveResult.message);
        }
        return Success(profile);
      case FailureResult<VpnProfile>(message: final message):
        return FailureResult(message);
    }
  }
}
