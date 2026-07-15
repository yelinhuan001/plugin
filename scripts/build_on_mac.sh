#!/usr/bin/env bash
# 在 macOS 上一键编译巨魔可用 dylib
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcrun >/dev/null 2>&1; then
  echo "[!] 需要安装 Xcode Command Line Tools"
  exit 1
fi

SDK="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || true)"
if [[ -z "${SDK}" || ! -d "${SDK}" ]]; then
  echo "[!] 找不到 iphoneos SDK，请安装完整 Xcode"
  exit 1
fi

echo "[*] SDK: $SDK"
make -f Makefile.standalone clean || true
make -f Makefile.standalone

DYLIB="$ROOT/packages/TrollDylibPlugin.dylib"
if [[ -f "$DYLIB" ]]; then
  echo ""
  echo "========================================"
  echo " 编译成功"
  echo " 文件: $DYLIB"
  file "$DYLIB" || true
  otool -hv "$DYLIB" 2>/dev/null | head -20 || true
  echo "========================================"
  echo " 下一步: 用 TrollFools 注入到目标 App"
else
  echo "[!] 未生成 dylib"
  exit 1
fi
