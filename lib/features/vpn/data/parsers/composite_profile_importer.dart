import '../../../../core/result/result.dart';
import '../../domain/entities/vpn_profile.dart';
import '../../domain/services/vpn_profile_importer.dart';

class CompositeProfileImporter implements VpnProfileImporter {
  const CompositeProfileImporter(this._parsers);

  final List<VpnProfileImporter> _parsers;

  @override
  bool canParse(String raw) => _parsers.any((parser) => parser.canParse(raw));

  @override
  Result<VpnProfile> parse(String raw) {
    final normalized = raw.trim();
    for (final parser in _parsers) {
      if (parser.canParse(normalized)) {
        return parser.parse(normalized);
      }
    }
    return const FailureResult(
      'Unsupported profile format. Try VLESS, VMess, Trojan, or Shadowsocks URI.',
    );
  }
}
