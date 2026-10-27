#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
harness_root="$PWD"
ultra_root="$(cd ../Milyonus-Agent-Ultra && pwd)"
swift build --package-path "$ultra_root" -j 4
ultra_bin="$(swift build --package-path "$ultra_root" --show-bin-path)/MilyonusAgentUltra"
preview_app="$harness_root/build/UltraComputerUsePreview.app"
mkdir -p "$preview_app/Contents/MacOS"
cp "$ultra_bin" "$preview_app/Contents/MacOS/MilyonusAgentUltra.new"
mv "$preview_app/Contents/MacOS/MilyonusAgentUltra.new" "$preview_app/Contents/MacOS/MilyonusAgentUltra"
python3 - "$preview_app" <<'PY'
import plistlib,sys
from pathlib import Path
info={'CFBundleIdentifier':'com.milyonus.computeruse.ultrapreview','CFBundleExecutable':'MilyonusAgentUltra',
      'CFBundleName':'UltraComputerUsePreview','CFBundleDisplayName':'Ultra Computer Use Preview',
      'CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.1.0','CFBundleVersion':'1',
      'LSMinimumSystemVersion':'14.0','NSHighResolutionCapable':True}
Path(sys.argv[1],'Contents','Info.plist').write_bytes(plistlib.dumps(info))
PY
codesign --force --sign - --options runtime "$preview_app"
codesign --verify --strict "$preview_app"
printf 'Isolated development preview: %s\n' "$preview_app"
