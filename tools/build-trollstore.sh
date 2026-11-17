#!/bin/bash
# Builds a complete iOS 14+ IPA with a finite per-tunnel memory allowance.
set -euo pipefail
cd "$(dirname "$0")/.."
export LC_ALL=en_US.UTF-8
output="${OUTPUT_DIR:-$PWD/build/trollstore}"
export TEAM_ID="${TEAM_ID:-M2G6355ZK7}"
mkdir -p "$output"
xcodebuild -project EasyTier.xcodeproj -scheme EasyTier -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$output/DerivedData" \
  CODE_SIGNING_ALLOWED=NO 'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) TROLLSTORE_BUILD' build
stage=$(mktemp -d "$output/package.XXXXXX")
python3 - "$output/DerivedData/Build/Products/Release-iphoneos/EasyTier.app" "$stage" <<'PY'
import os,pathlib,plistlib,shutil,subprocess,sys
source,stage=map(pathlib.Path,sys.argv[1:]);app=stage/'Payload/EasyTier.app';shutil.copytree(source,app)
for bundle in [*app.glob('PlugIns/*.appex'),app]:
    name=bundle.stem
    ent=pathlib.Path(name)/('TrollStore.entitlements' if name=='EasyTierNetworkExtension' else name+'.entitlements')
    values=plistlib.loads(ent.read_bytes());info=plistlib.loads((bundle/'Info.plist').read_bytes());bid=info['CFBundleIdentifier']
    values['application-identifier']=os.environ['TEAM_ID']+'.'+bid
    values['com.apple.developer.team-identifier']=os.environ['TEAM_ID']
    if bundle==app:
        values['keychain-access-groups']=[os.environ['TEAM_ID']+'.'+bid]
        values['com.apple.private.networking.vpn.configuration']=True
        values['com.apple.developer.networking.vpn.api']=['allow-vpn']
        values['com.apple.private.security.container-required']=bid
    ep=stage/(name+'.plist');ep.write_bytes(plistlib.dumps(values))
    subprocess.run(['codesign','-f','-s','-','--timestamp=none','--entitlements',str(ep),str(bundle)],check=True)
PY
(cd "$stage" && zip -qry ../EasyTier-compat.ipa Payload)
echo "Built $output/EasyTier-compat.ipa"
