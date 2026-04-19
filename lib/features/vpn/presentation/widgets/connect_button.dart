import 'package:flutter/material.dart';

import '../../domain/entities/vpn_status.dart';

class ConnectButton extends StatelessWidget {
  const ConnectButton({
    required this.status,
    required this.isBusy,
    required this.onConnect,
    required this.onDisconnect,
    super.key,
  });

  final VpnStatus status;
  final bool isBusy;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final showDisconnect = status == VpnStatus.connected ||
        status == VpnStatus.connecting ||
        status == VpnStatus.error;
    final isTransitioning =
        status == VpnStatus.connecting || status == VpnStatus.disconnecting;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isBusy
            ? null
            : (showDisconnect ? onDisconnect : onConnect),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor:
              showDisconnect ? Colors.red.shade700 : null,
        ),
        child: isTransitioning
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    status == VpnStatus.connecting
                        ? 'Connecting…'
                        : 'Disconnecting…',
                  ),
                ],
              )
            : Text(showDisconnect ? 'Disconnect' : 'Connect'),
      ),
    );
  }
}
