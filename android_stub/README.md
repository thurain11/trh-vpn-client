# Android Stub

Create Android platform files with `flutter create .`, then move your native VPN integration into:

- `android/app/src/main/kotlin/.../MainActivity.kt`
- `android/app/src/main/kotlin/.../vpn/MyVpnService.kt`

Recommended responsibilities:

- `MainActivity.kt`: method/event channel registration
- `MyVpnService.kt`: `VpnService`, TUN setup, route management, core process lifecycle
