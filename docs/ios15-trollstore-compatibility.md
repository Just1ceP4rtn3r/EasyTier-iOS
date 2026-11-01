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
