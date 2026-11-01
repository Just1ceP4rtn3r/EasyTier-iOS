#!/usr/bin/env python3
"""Package an existing arm64 app and tunnel extension for iOS 15 TrollStore.

TrollStore signs the IPA on installation. Existing entitlements are preserved.
This can reuse a previously built Rust extension when no Rust toolchain is installed.
"""
import argparse
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile


def add_library(binary: Path, library: str) -> None:
    data = bytearray(binary.read_bytes())
    header = list(struct.unpack_from('<8I', data))
    if header[0] != 0xFEEDFACF:
        raise ValueError(f'{binary}: an arm64 Mach-O executable is required')
    encoded = library.encode() + b'\0'
    pos = 32
    for _ in range(header[4]):
        kind, size = struct.unpack_from('<2I', data, pos)
        if kind == 0xC and encoded in data[pos:pos + size]:
            return
        pos += size
    size = (24 + len(encoded) + 7) // 8 * 8
    command = struct.pack('<6I', 0xC, size, 24, 0, 0x10000, 0x10000) + encoded
    command += bytes(size - len(command))
    end = 32 + header[5]
    if any(data[end:end + size]) or len(data[end:end + size]) != size:
        raise ValueError(f'{binary}: insufficient load-command padding')
    data[end:end + size] = command
    header[4] += 1
    header[5] += size
    struct.pack_into('<8I', data, 0, *header)
    binary.write_bytes(data)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--host-app', type=Path, required=True, help='overlay a freshly built host app while retaining the input tunnel extension')
    args = parser.parse_args()
    original = args.app.resolve()
    output = args.output.resolve()
    extension = original / 'PlugIns/EasyTierNetworkExtension.appex/EasyTierNetworkExtension'
    if not extension.is_file():
        parser.error('the input .app must include EasyTierNetworkExtension.appex; a main-app-only build cannot provide VPN service')
    if output.exists():
        parser.error('output already exists; use a new path to preserve the previous IPA')
    host_binary = args.host_app.resolve() / 'EasyTier'
    if not host_binary.is_file() or b'VPNPreferencesCompatibility' not in host_binary.read_bytes():
        parser.error('--host-app must be rebuilt from this source with the iOS 15 VPN async-preferences compatibility fix')
    source = Path(__file__).resolve().parents[1] / 'EasyTierShared/SharedPreferencesCompatibility.m'
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='easytier-ios15-') as tmp:
        root = Path(tmp)
        app = root / 'Payload/EasyTier.app'
        app.parent.mkdir()
        shutil.copytree(original, app)
        if args.host_app:
            host = args.host_app.resolve()
            if not (host / 'EasyTier').is_file():
                parser.error('--host-app must contain a freshly built EasyTier executable')
            entitlements = root / 'host.entitlements'
            entitlements.write_bytes(subprocess.run(
                ['codesign', '-d', '--entitlements', ':-', str(original)],
                capture_output=True, check=True).stdout)
            shutil.copytree(host, app, dirs_exist_ok=True)
            subprocess.run(['codesign', '-f', '-s', '-', '--timestamp=none',
                            '--generate-entitlement-der', '--entitlements', str(entitlements),
                            str(app)], check=True)
        dylib = root / 'SharedPreferencesCompatibility.dylib'
        subprocess.run(['xcrun', '--sdk', 'iphoneos', 'clang', '-arch', 'arm64',
                        '-miphoneos-version-min=15.0', '-fobjc-arc', '-dynamiclib',
                        '-framework', 'Foundation', '-install_name', '@rpath/' + dylib.name,
                        str(source), '-o', str(dylib)], check=True)
        subprocess.run(['codesign', '-f', '-s', '-', str(dylib)], check=True)
        for bundle, name in [(app, 'EasyTier'), (app / 'PlugIns/EasyTierNetworkExtension.appex', 'EasyTierNetworkExtension')]:
            # A freshly built host links the same compatibility category from
            # EasyTierShared. Only prebuilt binaries need dylib injection.
            if b'et_sharedPreferencesCompatibilityInstalled\0' not in (bundle / name).read_bytes():
                shutil.copy2(dylib, bundle / dylib.name)
                add_library(bundle / name, '@loader_path/' + dylib.name)
        subprocess.run(['/usr/bin/zip', '-qry', str(output), 'Payload'], cwd=root, check=True)
    print(output)


if __name__ == '__main__':
    main()
