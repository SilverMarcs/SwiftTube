#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: \$(basename "\$0") [platform] [options]

Platforms:
  macos        Build and run on macOS
  ios          Build and run on iOS Simulator (iPhone)
  ipad         Build and run on iPadOS Simulator (iPad)
  tvos         Build and run on tvOS Simulator (latest Apple TV)
  (default)    Auto-detected from project SDKROOT

Options:
  --device     iOS/iPadOS/tvOS only: install and run on a connected device
  --open       macOS only: launch via 'open' for proper bundle identity
  --build      Archive Release build and copy .app/.ipa to ~/Downloads
  -h, --help   Show this help

Examples:
  \$(basename "\$0")                # auto-detect platform
  \$(basename "\$0") macos --open
  \$(basename "\$0") macos --build
  \$(basename "\$0") ios
  \$(basename "\$0") ipad
  \$(basename "\$0") ios --device
  \$(basename "\$0") ios --build
  \$(basename "\$0") tvos
  \$(basename "\$0") tvos --device
  \$(basename "\$0") tvos --build
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE_ID_RE='([0-9A-F]{8}-[0-9A-F]{16}|[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12})'

PROJECT=$(ls -d "$ROOT_DIR"/*.xcodeproj 2>/dev/null | head -1)
if [[ -z "${PROJECT:-}" ]]; then
  echo "error: no .xcodeproj found in $ROOT_DIR" >&2
  exit 1
fi
APP_NAME=$(basename "$PROJECT" .xcodeproj)
BUNDLE_ID=$(grep -m1 PRODUCT_BUNDLE_IDENTIFIER "$PROJECT/project.pbxproj" \
  | sed 's/.*= //;s/;.*//;s/"//g' | tr -d '[:space:]')
PRODUCT_NAME=$(grep -m1 -E '^[[:space:]]*"?PRODUCT_NAME"?[[:space:]]*=' "$PROJECT/project.pbxproj" \
  | sed 's/.*= //;s/;.*//;s/"//g' | tr -d '[:space:]')
if [[ -z "$PRODUCT_NAME" || "$PRODUCT_NAME" == *'$'* ]]; then
  PRODUCT_NAME="$APP_NAME"
fi

DEFAULT_SDK=$(grep -m1 -E '^\s*SDKROOT' "$PROJECT/project.pbxproj" \
  | sed 's/.*= //;s/;.*//;s/"//g' | tr -d '[:space:]')
case "$DEFAULT_SDK" in
  macosx)    PLATFORM="macos" ;;
  iphoneos)  PLATFORM="ios" ;;
  appletvos) PLATFORM="tvos" ;;
  *)         PLATFORM="macos" ;;
esac

USE_DEVICE=0
MAC_MODE="run"
DO_BUILD=0

PLATFORM_EXPLICIT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    macos|mac)   PLATFORM="macos"; PLATFORM_EXPLICIT=1 ;;
    ios)         PLATFORM="ios"; PLATFORM_EXPLICIT=1 ;;
    ipad|ipados) PLATFORM="ipad"; PLATFORM_EXPLICIT=1 ;;
    tvos|tv)     PLATFORM="tvos"; PLATFORM_EXPLICIT=1 ;;
    --device)    USE_DEVICE=1; [[ "$PLATFORM_EXPLICIT" == "1" ]] || PLATFORM="ios" ;;
    --open)      MAC_MODE="open" ;;
    --build)     MAC_MODE="build"; DO_BUILD=1 ;;
    -h|--help)   usage; exit 0 ;;
    *)           echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

filter_xcodebuild() {
  awk '
    /: (warning|note):/ { skip = 1; next }
    /: (error|fatal error):/ { skip = 0; print; next }
    /^\*\* / { skip = 0; print; next }
    skip { next }
    { print }
  '
}

