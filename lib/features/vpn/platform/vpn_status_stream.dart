import '../domain/entities/vpn_status.dart';
import 'vpn_bridge.dart';

class VpnStatusStream {
  const VpnStatusStream(this._bridge);

  final VpnBridge _bridge;

  Stream<VpnStatus> watch() {
    return _bridge.watchStatusEvents().map((event) {
      switch (event['status']) {
        case 'connecting':
          return VpnStatus.connecting;
        case 'connected':
          return VpnStatus.connected;
        case 'disconnecting':
          return VpnStatus.disconnecting;
        case 'error':
          return VpnStatus.error;
        default:
          return VpnStatus.disconnected;
      }
    });
  }
}
