Bundled VPN engine binaries should be placed here.

Recommended layout:

- `bin/xray/android-arm64/xray`
- `bin/xray/android-armv7/xray`
- `bin/xray/android-x64/xray`
- `bin/sing-box/android-arm64/sing-box`
- `bin/sing-box/android-armv7/sing-box`
- `bin/sing-box/android-x64/sing-box`

The current launcher stub extracts the selected engine from assets into the
Gradle now mirrors matching binaries into generated `jniLibs` entries so the
runtime launcher can execute them from Android's `nativeLibraryDir`.

Current packaging mapping:

- `bin/xray/android-arm64/xray` -> `libxray.so` for `arm64-v8a`
- `bin/xray/android-armv7/xray` -> `libxray.so` for `armeabi-v7a`
- `bin/xray/android-x64/xray` -> `libxray.so` for `x86_64`

- `bin/sing-box/android-arm64/sing-box` -> `libsingbox.so` for `arm64-v8a`
- `bin/sing-box/android-armv7/sing-box` -> `libsingbox.so` for `armeabi-v7a`
- `bin/sing-box/android-x64/sing-box` -> `libsingbox.so` for `x86_64`