resolve_dependencies() {
  echo "Resolving Swift Package dependencies..."
  xcodebuild -project "$PROJECT" -resolvePackageDependencies -quiet || true
}

find_app_bundle() {
  local destination="$1"
  local bundle
  # Ask the same project/configuration/destination we just built. Directory
  # timestamps across DerivedData folders do not identify the current build.
  bundle=$(xcodebuild -project "$PROJECT" -scheme "$APP_NAME" \
    -configuration Debug -destination "$destination" -showBuildSettings | \
    awk -v target="$APP_NAME" '
      /^Build settings for action / {
        selected = ($0 == "Build settings for action build and target " target ":")
      }
      selected && / = / {
        key = $1
        value = $0
        sub(/^[[:space:]]*[^=]+ = /, "", value)
        if (key == "TARGET_BUILD_DIR") directory = value
        if (key == "FULL_PRODUCT_NAME") product = value
      }
      END {
        if (directory == "" || product == "") exit 1
        print directory "/" product
      }') || {
    echo "error: could not resolve the built app for $PROJECT ($destination)" >&2
    return 1
  }
  if [[ ! -d "$bundle" ]]; then
    echo "error: built app not found at $bundle" >&2
    return 1
  fi
  echo "Using built app: $bundle" >&2
  echo "$bundle"
}

build_macos() {
  local ARCHIVE="/tmp/$APP_NAME.xcarchive"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "generic/platform=macOS" \
    -configuration Release \
    -allowProvisioningUpdates \
    archive -archivePath "$ARCHIVE" 2>&1 | filter_xcodebuild

  local SRC_APP DISPLAY_NAME DEST_NAME
  SRC_APP=$(ls -d "$ARCHIVE/Products/Applications/"*.app | head -1)
  DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$SRC_APP/Contents/Info.plist" 2>/dev/null || true)
  if [[ -n "$DISPLAY_NAME" ]]; then
    DEST_NAME="$DISPLAY_NAME.app"
  else
    DEST_NAME="$(basename "$SRC_APP")"
  fi
  rm -rf "$HOME/Downloads/$DEST_NAME"
  cp -R "$SRC_APP" "$HOME/Downloads/$DEST_NAME"
  rm -rf "$ARCHIVE"
  echo "Built $DEST_NAME → ~/Downloads/"
}

build_ios() {
  local ARCHIVE="/tmp/$APP_NAME.xcarchive"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "generic/platform=iOS" \
    -configuration Release \
    -allowProvisioningUpdates \
    archive -archivePath "$ARCHIVE" 2>&1 | filter_xcodebuild
  mkdir -p /tmp/ipa_payload/Payload
  cp -R "$ARCHIVE/Products/Applications/"*.app /tmp/ipa_payload/Payload/
  cd /tmp/ipa_payload && zip -qr ~/Downloads/"$PRODUCT_NAME.ipa" Payload
  rm -rf "$ARCHIVE" /tmp/ipa_payload
  echo "Built $PRODUCT_NAME.ipa → ~/Downloads/"
}

run_macos() {
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "platform=macOS" \
    -allowProvisioningUpdates \
    -configuration Debug \
    -quiet \
    build 2>&1 | filter_xcodebuild

  local APP_BUNDLE APP_BIN APP_PID
  APP_BUNDLE=$(find_app_bundle "platform=macOS")
  APP_BIN="$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"

  cleanup() {
    if [[ "$MAC_MODE" == "open" ]]; then
      osascript -e "tell application \"$PRODUCT_NAME\" to quit" 2>/dev/null || true
    else
      kill "$APP_PID" 2>/dev/null || true
    fi
  }

  if [[ "$MAC_MODE" == "open" ]]; then
    open -W "$APP_BUNDLE" &
  else
    "$APP_BIN" &
  fi
  APP_PID=$!
  trap cleanup INT TERM EXIT
  wait $APP_PID
}

