# EasyTier iOS/macOS Client

[简体中文](README_CN.md) | [English](README.md)

iOS/macOS native client application for EasyTier, a decentralized virtual private network solution.

### Overview

This is an iOS/macOS client for EasyTier VPN. It provides a user-friendly interface to connect to EasyTier networks on iOS/macOS devices, with support for Network Extension framework for system-level VPN integration.

### Screenshots

![Screenshots](Assets/screenshots.jpg)

### Installation

Available on the App Store (except for China mainland region):

<a href="https://apps.apple.com/app/easytier/id6788989728">
  <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" alt="Download on the App Store" height="40">
</a>

### Nightly TrollStore build

On every push to `main`, the repository updates a credentials-free nightly Release IPA for TrollStore. The app and its extensions are ad-hoc signed with their required Network Extension and App Group entitlements.

### License

GNU General Public License v3.0 - See [LICENSE](LICENSE) file

### Project Links

- EasyTier: [EasyTier/EasyTier](https://github.com/EasyTier/EasyTier)


## iOS 14–16 compatibility build

The app, shared module, packet tunnel and widget now target iOS 14.0. Navigation and forms have iOS 14 fallbacks; iOS 16 uses NavigationStack. App Intents and interactive widgets remain guarded by their actual system versions. Earlier widgets open the app instead of attempting unsupported background button actions. System OSLog export requires iOS 15; the core log view remains available on iOS 14.

VPN preference operations use explicit callback bridges, and connection startup reloads saved preferences before starting the tunnel. Keep the complete Xcode-built app, including its Swift concurrency compatibility library and executable framework search paths. The conventional LegacyAppIcon asset also permits Xcode 16 builds without Xcode 26 Icon Composer support.

Build with Xcode 16.4 or later, a Rust toolchain with `aarch64-apple-ios`, and protoc available to the build script:

```sh
LC_ALL=en_US.UTF-8 xcodebuild -project EasyTier.xcodeproj -scheme EasyTier \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/easytier-build CODE_SIGNING_ALLOWED=NO build
bash tests/run-swift-tests.sh
```

Use development signing for regular devices or sign the complete app and extensions for the existing TrollStore installation. Do not overwrite an executable in place. Existing profile data is retained by a bundle upgrade. iOS 14.4.2 on iPhone 7 is the device used for this compatibility pass; iOS 15/16 still require a separate device regression run.

2026-11-17 iPhone 7 / iOS 14.4.2 实测冷启动、VPN 连接及重连，获得虚拟 IP、对等节点列表和双向实际流量；既有隧道生命周期、Web 配置与配置保存回归脚本通过。


### TrollStore on older iOS

On the test iOS 14.4.2 device, the kernel logged a fatal **17 MiB** packet-tunnel memory limit. Initial connection succeeded, but the system killed the extension after several minutes. For this installation type use `tools/build-trollstore.sh` (set `TEAM_ID` to retain your existing signing identity when necessary). It enables `TROLLSTORE_BUILD` and signs only the tunnel with `com.apple.private.memorystatus`; the extension requests a finite 128 MiB fatal limit for **its own process**. The result is logged for verification. This path is not suitable for App Store or ordinary development provisioning; the standard project does not request the private entitlement or call the private API. The iOS 14 ordinary-signing memory budget has not been validated for sustained use.

The command constants follow [Apple's XNU memory-status API](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/kern_memorystatus.h). The change does not disable system-wide memory pressure handling. Runtime API availability and memory budgets are independent compatibility requirements.

真机系统日志确认 TrollStore 专用额度设置返回 `result=0 errno=0`；后台维持连接期间完成 FNTV 的 NAS 详情加载与视频续播。测试时的常驻内存约 25–34 MiB，不代表所有流量场景的峰值。
