#!/usr/bin/env bash
set -euo pipefail

copy_settings=false
for arg in "$@"; do
  case "$arg" in
    --copy-settings) copy_settings=true ;;
    *)
      echo "Unknown flag: $arg" >&2
      echo "Usage: $0 [--copy-settings]" >&2
      exit 1
      ;;
  esac
done

script_dir="$(dirname "$0")"
case "$script_dir" in
  /*) root_dir="$(dirname "$script_dir")" ;;
  *) root_dir="$(cd "$script_dir/.." && pwd)" ;;
esac
cd "$root_dir"

derived_data="$root_dir/build/DerivedData"
app_path="$derived_data/Build/Products/Debug/Atoll.app"

# Prefer the identity SHA so codesign does not depend on the display name.
# The parenthetical in "Apple Development: email (XXXX)" is a cert user id,
# not the Team ID — passing it as DEVELOPMENT_TEAM makes xcodebuild fail.
codesign_identity="$(
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/^[[:space:]]*[0-9]*)[[:space:]]*\([A-F0-9]\{40\}\)[[:space:]]*"Apple Development: .*"$/\1/p' \
    | head -1
)"

echo "Building Atoll (Debug)…"
xcodebuild \
  -project DynamicIsland.xcodeproj \
  -scheme DynamicIsland \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="" \
  build

# xcodebuild stays ad-hoc so the project team does not have to match this
# machine. Re-sign with Apple Development so TCC (Accessibility, Screen
# Recording, Full Disk Access) is keyed by Team ID + bundle id and survives
# rebuilds. Sign nested Sparkle helpers individually — never --deep.
if [[ -n "$codesign_identity" ]]; then
  echo "Re-signing with Apple Development ($codesign_identity)"
  "$root_dir/scripts/sign-release-app.sh" --app "$app_path" --identity "$codesign_identity"
else
  echo "No Apple Development identity found; ad-hoc fallback (permissions will reset each run)" >&2
  "$root_dir/scripts/sign-release-app.sh" --app "$app_path" --identity -
fi

xattr -cr "$app_path" || true

osascript -e 'quit app "Atoll"' >/dev/null 2>&1 || true
sleep 0.4

if $copy_settings; then
  prod_defaults="com.Ebullioscopic.Atoll"
  dev_defaults="com.Ebullioscopic.Atoll.dev"
  echo "Copying settings $prod_defaults → $dev_defaults"
  defaults export "$prod_defaults" - | defaults import "$dev_defaults" -
  killall cfprefsd >/dev/null 2>&1 || true
fi

echo "Launching $app_path"
open "$app_path"
