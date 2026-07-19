#!/bin/bash
# ──────────────────────────────────────────────
# ClassDumpDylib — 本地 / 设备编译
# 用法: sh build.sh
# ──────────────────────────────────────────────

set -e

PROJECT="ClassDumpDylib"
FILES="ClassDumpEntry.m ClassDumpSearcher.m SearchOverlayWindow.m MethodHacker.m UserDefaultsEditor.m"
OUTDIR="packages"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════${NC}"
echo -e "${CYAN}  ClassDumpDylib 构建脚本${NC}"
echo -e "${CYAN}═══════════════════════════════════${NC}"

if command -v xcrun &> /dev/null; then
    SYSROOT=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
    echo "[✓] 使用 macOS xcrun, SDK: $SYSROOT"
elif [ -n "$THEOS" ]; then
    SYSROOT=$(ls -d "$THEOS/sdks/"iPhoneOS*.sdk 2>/dev/null | head -1)
    if [ -z "$SYSROOT" ]; then
        echo "[!] 未找到 iOS SDK，尝试直接用 clang..."
        SYSROOT=""
    else
        echo "[✓] 使用 Theos SDK: $SYSROOT"
    fi
else
    if command -v clang &> /dev/null; then
        echo "[!] 未找到 SDK 路径，尝试直接编译（iOS 设备）"
        SYSROOT=""
    else
        echo -e "${RED}[-] 错误：未找到 clang 编译器${NC}"
        exit 1
    fi
fi

mkdir -p "$OUTDIR"

CMD="clang -shared -fobjc-arc -I."
if [ -n "$SYSROOT" ]; then
    CMD="$CMD -isysroot \"$SYSROOT\""
fi
CMD="$CMD -arch arm64"
CMD="$CMD -miphoneos-version-min=14.0"
CMD="$CMD -lobjc -framework UIKit -framework Foundation -framework QuartzCore"
CMD="$CMD $FILES"
CMD="$CMD -o $OUTDIR/$PROJECT.dylib"

echo ""
echo "[...] 执行: $CMD"
echo ""

eval $CMD

echo ""
echo -e "${GREEN}[✓] 编译成功!${NC}"
echo "    输出: $OUTDIR/$PROJECT.dylib"
echo "    大小: $(wc -c < $OUTDIR/$PROJECT.dylib | tr -d ' ') 字节"
echo ""
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo "  使用方法:"
echo "  1. 将 $OUTDIR/$PROJECT.dylib 复制到 iOS 设备"
echo "  2. insert_dylib / TrollInject 注入目标 App"
echo "  3. 双指长按 0.6s 或 音量+连按 3 次 呼出面板"
echo -e "${CYAN}═══════════════════════════════════${NC}"
