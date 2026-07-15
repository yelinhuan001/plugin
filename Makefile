# ============================================================
# iOS 14 巨魔 (TrollStore) dylib 插件
# 依赖: Theos (https://theos.dev)
# 用法:
#   make package   # 编译并打包
#   make clean
# ============================================================

TARGET := iphone:clang:14.5:14.0
ARCHS  := arm64
# 若设备为 arm64e (A12+) 且需要，可改为: arm64 arm64e

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

# 插件名（最终产物: TrollDylibPlugin.dylib）
TWEAK_NAME = TrollDylibPlugin

TrollDylibPlugin_FILES = src/Tweak.x src/HookHelper.m src/fishhook.c
TrollDylibPlugin_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations
TrollDylibPlugin_FRAMEWORKS = UIKit Foundation
TrollDylibPlugin_LDFLAGS = -Wl,-install_name,@rpath/TrollDylibPlugin.dylib

# 仅当设备有 Cydia Substrate / ElleKit 时启用
# 巨魔纯注入场景通常不用 Substrate，用 fishhook + method swizzle
# TrollDylibPlugin_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

# 额外：输出裸 dylib，方便 TrollFools / 巨魔助手 注入
after-all::
	@mkdir -p packages
	@if [ -f $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib ]; then \
		cp -f $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib packages/$(TWEAK_NAME).dylib; \
		echo "[*] 已输出: packages/$(TWEAK_NAME).dylib"; \
	fi
