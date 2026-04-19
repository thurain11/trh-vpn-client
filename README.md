# Lunex

Starter Flutter skeleton for a VPN client inspired by the architecture we discussed.

## Included

- Clean architecture folders for `vpn`, `profile`, `subscription`, and `settings`
- Riverpod bootstrap
- VPN domain entities, repository contracts, use cases, and presentation controller
- Platform bridge abstractions for future Android `VpnService` and iOS `NEPacketTunnelProvider` integration

## Next Steps

1. Run `flutter create .` only if you want the standard platform folders generated.
2. Keep the generated `lib/` files from this skeleton.
3. Implement native bridge code for Android and iOS.
4. Add secure storage, local persistence, and config import flows.
# trh-vpn-client