run_ios_device() {
  local DEVICE_TYPE="${1:-iPhone}"
  local DEVICE_ID
  DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null \
    | awk -v dev="$DEVICE_TYPE" '!/unavailable/ && !/simulated/ && $0 ~ dev' \
    | grep -oE "$DEVICE_ID_RE" \
    | head -1 || true)
  if [[ -z "${DEVICE_ID:-}" ]]; then
    echo "error: no available $DEVICE_TYPE device found" >&2
    exit 1
  fi
  echo "Using device: $DEVICE_ID"

  xcrun devicectl device process terminate \
    --device "$DEVICE_ID" --bundle-identifier "$BUNDLE_ID" >/dev/null 2>&1 || true

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    -configuration Debug \
    -quiet \
    build 2>&1 | filter_xcodebuild

  local APP_BUNDLE
  APP_BUNDLE=$(find_app_bundle "id=$DEVICE_ID")
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP_BUNDLE"

  xcrun devicectl device process launch --console --device "$DEVICE_ID" "$BUNDLE_ID" &
  LAUNCH_PID=$!
  trap "kill \$LAUNCH_PID 2>/dev/null || true; xcrun devicectl device process terminate --device '$DEVICE_ID' --bundle-identifier '$BUNDLE_ID' >/dev/null 2>&1 || true" EXIT
  wait $LAUNCH_PID
  trap - EXIT
}

run_ios_simulator() {
  local SIM_PATTERN="${1:-iPhone.* Pro \(}"
  local SIM_NAME="${2:-iPhone Pro}"
  local SIM_ID
  SIM_ID=$(xcrun simctl list devices available \
    | grep -E "$SIM_PATTERN" \
    | head -1 \
    | grep -oE "$DEVICE_ID_RE")
  if [[ -z "${SIM_ID:-}" ]]; then
    echo "error: no $SIM_NAME simulator found" >&2
    exit 1
  fi
  echo "Using simulator: $SIM_ID"

  xcrun simctl boot "$SIM_ID" 2>/dev/null || true
  open -g -a Simulator

  xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "platform=iOS Simulator,id=$SIM_ID" \
    -allowProvisioningUpdates \
    -configuration Debug \
    -quiet \
    build 2>&1 | filter_xcodebuild

  local APP_BUNDLE
  APP_BUNDLE=$(find_app_bundle "platform=iOS Simulator,id=$SIM_ID")
  xcrun simctl install "$SIM_ID" "$APP_BUNDLE"
  open -a Simulator

  xcrun simctl launch --console-pty --terminate-running-process "$SIM_ID" "$BUNDLE_ID" &
  LAUNCH_PID=$!
  trap "kill \$LAUNCH_PID 2>/dev/null || true; xcrun simctl terminate '$SIM_ID' '$BUNDLE_ID' >/dev/null 2>&1 || true" EXIT
  wait $LAUNCH_PID
  trap - EXIT
}

build_tvos() {
  local ARCHIVE="/tmp/$APP_NAME.xcarchive"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "generic/platform=tvOS" \
    -configuration Release \
    -allowProvisioningUpdates \
    archive -archivePath "$ARCHIVE" 2>&1 | filter_xcodebuild
  mkdir -p /tmp/ipa_payload/Payload
  cp -R "$ARCHIVE/Products/Applications/"*.app /tmp/ipa_payload/Payload/
  cd /tmp/ipa_payload && zip -qr ~/Downloads/"$PRODUCT_NAME-tvos.ipa" Payload
  rm -rf "$ARCHIVE" /tmp/ipa_payload
  echo "Built $PRODUCT_NAME-tvos.ipa → ~/Downloads/"
}

