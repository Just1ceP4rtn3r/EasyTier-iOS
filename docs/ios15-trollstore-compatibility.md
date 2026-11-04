# iOS 15 TrollStore shared preferences compatibility

## Reproduced failure

On an iPhone SE (iPhone8,4) running iOS 15.7.5, the host app could read
`VPNConfig`, but the packet tunnel extension failed with
`startTunnel() options is nil`. The core had not reached the peer connection
stage. The same suite, `group.cn.easytier`, was being resolved to different
private preference domains. Both processes could resolve the actual App Group
container with `containerURLForSecurityApplicationGroupIdentifier:`.

## Implementation

`EasyTierShared/SharedPreferencesCompatibility.m` selects the resolved App Group
container explicitly when initializing this one NSUserDefaults suite on iOS 15.
It uses Foundation's `_initWithSuiteName:container:` compatibility initializer.
Other suites and standard defaults use the original initializer. iOS 16 and
later do not install the hook. The hook is installed once per process, and its
replacement initializer preserves the Objective-C init ownership convention.
The app and extension link with `-ObjC` so the shared static library's category
is retained.

This is an iOS 15 TrollStore compatibility build; the private initializer needs
to be reconsidered before any App Store distribution.

## Packaging an existing app and extension

The existing local `build.sh` builds only the main app. Its Xcode target does
not embed or build the Rust tunnel extension. Packaging that output by itself
cannot supply a working VPN. Preserve a previously built, matching extension
when using this build path.

The packaging script takes a complete arm64 `.app` containing the extension,
compiles the same compatibility source as a dylib, and adds its load command to
both executables. It preserves the existing entitlement blobs. TrollStore
re-signs the complete package during installation. The script fails if the
extension is missing or the executable has insufficient load-command padding.
It refuses to overwrite an existing IPA.

```sh
python3 scripts/package-ios15-compatibility.py \
  --app /path/to/previously-installed/EasyTier.app \
  --host-app /path/to/freshly-built/EasyTier.app \
  --output /path/to/EasyTier-iOS15-fixed.ipa
```

The device-tested package overlays the freshly built Swift host app and reuses
the matching Rust extension. It does not rebuild Rust. The freshly built host
is required: reusing the old host omits the iOS 15 async VPN-preferences fix and
can crash in `swift_continuation_throwingResume` on a manual Connect action. The Swift host app plus compatibility source also builds
successfully with local Xcode 16.4 targeting iOS 15.

## Device validation on 2026-10-30

- The extension read the same 383-byte VPN configuration as the host app.
- The tunnel reached `running` and acquired `10.18.18.3/24` via DHCP.
- The OS installed utun3 with MTU 1360; the core bound TUN descriptor 5.
- Mac (`10.18.18.2`) to iPhone: 4/4 ICMP replies, 0% loss.
- iPhone to Mac: 4/4 ICMP replies, 0% loss.
- The existing Swift tunnel lifecycle and profile selection suites passed.

Immediately after the first reinstall, iOS rebuilt its application UUID cache.
A network settings request waited long enough to trigger the core's existing
20-second setup timeout. Retrying after the cache rebuild completed succeeded;
no additional DHCP or routing code change was needed.

## Manual connection crash correction

A subsequent user report exposed an incomplete first package: it included the
shared-preferences fix but retained an old host binary (UUID
`A21B5791-AC16-32FA-93A3-5C78DD1E89CF`). Pressing Connect hit the old Swift async
`saveToPreferences` continuation and crashed with EXC_BAD_ACCESS at 0x18 in
`swift_continuation_throwingResume`. The earlier direct tunnel start probe did
not exercise that UI path.

The corrected package overlays the freshly built host with
`VPNPreferencesCompatibility` (UUID `DA11B022-2B28-3134-8527-E1AE5A36376B`).
The installed executable UUID was checked against the fresh build. Packaging
now requires `--host-app` and rejects binaries missing the async compatibility
implementation rather than silently reusing an old host. The host
links the compatibility category statically; only the prebuilt extension needs
the compatibility dylib.

Device validation used HID touch events through UIKit to press the actual
Connect and Disconnect buttons, including a subsequent reconnect. Screenshots
confirmed the running and disconnected states. No direct NETunnelProviderManager
start was used for this UI validation.

## 内存峰值与状态查询分配

VPN 扩展导出系统日志时，原实现从开机开始枚举，并把所有格式化日志追加到单个字符串，最后再编码写入文件。峰值随历史日志长度增长。现改为从最近日志开始惰性枚举、逐条写入文件，输出最多 8 MiB，并在达到限制时写入截断提示；空结果或失败时清理未完成文件，单次导出复用日期格式器。顺序为从新到旧。

模拟 200,000 条、每条约 1,000 字符的日志，在 macOS 上以优化构建测量：原拼接方式输出 201,488,890 字节，最大 RSS 473,317,376 字节；流式限额方式输出 8,387,963 字节，最大 RSS 4,194,304 字节。输出范围有意不同：新实现限制了导出大小。此结果证明原导出路径能够超过设备上约 150 MiB 的扩展限额，但不能证明历史 Jetsam 发生时用户正在导出日志。

Rust `get_running_info` 原先调用上游 `collect_network_infos_sync`。v2.6.4 的该方法每次创建新的 Tokio Runtime；界面周期性查询会反复创建并销毁线程池及相关调度资源。现复用进程既有运行时，通过 `get_network_info` 仅获取当前实例快照，保持返回 JSON 和 CString 释放约定。此处修复的是重复分配，不将它表述为已证实的永久泄漏。

`bash tests/run-swift-tests.sh` 增加日志导出的 UTF-8、惰性枚举、文件大小上限、截断提示与失败清理检查。Rust 生命周期测试增加每次启动后的 64 次真实状态查询及返回字符串释放检查。

本次验证：Rust `cargo test --lib --locked` 33 项全部通过（含跨两次会话共 128 次状态查询）；Swift 隧道生命周期、配置持久化、Profile 选择及日志边界检查全部通过；修改后的日志模块按 `arm64-apple-ios15.0` 编译通过。完整真机播放/VPN 压力场景仍需单独运行；这些结果不等同于已复现并消除了每一次历史 Jetsam。

### 优化版安装与真机检查（2026-11-04）

1.2.3 / build 11 已安装到 iPhone SE / iOS 15.7.5；主应用和 VPN 扩展均重新构建，未复用旧 Rust 核心。设备扩展与本地构建的 Mach-O UUID 均为 `2B0D229A-8F1B-3873-A166-E9C2B1925026`。

通过实际“连接”按钮启动隧道；电脑与手机经 VPN 双向各 4 次 ICMP 检查均无丢包。通过正式 Provider 消息接口连续查询 200 次状态，完成时间约 760 ms；系统日志导出成功，生成文件 320,677 字节。测试中扩展物理内存从冷启动约 9 MiB 增至约 38 MiB，观察到的生命周期峰值约 40 MiB，低于此前设备报告的约 150 MiB 限额。冷启动与多小时运行不能直接比较，仍需后续长时间观察是否持续增长。测试结束隧道保持连接，原网络配置和应用数据保留。
