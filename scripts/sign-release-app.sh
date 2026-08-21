#!/usr/bin/env bash
# Sign Atoll.app inside-out for distribution.
#
# Never uses --deep (that copies the app's entitlements onto Sparkle XPC
# helpers and breaks auto-update).
#
# Developer ID / Apple Development: default designated requirement, which is
# Team ID + bundle id. TCC (Accessibility, Screen Recording, …) survives
# Homebrew upgrades that replace the app with a newly signed copy from the
# same certificate.
#
# Ad-hoc fallback: designated requirement is only the bundle identifier, so
# TCC still matches after a new ad-hoc cdhash. Library validation is disabled
# because ad-hoc nested frameworks do not share a Team ID.

set -euo pipefail

usage() {
  echo "Usage: $0 --app <Atoll.app> [--identity <codesign identity>]" >&2
  exit 2
}

app_path=""
identity=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      app_path="${2:-}"
      shift 2
      ;;
    --identity)
      identity="${2:-}"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z "$app_path" || ! -d "$app_path" ]]; then
  usage
fi

app_path="$(cd "$app_path" && pwd)"
bundle_id="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist"
)"

if [[ -z "$identity" ]]; then
  identity="$(
    security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/^[[:space:]]*[0-9]*)[[:space:]]*\([A-F0-9]\{40\}\)[[:space:]]*"Developer ID Application: .*"$/\1/p' \
      | head -1
  )"
fi
if [[ -z "$identity" ]]; then
  identity="-"
fi

is_adhoc=false
if [[ "$identity" == "-" ]]; then
  is_adhoc=true
fi

echo "Signing $app_path"
echo "Bundle id $bundle_id"
if $is_adhoc; then
  echo "Identity ad-hoc (stable identifier designated requirement)"
else
  echo "Identity $identity"
fi

sign_nested() {
  local target="$1"
  echo "  nested $target"
  if $is_adhoc; then
    /usr/bin/codesign --force --sign - --options runtime \
      --preserve-metadata=identifier,entitlements \
      "$target"
  else
    /usr/bin/codesign --force --sign "$identity" --options runtime --timestamp \
      --preserve-metadata=identifier,entitlements \
      "$target"
  fi
}

sign_sparkle() {
  local sparkle="$1"
  local current="$sparkle/Versions/Current"
  if [[ ! -e "$current" ]]; then
    current="$sparkle"
  fi
  if [[ -d "$current/XPCServices" ]]; then
    for xpc in "$current/XPCServices/"*.xpc; do
      [[ -e "$xpc" ]] && sign_nested "$xpc"
    done
  fi
  if [[ -d "$current/Updater.app" ]]; then
    sign_nested "$current/Updater.app"
  fi
  if [[ -x "$current/Autoupdate" ]]; then
    sign_nested "$current/Autoupdate"
  fi
  sign_nested "$sparkle"
}

if [[ -d "$app_path/Contents/MacOS" ]]; then
  # Debug ENABLE_DEBUG_DYLIB drops Atoll.debug.dylib / __preview.dylib next
  # to the executable. Re-signing only the outer app leaves them ad-hoc, and
  # dyld then rejects a Team ID mismatch under library validation.
  for dylib in "$app_path/Contents/MacOS/"*.dylib; do
    [[ -f "$dylib" ]] && sign_nested "$dylib"
  done
fi

if [[ -d "$app_path/Contents/Frameworks" ]]; then
  for framework in "$app_path/Contents/Frameworks/"*.framework; do
    [[ -d "$framework" ]] || continue
    if [[ "$(basename "$framework")" == "Sparkle.framework" ]]; then
      sign_sparkle "$framework"
    else
      sign_nested "$framework"
    fi
  done
  for dylib in "$app_path/Contents/Frameworks/"*.dylib; do
    [[ -f "$dylib" ]] && sign_nested "$dylib"
  done
fi

if [[ -d "$app_path/Contents/XPCServices" ]]; then
  for xpc in "$app_path/Contents/XPCServices/"*.xpc; do
    [[ -d "$xpc" ]] && sign_nested "$xpc"
  done
fi

if [[ -d "$app_path/Contents/Library/LoginItems" ]]; then
  for helper in "$app_path/Contents/Library/LoginItems/"*.app; do
    [[ -d "$helper" ]] && sign_nested "$helper"
  done
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
entitlements="$work_dir/entitlements.plist"

if ! /usr/bin/codesign --display --entitlements - --xml "$app_path" 2>/dev/null > "$entitlements" \
  || ! grep -q "<plist" "$entitlements"; then
  echo "error: could not read entitlements from $app_path" >&2
  exit 1
fi

if $is_adhoc; then
  python3 - "$entitlements" "$bundle_id" <<'PY'
import plistlib
import sys
from pathlib import Path

path = Path(sys.argv[1])
bundle_id = sys.argv[2]
raw = path.read_bytes()
if raw.startswith(b"bplist"):
    data = plistlib.loads(raw)
else:
    text = raw.decode("utf-8")
    start = text.find("<?xml")
    if start < 0:
        start = text.find("<plist")
    if start < 0:
        raise SystemExit(f"{path} is not an entitlements plist")
    data = plistlib.loads(text[start:].encode("utf-8"))
if not isinstance(data, dict):
    raise SystemExit(f"{path} is not an entitlements dictionary")
data["com.apple.security.cs.disable-library-validation"] = True
data.pop("com.apple.security.get-task-allow", None)
lookups = data.get("com.apple.security.temporary-exception.mach-lookup.global-name")
if isinstance(lookups, list):
    data["com.apple.security.temporary-exception.mach-lookup.global-name"] = [
        item.replace("$(PRODUCT_BUNDLE_IDENTIFIER)", bundle_id) if isinstance(item, str) else item
        for item in lookups
    ]
with path.open("wb") as handle:
    plistlib.dump(data, handle)
PY
  /usr/bin/codesign --force --sign - --options runtime \
    --identifier "$bundle_id" \
    --requirements "=designated => identifier \"$bundle_id\"" \
    --entitlements "$entitlements" \
    "$app_path"
else
  /usr/bin/codesign --force --sign "$identity" --options runtime --timestamp \
    --entitlements "$entitlements" \
    "$app_path"
fi

/usr/bin/codesign --verify --verbose=2 "$app_path"
echo "Signed $app_path"
