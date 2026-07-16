# ─── 项目 ───
PROJECT = ClassDumpDylib
FILES   = ClassDumpEntry.m ClassDumpSearcher.m SearchOverlayWindow.m
CFLAGS  = -fobjc-arc -I.
LDFLAGS = -lobjc -framework UIKit -framework Foundation

# ─── 架构 ───
ARCHS = arm64 arm64e

# ─── 输出 ───
OUTDIR = packages

# ─── 检测 Theos ───
ifdef THEOS
include $(THEOS)/makefiles/common.mk

# 用 tool 类型 + 手动改后缀为 .dylib
TOOL_NAME = $(PROJECT)
$(PROJECT)_FILES = $(FILES)
$(PROJECT)_CFLAGS = $(CFLAGS)
$(PROJECT)_LDFLAGS = $(LDFLAGS)
$(PROJECT)_INSTALL_PATH = /usr/lib

include $(THEOS_MAKE_PATH)/tool.mk

# 编译后重命名为 .dylib
after-$(PROJECT):: 
	@echo "[✓] 编译完成，输出: $(OUTDIR)/$(PROJECT).dylib"
else
# ─── 不使用 Theos：直接用 clang 编译 ───
# 需要在 iOS 设备上运行，有 iOS SDK 可用
SYSROOT ?= $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
ifeq ($(SYSROOT),)
SYSROOT = $(THEOS)/sdks/iPhoneOS14.5.sdk
endif

all:
	@mkdir -p $(OUTDIR)
	@echo "[...] 使用 SDK: $(SYSROOT)"
	clang -shared \
		$(CFLAGS) \
		-isysroot "$(SYSROOT)" \
		-arch arm64 -arch arm64e \
		-miphoneos-version-min=14.0 \
		$(LDFLAGS) \
		$(FILES) \
		-o $(OUTDIR)/$(PROJECT).dylib
	@echo "[✓] 编译完成: $(OUTDIR)/$(PROJECT).dylib"

clean:
	rm -rf $(OUTDIR)
endif
