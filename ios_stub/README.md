# iOS Stub

Create iOS platform files with `flutter create .`, then add your tunnel extension:

- `ios/Runner/AppDelegate.swift`
- `ios/PacketTunnel/PacketTunnelProvider.swift`

Recommended responsibilities:

- `AppDelegate.swift`: Flutter bridge wiring
- `PacketTunnelProvider.swift`: `NEPacketTunnelProvider`, route/DNS config, core process lifecycle