run_tvos_device() {
  local DEVICE_ID
  DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null \
    | awk '!/unavailable/ && !/simulated/ && /Apple ?TV/' \
    | grep -oE "$DEVICE_ID_RE" \
    | head -1 || true)
  if [[ -z "${DEVICE_ID:-}" ]]; then
    echo "error: no available Apple TV device found" >&2
    exit 1
  fi
  echo "Using device: $DEVICE_ID"

  xcrun devicectl device process terminate \
    --device "$DEVICE_ID" --bundle-identifier "$BUNDLE_ID" >/dev/null 2>&1 || true

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    -configuration Debug \
    -quiet \
    build 2>&1 | filter_xcodebuild

  local APP_BUNDLE
  APP_BUNDLE=$(find_app_bundle "id=$DEVICE_ID")
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP_BUNDLE"

  xcrun devicectl device process launch --console --device "$DEVICE_ID" "$BUNDLE_ID" &
  LAUNCH_PID=$!
  trap "kill \$LAUNCH_PID 2>/dev/null || true; xcrun devicectl device process terminate --device '$DEVICE_ID' --bundle-identifier '$BUNDLE_ID' >/dev/null 2>&1 || true" EXIT
  wait $LAUNCH_PID
  trap - EXIT
}

run_tvos_simulator() {
  local SIM_ID
  SIM_ID=$(xcrun simctl list devices available \
    | awk '/-- tvOS /{rt=$0} /Apple TV/{print rt"\t"$0}' \
    | sort -t' ' -k3,3V \
    | tail -1 \
    | grep -oE "$DEVICE_ID_RE")
  if [[ -z "${SIM_ID:-}" ]]; then
    SIM_ID=$(xcrun simctl list devices available \
      | grep -E "Apple TV.*\(" \
      | tail -1 \
      | grep -oE "$DEVICE_ID_RE")
  fi
  if [[ -z "${SIM_ID:-}" ]]; then
    echo "error: no Apple TV simulator found" >&2
    exit 1
  fi
  echo "Using simulator: $SIM_ID"

  xcrun simctl boot "$SIM_ID" 2>/dev/null || true
  open -g -a Simulator

  xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" >/dev/null 2>&1 || true

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -destination "platform=tvOS Simulator,id=$SIM_ID" \
    -allowProvisioningUpdates \
    -configuration Debug \
    -quiet \
    build 2>&1 | filter_xcodebuild

  local APP_BUNDLE
  APP_BUNDLE=$(find_app_bundle "platform=tvOS Simulator,id=$SIM_ID")
  xcrun simctl install "$SIM_ID" "$APP_BUNDLE"
  open -a Simulator

  xcrun simctl launch --console-pty --terminate-running-process "$SIM_ID" "$BUNDLE_ID" &
  LAUNCH_PID=$!
  trap "kill \$LAUNCH_PID 2>/dev/null || true; xcrun simctl terminate '$SIM_ID' '$BUNDLE_ID' >/dev/null 2>&1 || true" EXIT
  wait $LAUNCH_PID
  trap - EXIT
}

resolve_dependencies

case "$PLATFORM" in
  macos)
    if [[ "$MAC_MODE" == "build" ]]; then
      build_macos
    else
      run_macos
    fi
    ;;
  ios)
    if [[ "$DO_BUILD" == "1" ]]; then
      build_ios
    elif [[ "$USE_DEVICE" == "1" ]]; then
      run_ios_device "iPhone"
    else
      run_ios_simulator "iPhone.* Pro \(" "iPhone Pro"
    fi
    ;;
  ipad)
    if [[ "$DO_BUILD" == "1" ]]; then
      build_ios
    elif [[ "$USE_DEVICE" == "1" ]]; then
      run_ios_device "iPad"
    else
      run_ios_simulator "iPad.* \(" "iPad"
    fi
    ;;
  tvos)
    if [[ "$DO_BUILD" == "1" ]]; then
      build_tvos
    elif [[ "$USE_DEVICE" == "1" ]]; then
      run_tvos_device
    else
      run_tvos_simulator
    fi
    ;;
  *) echo "error: unknown platform '$PLATFORM'" >&2; exit 2 ;;
esac
