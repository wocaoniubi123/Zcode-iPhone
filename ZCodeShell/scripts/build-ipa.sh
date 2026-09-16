#!/bin/bash
# 构建 unsigned IPA：XcodeGen 生成工程 → xcodebuild(iphoneos) → Payload → zip
# 单元测试不在本脚本（workflow 已单独跑）。用法: ./scripts/build-ipa.sh [输出目录]
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="${1:-dist}"
command -v xcodegen >/dev/null || { echo "需要 xcodegen (brew install xcodegen)"; exit 1; }

echo "==> XcodeGen 生成工程"
xcodegen generate

echo "==> 构建 iphoneos（未签名）"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
xcodebuild build \
  -project ZCodeShell.xcodeproj \
  -scheme ZCodeShell \
  -sdk iphoneos \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -quiet \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY= \

APP="$BUILD_DIR/Build/Products/Release-iphoneos/ZCodeShell.app"
[ -d "$APP" ] || { echo "构建产物不存在: $APP"; exit 1; }

echo "==> 组装 Payload → IPA"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/Payload"
cp -R "$APP" "$OUT_DIR/Payload/"
(cd "$OUT_DIR" && zip -qry ZCodeShell.ipa Payload && rm -rf Payload)

echo "==> 完成: $OUT_DIR/ZCodeShell.ipa (unsigned，用 Sideloadly/AltStore 重签安装)"
