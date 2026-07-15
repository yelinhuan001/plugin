# Theos 编译（可选）
TARGET := iphone:clang:14.5:14.0
ARCHS  := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TrollDylibPlugin

TrollDylibPlugin_FILES = \
	src/TweakStandalone.m \
	src/TDPConfig.m \
	src/TDPFloatingBall.m \
	src/TDPVipEngine.m \
	src/TDPAdBlocker.m \
	src/HookHelper.m \
	src/fishhook.c

TrollDylibPlugin_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations
TrollDylibPlugin_FRAMEWORKS = UIKit Foundation
TrollDylibPlugin_LDFLAGS = -Wl,-install_name,@rpath/TrollDylibPlugin.dylib

include $(THEOS_MAKE_PATH)/tweak.mk

after-all::
	@mkdir -p packages
	@if [ -f $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib ]; then \
		cp -f $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib packages/$(TWEAK_NAME).dylib; \
		echo "[*] packages/$(TWEAK_NAME).dylib"; \
	fi
