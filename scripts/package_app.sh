#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="iMon"
BUNDLE_ID="dev.imon.iMon"
BUILD_CONFIG="release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"

echo "Building $APP_NAME ($BUILD_CONFIG)..."
swift build -c "$BUILD_CONFIG" --product "$APP_NAME"
BIN_DIR="$(swift build -c "$BUILD_CONFIG" --product "$APP_NAME" --show-bin-path)"
EXECUTABLE="$BIN_DIR/$APP_NAME"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"
ASSETS_CAR="$ROOT_DIR/Resources/Assets.car"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Expected executable was not produced: $EXECUTABLE" >&2
  exit 1
fi

if [[ ! -s "$ICON_FILE" ]]; then
  echo "Missing app icon: $ICON_FILE" >&2
  echo "Run: swift scripts/generate_app_icon.swift" >&2
  exit 1
fi

if [[ ! -s "$ASSETS_CAR" ]]; then
  echo "Missing app icon asset catalog: $ASSETS_CAR" >&2
  echo "Run: swift scripts/generate_app_icon.swift" >&2
  exit 1
fi

echo "Creating $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
cp "$ICON_FILE" "$RESOURCES_DIR/AppIcon.icns"
cp "$ASSETS_CAR" "$RESOURCES_DIR/Assets.car"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

cat > "$CONTENTS_DIR/PkgInfo" <<PKGINFO
APPL????
PKGINFO

if command -v codesign >/dev/null 2>&1; then
  echo "Ad-hoc signing $APP_DIR..."
  codesign --force --sign - "$APP_DIR" >/dev/null
fi

echo "Packaged app: $APP_DIR"
