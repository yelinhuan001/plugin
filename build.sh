#!/bin/bash
# ──────────────────────────────────────────────
# ClassDumpDylib — 在 iOS 设备上直接编译
# 用法: sh build.sh
# 前提: 已安装 Theos 或 iOS SDK
# ──────────────────────────────────────────────

set -e

PROJECT="ClassDumpDylib"
FILES="ClassDumpEntry.m ClassDumpSearcher.m SearchOverlayWindow.m"
OUTDIR="packages"

# 颜色
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}═══════════════════════════════════${NC}"
echo -e "${CYAN}  ClassDumpDylib 构建脚本${NC}"
echo -e "${CYAN}═══════════════════════════════════${NC}"

# ── 检测编译工具 ──
if command -v xcrun &> /dev/null; then
    # macOS 环境
    SYSROOT=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
    echo "[✓] 使用 macOS xcrun, SDK: $SYSROOT"
elif [ -n "$THEOS" ]; then
    # Theos 环境（iOS 设备或 macOS）
    SYSROOT=$(ls -d "$THEOS/sdks/"iPhoneOS*.sdk 2>/dev/null | head -1)
    if [ -z "$SYSROOT" ]; then
        echo "[!] 未找到 iOS SDK，尝试直接用 clang..."
        SYSROOT=""
    else
        echo "[✓] 使用 Theos SDK: $SYSROOT"
    fi
else
    # 可能是在 iOS 设备上直接用 clang
    if command -v clang &> /dev/null; then
        echo "[!] 未找到 SDK 路径，尝试直接编译（iOS 设备）"
        SYSROOT=""
    else
        echo "[-] 错误：未找到 clang 编译器"
        echo "   请先安装 Theos 或配置 iOS SDK"
        exit 1
    fi
fi

mkdir -p "$OUTDIR"

# ── 编译命令 ──
CMD="clang -shared -fobjc-arc -I."
if [ -n "$SYSROOT" ]; then
    CMD="$CMD -isysroot \"$SYSROOT\""
fi
CMD="$CMD -arch arm64 -arch arm64e"
CMD="$CMD -miphoneos-version-min=14.0"
CMD="$CMD -lobjc -framework UIKit -framework Foundation"
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
echo "  2. 用 insert_dylib 注入目标 App:"
echo "     insert_dylib ClassDumpDylib.dylib /path/to/App/Binary"
echo "  3. 用 TrollStore 安装修改后的 IPA"
echo -e "${CYAN}═══════════════════════════════════${NC}"
