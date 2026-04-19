import '../../../../core/result/result.dart';
import '../entities/vpn_profile.dart';

abstract class VpnProfileImporter {
  bool canParse(String raw);
  Result<VpnProfile> parse(String raw);
}
